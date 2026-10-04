import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/user_role.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/db_initializer.dart';
import 'services/emergency_service.dart';
import 'services/offline_sync_service.dart';
import 'services/push_notification_service.dart';
import 'services/route_guard.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Flutter error catching to prevent black screen on uncaught exceptions
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  // 1. Initialize local SQLite database factory
  try {
    initializeDatabaseFactory();
  } catch (e) {
    debugPrint('DB Factory initialization error: $e');
  }

  // 2. Supabase standard local storage initialization
  try {
    await Supabase.initialize(
      url: 'https://lapfwiawufudxervauzc.supabase.co',
      anonKey: 'sb_publishable_6M90oMjDOdT5oXqzKpbZug_JJOO4U2k',
    );
  } catch (e) {
    debugPrint('Supabase client initialization error: $e');
  }

  // 3. Restore cached offline profile quickly for initial routing
  try {
    await AuthService().initialize();
  } catch (e) {
    debugPrint('AuthService initialization error: $e');
  }

  // 4. Mount and paint the Flutter UI IMMEDIATELY so screen is never black/frozen
  runApp(const FireSightApp());

  // 5. Initialize network and background services asynchronously without blocking UI paint
  _initializeBackgroundServices();
}

void _initializeBackgroundServices() {
  Future.microtask(() async {
    // Initialize offline SQLite DB & sync queue
    try {
      await OfflineSyncService().database;
    } catch (e) {
      debugPrint('OfflineSyncService init note: $e');
    }

    // Initialize connectivity monitor
    try {
      ConnectivityService().initialize();
    } catch (e) {
      debugPrint('ConnectivityService init note: $e');
    }

    // Initialize Emergency Report real-time subscription & state
    try {
      await EmergencyService().initialize();
    } catch (e) {
      debugPrint('EmergencyService init note: $e');
    }

    // Initialize Push Notifications (FCM & Local Notifications)
    try {
      await PushNotificationService().initialize();
    } catch (e) {
      debugPrint('PushNotificationService init note: $e');
    }
  });
}

class FireSightApp extends StatelessWidget {
  const FireSightApp({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRole = AuthService().currentRole;
    final String initialRoute = currentRole != UserRole.publicGuest
        ? RouteGuard.getLandingRoute(currentRole)
        : RouteGuard.routeLogin;

    return MaterialApp(
      title: 'FireSight Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: EmergencyService.navigatorKey,
      scaffoldMessengerKey: ConnectivityService.scaffoldMessengerKey,
      initialRoute: initialRoute,
      onGenerateInitialRoutes: (String initialRouteName) {
        return [
          RouteGuard.generateRoute(
            RouteSettings(name: initialRouteName),
            AuthService().currentRole,
          ),
        ];
      },
      onGenerateRoute: (settings) => RouteGuard.generateRoute(settings, AuthService().currentRole),
    );
  }
}
