import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/common/status_badge.dart';
import 'active_inspection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _inspectionQueue;
  late Future<Map<String, int>> _dashboardMetrics;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _inspectionQueue = _fetchInspectionQueue();
      _dashboardMetrics = _fetchDashboardMetrics();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchInspectionQueue() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await Supabase.instance.client
          .from('inspections')
          .select()
          .eq('inspector_id', userId)
          .eq('overall_status', 'Pending')
          .order('created_at', ascending: false)
          .limit(5);

      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, int>> _fetchDashboardMetrics() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return {'scheduled': 0, 'highRisk': 0, 'completed': 0, 'surveys': 0};

    try {
      final now = DateTime.now();
      final response = await Supabase.instance.client
          .from('inspections')
          .select('overall_status, risk_level, updated_at')
          .eq('inspector_id', userId);

      int scheduled = 0;
      int highRisk = 0;
      int completed = 0;

      for (var item in response) {
        final status = item['overall_status']?.toString();
        final risk = item['risk_level']?.toString();

        if (status == 'Pending') {
          scheduled++;
        }
        if (risk == 'High' || risk == 'Critical') {
          highRisk++;
        }
        if (status == 'Completed') {
          if (item['updated_at'] != null) {
            final updatedAt = DateTime.tryParse(item['updated_at'])?.toLocal();
            if (updatedAt != null &&
                updatedAt.year == now.year &&
                updatedAt.month == now.month &&
                updatedAt.day == now.day) {
              completed++;
            }
          }
        }
      }

      int surveysCount = 0;
      try {
        final surveysResponse = await Supabase.instance.client
            .from('fire_risk_surveys')
            .select('id')
            .eq('inspector_id', userId);
        surveysCount = (surveysResponse as List).length;
      } catch (_) {}

      return {
        'scheduled': scheduled,
        'highRisk': highRisk,
        'completed': completed,
        'surveys': surveysCount,
      };
    } catch (_) {
      return {'scheduled': 0, 'highRisk': 0, 'completed': 0, 'surveys': 0};
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateTodayStr = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final formattedDate = '${months[dateTodayStr.month - 1]} ${dateTodayStr.day}, ${dateTodayStr.year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        color: const Color(0xFFD84315),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero BFP Operational Command Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
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
                            color: const Color(0xFFD84315).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFD84315)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.shield_rounded, color: Color(0xFFFF7043), size: 14),
                              SizedBox(width: 6),
                              Text(
                                'BFP ON-DUTY FIELD MONITOR',
                                style: TextStyle(
                                  color: Color(0xFFFF7043),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Fire Safety & Operational Inspection',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bureau of Fire Protection • Lingayen Station',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Metrics Overview Header
              const Text(
                'Operational Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              // Metric Summary Cards
              FutureBuilder<Map<String, int>>(
                future: _dashboardMetrics,
                builder: (context, snapshot) {
                  final metrics = snapshot.data ?? {'scheduled': 0, 'highRisk': 0, 'completed': 0, 'surveys': 0};

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Scheduled IOs',
                              value: '${metrics['scheduled']}',
                              icon: Icons.calendar_month_rounded,
                              accentColor: const Color(0xFF0284C7),
                              bgColor: const Color(0xFFF0F9FF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'High Risk Hazards',
                              value: '${metrics['highRisk']}',
                              icon: Icons.warning_amber_rounded,
                              accentColor: const Color(0xFFDC2626),
                              bgColor: const Color(0xFFFEF2F2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12, height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Completed Today',
                              value: '${metrics['completed']}',
                              icon: Icons.task_alt_rounded,
                              accentColor: const Color(0xFF16A34A),
                              bgColor: const Color(0xFFF0FDF4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'OLP Risk Surveys',
                              value: '${metrics['surveys']}',
                              icon: Icons.fact_check_rounded,
                              accentColor: const Color(0xFFD84315),
                              bgColor: const Color(0xFFFFF7ED),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Active Inspection Queue Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Pending Inspection Orders',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Priority Dispatch',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Pending Inspection Cards List
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _inspectionQueue,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(color: Color(0xFFD84315)),
                      ),
                    );
                  }

                  final queue = snapshot.data ?? [];

                  if (queue.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.assignment_turned_in_outlined, size: 44, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text(
                            'No Pending Inspection Orders',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'All assigned commercial audits are up to date.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: queue.map((item) => _buildQueueCard(item)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueCard(Map<String, dynamic> item) {
    final String id = item['id']?.toString() ?? '';
    final String name = item['business_name'] ?? 'Establishment Audit';
    final String address = item['address'] ?? 'Lingayen, Pangasinan';
    final String risk = item['risk_level'] ?? 'Medium';
    final String ioNo = item['inspection_order_no'] ?? 'IO-${item['id']}';

    Color riskBadgeColor = const Color(0xFF16A34A);
    if (risk.toLowerCase().contains('high')) {
      riskBadgeColor = const Color(0xFFDC2626);
    } else if (risk.toLowerCase().contains('med')) {
      riskBadgeColor = const Color(0xFFEA580C);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ioNo,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskBadgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$risk Risk'.toUpperCase(),
                  style: TextStyle(
                    color: riskBadgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ActiveInspectionScreen(assignmentId: id),
                  ),
                );
              },
              icon: const Icon(Icons.assignment_sharp, size: 16),
              label: const Text('START COMMERCIAL INSPECTION'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD84315),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}