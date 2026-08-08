import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_service.dart';
import 'barangay_risk_survey_screen.dart';
import 'house_to_house_checklist_screen.dart';

class OlpHubScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const OlpHubScreen({
    super.key,
    this.onNavigateTab,
  });

  @override
  State<OlpHubScreen> createState() => _OlpHubScreenState();
}

class _OlpHubScreenState extends State<OlpHubScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _recentOlps = [];

  @override
  void initState() {
    super.initState();
    _fetchRecentOlps();
    OfflineSyncService().pendingCountNotifier.addListener(_fetchRecentOlps);
  }

  @override
  void dispose() {
    OfflineSyncService().pendingCountNotifier.removeListener(_fetchRecentOlps);
    super.dispose();
  }

  Future<void> _fetchRecentOlps() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    List<Map<String, dynamic>> list = [];

    // 1. Read offline pending surveys
    try {
      final offline = await OfflineSyncService().getPendingItems(targetTable: 'fire_risk_surveys');
      list.addAll(offline);
    } catch (e) {
      debugPrint('Error reading offline surveys: $e');
    }

    // 2. Fetch remote surveys from Supabase
    try {
      final res = await Supabase.instance.client
          .from('fire_risk_surveys')
          .select()
          .order('created_at', ascending: false)
          .limit(15);

      final remote = List<Map<String, dynamic>>.from(res);
      final Set<String> existingIds = list.map((i) => (i['id'] ?? '').toString()).toSet();
      for (var r in remote) {
        final rId = (r['id'] ?? '').toString();
        if (!existingIds.contains(rId)) {
          list.add(r);
        }
      }
    } catch (e) {
      debugPrint('Error loading OLP stream from network: $e');
    }

    if (mounted) {
      setState(() {
        _recentOlps = list;
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

  void _launchBarangaySurvey() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BarangayRiskSurveyScreen()),
    ).then((_) => _fetchRecentOlps());
  }

  void _launchH2HSurvey() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HouseToHouseChecklistScreen()),
    ).then((_) => _fetchRecentOlps());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Oplan Ligtas na Pamayanan (OLP)',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE2E8F0), height: 1.0),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRecentOlps,
        color: const Color(0xFFEA580C),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [


              // Actionable Cards Section Title
              const Text(
                'Launch OLP Risk Survey',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              // 2 Prominent Action Cards
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      title: 'Barangay CFPP Assessment',
                      subtitle: 'Community Fire Protection Plan & Vulnerability Matrix',
                      badge: 'BARANGAY PROFILE',
                      icon: Icons.location_city_outlined,
                      color: const Color(0xFF0F172A),
                      onTap: _launchBarangaySurvey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      title: 'House-to-House Safety Check',
                      subtitle: 'Official 35-Item Household Fire Safety Checklist',
                      badge: 'H2H HOUSEHOLD',
                      icon: Icons.home_work_outlined,
                      color: const Color(0xFFEA580C),
                      onTap: _launchH2HSurvey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Submissions Feed Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent OLP Submissions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _fetchRecentOlps,
                    icon: const Icon(Icons.refresh_outlined, size: 16, color: Color(0xFFEA580C)),
                    label: const Text(
                      'Refresh',
                      style: TextStyle(color: Color(0xFFEA580C), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Recent Submissions Feed List
              _buildRecentFeedList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
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
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFFEA580C),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'BFP Lingayen OLP Command Portal',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Conduct barangay vulnerability mapping or household safety checks. All submissions sync live to station analytics.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ValueListenableBuilder<int>(
            valueListenable: OfflineSyncService().pendingCountNotifier,
            builder: (context, pendingCount, _) {
              if (pendingCount == 0) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_problem_rounded, color: Color(0xFFB45309), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$pendingCount offline survey(s) pending sync to Supabase.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final res = await OfflineSyncService().syncNow();
                        _fetchRecentOlps();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Sync triggered.'),
                              backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sync_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Sync Now', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 190,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Icon(Icons.arrow_forward_outlined, color: color, size: 18),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentFeedList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: Color(0xFFEA580C)),
        ),
      );
    }

    if (_recentOlps.isEmpty) {
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
            Icon(Icons.inbox_outlined, size: 36, color: Color(0xFF94A3B8)),
            SizedBox(height: 8),
            Text(
              'No OLP surveys recorded yet',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentOlps.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final survey = _recentOlps[index];
        final surveyType = survey['survey_type']?.toString() ?? survey['checklist_type']?.toString() ?? 'barangay';
        final isH2H = surveyType == 'house_to_house';

        final titleText = isH2H
            ? (survey['occupant_name'] ?? survey['survey_data']?['occupantName'] ?? 'Household Check').toString()
            : 'Brgy. ${(survey['barangay_name'] ?? survey['barangay'] ?? 'Poblacion')}';

        final subtitleText = isH2H
            ? 'H2H Check • Brgy. ${(survey['barangay_name'] ?? survey['barangay'] ?? '')}'
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isH2H ? const Color(0xFFEA580C).withOpacity(0.1) : const Color(0xFF0F172A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isH2H ? Icons.home_work_outlined : Icons.domain_outlined,
                  color: isH2H ? const Color(0xFFEA580C) : const Color(0xFF0F172A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                        fontSize: 10,
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
