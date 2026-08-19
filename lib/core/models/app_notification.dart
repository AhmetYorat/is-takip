import 'package:cloud_firestore/cloud_firestore.dart';

/// A `notifications/{id}` document. Written by Cloud Functions (job
/// created/assigned/approved/rejected) and mirrored to FCM by
/// `onNotificationCreated`. Tapping a card marks it read and, when [jobId]
/// is set, deep-links to that job's detail screen.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    this.jobId,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool read;
  final String? jobId;
  final DateTime? createdAt;

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    return AppNotification(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      type: (data['type'] as String?) ?? '',
      read: (data['read'] as bool?) ?? false,
      jobId: data['jobId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
