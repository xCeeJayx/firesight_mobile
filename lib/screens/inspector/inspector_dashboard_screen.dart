import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/emergency_service.dart';
import '../../widgets/emergency/emergency_reports_feed.dart';
import '../../widgets/common/inspection_task_card.dart';
import '../../active_inspection_screen.dart';
import '../../new_inspection_screen.dart';

class FireInspectorDashboard extends StatefulWidget {
  const FireInspectorDashboard({super.key});

  @override
  State<FireInspectorDashboard> createState() => _FireInspectorDashboardState();
}

class _FireInspectorDashboardState extends State<FireInspectorDashboard> {
  late Future<Map<String, int>> _operationsCounterFuture;

  String _inspectorName = 'Fire Inspector';
  String _badgeNumber = 'BFP-9531';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _refreshData();
  }

  void _loadProfile() {
    final profile = AuthService().userProfile;
    if (profile != null) {
      setState(() {
        _inspectorName = profile['full_name']?.toString() ?? 'Fire Inspector';
        _badgeNumber = profile['badge_number']?.toString() ?? 'BFP-9531';
      });
    }
  }

  void _refreshData() {
    setState(() {
      _operationsCounterFuture = _fetchOperationsCounters();
    });
    EmergencyService().fetchReports();
  }

  Future<Map<String, int>> _fetchOperationsCounters() async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;

    try {
      final client = Supabase.instance.client;
      var query = client.from('inspections').select('overall_status');
      if (userId != null) {
        query = query.eq('inspector_id', userId);
      }

      final res = await query;
      int pending = 0;
      int inProgress = 0;
      int completed = 0;

      for (var item in res) {
        final st = item['overall_status']?.toString().toLowerCase() ?? '';
        if (st.contains('pending')) {
          pending++;
        } else if (st.contains('progress')) {
          inProgress++;
        } else if (st.contains('completed') || st.contains('passed') || st.contains('failed')) {
          completed++;
        }
      }

      return {
        'pending': pending,
        'inProgress': inProgress,
        'completed': completed,
      };
    } catch (_) {
      return {'pending': 0, 'inProgress': 0, 'completed': 0};
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAssignedInspections() async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;

    try {
      final client = Supabase.instance.client;
      var query = client.from('inspections').select();
      if (userId != null) {
        query = query.eq('inspector_id', userId);
      }
      final res = await query.order('created_at', ascending: false).limit(15);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  void _startInspection(Map<String, dynamic> item) {
    final status = item['overall_status']?.toString();
    final String assignmentId = item['id']?.toString() ?? '';
    if (status == 'In Progress' || status == 'Pending') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ActiveInspectionScreen(assignmentId: assignmentId),
        ),
      ).then((_) => _refreshData());
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const NewInspectionScreen(),
        ),
      ).then((_) => _refreshData());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Daily Operations Counter Chips
              const Text(
                'Daily Operations Metric Chips',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              _buildOperationsCounterChips(),
              // Live Emergency Reports Feed (Bottom Section)
              const EmergencyReportsFeed(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: Color(0xFFEA580C),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'FSIC Inspection Unit',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined, color: Colors.white, size: 11),
                          const SizedBox(width: 4),
                          Text(
                            _badgeNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _inspectorName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowGuardNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: const [
          Icon(Icons.shield_outlined, size: 16, color: Color(0xFF0F172A)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'RBAC Isolated: FSIC Business Establishment Operations Only',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsCounterChips() {
    return FutureBuilder<Map<String, int>>(
      future: _operationsCounterFuture,
      builder: (context, snapshot) {
        final counts = snapshot.data ?? {'pending': 0, 'inProgress': 0, 'completed': 0};

        return Row(
          children: [
            Expanded(
              child: _buildMetricChip(
                label: 'Pending Today',
                count: counts['pending'] ?? 0,
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
                icon: Icons.hourglass_empty_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricChip(
                label: 'In Progress',
                count: counts['inProgress'] ?? 0,
                color: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
                icon: Icons.pending_actions_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricChip(
                label: 'Completed',
                count: counts['completed'] ?? 0,
                color: const Color(0xFF16A34A),
                bgColor: const Color(0xFFDCFCE7),
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricChip({
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              Icon(icon, size: 18, color: color),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionScheduleList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _assignedInspectionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(color: Color(0xFFEA580C)),
            ),
          );
        }

        final schedule = snapshot.data ?? [];
        if (schedule.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No assigned inspections scheduled for today.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: schedule.length,
          itemBuilder: (context, index) {
            final item = schedule[index];
            return InspectionTaskCard(
              businessName: item['business_name'] ?? 'Establishment Inspection',
              category: item['checklist_type'] ?? 'commercial',
              address: item['address'] ?? 'Lingayen Address',
              status: item['overall_status'] ?? 'Pending',
              priority: item['risk_level'] ?? 'Medium',
              appointmentTime: item['appointment_time'] ?? 'Today',
              onStartInspection: () => _startInspection(item),
            );
          },
        );
      },
    );
  }
}
