import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'schedule_screen.dart';
import 'new_inspection_screen.dart';
import 'fire_risk_mapping_screen.dart';
import 'reports_screen.dart';
import 'widgets/common/sync_indicator_chip.dart';
import 'login_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String _inspectorName = 'FO1 Field Officer';
  String _stationBadge = 'BFP Station 4';

  final List<Widget> _screens = [
    const HomeScreen(),
    const ScheduleScreen(),
    const NewInspectionScreen(),
    const FireRiskMappingScreen(),
    const ReportsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fetchInspectorProfile();
  }

  Future<void> _fetchInspectorProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profileData = await Supabase.instance.client
          .from('profiles')
          .select('full_name, badge_number, role')
          .eq('id', user.id)
          .maybeSingle();

      if (profileData != null && mounted) {
        final String fullName = profileData['full_name']?.toString() ?? user.email?.split('@').first ?? 'BFP Officer';
        final String? badgeNo = profileData['badge_number']?.toString();
        final String role = (profileData['role']?.toString() ?? 'inspector').toUpperCase();

        setState(() {
          _inspectorName = fullName;
          if (badgeNo != null && badgeNo.isNotEmpty) {
            _stationBadge = badgeNo.toLowerCase().startsWith('bfp') ? badgeNo : 'BFP $badgeNo';
          } else {
            _stationBadge = 'BFP $role';
          }
        });
      } else if (user.email != null && mounted) {
        setState(() {
          _inspectorName = user.email!.split('@').first;
          _stationBadge = 'BFP INSPECTOR';
        });
      }
    } catch (e) {
      debugPrint('Error fetching inspector profile: $e');
    }
  }

  void _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFD84315).withOpacity(0.15),
              child: const Icon(
                Icons.person_pin_rounded,
                color: Color(0xFFD84315),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _inspectorName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 12, color: Color(0xFFD84315)),
                      const SizedBox(width: 4),
                      Text(
                        _stationBadge,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFE2E8F0),
            height: 1,
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_turned_in_outlined),
            selectedIcon: Icon(Icons.assignment_turned_in),
            label: 'Inspection',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check_rounded),
            label: 'Risk Mapping',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description_rounded),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
