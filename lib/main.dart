import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'services/route_guard.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lapfwiawufudxervauzc.supabase.co',
    anonKey: 'sb_publishable_6M90oMjDOdT5oXqzKpbZug_JJOO4U2k',
  );

  AuthService().initialize();

  runApp(const FireSightApp());
}

class FireSightApp extends StatelessWidget {
  const FireSightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FireSight Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: RouteGuard.routeLogin,
      onGenerateRoute: (settings) => RouteGuard.generateRoute(settings, AuthService().currentRole),
    );
  }
}
