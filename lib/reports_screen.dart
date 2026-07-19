import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'report_detail_screen.dart';

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
        .eq('overall_status', 'Completed')
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

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _reports = _fetchReports();
              });
            },
            color: const Color(0xFFF95921),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                return _buildReportCard(reports[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final checklistData = report['checklist_data'] as Map<String, dynamic>? ?? {};
    final String type = checklistData['checklist_type'] ?? 'commercial';

    String typeLabel = 'Commercial Inspection';
    IconData typeIcon = Icons.business;
    Color typeColor = const Color(0xFFF95921);

    if (type == 'community_urban') {
      typeLabel = 'Community Risk (Urban)';
      typeIcon = Icons.holiday_village;
      typeColor = const Color(0xFF3B82F6);
    } else if (type == 'house_to_house') {
      typeLabel = 'House to House Checklist';
      typeIcon = Icons.home;
      typeColor = const Color(0xFF10B981);
    }

    final String statusStr = report['compliance_status'] ?? report['recommendation'] ?? 'Completed';
    final String dateStr = report['date_inspected'] != null
        ? report['date_inspected'].toString().split('T').first
        : (report['created_at'] != null ? report['created_at'].toString().split('T').first : 'Today');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportDetailScreen(report: report),
          ),
        );
      },
      child: Container(
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
              children: [
                Icon(typeIcon, size: 16, color: typeColor),
                const SizedBox(width: 6),
                Text(
                  typeLabel,
                  style: TextStyle(color: typeColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusStr,
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              report['business_name'] ?? 'Inspection Report',
              style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (report['address'] != null && report['address'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      report['address'],
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Inspected: $dateStr',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                Row(
                  children: [
                    Text(
                      'Tap to view details',
                      style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 16, color: typeColor),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}