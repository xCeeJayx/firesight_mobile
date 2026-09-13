import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import 'barangay_risk_survey_screen.dart';

class BarangayRiskMapScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  final Function(String)? onSelectBarangayForSurvey;

  const BarangayRiskMapScreen({
    super.key,
    this.onNavigateTab,
    this.onSelectBarangayForSurvey,
  });

  @override
  State<BarangayRiskMapScreen> createState() => _BarangayRiskMapScreenState();
}

class _BarangayRiskMapScreenState extends State<BarangayRiskMapScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterRisk = 'All';

  // Map of barangay name -> latest CFPP survey record
  Map<String, Map<String, dynamic>> _latestCfppByBarangay = {};
  // Map of barangay name -> aggregated H2H inspection stats
  Map<String, Map<String, dynamic>> _h2hStatsByBarangay = {};

  @override
  void initState() {
    super.initState();
    _fetchLatestSurveys();
  }

  Future<void> _fetchLatestSurveys() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final res = await Supabase.instance.client
          .from('fire_risk_surveys')
          .select()
          .order('created_at', ascending: false);

      final Map<String, Map<String, dynamic>> latestCfpp = {};
      final Map<String, List<Map<String, dynamic>>> h2hListMap = {};

      for (var item in res) {
        final bgy = (item['barangay'] ?? item['barangay_name'] ?? '').toString().trim();
        if (bgy.isEmpty) continue;
        final sType = (item['survey_type'] ?? item['checklist_type'] ?? '').toString().toLowerCase().trim();

        if (sType == 'house_to_house') {
          h2hListMap.putIfAbsent(bgy, () => []).add(Map<String, dynamic>.from(item));
        } else {
          // CFPP assessment strictly drives barangay status
          if (!latestCfpp.containsKey(bgy)) {
            latestCfpp[bgy] = Map<String, dynamic>.from(item);
          }
        }
      }

      final Map<String, Map<String, dynamic>> h2hStats = {};
      h2hListMap.forEach((bgy, list) {
        int safe = 0;
        int mod = 0;
        int high = 0;
        for (var h in list) {
          final r = (h['risk_level'] ?? h['survey_data']?['riskLevel'] ?? '').toString().toLowerCase();
          final interp = (h['survey_data']?['safetyInterpretation'] ?? '').toString().toLowerCase();
          if (r.contains('high') || interp.contains('mapanganib')) {
            high++;
          } else if (r.contains('med') || interp.contains('ipangamba') || interp.contains('pangamba')) {
            mod++;
          } else {
            safe++;
          }
        }
        String dominant = 'Ligtas';
        if (high >= safe && high >= mod) {
          dominant = 'Mapanganib';
        } else if (mod >= safe && mod >= high) {
          dominant = 'May Pangamba';
        }
        h2hStats[bgy] = {
          'total': list.length,
          'safe': safe,
          'moderate': mod,
          'high': high,
          'dominant': dominant,
        };
      });

      setState(() {
        _latestCfppByBarangay = latestCfpp;
        _h2hStatsByBarangay = h2hStats;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching risk surveys: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getRiskColor(String? risk) {
    if (risk == null) return const Color(0xFF94A3B8); // Gray for pending/unassessed
    final r = risk.toLowerCase();
    if (r.contains('high')) return const Color(0xFFDC2626);
    if (r.contains('med')) return const Color(0xFFD97706);
    if (r.contains('low')) return const Color(0xFF16A34A);
    return const Color(0xFF94A3B8);
  }

  String _formatRiskBadgeText(String? riskLevel) {
    if (riskLevel == null || riskLevel.trim().isEmpty) return 'Pending';
    final clean = riskLevel.replaceAll(RegExp(r'\s*risk', caseSensitive: false), '').trim();
    if (clean.isEmpty) return 'Pending';
    return '$clean Risk';
  }

  List<String> get _filteredBarangays {
    return SupabaseService.lingayenBarangays.where((bgy) {
      final matchesSearch = bgy.toLowerCase().contains(_searchQuery.toLowerCase().trim());
      if (!matchesSearch) return false;

      final survey = _latestCfppByBarangay[bgy];
      final risk = survey?['risk_level']?.toString() ?? survey?['vulnerability_rating']?.toString();

      if (_filterRisk == 'All') return true;
      if (_filterRisk == 'Pending') return survey == null;
      if (_filterRisk == 'High') return risk != null && risk.toLowerCase().contains('high');
      if (_filterRisk == 'Medium') return risk != null && risk.toLowerCase().contains('med');
      if (_filterRisk == 'Low') return risk != null && risk.toLowerCase().contains('low');

      return true;
    }).toList();
  }

  void _showBarangayDetailSheet(String barangayName, Map<String, dynamic>? survey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final riskLevel = survey?['risk_level']?.toString() ?? survey?['vulnerability_rating']?.toString() ?? 'Pending Assessment';
        final riskColor = _getRiskColor(survey != null ? riskLevel : null);
        final lastDateStr = survey?['created_at']?.toString() ?? survey?['date_inspected']?.toString();
        final formattedDate = lastDateStr != null
            ? DateTime.tryParse(lastDateStr)?.toLocal().toString().split(' ')[0] ?? 'N/A'
            : 'Never Assessed';
        final surveyor = survey?['surveyor_name']?.toString() ?? 'N/A';

        final buildingDensity = survey?['building_density']?.toString() ?? 'Not Recorded';
        final waterSupply = survey?['water_supply_status']?.toString() ?? 'Not Recorded';
        final construction = survey?['construction_material']?.toString() ?? 'Not Recorded';
        final incidents = survey?['historical_fire_incidents']?.toString() ?? '0';

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Risk Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Brgy. $barangayName',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Municipality of Lingayen, Pangasinan',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: riskColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      riskLevel.toUpperCase(),
                      style: TextStyle(
                        color: riskColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              // Hazard factors list
              const Text(
                'Primary Hazard & Vulnerability Factors',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              _buildDetailItem(Icons.domain_outlined, 'Building Structure Density', buildingDensity),
              _buildDetailItem(Icons.water_drop_outlined, 'Water Supply / Hydrants', waterSupply),
              _buildDetailItem(Icons.other_houses_outlined, 'Dominant Material', construction),
              _buildDetailItem(Icons.local_fire_department_outlined, 'Historical Fire Incidents', '$incidents reported'),
              _buildDetailItem(Icons.calendar_month_outlined, 'Last Surveyed Date', formattedDate),
              _buildDetailItem(Icons.badge_outlined, 'Assessing Officer', surveyor),

              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 10),

              // HOUSE-TO-HOUSE (H2H) SECTION
              Builder(
                builder: (context) {
                  final h2h = _h2hStatsByBarangay[barangayName];
                  final totalH2H = (h2h?['total'] as num?)?.toInt() ?? 0;
                  final safe = (h2h?['safe'] as num?)?.toInt() ?? 0;
                  final mod = (h2h?['moderate'] as num?)?.toInt() ?? 0;
                  final high = (h2h?['high'] as num?)?.toInt() ?? 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'House-to-House (H2H) Inspections',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (totalH2H > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$totalH2H Inspected',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (totalH2H == 0)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Text(
                            'No household fire safety checks recorded for this barangay.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(child: _buildDetailPill('Ligtas', '$safe', const Color(0xFF16A34A))),
                            const SizedBox(width: 8),
                            Expanded(child: _buildDetailPill('May Pangamba', '$mod', const Color(0xFFD97706))),
                            const SizedBox(width: 8),
                            Expanded(child: _buildDetailPill('Mapanganib', '$high', const Color(0xFFDC2626))),
                          ],
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // Update trigger button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BarangayRiskSurveyScreen(
                          initialBarangay: barangayName,
                        ),
                      ),
                    ).then((_) => _fetchLatestSurveys());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text(
                    'Update CFPP Risk Profile',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBarangays;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Community Risk Directory & Map',
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
            icon: const Icon(Icons.refresh_outlined, color: Color(0xFF0F172A)),
            onPressed: _fetchLatestSurveys,
            tooltip: 'Refresh Surveys',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE2E8F0), height: 1.0),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLatestSurveys,
        child: Column(
          children: [
            // Search Bar & Filter Chips Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  // Search Field
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search barangay by name...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_outlined, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All'),
                        _buildFilterChip('High'),
                        _buildFilterChip('Medium'),
                        _buildFilterChip('Low'),
                        _buildFilterChip('Pending'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Barangays Grid / List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.search_off_outlined, size: 48, color: Color(0xFF94A3B8)),
                              SizedBox(height: 12),
                              Text(
                                'No barangays match your filter',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.74,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final bgyName = filtered[index];
                            final cfppSurvey = _latestCfppByBarangay[bgyName];
                            final h2h = _h2hStatsByBarangay[bgyName];
                            final totalH2H = (h2h?['total'] as num?)?.toInt() ?? 0;
                            final dominant = h2h?['dominant']?.toString() ?? 'Ligtas';

                            final riskLevel = cfppSurvey?['risk_level']?.toString() ?? cfppSurvey?['vulnerability_rating']?.toString();
                            final riskColor = _getRiskColor(riskLevel);
                            final badgeText = _formatRiskBadgeText(riskLevel);

                            Color h2hColor;
                            if (dominant == 'Mapanganib') {
                              h2hColor = const Color(0xFFDC2626);
                            } else if (dominant == 'May Pangamba') {
                              h2hColor = const Color(0xFFD97706);
                            } else {
                              h2hColor = const Color(0xFF16A34A);
                            }

                            return GestureDetector(
                              onTap: () => _showBarangayDetailSheet(bgyName, cfppSurvey),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Top: Barangay Name + Chevron
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            bgyName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right_outlined,
                                          size: 13,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ],
                                    ),

                                    // Middle: CFPP Risk Badge & Status
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: riskColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: riskColor.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            badgeText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: riskColor,
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          cfppSurvey != null ? 'CFPP Assessed' : 'Needs CFPP',
                                          style: const TextStyle(
                                            fontSize: 8.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Bottom: H2H Sub-Card
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.home_outlined, size: 9, color: Color(0xFF64748B)),
                                              const SizedBox(width: 2),
                                              Expanded(
                                                child: Text(
                                                  totalH2H > 0 ? '$totalH2H H2H' : '0 H2H',
                                                  style: const TextStyle(
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF334155),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            totalH2H > 0 ? dominant : 'None',
                                            style: TextStyle(
                                              fontSize: 7.5,
                                              fontWeight: FontWeight.bold,
                                              color: totalH2H > 0 ? h2hColor : const Color(0xFF94A3B8),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filterRisk.toLowerCase() == label.toLowerCase();
    final chipLabel = label == 'All' ? 'All (32)' : label;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(chipLabel),
        selected: isSelected,
        selectedColor: const Color(0xFF0F172A),
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
        showCheckmark: false,
        onSelected: (val) {
          if (val) {
            setState(() => _filterRisk = label);
          }
        },
      ),
    );
  }
}
