import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/inspection_monitoring_model.dart';
import '../../services/emergency_service.dart';
import '../../services/inspection_monitoring_service.dart';
import '../../widgets/emergency/emergency_reports_feed.dart';

class FireInspectorDashboardScreen extends StatefulWidget {
  final Function(int index)? onNavigateTab;

  const FireInspectorDashboardScreen({
    super.key,
    this.onNavigateTab,
  });

  @override
  State<FireInspectorDashboardScreen> createState() => _FireInspectorDashboardScreenState();
}

class _FireInspectorDashboardScreenState extends State<FireInspectorDashboardScreen> {
  int _todayVisitsCount = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
    InspectionMonitoringService().activeSessionNotifier.addListener(_onActiveSessionChanged);
  }

  @override
  void dispose() {
    InspectionMonitoringService().activeSessionNotifier.removeListener(_onActiveSessionChanged);
    super.dispose();
  }

  void _onActiveSessionChanged() {
    if (mounted) {
      _fetchTodayStats();
    }
  }

  Future<void> _refreshData() async {
    EmergencyService().fetchReports();
    InspectionMonitoringService().fetchActiveSession();
    InspectionMonitoringService().fetchOnSiteInspectors();
    await _fetchTodayStats();
  }

  Future<void> _fetchTodayStats() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final now = DateTime.now();
      final startOfDayLocal = DateTime(now.year, now.month, now.day);
      final startOfDayUtc = startOfDayLocal.toUtc().toIso8601String();

      var query = Supabase.instance.client
          .from('inspection_monitoring_sessions')
          .select('id, status, start_time');
      if (user?.id != null) {
        query = query.eq('inspector_id', user!.id);
      }
      query = query.gte('start_time', startOfDayUtc);

      final res = await query;
      if (mounted) {
        setState(() {
          _todayVisitsCount = (res as List).length;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching inspector today stats: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sticky Top Operational Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Field Monitoring Operations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Live session status & real-time emergency feed',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                _buildLiveKpiRow(),
              ],
            ),
          ),

          // Scrollable Live Emergency Reports Feed (Identical to CRO Dashboard)
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFFEA580C),
              child: const EmergencyReportsFeed(
                isExpanded: true,
                padding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveKpiRow() {
    return ValueListenableBuilder<InspectionMonitoringModel?>(
      valueListenable: InspectionMonitoringService().activeSessionNotifier,
      builder: (context, activeSession, _) {
        final isOnSite = activeSession != null;

        return ValueListenableBuilder<List<InspectionMonitoringModel>>(
          valueListenable: InspectionMonitoringService().onSiteInspectorsNotifier,
          builder: (context, onSiteList, _) {
            return Row(
              children: [
                // Card 1: My Monitoring Status
                _buildKpiCard(
                  title: 'My Status',
                  value: isOnSite ? 'ON SITE' : 'STANDBY',
                  subtitle: isOnSite ? activeSession.visitType : 'Off-site',
                  icon: isOnSite ? Icons.sensors_rounded : Icons.radio_button_off_rounded,
                  color: isOnSite ? const Color(0xFF16A34A) : const Color(0xFF475569),
                  onTap: () {
                    if (isOnSite) {
                      widget.onNavigateTab?.call(2); // Active Session
                    } else {
                      widget.onNavigateTab?.call(1); // Start Monitor
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Card 2: Today's Visits
                _buildKpiCard(
                  title: 'Visits Today',
                  value: _isLoadingStats ? '...' : '$_todayVisitsCount',
                  subtitle: 'Logged sessions',
                  icon: Icons.assignment_turned_in_outlined,
                  color: const Color(0xFF0284C7),
                  onTap: () => widget.onNavigateTab?.call(3), // History
                ),
                const SizedBox(width: 8),

                // Card 3: Team On-Site (Lingayen)
                _buildKpiCard(
                  title: 'Team On-Site',
                  value: '${onSiteList.length}',
                  subtitle: 'Inspectors live',
                  icon: Icons.people_outline_rounded,
                  color: const Color(0xFFEA580C),
                  onTap: () => widget.onNavigateTab?.call(4), // Live Map
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
