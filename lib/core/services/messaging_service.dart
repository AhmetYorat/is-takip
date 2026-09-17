import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/constants.dart';

final messagingServiceProvider = Provider<MessagingService>((ref) {
  return MessagingService();
});

/// Handles FCM permission/token lifecycle and shows a local notification
/// when a push arrives while the app is in the foreground (FCM does not
/// auto-display notifications in that state). Actual push *sending* is
/// done server-side by the Cloud Functions in `functions/index.js` — this
/// class only manages the receiving/token side.
class MessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'job_updates',
    'İş bildirimleri',
    description: 'İş atama, onay ve tahsilat bildirimleri',
    importance: Importance.high,
  );

  Future<void> init({
    required void Function(String? jobId) onTapNotification,
  }) async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        // Permission already requested above via
        // FirebaseMessaging.requestPermission (covers iOS too) — don't ask
        // a second time here.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        onTapNotification(response.payload);
      },
    );

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            color: const Color(0xFF2563EB),
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
            styleInformation: const BigTextStyleInformation(''),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['jobId'] as String?,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onTapNotification(message.data['jobId'] as String?);
    });
  }

  /// Registers the current device's FCM token on `users/{uid}.fcmTokens`
  /// and keeps it fresh on rotation, so Cloud Functions can target this
  /// device for push.
  Future<void> syncToken(String uid) async {
    // Registered up front so a token obtained after a retry below (or any
    // later rotation) is never missed, even if the initial fetch fails.
    _messaging.onTokenRefresh.listen((newToken) => _saveToken(uid, newToken));

    try {
      // On iOS, FCM's token depends on the native APNs device token being
      // registered first. Right after a fresh install that registration
      // (a round trip to Apple's push servers) hasn't necessarily finished
      // yet, so getAPNSToken() can come back null; retry briefly instead of
      // letting getToken() throw immediately.
      if (!kIsWeb && Platform.isIOS) {
        String? apnsToken = await _messaging.getAPNSToken();
        var attempts = 0;
        while (apnsToken == null && attempts < 10) {
          await Future.delayed(const Duration(seconds: 1));
          apnsToken = await _messaging.getAPNSToken();
          attempts++;
        }
      }
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(uid, token);
      }
    } catch (e) {
      debugPrint('FCM token alınamadı: $e');
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .update({
            'fcmTokens': FieldValue.arrayUnion([token]),
          });
    } catch (e) {
      debugPrint('FCM token kaydedilemedi: $e');
    }
  }

  Future<void> clearToken(String uid) async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        await _messaging.getAPNSToken();
      }
      final token = await _messaging.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .update({
            'fcmTokens': FieldValue.arrayRemove([token]),
          });
    } catch (e) {
      debugPrint('FCM token silinemedi: $e');
    }
  }
}

/// Background message handler must be a top-level function per the
/// firebase_messaging plugin contract (registered in `main.dart`).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op: system tray already shows the notification for data+notification
  // payloads while the app is backgrounded/terminated. Kept as an
  // extension point for background data processing if needed later.
}
