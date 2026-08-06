import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  late Future<List<Map<String, dynamic>>> _assignedInspectionsFuture;
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
  }

  void _refreshData() {
    setState(() {
      _assignedInspectionsFuture = _fetchTodaySchedule();
      _kpiMetricsFuture = _fetchKpiMetrics();
    });
  }

  Future<Map<String, int>> _fetchKpiMetrics() async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;

    try {
      final client = Supabase.instance.client;
      var query = client.from('inspections').select('overall_status, recommendation, compliance_status, date_inspected');
      if (userId != null) {
        query = query.eq('inspector_id', userId);
      }

      final res = await query;
      int scheduledToday = 0;
      int completed = 0;
      int pendingDeficiencies = 0;

      final todayStr = DateTime.now().toIso8601String().split('T').first;

      for (var item in res) {
        final st = (item['overall_status'] ?? '').toString().toLowerCase();
        final rec = (item['recommendation'] ?? item['compliance_status'] ?? '').toString().toUpperCase();
        final dateInspected = (item['date_inspected'] ?? '').toString();

        if (dateInspected.startsWith(todayStr) || st == 'pending' || st == 'in progress' || st == 'assigned') {
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
      return {'scheduledToday': 0, 'completed': 0, 'pendingDeficiencies': 0};
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTodaySchedule() async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;

    try {
      final client = Supabase.instance.client;
      var query = client.from('inspections').select();
      if (userId != null) {
        query = query.eq('inspector_id', userId);
      }
      final res = await query.order('created_at', ascending: false).limit(30);
      final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(res);
      return items.where((item) {
        final st = (item['overall_status'] ?? '').toString().toLowerCase();
        return st != 'completed' && st != 'passed';
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void _launchForm([Map<String, dynamic>? item]) {
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
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        color: colorAccent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Metrics Overview
              const Text(
                'Compliance Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              _buildKpiMetricsRow(),
              const SizedBox(height: 24),

              // Assigned Commercial Schedule Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Assigned Commercial Schedule',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorTextPrimary,
                    ),
                  ),
                  if (widget.onNavigateTab != null)
                    TextButton.icon(
                      onPressed: () => widget.onNavigateTab!(2), // Switch to Inspection Hub (Tab Index 2)
                      icon: const Icon(Icons.arrow_forward_outlined, size: 16, color: colorAccent),
                      label: const Text(
                        'View All',
                        style: TextStyle(color: colorAccent, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _buildScheduleList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiMetricsRow() {
    return FutureBuilder<Map<String, int>>(
      future: _kpiMetricsFuture,
      builder: (context, snapshot) {
        final metrics = snapshot.data ?? {'scheduledToday': 0, 'completed': 0, 'pendingDeficiencies': 0};

        return Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Scheduled Today',
                count: metrics['scheduledToday'] ?? 0,
                icon: Icons.calendar_today_outlined,
                accentColor: const Color(0xFF0284C7),
                bgColor: const Color(0xFFF0F9FF),
                borderColor: const Color(0xFFBAE6FD),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                title: 'Completed',
                count: metrics['completed'] ?? 0,
                icon: Icons.check_circle_outline,
                accentColor: colorSuccess,
                bgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFBBF7D0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                title: 'Pending Deficiencies',
                count: metrics['pendingDeficiencies'] ?? 0,
                icon: Icons.warning_amber_outlined,
                accentColor: colorWarning,
                bgColor: const Color(0xFFFFFBEB),
                borderColor: const Color(0xFFFDE68A),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required int count,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colorTextSecondary,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _assignedInspectionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: colorAccent),
            ),
          );
        }

        final schedule = snapshot.data ?? [];
        if (schedule.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: colorSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorBorder),
            ),
            child: Column(
              children: [
                const Icon(Icons.assignment_turned_in_outlined, size: 40, color: colorTextSecondary),
                const SizedBox(height: 10),
                const Text(
                  'No assigned commercial inspections found.',
                  style: TextStyle(color: colorTextPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap "Start Instant Inspection Order" to conduct a new commercial safety check.',
                  style: TextStyle(color: colorTextSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: schedule.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = schedule[index];
            final businessName = item['business_name'] ?? 'Commercial Business';
            final address = item['address'] ?? 'Lingayen, Pangasinan';
            final ioNo = item['inspection_order_no'] ?? 'N/A';
            final status = item['overall_status'] ?? 'Pending';
            final recommendation = item['recommendation'] ?? item['compliance_status'] ?? 'Scheduled';

            final isCompleted = status.toString().toLowerCase() == 'completed' || status.toString().toLowerCase() == 'passed';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colorBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colorBorder),
                        ),
                        child: Text(
                          'IO: $ioNo',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextPrimary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusBgColor(status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getStatusTextColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    businessName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: colorTextSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(fontSize: 12, color: colorTextSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: colorBorder),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Status: $recommendation',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'passed':
        return const Color(0xFFDCFCE7);
      case 'in progress':
        return const Color(0xFFE0F2FE);
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'passed':
        return const Color(0xFF15803D);
      case 'in progress':
        return const Color(0xFF0369A1);
      default:
        return const Color(0xFFB45309);
    }
  }
}
