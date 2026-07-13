import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _todaysSchedule;
  late Future<Map<String, int>> _dashboardMetrics;
  String _inspectorName = 'FO1 Inspector';

  @override
  void initState() {
    super.initState();
    _todaysSchedule = _fetchTodaysSchedule();
    _dashboardMetrics = _fetchDashboardMetrics();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final profileData = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      if (profileData != null && profileData['full_name'] != null) {
        if (mounted) {
          setState(() {
            _inspectorName = profileData['full_name'];
          });
        }
      }
    } catch (e) {
      // fallback to FO1 Inspector
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTodaysSchedule() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await Supabase.instance.client
        .from('inspections')
        .select()
        .eq('inspector_id', userId)
        .eq('overall_status', 'Pending') // Use uppercase 'Pending'
        .order('created_at', ascending: false)
        .limit(3); // Just show a few on the home screen

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, int>> _fetchDashboardMetrics() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return {'pending': 0, 'completedToday': 0, 'total': 0};

    try {
      final now = DateTime.now();

      final response = await Supabase.instance.client
          .from('inspections')
          .select('overall_status, updated_at')
          .eq('inspector_id', userId);

      int pending = 0;
      int completedToday = 0;
      int total = response.length;

      for (var item in response) {
        if (item['overall_status'] == 'Pending') {
          pending++;
        } else if (item['overall_status'] == 'Completed') {
          if (item['updated_at'] != null) {
            final updatedAt = DateTime.tryParse(item['updated_at'])?.toLocal();
            if (updatedAt != null && 
                updatedAt.year == now.year && 
                updatedAt.month == now.month && 
                updatedAt.day == now.day) {
              completedToday++;
            }
          }
        }
      }

      return {'pending': pending, 'completedToday': completedToday, 'total': total};
    } catch (e) {
      return {'pending': 0, 'completedToday': 0, 'total': 0};
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back,',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              _inspectorName,
              style: const TextStyle(color: Color(0xFF1E293B), fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dashboard Metrics
            FutureBuilder<Map<String, int>>(
              future: _dashboardMetrics,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFFF95921))),
                  );
                }
                
                final metrics = snapshot.data ?? {'pending': 0, 'completedToday': 0, 'total': 0};
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Overview",
                      style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Pending Tasks',
                            value: metrics['pending'].toString(),
                            icon: Icons.pending_actions,
                            color: const Color(0xFFF95921),
                            bgColor: const Color(0xFFFFF7ED),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Completed Today',
                            value: metrics['completedToday'].toString(),
                            icon: Icons.check_circle_outline,
                            color: const Color(0xFF10B981),
                            bgColor: const Color(0xFFECFDF5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildMetricCard(
                      title: 'Total Assigned Reports',
                      value: metrics['total'].toString(),
                      icon: Icons.assignment,
                      color: const Color(0xFF3B82F6),
                      bgColor: const Color(0xFFEFF6FF),
                      isFullWidth: true,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            
            // Today's Schedule Section
            const Text(
              "Today's Schedule",
              style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Live Schedule Data
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _todaysSchedule,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFF95921)));
                }
                if (snapshot.hasError) {
                  return Text('Error loading schedule.', style: TextStyle(color: Colors.red.shade300));
                }

                final schedules = snapshot.data ?? [];

                if (schedules.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text('No pending inspections today.', style: TextStyle(color: Color(0xFF64748B))),
                  );
                }

                return Column(
                  children: schedules.map((schedule) => _buildScheduleItem(schedule)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Text(
                value,
                style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(color: const Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> schedule) {
    String risk = schedule['risk_level'] ?? 'Medium';
    Color riskColor;

    if (risk == 'High') {
      riskColor = const Color(0xFFEF4444);
    } else if (risk == 'Low') {
      riskColor = const Color(0xFF10B981);
    } else {
      riskColor = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: riskColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(11), bottomLeft: Radius.circular(11)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule['business_name'] ?? 'Unknown Business',
                      style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            schedule['address'] ?? 'No address provided',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}