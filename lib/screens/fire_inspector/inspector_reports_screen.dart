import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import 'view_inspection_form_dialog.dart';

class InspectorReportsScreen extends StatefulWidget {
  const InspectorReportsScreen({super.key});

  @override
  State<InspectorReportsScreen> createState() => _InspectorReportsScreenState();
}

class _InspectorReportsScreenState extends State<InspectorReportsScreen> {
  // Design Tokens
  static const Color colorCanvas = Color(0xFFF8FAFC);
  static const Color colorSurface = Color(0xFFFFFFFF);
  static const Color colorTextPrimary = Color(0xFF0F172A);
  static const Color colorTextSecondary = Color(0xFF475569);
  static const Color colorAccent = Color(0xFFEA580C);
  static const Color colorBorder = Color(0xFFE2E8F0);
  static const Color colorSuccess = Color(0xFF16A34A);
  static const Color colorWarning = Color(0xFFD97706);
  static const Color colorDanger = Color(0xFFDC2626);

  late Future<List<Map<String, dynamic>>> _reportsFuture;
  late Future<Map<String, int>> _reportStatsFuture;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _refreshReports();
  }

  void _refreshReports() {
    setState(() {
      _reportsFuture = _fetchAfterInspectionReports();
      _reportStatsFuture = _fetchReportStats();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchAfterInspectionReports() async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;

    try {
      final client = Supabase.instance.client;
      var query = client.from('inspections').select();
      if (userId != null) {
        query = query.eq('inspector_id', userId);
      }
      final res = await query.order('created_at', ascending: false).limit(30);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching AIR reports: $e');
      return [];
    }
  }

  Future<Map<String, int>> _fetchReportStats() async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;

    try {
      final client = Supabase.instance.client;
      var query = client.from('inspections').select('recommendation, compliance_status');
      if (userId != null) {
        query = query.eq('inspector_id', userId);
      }
      final res = await query;

      int total = res.length;
      int fsicCount = 0;
      int ntcCount = 0;
      int ntcvCount = 0;

      for (var item in res) {
        final rec = (item['recommendation'] ?? item['compliance_status'] ?? '').toString().toUpperCase();
        if (rec.contains('FSIC') || rec.contains('ISSUANCE')) {
          fsicCount++;
        } else if (rec.contains('NTCV') || rec.contains('VIOLATION')) {
          ntcvCount++;
        } else if (rec.contains('NTC') || rec.contains('COMPLY')) {
          ntcCount++;
        }
      }

      return {
        'total': total,
        'fsic': fsicCount,
        'ntc': ntcCount,
        'ntcv': ntcvCount,
      };
    } catch (_) {
      return {'total': 0, 'fsic': 0, 'ntc': 0, 'ntcv': 0};
    }
  }

  Future<void> _exportLogSummary() async {
    setState(() => _isExporting = true);

    try {
      await AuthService().logAuditAction(
        actionType: 'REPORT_EXPORTED',
        targetEntity: 'Station Officer Summary Log',
        details: 'Exported Commercial After-Inspection Reports (AIR) summary batch for Station Officer review.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('After-Inspection Summary Log Exported for Station Officer Review!'),
            backgroundColor: colorSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export note: $e'), backgroundColor: colorDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showAirReportModal(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAirModal(report),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorCanvas,
      body: RefreshIndicator(
        onRefresh: () async => _refreshReports(),
        color: colorAccent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              _buildHeaderCard(),
              const SizedBox(height: 16),

              // Summary Stats
              _buildStatsRow(),
              const SizedBox(height: 20),

              // Export Button Section
              _buildExportBar(),
              const SizedBox(height: 20),

              // Reports List
              const Text(
                'Submitted After-Inspection Reports (AIR)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              _buildReportsList(),
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
        color: colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorAccent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_turned_in_outlined, color: colorAccent, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reports & Compliance Hub',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colorTextPrimary),
                ),
                SizedBox(height: 2),
                Text(
                  'After-Inspection Reports (AIR) and Station Officer compliance summary logs.',
                  style: TextStyle(fontSize: 12, color: colorTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return FutureBuilder<Map<String, int>>(
      future: _reportStatsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'total': 0, 'fsic': 0, 'ntc': 0, 'ntcv': 0};

        return Row(
          children: [
            Expanded(
              child: _buildStatTile('Total AIR', stats['total'] ?? 0, Icons.description_outlined, colorTextPrimary, const Color(0xFFF1F5F9)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatTile('FSIC Rec.', stats['fsic'] ?? 0, Icons.verified_outlined, colorSuccess, const Color(0xFFDCFCE7)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatTile('NTC Issued', stats['ntc'] ?? 0, Icons.warning_amber_outlined, colorWarning, const Color(0xFFFEF3C7)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatTile('NTCV Issued', stats['ntcv'] ?? 0, Icons.report_problem_outlined, colorDanger, const Color(0xFFFEE2E2)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatTile(String label, int count, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: colorSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorTextPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colorTextSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExportBar() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isExporting ? null : _exportLogSummary,
        icon: _isExporting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.file_upload_outlined, size: 18, color: Colors.white),
        label: Text(
          _isExporting ? 'Exporting Summary Log...' : 'Export AIR Summary for Station Officer Review',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorAccent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildReportsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(color: colorAccent),
            ),
          );
        }

        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: colorSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorBorder),
            ),
            child: Column(
              children: const [
                Icon(Icons.assignment_outlined, size: 40, color: colorTextSecondary),
                SizedBox(height: 10),
                Text(
                  'No After-Inspection Reports recorded.',
                  style: TextStyle(color: colorTextPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'Complete commercial safety inspections to generate AIR records.',
                  style: TextStyle(color: colorTextSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reports.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final r = reports[index];
            final bName = r['business_name'] ?? 'Commercial Establishment';
            final ioNo = r['inspection_order_no'] ?? 'N/A';
            final rec = r['recommendation'] ?? r['compliance_status'] ?? 'Inspected';
            final dateStr = (r['date_inspected'] ?? r['created_at'] ?? '').toString().split('T').first;

            return InkWell(
              onTap: () => _showAirReportModal(r),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.picture_as_pdf_outlined, color: colorAccent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorTextPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'IO: $ioNo | Date: $dateStr',
                            style: const TextStyle(fontSize: 11, color: colorTextSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Action: $rec',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getRecColor(rec),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_outlined, color: colorTextSecondary, size: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAirModal(Map<String, dynamic> r) {
    final bName = r['business_name'] ?? 'Commercial Establishment';
    final addr = r['address'] ?? 'Lingayen, Pangasinan';
    final ioNo = r['inspection_order_no'] ?? 'N/A';
    final rec = r['recommendation'] ?? r['compliance_status'] ?? 'Inspected';
    final dateStr = (r['date_inspected'] ?? r['created_at'] ?? '').toString().split('T').first;
    final checklistData = r['checklist_data'] is Map<String, dynamic> ? r['checklist_data'] as Map<String, dynamic> : {};
    final defects = checklistData['defects_summary'] ?? 'No defects noted during inspection.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: colorSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: colorBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Icon(Icons.shield_outlined, color: colorAccent, size: 22),
              SizedBox(width: 8),
              Text(
                'BFP OFFICIAL AFTER-INSPECTION REPORT',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorTextPrimary, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Establishment: $bName', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorTextPrimary)),
                const SizedBox(height: 4),
                Text('Address: $addr', style: const TextStyle(fontSize: 12, color: colorTextSecondary)),
                Text('Inspection Order #: $ioNo', style: const TextStyle(fontSize: 12, color: colorTextSecondary)),
                Text('Date Conducted: $dateStr', style: const TextStyle(fontSize: 12, color: colorTextSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text('Recommended Enforcement Action:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorTextPrimary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _getRecColor(rec).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rec,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _getRecColor(rec)),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Summary Findings & Observations:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorTextPrimary)),
          const SizedBox(height: 4),
          Text(defects, style: const TextStyle(fontSize: 12, color: colorTextSecondary)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => ViewInspectionFormDialog(
                    targetInspectionId: r['id']?.toString(),
                    initialData: r,
                  ),
                );
              },
              icon: const Icon(Icons.description_outlined, size: 18, color: Colors.white),
              label: const Text(
                'View Form',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_outlined, size: 18, color: colorTextPrimary),
              label: const Text('Close Report Preview', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorTextPrimary)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: colorBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Color _getRecColor(String rec) {
    final r = rec.toUpperCase();
    if (r.contains('FSIC') || r.contains('ISSUANCE')) return colorSuccess;
    if (r.contains('NTCV') || r.contains('VIOLATION')) return colorDanger;
    return colorWarning;
  }
}
