import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/constants.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/job.dart';
import '../models/payment.dart';
import '../models/receivable.dart';
import 'auth_service.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(ref.watch(firestoreProvider));
});

/// All Firestore reads/writes for jobs, receivables (alacaklar), payments
/// (tahsilatlar), staff and notifications. Writes that must be privileged
/// (role change, job approval, automatic receivable creation) are also
/// enforced server-side by `firestore.rules` / Cloud Functions — this class
/// does not duplicate that trust boundary, it just shapes the requests.
class FirestoreService {
  FirestoreService(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(FirestoreCollections.users);
  CollectionReference<Map<String, dynamic>> get _jobs =>
      _db.collection(FirestoreCollections.jobs);
  CollectionReference<Map<String, dynamic>> get _receivables =>
      _db.collection(FirestoreCollections.receivables);
  CollectionReference<Map<String, dynamic>> get _payments =>
      _db.collection(FirestoreCollections.payments);
  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection(FirestoreCollections.notifications);

  // ---- Jobs ----------------------------------------------------------

  /// All jobs, newest first — used by the patron's "İşler" screen.
  Stream<List<Job>> watchAllJobs() {
    return _jobs
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Job.fromFirestore).toList());
  }

  /// Jobs assigned to [uid] (a job may have several assignees) — used by
  /// the personel's "İşlerim" screen so only that person's jobs are visible.
  Stream<List<Job>> watchMyJobs(String uid) {
    return _jobs
        .where('assignedTo', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Job.fromFirestore).toList());
  }

  /// Jobs [uid] created themselves — used for personel's own "Onay
  /// Bekleyen" tab (their submissions the patron hasn't approved yet).
  Stream<List<Job>> watchJobsCreatedBy(String uid) {
    return _jobs
        .where('createdBy', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Job.fromFirestore).toList());
  }

  Future<void> createJob(Job job) => _jobs.add(job.toCreateMap());

  Stream<Job?> watchJob(String jobId) {
    return _jobs
        .doc(jobId)
        .snapshots()
        .map((doc) => doc.exists ? Job.fromFirestore(doc) : null);
  }

  /// Patron sets the assignee list and approves a pending job in one step.
  Future<void> assignAndApproveJob({
    required String jobId,
    required List<String> assignedTo,
    required String approvedBy,
  }) {
    return _jobs.doc(jobId).update({
      'assignedTo': assignedTo,
      'approvedBy': approvedBy,
      'approvedAt': FieldValue.serverTimestamp(),
      'status': JobStatus.approved,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Patron changes who's assigned to an already-approved job (add/remove
  /// personnel any time, not just at creation/approval).
  Future<void> updateAssignedPersonnel({
    required String jobId,
    required List<String> assignedTo,
  }) {
    return _jobs.doc(jobId).update({
      'assignedTo': assignedTo,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectJob(String jobId) {
    return _jobs.doc(jobId).update({
      'status': JobStatus.rejected,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateJobStatus(String jobId, String status) {
    return _jobs.doc(jobId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---- Receivables (alacaklar) -----------------------------------------

  Stream<List<Receivable>> watchReceivables() {
    return _receivables
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Receivable.fromFirestore).toList());
  }

  Stream<Receivable?> watchReceivable(String receivableId) {
    return _receivables
        .doc(receivableId)
        .snapshots()
        .map((doc) => doc.exists ? Receivable.fromFirestore(doc) : null);
  }

  Future<void> addManualReceivable(Receivable receivable) {
    return _receivables.add(receivable.toManualCreateMap());
  }

  // ---- Payments (tahsilatlar) -------------------------------------------

  /// Every payment, newest first — used by the patron's Tahsilatlar screen.
  Stream<List<Payment>> watchPayments() {
    return _payments
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Payment.fromFirestore).toList());
  }

  /// Only payments [uid] personally recorded — used by the personel's
  /// Tahsilatlar screen (they can't see what colleagues logged).
  Stream<List<Payment>> watchPaymentsCreatedBy(String uid) {
    return _payments
        .where('createdBy', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Payment.fromFirestore).toList());
  }

  /// Payments linked to one receivable — its "Ödeme Geçmişi".
  Stream<List<Payment>> watchPaymentsForReceivable(String receivableId) {
    return _payments
        .where('receivableId', isEqualTo: receivableId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Payment.fromFirestore).toList());
  }

  /// Records a payment. If it's linked to a receivable, atomically bumps
  /// that receivable's denormalized `paidAmount` in the same transaction so
  /// list views and the status badge stay consistent with payment history.
  Future<void> addPayment(Payment payment) {
    final paymentRef = _payments.doc();
    if (payment.receivableId == null) {
      return paymentRef.set(payment.toCreateMap());
    }
    final receivableRef = _receivables.doc(payment.receivableId);
    return _db.runTransaction((tx) async {
      final receivableSnap = await tx.get(receivableRef);
      final currentPaid = ((receivableSnap.data()?['paidAmount'] as num?) ?? 0)
          .toDouble();
      tx.set(paymentRef, payment.toCreateMap());
      tx.update(receivableRef, {'paidAmount': currentPaid + payment.amount});
    });
  }

  // ---- Staff (personeller) --------------------------------------------

  Stream<List<AppUser>> watchStaff() {
    return _users
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map(AppUser.fromFirestore).toList());
  }

  Future<void> updateUserRole(String uid, String role) {
    return _users.doc(uid).update({'role': role});
  }

  /// Patron fixes a staff member's display name (e.g. it defaulted to
  /// their email prefix at some point) without that person needing to sign
  /// back in themselves.
  Future<void> updateUserName(String uid, String name) {
    return _users.doc(uid).update({'name': name.trim()});
  }

  // ---- Notifications ----------------------------------------------------

  Stream<List<AppNotification>> watchNotifications(String uid) {
    return _notifications
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(AppNotification.fromFirestore).toList());
  }

  Future<void> markNotificationRead(String notificationId) {
    return _notifications.doc(notificationId).update({'read': true});
  }
}

// ---- Riverpod stream providers -------------------------------------------
//
// Every provider below watches authStateChangesProvider (even when it
// doesn't need the value) so a fresh Firestore listener is created on every
// sign-out/sign-in transition. Without this, a listener opened under the
// old session keeps running — Firestore doesn't silently re-authenticate an
// existing snapshots() stream, so after sign-out it settles into a
// permission-denied error that a later sign-in never clears, even for the
// same account.

final allJobsProvider = StreamProvider<List<Job>>((ref) {
  final signedIn = ref.watch(authStateChangesProvider).valueOrNull != null;
  if (!signedIn) return Stream.value(const []);
  return ref.watch(firestoreServiceProvider).watchAllJobs();
});

final myJobsProvider = StreamProvider.family<List<Job>, String>((ref, uid) {
  ref.watch(authStateChangesProvider);
  return ref.watch(firestoreServiceProvider).watchMyJobs(uid);
});

final myCreatedJobsProvider = StreamProvider.family<List<Job>, String>((
  ref,
  uid,
) {
  ref.watch(authStateChangesProvider);
  return ref.watch(firestoreServiceProvider).watchJobsCreatedBy(uid);
});

final jobByIdProvider = StreamProvider.family<Job?, String>((ref, jobId) {
  ref.watch(authStateChangesProvider);
  return ref.watch(firestoreServiceProvider).watchJob(jobId);
});

final receivablesProvider = StreamProvider<List<Receivable>>((ref) {
  final signedIn = ref.watch(authStateChangesProvider).valueOrNull != null;
  if (!signedIn) return Stream.value(const []);
  return ref.watch(firestoreServiceProvider).watchReceivables();
});

final receivableByIdProvider = StreamProvider.family<Receivable?, String>((
  ref,
  id,
) {
  ref.watch(authStateChangesProvider);
  return ref.watch(firestoreServiceProvider).watchReceivable(id);
});

final paymentsProvider = StreamProvider<List<Payment>>((ref) {
  final signedIn = ref.watch(authStateChangesProvider).valueOrNull != null;
  if (!signedIn) return Stream.value(const []);
  return ref.watch(firestoreServiceProvider).watchPayments();
});

final paymentsCreatedByProvider = StreamProvider.family<List<Payment>, String>((
  ref,
  uid,
) {
  ref.watch(authStateChangesProvider);
  return ref.watch(firestoreServiceProvider).watchPaymentsCreatedBy(uid);
});

final paymentsForReceivableProvider =
    StreamProvider.family<List<Payment>, String>((ref, receivableId) {
      ref.watch(authStateChangesProvider);
      return ref
          .watch(firestoreServiceProvider)
          .watchPaymentsForReceivable(receivableId);
    });

final staffProvider = StreamProvider<List<AppUser>>((ref) {
  final signedIn = ref.watch(authStateChangesProvider).valueOrNull != null;
  if (!signedIn) return Stream.value(const []);
  return ref.watch(firestoreServiceProvider).watchStaff();
});

final notificationsProvider =
    StreamProvider.family<List<AppNotification>, String>((ref, uid) {
      ref.watch(authStateChangesProvider);
      return ref.watch(firestoreServiceProvider).watchNotifications(uid);
    });
