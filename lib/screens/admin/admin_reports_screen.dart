import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _selectedDateRange = 'This Month';
  final List<String> _dateRangeOptions = ['This Week', 'This Month', 'Quarterly', 'Custom Range'];

  late Future<Map<String, dynamic>> _reportsDataFuture;

  @override
  void initState() {
    super.initState();
    _refreshReportsData();
  }

  void _refreshReportsData() {
    setState(() {
      _reportsDataFuture = _fetchReportsData();
    });
  }

  Future<Map<String, dynamic>> _fetchReportsData() async {
    try {
      final client = Supabase.instance.client;

      final inspectionsRes = await client.from('inspections').select();
      final surveysRes = await client.from('fire_risk_surveys').select();

      final inspectionsList = List<Map<String, dynamic>>.from(inspectionsRes as List);
      final surveysList = List<Map<String, dynamic>>.from(surveysRes as List);

      int totalInspections = inspectionsList.length;
      int compliantCount = inspectionsList.where((i) {
        final status = (i['compliance_status'] ?? i['overall_status'] ?? '').toString().toLowerCase();
        return status.contains('compliant') || status.contains('pass');
      }).length;
      int nonCompliantCount = inspectionsList.where((i) {
        final status = (i['compliance_status'] ?? i['overall_status'] ?? '').toString().toLowerCase();
        return status.contains('non-compliant') || status.contains('fail');
      }).length;
      int reInspectionCount = totalInspections - compliantCount - nonCompliantCount;
      if (reInspectionCount < 0) reInspectionCount = 0;

      double complianceRate = totalInspections > 0 ? (compliantCount / totalInspections * 100) : 0.0;

      // Group OLP Surveys by hazard level
      int highRiskSurveys = surveysList.where((s) {
        final r = (s['vulnerability_rating'] ?? s['risk_level'] ?? '').toString().toLowerCase();
        return r.contains('high') || r.contains('critical');
      }).length;

      int moderateRiskSurveys = surveysList.where((s) {
        final r = (s['vulnerability_rating'] ?? s['risk_level'] ?? '').toString().toLowerCase();
        return r.contains('mod') || r.contains('medium');
      }).length;

      int lowRiskSurveys = surveysList.length - highRiskSurveys - moderateRiskSurveys;
      if (lowRiskSurveys < 0) lowRiskSurveys = 0;

      // Parse barangay risk distribution from live surveys & inspections
      Map<String, Map<String, dynamic>> barangayMap = {};

      for (var s in surveysList) {
        final bName = (s['barangay_name'] ?? s['barangay'] ?? '').toString().trim();
        if (bName.isEmpty) continue;

        final sType = (s['survey_type'] ?? s['checklist_type'] ?? '').toString().toLowerCase().trim();
        final sDataChecklistType = (s['survey_data'] is Map ? s['survey_data']['checklist_type'] : '').toString().toLowerCase().trim();
        final isH2H = sType == 'house_to_house' || sType == 'h2h' || sDataChecklistType == 'house_to_house';
        if (isH2H) continue; // Only CFPP surveys determine barangay community risk

        final risk = (s['risk_level'] ?? s['vulnerability_rating'] ?? '').toString().toLowerCase();
        final isHigh = risk.contains('high') || risk.contains('critical');
        final isMod = risk.contains('mod') || risk.contains('medium');

        if (!barangayMap.containsKey(bName)) {
          barangayMap[bName] = {
            'name': bName,
            'highCount': 0,
            'modCount': 0,
            'total': 0,
            'statusText': isHigh ? 'Critical Priority' : (isMod ? 'Moderate Risk' : 'Monitored'),
          };
        }

        barangayMap[bName]!['total'] = (barangayMap[bName]!['total'] as int) + 1;
        if (isHigh) {
          barangayMap[bName]!['highCount'] = (barangayMap[bName]!['highCount'] as int) + 1;
        } else if (isMod) {
          barangayMap[bName]!['modCount'] = (barangayMap[bName]!['modCount'] as int) + 1;
        }
      }

      for (var i in inspectionsList) {
        final bName = (i['barangay'] ?? i['address'] ?? '').toString().trim();
        if (bName.isEmpty) continue;
        final status = (i['compliance_status'] ?? i['overall_status'] ?? '').toString().toLowerCase();
        final isNonCompliant = status.contains('non-compliant') || status.contains('fail');

        if (!barangayMap.containsKey(bName)) {
          barangayMap[bName] = {
            'name': bName,
            'highCount': 0,
            'modCount': 0,
            'total': 0,
            'statusText': isNonCompliant ? 'High Hazard Area' : 'Monitored Sector',
          };
        }

        barangayMap[bName]!['total'] = (barangayMap[bName]!['total'] as int) + 1;
        if (isNonCompliant) {
          barangayMap[bName]!['highCount'] = (barangayMap[bName]!['highCount'] as int) + 1;
        }
      }

      List<Map<String, dynamic>> barangayProgressList = barangayMap.values.map((b) {
        final total = b['total'] as int;
        final high = b['highCount'] as int;
        final mod = b['modCount'] as int;
        double factor = total > 0 ? ((high * 1.0 + mod * 0.5) / total).clamp(0.15, 1.0) : 0.2;
        return {
          'barangay': b['name'],
          'factor': factor,
          'statusText': b['statusText'],
        };
      }).toList();

      barangayProgressList.sort((a, b) => (b['factor'] as double).compareTo(a['factor'] as double));

      return {
        'totalInspections': totalInspections,
        'compliantCount': compliantCount,
        'nonCompliantCount': nonCompliantCount,
        'reInspectionCount': reInspectionCount,
        'complianceRate': complianceRate,
        'olpTotalSurveys': surveysList.length,
        'highRiskBarangays': highRiskSurveys,
        'moderateRiskBarangays': moderateRiskSurveys,
        'lowRiskBarangays': lowRiskSurveys,
        'barangayProgressList': barangayProgressList,
      };
    } catch (e) {
      debugPrint('Error fetching reports data: $e');
      return {
        'totalInspections': 0,
        'compliantCount': 0,
        'nonCompliantCount': 0,
        'reInspectionCount': 0,
        'complianceRate': 0.0,
        'olpTotalSurveys': 0,
        'highRiskBarangays': 0,
        'moderateRiskBarangays': 0,
        'lowRiskBarangays': 0,
        'barangayProgressList': <Map<String, dynamic>>[],
      };
    }
  }

  void _triggerExportDialog(String format) async {
    await AuthService().logAuditAction(
      actionType: 'REPORT_GENERATED',
      targetEntity: 'Executive Station Report ($_selectedDateRange)',
      details: 'Exported station analytics summary in $format format.',
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFEA580C), size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Export Report ($format)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BFP Official Station Report Preview',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BUREAU OF FIRE PROTECTION - LINGAYEN HQ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
                    const SizedBox(height: 4),
                    Text('Date Range: $_selectedDateRange', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    Text('Generated By: ${AuthService().userProfile?['full_name'] ?? 'Station Officer'}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    Text('Timestamp: ${DateTime.now().toString().split('.')[0]}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Report package containing FSIC compliance metrics, OLP community risk assessment trends, and audit summaries is ready.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.download_done_rounded, color: Colors.white),
                        const SizedBox(width: 10),
                        Text('Station Report Exported ($format) Successfully'),
                      ],
                    ),
                    backgroundColor: const Color(0xFF16A34A),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print / Save File'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async => _refreshReportsData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              _buildHeaderCard(),
              const SizedBox(height: 16),

              // Date Range Selector Chips
              _buildDateRangeSelector(),
              const SizedBox(height: 16),

              // Main Metrics Hub
              FutureBuilder<Map<String, dynamic>>(
                future: _reportsDataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(color: Color(0xFFEA580C)),
                      ),
                    );
                  }

                  final data = snapshot.data ?? {};
                  return Column(
                    children: [
                      _buildFsicSummaryCard(data),
                      const SizedBox(height: 16),
                      _buildOlpRiskSummaryCard(data),
                      const SizedBox(height: 16),
                      _buildBarangayDistributionCard(data),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.analytics_outlined, color: Color(0xFFEA580C), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Reports & Analytics Hub',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'FSIC inspection rates, OLP risk trends & exports',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.file_download_outlined, color: Colors.white, size: 20),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (format) => _triggerExportDialog(format),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'PDF',
                child: Row(
                  children: const [
                    Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFDC2626), size: 18),
                    SizedBox(width: 10),
                    Text('Export Official PDF'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'CSV',
                child: Row(
                  children: const [
                    Icon(Icons.table_chart_outlined, color: Color(0xFF16A34A), size: 18),
                    SizedBox(width: 10),
                    Text('Export Data CSV'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _dateRangeOptions.map((range) {
          final isSelected = _selectedDateRange == range;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF64748B),
              ),
              label: Text(range),
              selected: isSelected,
              selectedColor: const Color(0xFFEA580C).withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedDateRange = range;
                    _refreshReportsData();
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFsicSummaryCard(Map<String, dynamic> data) {
    final total = data['totalInspections'] ?? 0;
    final compliant = data['compliantCount'] ?? 0;
    final nonCompliant = data['nonCompliantCount'] ?? 0;
    final reInspection = data['reInspectionCount'] ?? 0;
    final double rate = (data['complianceRate'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD84315).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFFD84315), size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'FSIC Form 061 Compliance Rate',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${rate.toStringAsFixed(1)}% Compliant',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total > 0 ? (compliant / total) : 0.0,
              minHeight: 10,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Total Conducted',
                  value: total.toString(),
                  color: const Color(0xFF0F172A),
                  icon: Icons.check_box_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  title: 'Passed / Issued',
                  value: compliant.toString(),
                  color: const Color(0xFF16A34A),
                  icon: Icons.verified_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  title: 'Non-Compliant',
                  value: nonCompliant.toString(),
                  color: const Color(0xFFDC2626),
                  icon: Icons.error_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  title: 'Re-Inspection',
                  value: reInspection.toString(),
                  color: const Color(0xFFEA580C),
                  icon: Icons.sync_problem_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOlpRiskSummaryCard(Map<String, dynamic> data) {
    final olpTotal = data['olpTotalSurveys'] ?? 0;
    final highRisk = data['highRiskBarangays'] ?? 0;
    final modRisk = data['moderateRiskBarangays'] ?? 0;
    final lowRisk = data['lowRiskBarangays'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.map_outlined, color: Color(0xFF0F172A), size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'OLP Risk Assessment Statistics',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$olpTotal Total Assessments',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildRiskCategoryBadge(
                  label: 'High Hazard Zones',
                  count: highRisk,
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEF2F2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRiskCategoryBadge(
                  label: 'Moderate Risk',
                  count: modRisk,
                  color: const Color(0xFFEA580C),
                  bgColor: const Color(0xFFFFEDD5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRiskCategoryBadge(
                  label: 'Low Vulnerability',
                  count: lowRisk,
                  color: const Color(0xFF16A34A),
                  bgColor: const Color(0xFFDCFCE7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarangayDistributionCard(Map<String, dynamic> data) {
    final List<Map<String, dynamic>> barangayList = List<Map<String, dynamic>>.from(data['barangayProgressList'] ?? []);

    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(
                child: Text(
                  'Top High-Hazard Barangays Monitored',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Lingayen Command',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (barangayList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.location_off_outlined, color: Color(0xFF94A3B8), size: 32),
                    SizedBox(height: 8),
                    Text(
                      'No Barangay Risk Records Found',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Surveys and inspections will populate risk monitoring automatically.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            )
          else
            ...barangayList.take(5).map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildBarangayProgressRow(
                    b['barangay']?.toString() ?? 'Barangay',
                    (b['factor'] as num?)?.toDouble() ?? 0.2,
                    b['statusText']?.toString() ?? 'Monitored',
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500, height: 1.1),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRiskCategoryBadge({
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarangayProgressRow(String barangay, double factor, String statusText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              barangay,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            Text(
              statusText,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: factor,
            minHeight: 7,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(
              factor > 0.8
                  ? const Color(0xFFDC2626)
                  : factor > 0.6
                      ? const Color(0xFFEA580C)
                      : const Color(0xFF0284C7),
            ),
          ),
        ),
      ],
    );
  }
}
