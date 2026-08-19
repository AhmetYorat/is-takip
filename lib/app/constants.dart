/// App-wide constants: Firestore collection names, roles, job/collection
/// status enums kept as plain strings so they serialize directly to
/// Firestore documents without extra mapping code.
library;

/// Firestore top-level collection names.
class FirestoreCollections {
  FirestoreCollections._();

  static const String users = 'users';
  static const String jobs = 'jobs';
  static const String receivables = 'receivables';
  static const String payments = 'payments';
  static const String notifications = 'notifications';
}

/// User roles. Stored verbatim in `users/{uid}.role`.
class AppRole {
  AppRole._();

  static const String patron = 'patron';
  static const String personel = 'personel';
}

/// Job lifecycle status. Stored verbatim in `jobs/{id}.status`.
class JobStatus {
  JobStatus._();

  static const String pendingApproval = 'pending_approval';
  static const String approved = 'approved';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String rejected = 'rejected';
}

/// Receivable (alacak) entry type. Stored verbatim in
/// `receivables/{id}.type`.
class ReceivableType {
  ReceivableType._();

  static const String otomatik = 'otomatik';
  static const String manuel = 'manuel';
}

/// Payment (tahsilat) method. Stored verbatim in `payments/{id}.method`.
class PaymentMethod {
  PaymentMethod._();

  static const String nakit = 'nakit';
  static const String havale = 'havale';
  static const String kart = 'kart';
  static const String diger = 'diger';

  static const all = [nakit, havale, kart, diger];

  static String label(String method) => switch (method) {
    nakit => 'Nakit',
    havale => 'Havale/EFT',
    kart => 'Kart',
    diger => 'Diğer',
    _ => method,
  };
}

/// Notification payload type, used for deep-linking when a notification
/// card is tapped.
class NotificationType {
  NotificationType._();

  static const String jobAssigned = 'job_assigned';
  static const String jobCreated = 'job_created';
  static const String jobApproved = 'job_approved';
  static const String jobRejected = 'job_rejected';
}

/// go_router path constants.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String jobCreate = '/jobs/create';
  static const String jobDetail = '/jobs/:id';
  static const String receivableDetail = '/receivables/:id';

  static String jobDetailPath(String id) => '/jobs/$id';
  static String receivableDetailPath(String id) => '/receivables/$id';
}
