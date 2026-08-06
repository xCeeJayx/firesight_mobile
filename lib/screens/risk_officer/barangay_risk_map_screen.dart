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

  // Map of barangay name -> latest survey record
  Map<String, Map<String, dynamic>> _latestSurveysByBarangay = {};

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

      final Map<String, Map<String, dynamic>> latestMap = {};

      for (var item in res) {
        final bgy = item['barangay']?.toString() ?? item['barangay_name']?.toString() ?? '';
        if (bgy.isNotEmpty && !latestMap.containsKey(bgy)) {
          latestMap[bgy] = Map<String, dynamic>.from(item);
        }
      }

      setState(() {
        _latestSurveysByBarangay = latestMap;
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
    switch (risk.toLowerCase()) {
      case 'high':
        return const Color(0xFFDC2626);
      case 'medium':
        return const Color(0xFFD97706);
      case 'low':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  List<String> get _filteredBarangays {
    return SupabaseService.lingayenBarangays.where((bgy) {
      final matchesSearch = bgy.toLowerCase().contains(_searchQuery.toLowerCase().trim());
      if (!matchesSearch) return false;

      final survey = _latestSurveysByBarangay[bgy];
      final risk = survey?['risk_level']?.toString() ?? survey?['vulnerability_rating']?.toString();

      if (_filterRisk == 'All') return true;
      if (_filterRisk == 'Pending') return survey == null;
      if (_filterRisk == 'High') return risk?.toLowerCase() == 'high';
      if (_filterRisk == 'Medium') return risk?.toLowerCase() == 'medium';
      if (_filterRisk == 'Low') return risk?.toLowerCase() == 'low';

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

              const SizedBox(height: 24),

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
                    'Update Risk Profile & Survey',
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
                            childAspectRatio: 0.95,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final bgyName = filtered[index];
                            final survey = _latestSurveysByBarangay[bgyName];
                            final riskLevel = survey?['risk_level']?.toString() ?? survey?['vulnerability_rating']?.toString();
                            final riskColor = _getRiskColor(riskLevel);

                            return GestureDetector(
                              onTap: () => _showBarangayDetailSheet(bgyName, survey),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            bgyName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right_outlined,
                                          size: 14,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: riskColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: riskColor.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            riskLevel != null ? '$riskLevel Risk' : 'Pending',
                                            style: TextStyle(
                                              color: riskColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          survey != null ? 'Assessed' : 'Needs Survey',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
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
