import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../active_inspection_screen.dart';
import 'emergency_service.dart';

/// Top-level background message handler required by Firebase Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Background Firebase init note: $e');
  }
  debugPrint('Handling background push notification: ${message.messageId}, data: ${message.data}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _highImportanceChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'Inspection & Emergency Alerts',
    description: 'Notifications for newly assigned inspections and emergency alerts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  bool _isInitialized = false;
  String? _fcmToken;
  String? _pendingInspectionId;

  String? get fcmToken => _fcmToken;

  /// Initialize Firebase Push Notifications & Local Notification channels
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      // 1. Initialize Firebase Core
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Request notification permissions (required for Android 13+ and iOS)
      final NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('FCM Authorization status: ${settings.authorizationStatus}');

      // 3. Initialize Local Notifications for foreground heads-up display
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const InitializationSettings initSettings = InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final Map<String, dynamic> data = jsonDecode(payload);
              _handleNotificationData(data);
            } catch (e) {
              debugPrint('Error decoding notification payload: $e');
            }
          }
        },
      );

      // Create Android Notification Channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_highImportanceChannel);

      // 4. Retrieve and store device FCM token
      await _fetchAndSyncToken();

      // Listen for token refreshments
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        syncTokenToSupabase();
      });

      // 5. Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received foreground push notification: ${message.notification?.title}');
        _showLocalNotification(message);
      });

      // 6. Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification clicked while app was in background: ${message.data}');
        _handleNotificationData(message.data);
      });

      // 7. Check if app was opened from terminated state via notification click
      final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('Notification launched app from terminated state: ${initialMessage.data}');
        _handleNotificationData(initialMessage.data);
      }
    } catch (e) {
      debugPrint('PushNotificationService initialization error: $e');
      debugPrint('Note: Ensure google-services.json from Firebase Console is placed in android/app/');
    }
  }

  /// Retrieve current FCM token
  Future<void> _fetchAndSyncToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('FCM Device Token: $_fcmToken');
      await syncTokenToSupabase();
    } catch (e) {
      debugPrint('Error retrieving FCM token: $e');
    }
  }

  /// Sync device FCM token to Supabase profiles table for the currently logged in user
  Future<void> syncTokenToSupabase() async {
    try {
      if (_fcmToken == null || _fcmToken!.isEmpty) return;

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('Cannot sync FCM token: User not authenticated.');
        return;
      }

      await Supabase.instance.client.from('profiles').update({
        'fcm_token': _fcmToken,
        'fcm_token_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      debugPrint('Successfully synced FCM token to Supabase profile for user: ${user.id}');
    } catch (e) {
      debugPrint('Error syncing FCM token to Supabase: $e');
    }
  }

  /// Clear token on logout
  Future<void> clearTokenOnLogout() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('profiles').update({
          'fcm_token': null,
          'fcm_token_updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      }
    } catch (e) {
      debugPrint('Error clearing FCM token on logout: $e');
    }
  }

  /// Display a heads-up banner when notification arrives in the foreground
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      _highImportanceChannel.id,
      _highImportanceChannel.name,
      channelDescription: _highImportanceChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      color: const Color(0xFFD84315), // BFP Fire Orange
      playSound: true,
      enableVibration: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'Inspection Notification',
      body: notification.body ?? 'You have a new inspection update.',
      notificationDetails: notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  /// Route the user to the active inspection screen
  void _handleNotificationData(Map<String, dynamic> data) {
    final inspectionId = data['inspection_id']?.toString() ?? data['assignmentId']?.toString();

    if (inspectionId == null || inspectionId.isEmpty) {
      debugPrint('No inspection_id found in notification data: $data');
      return;
    }

    _pendingInspectionId = inspectionId;
    _navigateToInspection(inspectionId);
  }

  /// Execute navigation to the specific ActiveInspectionScreen
  void _navigateToInspection(String inspectionId) {
    final navState = EmergencyService.navigatorKey.currentState;
    if (navState != null) {
      _pendingInspectionId = null;
      navState.push(
        MaterialPageRoute(
          builder: (context) => ActiveInspectionScreen(assignmentId: inspectionId),
        ),
      );
    } else {
      // Defer navigation until MaterialApp navigator is mounted
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final delayedNav = EmergencyService.navigatorKey.currentState;
        if (delayedNav != null && _pendingInspectionId != null) {
          final idToOpen = _pendingInspectionId!;
          _pendingInspectionId = null;
          delayedNav.push(
            MaterialPageRoute(
              builder: (context) => ActiveInspectionScreen(assignmentId: idToOpen),
            ),
          );
        }
      });
    }
  }

  /// Check for any pending notification navigation on app resume/mount
  void checkPendingNavigation() {
    if (_pendingInspectionId != null) {
      _navigateToInspection(_pendingInspectionId!);
    }
  }
}
