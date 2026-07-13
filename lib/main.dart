import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  // Replace these with your actual Supabase project URL and anon key
  await Supabase.initialize(
    url: 'https://lapfwiawufudxervauzc.supabase.co',
    anonKey: 'sb_publishable_6M90oMjDOdT5oXqzKpbZug_JJOO4U2k',
  );

  runApp(const FireSightApp());
}

class FireSightApp extends StatelessWidget {
  const FireSightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FireSight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        primaryColor: const Color(0xFFF95921),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF95921),
          primary: const Color(0xFFF95921),
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}
