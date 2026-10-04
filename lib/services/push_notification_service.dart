import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../active_inspection_screen.dart';
import '../firebase_options.dart';
import '../models/emergency_report_model.dart';
import '../models/user_role.dart';
import '../screens/public/public_announcements_screen.dart';
import '../widgets/emergency/emergency_alert_dialog.dart';
import 'auth_service.dart';
import 'emergency_service.dart';

/// Top-level background message handler required by Firebase Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Background Firebase init note: $e');
  }
  debugPrint('Handling background push notification: ${message.messageId}, data: ${message.data}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  FirebaseMessaging? _messagingInstance;
  FirebaseMessaging get _messaging {
    _messagingInstance ??= FirebaseMessaging.instance;
    return _messagingInstance!;
  }

  /// Ensure Firebase Core is initialized before any messaging operation
  Future<void> ensureFirebaseInitialized() async {
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        debugPrint('Firebase ensureInitialized note: $e');
      }
    }
  }

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Channel 1: Critical Emergency Alarms (Officers & Critical Incidents) with loud siren sound
  static const AndroidNotificationChannel _emergencyChannel = AndroidNotificationChannel(
    'emergency_alarm_channel_v4',
    '🚨 Critical Emergency Alerts',
    description: 'High-priority critical emergency incident alarms with loud siren sound & continuous vibration',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('emergency_siren'),
    enableVibration: true,
  );

  /// Channel 2: Public Bulletins, Advisories & Announcements with crisp melodic chime sound
  static const AndroidNotificationChannel _publicBulletinChannel = AndroidNotificationChannel(
    'public_bulletin_channel_v4',
    '📢 Public Bulletins & Advisories',
    description: 'Public safety advisories, community bulletins, and public emergency broadcasts',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('public_chime'),
    enableVibration: true,
  );

  /// Channel 3: Inspection Advisories for assigned personnel
  static const AndroidNotificationChannel _inspectionChannel = AndroidNotificationChannel(
    'inspection_channel_v4',
    'Inspection Advisories',
    description: 'Notifications for newly assigned inspections',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('public_chime'),
    enableVibration: true,
  );

  AudioPlayer? _alertChimePlayer;

  /// Plays crisp melodic chime sound and haptic pulse for in-app alert dialogs
  Future<void> playAlertChime() async {
    try {
      _alertChimePlayer?.dispose();
      _alertChimePlayer = AudioPlayer();
      await _alertChimePlayer!.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: {
              AVAudioSessionOptions.duckOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
      await _alertChimePlayer!.setVolume(1.0);
      try {
        await _alertChimePlayer!.play(AssetSource('audio/public_chime.wav'));
      } catch (assetErr) {
        debugPrint('playAlertChime AssetSource error: $assetErr');
      }
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    } catch (e) {
      debugPrint('Error playing alert chime: $e');
    }
  }

  bool _isInitialized = false;
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Global notification stream to immediately notify UI widgets (like the bell badge)
  final StreamController<Map<String, dynamic>> _onNotificationReceivedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationReceived =>
      _onNotificationReceivedController.stream;
  String? _pendingInspectionId;

  /// Track recently handled alert keys to prevent duplicate popping within a short window
  final Set<String> _recentlyHandledKeys = {};

  /// Initialize Firebase Push Notifications & Local Notification channels
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      // 1. Initialize Firebase Core safely with explicit options
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
      } catch (fbInitErr) {
        debugPrint('Firebase explicit options init note: $fbInitErr');
        try {
          if (Firebase.apps.isEmpty) {
            await Firebase.initializeApp();
          }
        } catch (fallbackErr) {
          debugPrint('Firebase fallback init note: $fallbackErr');
        }
      }

      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (bgErr) {
        debugPrint('Firebase background handler note: $bgErr');
      }

      // 2. Request notification permissions (required for Android 13+ and iOS)
      try {
        final NotificationSettings settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        debugPrint('FCM Authorization status: ${settings.authorizationStatus}');
      } catch (permErr) {
        debugPrint('Permission request note: $permErr');
      }

      // 3. Initial subscription based on active user role
      try {
        await _messaging.subscribeToTopic('public_announcements');
        final isStaff = AuthService().isAuthenticated ||
            (Supabase.instance.client.auth.currentUser != null) ||
            (AuthService().currentRole != UserRole.publicGuest);
        await updateOfficerTopicSubscription(isOfficer: isStaff);
        debugPrint('Initial FCM topic subscription set: isOfficer=$isStaff');
      } catch (topicErr) {
        debugPrint('FCM topic subscription note: $topicErr');
      }

      // 4. Initialize Local Notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@drawable/ic_notification');
      const InitializationSettings initSettings = InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final Map<String, dynamic> data = jsonDecode(payload);
              _handleNotificationData(data, isForeground: false);
            } catch (e) {
              debugPrint('Error decoding notification payload: $e');
            }
          }
        },
      );

      // Create Android Notification Channels with dedicated sound configurations
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_emergencyChannel);
      await androidPlugin?.createNotificationChannel(_publicBulletinChannel);
      await androidPlugin?.createNotificationChannel(_inspectionChannel);

      // Clean up deprecated channels
      try {
        await androidPlugin?.deleteNotificationChannel(channelId: 'emergency_alarm_channel');
        await androidPlugin?.deleteNotificationChannel(channelId: 'high_importance_channel');
        await androidPlugin?.deleteNotificationChannel(channelId: 'emergency_alarm_channel_v3');
        await androidPlugin?.deleteNotificationChannel(channelId: 'public_bulletin_channel_v3');
        await androidPlugin?.deleteNotificationChannel(channelId: 'inspection_channel_v3');
      } catch (_) {}

      // 5. Retrieve and store device FCM token
      await _fetchAndSyncToken();

      // Listen for token refreshments
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        syncTokenToSupabase();
      });

      // 6. Handle foreground notifications:
      // When user is actively IN the app, ONLY trigger on-screen alert / modal dialog.
      // Do NOT display a push notification banner in the system notification shade.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
        debugPrint('Received in-app foreground notification: $title');

        // A) Broadcast to in-app stream listeners (e.g. unread badge count)
        _onNotificationReceivedController.add(message.data);

        // B) Directly pop up the in-app alert dialog/modal on screen (with siren audio for emergencies)
        _handleNotificationData(message.data, isForeground: true);
      });

      // 7. Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification clicked while app was in background: ${message.data}');
        _handleNotificationData(message.data, isForeground: false);
      });

      // 8. Check if app was opened from terminated state via notification click
      final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('Notification launched app from terminated state: ${initialMessage.data}');
        _handleNotificationData(initialMessage.data, isForeground: false);
      }
    } catch (e) {
      debugPrint('PushNotificationService initialization error: $e');
      debugPrint('Note: Ensure google-services.json from Firebase Console is placed in android/app/');
    }
  }

  /// Subscribe or unsubscribe from officer emergency topics based on user role
  Future<void> updateOfficerTopicSubscription({required bool isOfficer}) async {
    try {
      await ensureFirebaseInitialized();
      if (Firebase.apps.isEmpty) return;

      // Always guarantee subscription to public announcements
      try {
        await _messaging.subscribeToTopic('public_announcements');
      } catch (pubErr) {
        debugPrint('Public topic subscription note: $pubErr');
      }

      if (isOfficer) {
        // Officer: Subscribe to officer alerts, UNSUBSCRIBE from public emergency alerts so NO DUPLICATES!
        await _messaging.subscribeToTopic('emergency_officers');
        await _messaging.unsubscribeFromTopic('emergency_public');
        debugPrint('Officer mode: Subscribed to emergency_officers; Unsubscribed from emergency_public');
      } else {
        // Citizen / Guest: Subscribe to public emergency broadcasts, UNSUBSCRIBE from officer alerts
        await _messaging.subscribeToTopic('emergency_public');
        await _messaging.unsubscribeFromTopic('emergency_officers');
        debugPrint('Citizen/Guest mode: Subscribed to emergency_public; Unsubscribed from emergency_officers');
      }
    } catch (e) {
      debugPrint('Error updating officer topic subscription: $e');
    }
  }

  /// Retrieve current FCM token
  Future<void> _fetchAndSyncToken() async {
    try {
      await ensureFirebaseInitialized();
      if (Firebase.apps.isEmpty) return;

      _fcmToken = await _messaging.getToken();
      debugPrint('FCM Device Token: $_fcmToken');
      await syncTokenToSupabase();
    } catch (e) {
      debugPrint('Error retrieving FCM token: $e');
    }
  }

  /// Sync device FCM token to Supabase profiles table for the currently logged in user
  Future<void> syncTokenToSupabase({int retries = 3}) async {
    try {
      await ensureFirebaseInitialized();
      if (Firebase.apps.isEmpty) return;

      if (_fcmToken == null || _fcmToken!.isEmpty) {
        try {
          _fcmToken = await _messaging.getToken();
          debugPrint('Retrieved FCM Device Token: $_fcmToken');
        } catch (tokenErr) {
          debugPrint('Error retrieving FCM token: $tokenErr');
        }
      }

      if (_fcmToken == null || _fcmToken!.isEmpty) {
        if (retries > 0) {
          debugPrint('FCM token not ready yet. Retrying in 2 seconds ($retries attempts remaining)...');
          Future.delayed(const Duration(seconds: 2), () => syncTokenToSupabase(retries: retries - 1));
        }
        return;
      }

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

  /// Optional helper to display a heads-up banner locally if needed
  void showLocalNotification(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        message.data['content']?.toString();

    if (title == null && body == null) return;

    final isEmergency = message.data['type'] == 'emergency' ||
        message.data['report_id'] != null ||
        (title?.toUpperCase().contains('EMERGENCY') ?? false);

    final androidDetails = AndroidNotificationDetails(
      isEmergency ? _emergencyChannel.id : _publicBulletinChannel.id,
      isEmergency ? _emergencyChannel.name : _publicBulletinChannel.name,
      channelDescription:
          isEmergency ? _emergencyChannel.description : _publicBulletinChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@drawable/ic_notification',
      color: isEmergency ? const Color(0xFFDC2626) : const Color(0xFFEA580C),
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
        isEmergency ? 'emergency_siren' : 'public_chime',
      ),
      enableVibration: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    _localNotifications.show(
      id: message.messageId.hashCode != 0
          ? message.messageId.hashCode
          : (title.hashCode ^ DateTime.now().millisecondsSinceEpoch),
      title: title ?? (isEmergency ? '🚨 Emergency Alert' : 'FireSight Notification'),
      body: body ?? 'New update received.',
      notificationDetails: notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  /// Route the user based on notification payload type
  void _handleNotificationData(Map<String, dynamic> data, {bool isForeground = false}) {
    if (data.isEmpty) return;

    final String? type = data['type']?.toString();
    final String? announcementId = data['announcement_id']?.toString() ?? data['id']?.toString();
    final String? emergencyId = data['report_id']?.toString() ?? data['emergency_id']?.toString();
    final String? inspectionId = data['inspection_id']?.toString() ?? data['assignmentId']?.toString();

    // Determine unique deduplication key
    String? dedupeKey;
    if (type == 'emergency' || emergencyId != null) {
      dedupeKey = 'emergency_${emergencyId ?? data['id']}';
    } else if (type == 'announcement' || announcementId != null) {
      dedupeKey = 'announcement_${announcementId ?? data['title']}';
    } else if (inspectionId != null) {
      dedupeKey = 'inspection_$inspectionId';
    }

    if (dedupeKey != null) {
      if (_recentlyHandledKeys.contains(dedupeKey)) {
        debugPrint('Skipping duplicate alert presentation for key: $dedupeKey');
        return;
      }
      _recentlyHandledKeys.add(dedupeKey);
      Future.delayed(const Duration(seconds: 8), () {
        _recentlyHandledKeys.remove(dedupeKey);
      });
    }

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
    if (inspectionId != null && inspectionId.isNotEmpty) {
      if (isForeground) {
        // While user is in the app, display an alert dialog with establishment details
        _showInspectionAlertDialog(data, inspectionId);
      } else {
        // Tapped from background / notification shade: navigate directly
        _pendingInspectionId = inspectionId;
        _navigateToInspection(inspectionId);
      }
      return;
    }

    debugPrint('No recognized entity id found in notification data: $data');
  }

  /// Display in-app alert dialog for scheduled inspection assignments in foreground
  void _showInspectionAlertDialog(Map<String, dynamic> data, String inspectionId) {
    playAlertChime();
    final businessName = data['business_name']?.toString() ??
        data['establishment_name']?.toString() ??
        data['title']?.toString() ??
        'Assigned Commercial Establishment';
    final schedule = data['schedule']?.toString() ??
        data['inspection_date']?.toString() ??
        'Scheduled Today';
    final address = data['address']?.toString() ?? data['barangay']?.toString();

    void showModal(BuildContext ctx) {
      showDialog(
        context: ctx,
        barrierDismissible: true,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: Color(0xFFEA580C),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'New Inspection Assigned',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                businessName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (address != null && address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF475569)),
                    const SizedBox(width: 6),
                    Text(
                      schedule,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text(
                'Later',
                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                _pendingInspectionId = inspectionId;
                _navigateToInspection(inspectionId);
              },
              child: const Text('Open Inspection'),
            ),
          ],
        ),
      );
    }

    final navContext = EmergencyService.navigatorKey.currentContext;
    if (navContext != null) {
      showModal(navContext);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final delayedCtx = EmergencyService.navigatorKey.currentContext;
        if (delayedCtx != null) {
          showModal(delayedCtx);
        }
      });
    }
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

    if (report.id.isNotEmpty) {
      if (EmergencyService().isRecentlyAlerted(report.id)) {
        debugPrint('Emergency report ${report.id} already alerted in-app. Skipping duplicate.');
        return;
      }
      EmergencyService().markAlerted(report.id);
    }

    final title = report.isVerified ? 'Verified Emergency Incident' : 'Incoming Emergency Report';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentCtx = EmergencyService.navigatorKey.currentContext;
      if (currentCtx != null) {
        EmergencyAlertDialog.show(
          currentCtx,
          report!,
          alertTitle: title,
        );
      }
    });
  }

  /// Display announcement bulletin dialog
  void _handleAnnouncementData(Map<String, dynamic> data) {
    playAlertChime();
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
