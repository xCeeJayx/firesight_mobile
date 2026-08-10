import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/user_role.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/db_initializer.dart';
import 'services/emergency_service.dart';
import 'services/offline_sync_service.dart';
import 'services/route_guard.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database factory across all platforms (Web, Desktop, Mobile)
  initializeDatabaseFactory();

  // Supabase standard local storage initialization
  await Supabase.initialize(
    url: 'https://lapfwiawufudxervauzc.supabase.co',
    anonKey: 'sb_publishable_6M90oMjDOdT5oXqzKpbZug_JJOO4U2k',
  );

  // Initialize offline SQLite DB & sync queue
  await OfflineSyncService().database;

  // Initialize connectivity monitor
  ConnectivityService().initialize();

  // Initialize Auth & restore cached offline profile
  await AuthService().initialize();

  // Initialize Emergency Report real-time subscription & state
  await EmergencyService().initialize();

  runApp(const FireSightApp());
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
