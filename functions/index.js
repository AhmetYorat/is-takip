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
const {getAuth} = require("firebase-admin/auth");
const {onDocumentCreated, onDocumentUpdated} =
  require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
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
 * Keeps the "(OTOMATİK)" alacak (receivable) entry for a job's price in
 * sync with that price: creates it if one doesn't exist yet, or updates its
 * `totalAmount` if it does. Never touches `paidAmount` — that's
 * `FirestoreService.addPayment`'s exclusive domain. Shared by
 * [onJobCreated] (price given at creation) and [onJobPriceSet] (price set
 * or edited later from the job detail page) so they never drift apart on
 * which fields get written.
 */
async function syncAutomaticReceivable(tasks, jobId, job) {
  if (typeof job.price !== "number" || job.price <= 0) return;

  const existing = await db
      .collection("receivables")
      .where("jobId", "==", jobId)
      .limit(1)
      .get();

  if (existing.empty) {
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
  } else {
    tasks.push(existing.docs[0].ref.update({totalAmount: job.price}));
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

  await syncAutomaticReceivable(tasks, jobId, job);

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
 * A job's price was set for the first time, or edited afterwards (job
 * detail page's "Fiyat Ekle"/"Fiyatı Düzenle" — `firestore.rules` decides
 * who may do which: a patron always, the creator only while it's still
 * `pending_approval`, unless it's the very first price the job's ever had).
 * Keeps the linked "(OTOMATİK)" alacak entry's `totalAmount` in step —
 * creating it if this is the first price, updating it otherwise — via
 * [syncAutomaticReceivable].
 */
exports.onJobPriceSet = onDocumentUpdated("jobs/{jobId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const jobId = event.params.jobId;

  const beforePrice = typeof before.price === "number" ? before.price : 0;
  const afterPrice = typeof after.price === "number" ? after.price : 0;
  if (beforePrice === afterPrice) return;

  const tasks = [];
  await syncAutomaticReceivable(tasks, jobId, after);
  await Promise.all(tasks);
});

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

/**
 * Deletes a job — always via this callable, never a direct client write
 * (`firestore.rules` keeps `jobs.delete` permanently `false`) because
 * whether it's allowed depends on a different collection's data (the
 * linked automatic receivable's `paidAmount`), which security rules can't
 * look up (no doc-id relationship, only a `jobId` field).
 *
 * Anyone signed in may call it, but only a patron, or the job's own
 * creator while it's still `pending_approval`, is authorized — mirrors
 * `Job.canBeDeletedBy`. If the job has an automatic receivable that's
 * already been paid against (`paidAmount > 0`), deletion is refused
 * outright to protect that payment history; otherwise the receivable (if
 * any) is deleted along with the job.
 */
exports.deleteJob = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError(
        "unauthenticated",
        "Bu işlem için giriş yapmış olmanız gerekir.",
    );
  }
  const jobId = request.data && request.data.jobId;
  if (typeof jobId !== "string" || !jobId) {
    throw new HttpsError(
        "invalid-argument",
        "Geçerli bir iş kimliği gerekli.",
    );
  }

  const jobRef = db.collection("jobs").doc(jobId);
  const jobSnap = await jobRef.get();
  if (!jobSnap.exists) {
    throw new HttpsError("not-found", "İş bulunamadı.");
  }
  const job = jobSnap.data();

  const userSnap = await db.collection("users").doc(uid).get();
  const isPatron = userSnap.exists && userSnap.data().role === ROLE_PATRON;
  const canDelete = isPatron ||
      (job.createdBy === uid && job.status === "pending_approval");
  if (!canDelete) {
    throw new HttpsError("permission-denied", "Bu işi silme yetkiniz yok.");
  }

  const receivablesSnap = await db.collection("receivables")
      .where("jobId", "==", jobId)
      .limit(1)
      .get();
  if (!receivablesSnap.empty &&
      (receivablesSnap.docs[0].data().paidAmount || 0) > 0) {
    throw new HttpsError(
        "failed-precondition",
        "Bu iş için ödeme alınmış, silinemez.",
    );
  }

  const batch = db.batch();
  batch.delete(jobRef);
  if (!receivablesSnap.empty) batch.delete(receivablesSnap.docs[0].ref);
  await batch.commit();
});

/**
 * Self-service account deletion (Apple App Store guideline 5.1.1(v)).
 * Runs with the Admin SDK so it isn't subject to firestore.rules (which,
 * e.g., never lets a client delete its own `users/{uid}` doc) and so a
 * client's stale-but-still-valid ID token can't be used to fight this: the
 * Auth user is removed for real, not just disabled.
 *
 * Deletes the caller's personal data: their `users/{uid}` profile (name,
 * email, fcmTokens), every notification addressed to them, and their
 * membership in any job's `assignedTo`. Jobs/receivables/payments/expenses/
 * staffPayments they created are *kept* — those are shared business/
 * financial records other users' history depends on (payments and
 * staffPayments are an immutable audit log, a deleted user's expenses would
 * otherwise retroactively shrink past months' company totals and their
 * reimbursement balance — see ../firestore.rules), which Apple's guideline
 * explicitly allows retaining for legitimate record-keeping even after
 * account deletion.
 */
exports.deleteAccount = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError(
        "unauthenticated",
        "Bu işlem için giriş yapmış olmanız gerekir.",
    );
  }

  const batch = db.batch();

  const notificationsSnap = await db
      .collection("notifications")
      .where("userId", "==", uid)
      .get();
  notificationsSnap.forEach((doc) => batch.delete(doc.ref));

  const assignedJobsSnap = await db
      .collection("jobs")
      .where("assignedTo", "array-contains", uid)
      .get();
  assignedJobsSnap.forEach((doc) => {
    batch.update(doc.ref, {assignedTo: FieldValue.arrayRemove(uid)});
  });

  batch.delete(db.collection("users").doc(uid));

  await batch.commit();
  await getAuth().deleteUser(uid);

  logger.info(`users/${uid} deleted their own account.`);
  return {success: true};
});
