import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/emergency_service.dart';
import '../../widgets/emergency/emergency_reports_feed.dart';

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
    EmergencyService().fetchReports();
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

      final surveyType = (item['survey_type'] ?? '').toString().toLowerCase().trim();
      final checklistType = (item['checklist_type'] ?? '').toString().toLowerCase().trim();
      final isH2H = surveyType == 'house_to_house' || checklistType == 'house_to_house';

      if (isH2H) {
        h2hCount++;
      } else {
        if (cleanBgy.isNotEmpty) {
          distinctAssessedBarangays.add(cleanBgy.toLowerCase());
        }
        final risk = (item['risk_level'] ?? item['vulnerability_rating'] ?? '').toString();
        if (risk.toLowerCase().contains('high')) {
          highRiskCount++;
        }
      }
    }

    if (mounted) {
      setState(() {
        _assessedBarangaysCount = distinctAssessedBarangays.length;
        _totalH2HInspectionsCount = h2hCount;
        _highRiskZonesCount = highRiskCount;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed Top Header & Overview Cards (Sticky / Non-scrolling)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              ],
            ),
          ),

          // Scrollable Live Emergency Reports Feed
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchLiveMetricsAndFeed,
              color: const Color(0xFFEA580C),
              child: const EmergencyReportsFeed(
                isExpanded: true,
                padding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 10),
            Text(
              _isLoading ? '...' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
}
