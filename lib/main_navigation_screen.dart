import 'package:flutter/material.dart';
import 'models/user_role.dart';
import 'services/auth_service.dart';
import 'services/route_guard.dart';
import 'fire_risk_mapping_screen.dart';
import 'report_emergency_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/admin_reports_screen.dart';
import 'screens/admin/audit_logs_screen.dart';
import 'screens/risk_officer/risk_officer_dashboard_screen.dart';
import 'screens/risk_officer/olp_hub_screen.dart';
import 'screens/risk_officer/barangay_risk_map_screen.dart';
import 'screens/risk_officer/risk_reports_screen.dart';
import 'screens/fire_inspector/fire_inspector_dashboard_screen.dart';
import 'screens/fire_inspector/inspection_hub_screen.dart';
import 'screens/fire_inspector/establishment_directory_screen.dart';
import 'screens/fire_inspector/inspector_reports_screen.dart';
import 'screens/public/public_announcements_screen.dart';
import 'widgets/notifications_sheet.dart';

class MainNavigationScreen extends StatefulWidget {
  final UserRole activeRole;
  final bool isPublicUser;

  const MainNavigationScreen({
    super.key,
    this.activeRole = UserRole.fireInspector,
    this.isPublicUser = false,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String _inspectorName = 'BFP Officer';
  String _stationBadge = 'BFP Lingayen';

  late final UserRole _effectiveRole;
  late final List<Widget> _screens;
  late final List<NavigationDestination> _navigationDestinations;

  @override
  void initState() {
    super.initState();
    _effectiveRole = widget.isPublicUser ? UserRole.publicGuest : widget.activeRole;
    _setupRoleNavigation();
    _fetchUserProfile();
  }

  void _setupRoleNavigation() {
    switch (_effectiveRole) {
      case UserRole.fireInspector:
        _inspectorName = 'Fire Inspector';
        _stationBadge = 'BFP-9531';
        _screens = [
          FireInspectorDashboardScreen(
            onNavigateTab: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          const InteractiveRiskMapWidget(isPublicUser: false),
          const InspectionHubScreen(),
          const EstablishmentDirectoryScreen(),
          const InspectorReportsScreen(),
        ];
        _navigationDestinations = const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Risk Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check_rounded),
            label: 'Inspection',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Establishment',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_turned_in_outlined),
            selectedIcon: Icon(Icons.assignment_turned_in_rounded),
            label: 'Reports',
          ),
        ];
        break;

      case UserRole.communityRiskOfficer:
        _inspectorName = 'Community Risk Officer';
        _stationBadge = 'BFP-5153';
        _screens = [
          CommunityRiskOfficerDashboard(
            onNavigateTab: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          const InteractiveRiskMapWidget(isPublicUser: false),
          OlpHubScreen(
            onNavigateTab: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          BarangayRiskMapScreen(
            onNavigateTab: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          const RiskReportsScreen(),
        ];
        _navigationDestinations = const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Risk Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'OLP',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_shared_outlined),
            selectedIcon: Icon(Icons.folder_shared_rounded),
            label: 'Risk Directory',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'OLP Analytics',
          ),
        ];
        break;

      case UserRole.stationOfficer:
        _inspectorName = 'Station Officer';
        _stationBadge = 'BFP-2188';
        _screens = [
          StationOfficerDashboard(onSelectTab: (index) {
            setState(() {
              _currentIndex = index;
            });
          }),
          const UserManagementScreen(),
          const AdminReportsScreen(),
          const AuditLogsScreen(),
        ];
        _navigationDestinations = const [
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings_rounded),
            label: 'Command Hub',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Personnel',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_edu_outlined),
            selectedIcon: Icon(Icons.history_edu_rounded),
            label: 'Audit Logs',
          ),
        ];
        break;

      case UserRole.publicGuest:
        _inspectorName = 'Citizen Guest';
        _stationBadge = 'Public Access Mode';
        _screens = const [
          FireRiskMappingScreen(isPublicUser: true),
          PublicAnnouncementsScreen(),
          ReportEmergencyScreen(),
        ];
        _navigationDestinations = const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'GIS Risk Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign_rounded),
            label: 'Announcements',
          ),
          NavigationDestination(
            icon: Icon(Icons.emergency_outlined),
            selectedIcon: Icon(Icons.emergency_rounded),
            label: 'Report Emergency',
          ),
        ];
        break;
    }
  }

  Future<void> _fetchUserProfile() async {
    if (_effectiveRole == UserRole.publicGuest) return;

    final authService = AuthService();
    await authService.refreshUserProfile();
    final profile = authService.userProfile;

    if (profile != null && mounted) {
      final String? name = profile['full_name']?.toString();
      final String? badge = profile['badge_number']?.toString();

      setState(() {
        if (name != null && name.trim().isNotEmpty) {
          _inspectorName = name.trim();
        }
        if (badge != null && badge.trim().isNotEmpty) {
          _stationBadge = badge.trim();
        }
      });
    }
  }

  void _signOut() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        RouteGuard.routeLogin,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isGuest = _effectiveRole == UserRole.publicGuest;

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
              backgroundColor: isGuest
                  ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                  : const Color(0xFFD84315).withValues(alpha: 0.15),
              child: Icon(
                isGuest ? Icons.person_pin_circle_rounded : Icons.person_pin_rounded,
                color: isGuest ? const Color(0xFFDC2626) : const Color(0xFFD84315),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isGuest ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isGuest ? Icons.public_rounded : Icons.shield_outlined,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _stationBadge,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
          if (isGuest) ...[
            IconButton(
              icon: const Icon(Icons.campaign_outlined, color: Color(0xFFD84315), size: 24),
              onPressed: () {
                setState(() => _currentIndex = 1);
              },
              tooltip: 'BFP Public Announcements',
            ),
            TextButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.login_rounded, size: 18, color: Color(0xFFD84315)),
              label: const Text(
                'BFP Login',
                style: TextStyle(color: Color(0xFFD84315), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ] else ...[
            const NotificationBellButton(),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
              onPressed: _signOut,
              tooltip: 'Sign Out',
            ),
          ],
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
        destinations: _navigationDestinations,
      ),
    );
  }
}
