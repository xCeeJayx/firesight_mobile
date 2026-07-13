import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late Future<List<Map<String, dynamic>>> _schedules;

  @override
  void initState() {
    super.initState();
    _schedules = _fetchSchedules();
  }

  Future<List<Map<String, dynamic>>> _fetchSchedules() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await Supabase.instance.client
        .from('inspections')
        .select()
        .eq('inspector_id', userId)
        .eq('overall_status', 'Pending') // Fetching real pending data
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Inspection Schedule',
          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _schedules,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFF95921)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading schedule: ${snapshot.error}'));
          }
          
          final schedules = snapshot.data ?? [];
          
          if (schedules.isEmpty) {
            return const Center(child: Text('No upcoming inspections scheduled.', style: TextStyle(color: Color(0xFF64748B))));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: schedules.length,
            itemBuilder: (context, index) {
              final schedule = schedules[index];
              return _buildScheduleCard(schedule);
            },
          );
        },
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    String risk = schedule['risk'] ?? 'Medium'; 
    Color riskColor;
    Color riskBgColor;
    Color riskTextColor;

    switch (risk) {
      case 'High':
        riskColor = const Color(0xFFEF4444); // Red
        riskBgColor = const Color(0xFFFEE2E2);
        riskTextColor = const Color(0xFFB91C1C);
        break;
      case 'Low':
        riskColor = const Color(0xFF10B981); // Green
        riskBgColor = const Color(0xFFD1FAE5);
        riskTextColor = const Color(0xFF047857);
        break;
      case 'Medium':
      default:
        riskColor = const Color(0xFFF59E0B); // Amber
        riskBgColor = const Color(0xFFFEF3C7);
        riskTextColor = const Color(0xFFB45309);
        break;
    }

    final dateStr = schedule['created_at'] != null 
        ? schedule['created_at'].toString().split('T').first 
        : 'Unknown Date';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            schedule['business_name'] ?? 'Unknown',
                            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: riskBgColor, borderRadius: BorderRadius.circular(12)),
                          child: Text(risk, style: TextStyle(color: riskTextColor, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(schedule['address'] ?? 'No address', style: const TextStyle(color: Color(0xFF64748B), fontSize: 14))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(dateStr, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
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