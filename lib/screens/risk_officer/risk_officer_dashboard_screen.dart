import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_service.dart';
import 'barangay_risk_survey_screen.dart';
import 'house_to_house_checklist_screen.dart';

class CommunityRiskOfficerDashboard extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const CommunityRiskOfficerDashboard({
    super.key,
    this.onNavigateTab,
  });

  @override
  State<CommunityRiskOfficerDashboard> createState() => _CommunityRiskOfficerDashboardState();
}

class _CommunityRiskOfficerDashboardState extends State<CommunityRiskOfficerDashboard> {
  String _officerName = 'Community Risk Officer';
  String _badgeNumber = 'BFP-CRO';

  bool _isLoading = true;
  int _assessedBarangaysCount = 0;
  int _totalH2HInspectionsCount = 0;
  int _highRiskZonesCount = 0;

  List<Map<String, dynamic>> _recentSurveys = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchLiveMetricsAndFeed();
    OfflineSyncService().pendingCountNotifier.addListener(_fetchLiveMetricsAndFeed);
  }

  @override
  void dispose() {
    OfflineSyncService().pendingCountNotifier.removeListener(_fetchLiveMetricsAndFeed);
    super.dispose();
  }

  void _loadProfile() {
    final profile = AuthService().userProfile;
    if (profile != null) {
      setState(() {
        _officerName = profile['full_name']?.toString() ?? 'Community Risk Officer';
        _badgeNumber = profile['badge_number']?.toString() ?? 'BFP-CRO';
      });
    }
  }

  Future<void> _fetchLiveMetricsAndFeed() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    List<Map<String, dynamic>> allSurveys = [];

    // 1. Read offline pending surveys
    try {
      final offline = await OfflineSyncService().getPendingItems(targetTable: 'fire_risk_surveys');
      allSurveys.addAll(offline);
    } catch (e) {
      debugPrint('Error reading offline surveys in dashboard: $e');
    }

    // 2. Fetch remote surveys from Supabase
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('fire_risk_surveys')
          .select()
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> remote = List<Map<String, dynamic>>.from(res);
      final Set<String> existingIds = allSurveys.map((i) => (i['id'] ?? '').toString()).toSet();
      for (var r in remote) {
        final rId = (r['id'] ?? '').toString();
        if (!existingIds.contains(rId)) {
          allSurveys.add(r);
        }
      }
    } catch (e) {
      debugPrint('Error loading remote surveys in dashboard: $e');
    }

    // KPI Metrics calculation
    final Set<String> distinctAssessedBarangays = {};
    int h2hCount = 0;
    int highRiskCount = 0;

    for (var item in allSurveys) {
      String bgy = (item['barangay_name'] ?? item['barangay'] ?? '').toString().trim();
      if (bgy.isEmpty && item['survey_data'] is Map) {
        bgy = (item['survey_data']['barangayName'] ?? item['survey_data']['barangay'] ?? '').toString().trim();
      }

      final cleanBgy = bgy
          .replaceAll(RegExp(r'^brgy\.?\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'^barangay\s*', caseSensitive: false), '')
          .trim();

      if (cleanBgy.isNotEmpty) {
        distinctAssessedBarangays.add(cleanBgy.toLowerCase());
      }

      final surveyType = (item['survey_type'] ?? '').toString().toLowerCase().trim();
      final checklistType = (item['checklist_type'] ?? '').toString().toLowerCase().trim();
      final isH2H = surveyType == 'house_to_house' || checklistType == 'house_to_house';

      if (isH2H) {
        h2hCount++;
      }

      final risk = (item['risk_level'] ?? item['vulnerability_rating'] ?? '').toString();
      if (risk.toLowerCase().contains('high')) {
        highRiskCount++;
      }
    }

    if (mounted) {
      setState(() {
        _recentSurveys = allSurveys.take(10).toList();
        _assessedBarangaysCount = distinctAssessedBarangays.length;
        _totalH2HInspectionsCount = h2hCount;
        _highRiskZonesCount = highRiskCount;
        _isLoading = false;
      });
    }
  }

  Color _getRiskColor(String risk) {
    if (risk.toLowerCase().contains('high')) {
      return const Color(0xFFDC2626);
    } else if (risk.toLowerCase().contains('med')) {
      return const Color(0xFFD97706);
    } else {
      return const Color(0xFF16A34A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _fetchLiveMetricsAndFeed,
        color: const Color(0xFFEA580C),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [


              // Live KPI Grid
              const Text(
                'OLP Operational Risk Metrics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              _buildLiveKpiGrid(),
              const SizedBox(height: 20),

              // Quick Action Bar (H2H & Barangay triggers)
              _buildQuickActionBar(),
              const SizedBox(height: 20),

              // Live Stream Header & Feed List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent OLP Risk Inspections',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (widget.onNavigateTab != null) {
                        widget.onNavigateTab!(4); // Jump to Analytics & Reports
                      }
                    },
                    icon: const Icon(Icons.analytics_outlined, size: 16, color: Color(0xFFEA580C)),
                    label: const Text(
                      'Analytics Hub',
                      style: TextStyle(color: Color(0xFFEA580C), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildRecentSurveysStream(),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildLiveKpiGrid() {
    return Row(
      children: [
        _buildKpiCard(
          title: 'Assessed Barangays',
          value: '$_assessedBarangaysCount / 32',
          subtitle: 'CFPP Profiles',
          icon: Icons.map_outlined,
          color: const Color(0xFF0F172A),
        ),
        const SizedBox(width: 10),
        _buildKpiCard(
          title: 'H2H Inspections',
          value: '$_totalH2HInspectionsCount',
          subtitle: 'Households checked',
          icon: Icons.home_work_outlined,
          color: const Color(0xFFEA580C),
        ),
        const SizedBox(width: 10),
        _buildKpiCard(
          title: 'High-Risk Zones',
          value: '$_highRiskZonesCount',
          subtitle: 'High vulnerability',
          icon: Icons.warning_amber_outlined,
          color: const Color(0xFFDC2626),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
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
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 10),
            Text(
              _isLoading ? '...' : value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OLP Survey Triggers',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HouseToHouseChecklistScreen()),
                    ).then((_) => _fetchLiveMetricsAndFeed());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.home_work_outlined, size: 18),
                  label: const Text(
                    'New H2H Check',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const BarangayRiskSurveyScreen()),
                    ).then((_) => _fetchLiveMetricsAndFeed());
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.location_city_outlined, size: 18),
                  label: const Text(
                    'Barangay Profile',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSurveysStream() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: Color(0xFFEA580C)),
        ),
      );
    }

    if (_recentSurveys.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: const [
            Icon(Icons.rate_review_outlined, size: 36, color: Color(0xFF94A3B8)),
            SizedBox(height: 8),
            Text(
              'No recent OLP surveys logged',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentSurveys.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final survey = _recentSurveys[index];
        final surveyType = survey['survey_type']?.toString() ?? survey['checklist_type']?.toString() ?? 'barangay';
        final isH2H = surveyType == 'house_to_house';

        final titleText = isH2H
            ? (survey['occupant_name'] ?? survey['survey_data']?['occupantName'] ?? 'Household Inspection').toString()
            : 'Brgy. ${(survey['barangay_name'] ?? survey['barangay'] ?? 'Poblacion')}';

        final subtitleText = isH2H
            ? 'H2H Household • Brgy. ${(survey['barangay_name'] ?? survey['barangay'] ?? '')}'
            : 'Barangay CFPP Assessment';

        final risk = (survey['risk_level'] ?? survey['vulnerability_rating'] ?? 'Medium').toString();
        final riskColor = _getRiskColor(risk);

        final dateStr = survey['created_at']?.toString() ?? survey['date_inspected']?.toString();
        final date = dateStr != null
            ? DateTime.tryParse(dateStr)?.toLocal().toString().split(' ')[0] ?? 'N/A'
            : 'N/A';
        final bool isOfflinePending = (survey['status'] ?? '').toString().toLowerCase() == 'pending sync' || survey['_is_offline_pending'] == true;

        return Container(
          padding: const EdgeInsets.all(14),
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
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isH2H ? const Color(0xFFEA580C).withOpacity(0.1) : const Color(0xFF0F172A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isH2H ? Icons.home_work_outlined : Icons.domain_outlined,
                  color: isH2H ? const Color(0xFFEA580C) : const Color(0xFF0F172A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isH2H ? const Color(0xFFEA580C) : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isH2H ? 'H2H' : 'BARANGAY',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            titleText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$subtitleText • $date',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOfflinePending ? const Color(0xFFFEF3C7) : riskColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
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
    );
  }
}
