/**
 * Cloud Functions for is_takip (personel tahsilat & iş takip).
 *
 * These are the only places that may (a) decide who becomes "patron",
 * (b) create automatic ("OTOMATİK") alacak (receivable) entries, and
 * (c) send FCM push notifications — the Flutter client never does any of
 * these directly, both for security (see ../firestore.rules) and so the
 * app works correctly even if two clients race each other.
 */

const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {onDocumentCreated, onDocumentUpdated} =
  require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions");

initializeApp();
const db = getFirestore();

const ROLE_PATRON = "patron";
const ROLE_PERSONEL = "personel";

const NOTIFICATION_TYPE = {
  jobCreated: "job_created",
  jobAssigned: "job_assigned",
  jobApproved: "job_approved",
  jobRejected: "job_rejected",
};

/**
 * First registered user becomes "patron"; everyone after starts as
 * "personel". A single `meta/roles` doc with `patronAssigned` acts as a
 * lock so two simultaneous registrations can't both become patron.
 */
exports.assignPatronRoleOnCreate = onDocumentCreated(
    "users/{uid}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const metaRef = db.collection("meta").doc("roles");
      const role = await db.runTransaction(async (tx) => {
        const metaSnap = await tx.get(metaRef);
        const patronAssigned = metaSnap.exists ?
        Boolean(metaSnap.data().patronAssigned) :
        false;

        if (!patronAssigned) {
          tx.set(metaRef, {patronAssigned: true}, {merge: true});
          return ROLE_PATRON;
        }
        return ROLE_PERSONEL;
      });

      await snap.ref.update({role});
      logger.info(`users/${event.params.uid} role assigned: ${role}`);
    },
);

/**
 * Notifies each uid in [assigneeUids] that they've been assigned to
 * [jobId]. Used both when a patron assigns personnel at creation time and
 * when they add someone to an already-approved job later.
 */
function notifyAssignees(tasks, jobId, job, assigneeUids) {
  for (const uid of assigneeUids) {
    tasks.push(
        db.collection("notifications").add({
          userId: uid,
          title: "Bir işe atandınız",
          body: job.title,
          type: NOTIFICATION_TYPE.jobAssigned,
          read: false,
          jobId,
          createdAt: FieldValue.serverTimestamp(),
        }),
    );
  }
}

/**
 * A personel's new job automatically becomes an alacak (receivable) entry
 * (badged "(OTOMATİK)" client-side) and every patron gets an
 * approval-needed notification. If a patron assigned personnel right at
 * creation, those assignees are notified immediately too.
 */
exports.onJobCreated = onDocumentCreated("jobs/{jobId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const job = snap.data();
  const jobId = event.params.jobId;

  const tasks = [];

  if (typeof job.price === "number" && job.price > 0) {
    tasks.push(
        db.collection("receivables").add({
          title: job.title,
          totalAmount: job.price,
          paidAmount: 0,
          type: "otomatik",
          jobId,
          customerName: job.customerName || null,
          createdBy: job.createdBy || null,
          createdAt: FieldValue.serverTimestamp(),
        }),
    );
  }

  // Patron-created jobs are self-approved (no pending_approval step), so
  // there's nothing for other patrons to be notified about.
  if (job.status === "pending_approval") {
    const patronsSnap = await db
        .collection("users")
        .where("role", "==", ROLE_PATRON)
        .get();

    for (const patronDoc of patronsSnap.docs) {
      // Don't notify a patron about a job they created themselves.
      if (patronDoc.id === job.createdBy) continue;
      tasks.push(
          db.collection("notifications").add({
            userId: patronDoc.id,
            title: "Yeni iş onay bekliyor",
            body: `${job.title} — ${job.customerName || ""}`.trim(),
            type: NOTIFICATION_TYPE.jobCreated,
            read: false,
            jobId,
            createdAt: FieldValue.serverTimestamp(),
          }),
      );
    }
  } else if (Array.isArray(job.assignedTo) && job.assignedTo.length > 0) {
    notifyAssignees(tasks, jobId, job, job.assignedTo);
  }

  await Promise.all(tasks);
});

/**
 * When a patron adds personnel to a job (at approval time or later),
 * push-notify each newly added assignee. When a job is approved or
 * rejected, let the personel who created it know the outcome.
 */
exports.onJobStatusChanged = onDocumentUpdated(
    "jobs/{jobId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      const jobId = event.params.jobId;
      const tasks = [];

      const beforeAssigned = Array.isArray(before.assignedTo) ?
      before.assignedTo :
      [];
      const afterAssigned = Array.isArray(after.assignedTo) ?
      after.assignedTo :
      [];
      const newlyAssigned = afterAssigned.filter(
          (uid) => !beforeAssigned.includes(uid),
      );
      notifyAssignees(tasks, jobId, after, newlyAssigned);

      const justApproved =
        before.status !== "approved" && after.status === "approved";
      const justRejected =
        before.status !== "rejected" && after.status === "rejected";

      if ((justApproved || justRejected) && after.createdBy) {
        tasks.push(
            db.collection("notifications").add({
              userId: after.createdBy,
              title: justApproved ? "İşiniz onaylandı" : "İşiniz reddedildi",
              body: after.title,
              type: justApproved ?
              NOTIFICATION_TYPE.jobApproved :
              NOTIFICATION_TYPE.jobRejected,
              read: false,
              jobId,
              createdAt: FieldValue.serverTimestamp(),
            }),
        );
      }

      await Promise.all(tasks);
    },
);

/**
 * Mirrors every `notifications/{id}` doc to FCM push on the target user's
 * registered devices, pruning tokens that are no longer valid.
 */
exports.onNotificationCreated = onDocumentCreated(
    "notifications/{notificationId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;
      const notification = snap.data();

      const userSnap = await db
          .collection("users")
          .doc(notification.userId)
          .get();
      if (!userSnap.exists) return;

      const tokens = userSnap.data().fcmTokens || [];
      if (tokens.length === 0) return;

      const response = await getMessaging().sendEachForMulticast({
        tokens,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: {
          jobId: notification.jobId || "",
          type: notification.type || "",
        },
      });

      const invalidTokens = [];
      response.responses.forEach((result, index) => {
        if (
          !result.success &&
        result.error &&
        (result.error.code === "messaging/registration-token-not-registered" ||
          result.error.code === "messaging/invalid-registration-token")
        ) {
          invalidTokens.push(tokens[index]);
        }
      });

      if (invalidTokens.length > 0) {
        await userSnap.ref.update({
          fcmTokens: FieldValue.arrayRemove(...invalidTokens),
        });
      }
    },
);
