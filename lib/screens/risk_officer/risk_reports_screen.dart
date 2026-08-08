import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/supabase_service.dart';
import '../../models/user_role.dart';
import '../../models/house_to_house_checklist_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class RiskReportsScreen extends StatefulWidget {
  const RiskReportsScreen({super.key});

  @override
  State<RiskReportsScreen> createState() => _RiskReportsScreenState();
}

class _RiskReportsScreenState extends State<RiskReportsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allSurveys = [];
  String _selectedBarangayFilter = 'All Barangays';
  String _selectedRiskFilter = 'All Risks';

  int _highRiskCount = 0;
  int _mediumRiskCount = 0;
  int _lowRiskCount = 0;
  int _totalSurveys = 0;

  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _fetchRiskSurveys();
    OfflineSyncService().pendingCountNotifier.addListener(_fetchRiskSurveys);
  }

  @override
  void dispose() {
    OfflineSyncService().pendingCountNotifier.removeListener(_fetchRiskSurveys);
    super.dispose();
  }

  Future<void> _fetchRiskSurveys() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    List<Map<String, dynamic>> list = [];

    // 1. Read offline pending surveys
    try {
      final offline = await OfflineSyncService().getPendingItems(targetTable: 'fire_risk_surveys');
      list.addAll(offline);
    } catch (_) {}

    // 2. Fetch remote surveys from Supabase
    try {
      final res = await Supabase.instance.client
          .from('fire_risk_surveys')
          .select()
          .order('created_at', ascending: false);

      final remote = List<Map<String, dynamic>>.from(res);
      final Set<String> existingIds = list.map((i) => (i['id'] ?? '').toString()).toSet();
      for (var r in remote) {
        final rId = (r['id'] ?? '').toString();
        if (!existingIds.contains(rId)) {
          list.add(r);
        }
      }
    } catch (e) {
      debugPrint('Error loading survey analytics: $e');
    }

    int high = 0;
    int med = 0;
    int low = 0;

    for (var item in list) {
      final r = (item['risk_level'] ?? item['vulnerability_rating'] ?? '').toString().toLowerCase();
      if (r.contains('high')) {
        high++;
      } else if (r.contains('med')) {
        med++;
      } else if (r.contains('low')) {
        low++;
      }
    }

    if (mounted) {
      setState(() {
        _allSurveys = list;
        _totalSurveys = list.length;
        _highRiskCount = high;
        _mediumRiskCount = med;
        _lowRiskCount = low;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredSurveys {
    return _allSurveys.where((item) {
      // Barangay filter
      if (_selectedBarangayFilter != 'All Barangays') {
        final bgy = (item['barangay'] ?? item['barangay_name'] ?? '').toString();
        if (bgy.toLowerCase() != _selectedBarangayFilter.toLowerCase()) {
          return false;
        }
      }

      // Risk filter
      if (_selectedRiskFilter != 'All Risks') {
        final r = (item['risk_level'] ?? item['vulnerability_rating'] ?? '').toString().toLowerCase();
        if (!r.contains(_selectedRiskFilter.toLowerCase())) {
          return false;
        }
      }

      // Date Range filter
      if (_selectedDateRange != null) {
        final dateStr = item['created_at']?.toString() ?? item['date_inspected']?.toString();
        if (dateStr != null) {
          final dt = DateTime.tryParse(dateStr);
          if (dt != null) {
            if (dt.isBefore(_selectedDateRange!.start) || dt.isAfter(_selectedDateRange!.end.add(const Duration(days: 1)))) {
              return false;
            }
          }
        }
      }

      return true;
    }).toList();
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return const Color(0xFFDC2626);
      case 'medium':
        return const Color(0xFFD97706);
      case 'low':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF64748B);
    }
  }

  void _showPrintExportModal() {
    final filtered = _filteredSurveys;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.print_outlined, color: Color(0xFFEA580C)),
              SizedBox(width: 8),
              Text(
                'Export Station OLP Report',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BFP Lingayen Municipal Fire Station',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 4),
              Text(
                'Summary of ${filtered.length} Barangay Risk Surveys generated for official filing.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildModalRow('High Risk Zones', '$_highRiskCount', const Color(0xFFDC2626)),
                    const SizedBox(height: 6),
                    _buildModalRow('Medium Risk Zones', '$_mediumRiskCount', const Color(0xFFD97706)),
                    const SizedBox(height: 6),
                    _buildModalRow('Low Risk Zones', '$_lowRiskCount', const Color(0xFF16A34A)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('OLP Risk Report exported for station archives.'),
                    backgroundColor: Color(0xFF16A34A),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Download PDF'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModalRow(String label, String val, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _filteredSurveys;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'OLP Risk Reports & Analytics',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Color(0xFF0F172A)),
            onPressed: _showPrintExportModal,
            tooltip: 'Export Report',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE2E8F0), height: 1.0),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRiskSurveys,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Aggregated Distribution Breakdown Card
              _buildAnalyticsCard(),
              const SizedBox(height: 20),

              // Filter Controls Card
              _buildFilterControlsCard(),
              const SizedBox(height: 20),

              // Historical Survey Log Table Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Historical Survey Records',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${filteredLogs.length} Records',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Historical Survey List
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)))
                  : filteredLogs.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(30),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.assignment_late_outlined, size: 40, color: Color(0xFF94A3B8)),
                              SizedBox(height: 10),
                              Text(
                                'No survey records found matching filters',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredLogs.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final survey = filteredLogs[index];
                            final bgy = (survey['barangay'] ?? survey['barangay_name'] ?? 'Poblacion').toString();
                            final risk = (survey['risk_level'] ?? survey['vulnerability_rating'] ?? 'Medium').toString();
                            final riskColor = _getRiskColor(risk);

                            final dateStr = survey['created_at']?.toString() ?? survey['date_inspected']?.toString();
                            final date = dateStr != null
                                ? DateTime.tryParse(dateStr)?.toLocal().toString().split(' ')[0] ?? ''
                                : '';
                            final surveyor = survey['surveyor_name']?.toString() ?? 'Officer';
                            final bool isOfflinePending = (survey['status'] ?? '').toString().toLowerCase() == 'pending sync' || survey['_is_offline_pending'] == true;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: riskColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.shield_outlined,
                                      color: riskColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Brgy. $bgy',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Assessed by $surveyor • $date',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isOfflinePending ? const Color(0xFFFEF3C7) : riskColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isOfflinePending ? const Color(0xFFF59E0B).withOpacity(0.5) : riskColor.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isOfflinePending) ...[
                                          const Icon(Icons.sync_problem_rounded, size: 12, color: Color(0xFFB45309)),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          isOfflinePending ? 'PENDING SYNC (OFFLINE)' : risk.toUpperCase(),
                                          style: TextStyle(
                                            color: isOfflinePending ? const Color(0xFFB45309) : riskColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    final highPct = _totalSurveys > 0 ? (_highRiskCount / _totalSurveys) : 0.0;
    final medPct = _totalSurveys > 0 ? (_mediumRiskCount / _totalSurveys) : 0.0;
    final lowPct = _totalSurveys > 0 ? (_lowRiskCount / _totalSurveys) : 0.0;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lingayen OLP Risk Distribution',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total: $_totalSurveys',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stacked Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (highPct > 0)
                    Expanded(
                      flex: (highPct * 100).toInt(),
                      child: Container(color: const Color(0xFFDC2626)),
                    ),
                  if (medPct > 0)
                    Expanded(
                      flex: (medPct * 100).toInt(),
                      child: Container(color: const Color(0xFFD97706)),
                    ),
                  if (lowPct > 0)
                    Expanded(
                      flex: (lowPct * 100).toInt(),
                      child: Container(color: const Color(0xFF16A34A)),
                    ),
                  if (_totalSurveys == 0)
                    Expanded(
                      child: Container(color: const Color(0xFFE2E8F0)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend Metrics
          Row(
            children: [
              _buildDistributionLegend('High Risk', '$_highRiskCount', const Color(0xFFDC2626)),
              _buildDistributionLegend('Medium Risk', '$_mediumRiskCount', const Color(0xFFD97706)),
              _buildDistributionLegend('Low Risk', '$_lowRiskCount', const Color(0xFF16A34A)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionLegend(String label, String count, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterControlsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Reports & Audit Stream',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Barangay Dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBarangayFilter,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A)),
                      items: ['All Barangays', ...SupabaseService.lingayenBarangays].map((bgy) {
                        return DropdownMenuItem<String>(
                          value: bgy,
                          child: Text(bgy, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedBarangayFilter = val);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Risk Level Dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRiskFilter,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A)),
                      items: const ['All Risks', 'High', 'Medium', 'Low'].map((r) {
                        return DropdownMenuItem<String>(
                          value: r,
                          child: Text(r),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedRiskFilter = val);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Date Range Filter Button
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2023),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: _selectedDateRange,
              );
              if (picked != null) {
                setState(() => _selectedDateRange = picked);
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.date_range_outlined, size: 16, color: Color(0xFF0F172A)),
            label: Text(
              _selectedDateRange != null
                  ? '${_selectedDateRange!.start.toString().split(' ')[0]} to ${_selectedDateRange!.end.toString().split(' ')[0]}'
                  : 'Select Date Range Filter',
              style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
