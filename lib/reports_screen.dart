import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<List<Map<String, dynamic>>> _reports;

  @override
  void initState() {
    super.initState();
    _reports = _fetchReports();
  }

  Future<List<Map<String, dynamic>>> _fetchReports() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await Supabase.instance.client
        .from('inspections')
        .select()
        .eq('inspector_id', userId)
        .eq('overall_status', 'Completed') // Fetching real completed data
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'My Reports',
          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _reports,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFF95921)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading reports: ${snapshot.error}'));
          }
          
          final reports = snapshot.data ?? [];
          
          if (reports.isEmpty) {
            return const Center(child: Text('No completed reports found.', style: TextStyle(color: Color(0xFF64748B))));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              return _buildReportCard(reports[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final bool isCompliant = report['compliance_status'] == 'Compliant';
    
    int violationCount = 0;
    if (report['checklist_data'] != null && report['checklist_data']['violations'] != null) {
      final violations = report['checklist_data']['violations'] as Map<String, dynamic>;
      violationCount = violations.values.where((v) => v == true).length;
    }

    final dateStr = report['created_at'] != null 
        ? report['created_at'].toString().split('T').first 
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  report['business_name'] ?? 'Unknown',
                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompliant ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCompliant ? 'Compliant' : 'Non-Compliant',
                  style: TextStyle(
                    color: isCompliant ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dateStr,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          if (!isCompliant && violationCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$violationCount violations found',
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ]
        ],
      ),
    );
  }
}