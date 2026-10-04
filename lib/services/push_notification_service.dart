import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../active_inspection_screen.dart';
import '../models/emergency_report_model.dart';
import '../screens/public/public_announcements_screen.dart';
import '../widgets/emergency/emergency_alert_dialog.dart';
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

  /// Channel 1: Standard high importance for inspections & announcements
  static const AndroidNotificationChannel _highImportanceChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'Inspection & Bulletin Advisories',
    description: 'Notifications for newly assigned inspections and public announcements',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Channel 2: Critical emergency alarm with siren vibration
  static const AndroidNotificationChannel _emergencyChannel = AndroidNotificationChannel(
    'emergency_alarm_channel',
    '🚨 Critical Emergency Alerts',
    description: 'High-priority critical emergency incident alarms with loud siren sound & continuous vibration',
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

      // 3. Subscribe all devices to public announcements & verified emergency broadcasts
      try {
        await _messaging.subscribeToTopic('public_announcements');
        await _messaging.subscribeToTopic('emergency_public');
        debugPrint('Subscribed to public FCM topics: public_announcements, emergency_public');
      } catch (topicErr) {
        debugPrint('FCM topic subscription note: $topicErr');
      }

      // 4. Initialize Local Notifications for foreground heads-up display
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

      // Create Android Notification Channels
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_highImportanceChannel);
      await androidPlugin?.createNotificationChannel(_emergencyChannel);

      // 5. Retrieve and store device FCM token
      await _fetchAndSyncToken();

      // Listen for token refreshments
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        syncTokenToSupabase();
      });

      // 6. Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received foreground push notification: ${message.notification?.title}');
        _showLocalNotification(message);
      });

      // 7. Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification clicked while app was in background: ${message.data}');
        _handleNotificationData(message.data);
      });

      // 8. Check if app was opened from terminated state via notification click
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

  /// Subscribe or unsubscribe from officer emergency topics based on user role
  Future<void> updateOfficerTopicSubscription({required bool isOfficer}) async {
    try {
      if (isOfficer) {
        await _messaging.subscribeToTopic('emergency_officers');
        debugPrint('Officer logged in: Subscribed to FCM topic: emergency_officers');
      } else {
        await _messaging.unsubscribeFromTopic('emergency_officers');
        debugPrint('Citizen/Guest mode: Unsubscribed from FCM topic: emergency_officers');
      }
    } catch (e) {
      debugPrint('Error updating officer topic subscription: $e');
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

    final isEmergency = message.data['type'] == 'emergency' ||
        message.data['report_id'] != null ||
        (notification.title?.toUpperCase().contains('EMERGENCY') ?? false);

    final androidDetails = AndroidNotificationDetails(
      isEmergency ? _emergencyChannel.id : _highImportanceChannel.id,
      isEmergency ? _emergencyChannel.name : _highImportanceChannel.name,
      channelDescription:
          isEmergency ? _emergencyChannel.description : _highImportanceChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/launcher_icon',
      color: isEmergency ? const Color(0xFFDC2626) : const Color(0xFFD84315),
      playSound: true,
      enableVibration: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? (isEmergency ? '🚨 Emergency Alert' : 'Inspection Notification'),
      body: notification.body ?? 'Emergency update received.',
      notificationDetails: notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  /// Route the user based on notification payload type
  void _handleNotificationData(Map<String, dynamic> data) {
    final String? type = data['type']?.toString();
    final String? announcementId = data['announcement_id']?.toString();
    final String? emergencyId = data['report_id']?.toString() ?? data['emergency_id']?.toString();

    // 1. Handle Public Announcements
    if (type == 'announcement' || announcementId != null) {
      _handleAnnouncementData(data);
      return;
    }

    // 2. Handle Emergency Incidents
    if (type == 'emergency' || emergencyId != null) {
      _handleEmergencyData(data);
      return;
    }

    // 3. Handle Inspection Scheduling
    final inspectionId = data['inspection_id']?.toString() ?? data['assignmentId']?.toString();

    if (inspectionId == null || inspectionId.isEmpty) {
      debugPrint('No recognized entity id found in notification data: $data');
      return;
    }

    _pendingInspectionId = inspectionId;
    _navigateToInspection(inspectionId);
  }

  /// Handle emergency push notification tap: Fetch report and display EmergencyAlertDialog
  Future<void> _handleEmergencyData(Map<String, dynamic> data) async {
    final String? reportId = data['report_id']?.toString() ?? data['id']?.toString();

    EmergencyReportModel? report;

    // Try fetching fresh report record from Supabase
    if (reportId != null && reportId.isNotEmpty) {
      try {
        final res = await Supabase.instance.client
            .from('emergency_reports')
            .select()
            .eq('id', reportId)
            .maybeSingle();
        if (res != null) {
          report = EmergencyReportModel.fromJson(res);
        }
      } catch (e) {
        debugPrint('Error fetching emergency report from DB: $e');
      }
    }

    // Fallback: construct report from push notification data payload
    report ??= EmergencyReportModel(
      id: reportId ?? 'emergency-${DateTime.now().millisecondsSinceEpoch}',
      reporterName: data['reporter_name']?.toString() ?? 'Anonymous Citizen',
      incidentType: data['incident_type']?.toString() ?? 'Emergency Incident',
      barangay: data['barangay']?.toString() ?? 'Lingayen',
      address: data['address']?.toString(),
      status: data['status']?.toString() ?? 'Unverified',
      description: data['description']?.toString(),
      photoUrl: data['photo_url']?.toString(),
      latitude: double.tryParse(data['latitude']?.toString() ?? ''),
      longitude: double.tryParse(data['longitude']?.toString() ?? ''),
      createdAt: DateTime.now(),
    );

    final title = report.isVerified ? 'Verified Emergency Incident' : 'Incoming Emergency Report';

    void showEmergencyPopup(BuildContext ctx) {
      EmergencyAlertDialog.show(
        ctx,
        report!,
        alertTitle: title,
      );
    }

    final navContext = EmergencyService.navigatorKey.currentContext;
    if (navContext != null) {
      showEmergencyPopup(navContext);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final delayedCtx = EmergencyService.navigatorKey.currentContext;
        if (delayedCtx != null) {
          showEmergencyPopup(delayedCtx);
        }
      });
    }
  }

  /// Display announcement bulletin dialog
  void _handleAnnouncementData(Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? 'BFP Public Safety Bulletin';
    final content = data['content']?.toString() ?? '';
    final priority = data['priority']?.toString() ?? 'normal';
    final createdBy = data['created_by']?.toString() ?? 'BFP Lingayen';

    final navContext = EmergencyService.navigatorKey.currentContext;
    if (navContext != null) {
      PublicAnnouncementsScreen.showAnnouncementModal(
        context: navContext,
        title: title,
        content: content,
        priority: priority,
        dateStr: 'Just now',
        createdBy: createdBy,
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final delayedContext = EmergencyService.navigatorKey.currentContext;
        if (delayedContext != null) {
          PublicAnnouncementsScreen.showAnnouncementModal(
            context: delayedContext,
            title: title,
            content: content,
            priority: priority,
            dateStr: 'Just now',
            createdBy: createdBy,
          );
        }
      });
    }
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
