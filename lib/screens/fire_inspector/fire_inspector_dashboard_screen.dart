import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/offline_sync_service.dart';
import '../../services/emergency_service.dart';
import '../../widgets/emergency/emergency_reports_feed.dart';
import 'commercial_inspection_form_screen.dart';
import 'view_inspection_form_dialog.dart';

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
  late Future<Map<String, int>> _kpiMetricsFuture;

  // Design Tokens
  static const Color colorCanvas = Color(0xFFF8FAFC);
  static const Color colorSurface = Color(0xFFFFFFFF);
  static const Color colorTextPrimary = Color(0xFF0F172A);
  static const Color colorTextSecondary = Color(0xFF475569);
  static const Color colorAccent = Color(0xFFEA580C);
  static const Color colorBorder = Color(0xFFE2E8F0);
  static const Color colorSuccess = Color(0xFF16A34A);
  static const Color colorWarning = Color(0xFFD97706);

  @override
  void initState() {
    super.initState();
    _refreshData();
    OfflineSyncService().pendingCountNotifier.addListener(_refreshData);
  }

  @override
  void dispose() {
    OfflineSyncService().pendingCountNotifier.removeListener(_refreshData);
    super.dispose();
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _kpiMetricsFuture = _fetchKpiMetrics();
      });
      EmergencyService().fetchReports();
    }
  }

  Future<Map<String, int>> _fetchKpiMetrics() async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;

    int scheduledToday = 0;
    int completed = 0;
    int pendingDeficiencies = 0;

    // 1. Account for offline pending items
    try {
      final offline = await OfflineSyncService().getPendingItems(targetTable: 'inspections');
      for (var item in offline) {
        scheduledToday++;
      }
    } catch (_) {}

    // 2. Fetch remote metrics from Supabase
    try {
      final client = Supabase.instance.client;
      var query = client.from('inspections').select('overall_status, recommendation, compliance_status, date_inspected');
      if (userId != null) {
        query = query.eq('inspector_id', userId);
      }

      final res = await query;
      final todayStr = DateTime.now().toIso8601String().split('T').first;

      for (var item in res) {
        final st = (item['overall_status'] ?? '').toString().toLowerCase();
        final rec = (item['recommendation'] ?? item['compliance_status'] ?? '').toString().toUpperCase();
        final dateInspected = (item['date_inspected'] ?? '').toString();

        if (dateInspected.startsWith(todayStr) || st == 'pending' || st == 'in progress' || st == 'assigned' || st == 'pending sync') {
          scheduledToday++;
        }
        if (st == 'completed' || st == 'passed' || st == 'inspected') {
          completed++;
        }
        if (rec.contains('NTC') || rec.contains('NOTICE') || rec.contains('DEFICIENCY') || rec.contains('VIOLATION')) {
          pendingDeficiencies++;
        }
      }

      return {
        'scheduledToday': scheduledToday,
        'completed': completed,
        'pendingDeficiencies': pendingDeficiencies,
      };
    } catch (_) {
      return {'scheduledToday': scheduledToday, 'completed': completed, 'pendingDeficiencies': pendingDeficiencies};
    }
  } void _launchForm([Map<String, dynamic>? item]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CommercialInspectionFormScreen(
          assignmentId: item?['id']?.toString(),
          initialBusinessName: item?['business_name']?.toString(),
          initialAddress: item?['address']?.toString(),
          initialIoNumber: item?['inspection_order_no']?.toString(),
        ),
      ),
    ).then((_) => _refreshData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorCanvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed Top Header & Overview Cards (Sticky / Non-scrolling)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Operations Metric Cards',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorTextPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _buildKpiMetricsRow(),
              ],
            ),
          ),

          // Scrollable Live Emergency Reports Feed
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refreshData(),
              color: colorAccent,
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

  Widget _buildKpiMetricsRow() {
    return FutureBuilder<Map<String, int>>(
      future: _kpiMetricsFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final metrics = snapshot.data ?? {'scheduledToday': 0, 'completed': 0, 'pendingDeficiencies': 0};

        return Row(
          children: [
            _buildKpiCard(
              title: 'Scheduled Today',
              value: isLoading ? '...' : '${metrics['scheduledToday'] ?? 0}',
              subtitle: 'Assigned today',
              icon: Icons.calendar_today_outlined,
              color: const Color(0xFF0284C7),
            ),
            const SizedBox(width: 10),
            _buildKpiCard(
              title: 'Completed',
              value: isLoading ? '...' : '${metrics['completed'] ?? 0}',
              subtitle: 'FSIC Conducted',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF16A34A),
            ),
            const SizedBox(width: 10),
            _buildKpiCard(
              title: 'Deficiencies',
              value: isLoading ? '...' : '${metrics['pendingDeficiencies'] ?? 0}',
              subtitle: 'Action required',
              icon: Icons.warning_amber_outlined,
              color: const Color(0xFFDC2626),
            ),
          ],
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
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
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
    );
  }
}
