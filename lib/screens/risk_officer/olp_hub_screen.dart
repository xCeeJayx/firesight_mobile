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
  String _feedFilter = 'All'; // 'All', 'CFPP', 'H2H'

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed Top Launch Cards (Sticky / Non-scrolling)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
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
          ),

          // Scrollable Recent Submissions Feed
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchRecentOlps,
              color: const Color(0xFFEA580C),
              child: _buildRecentFeedList(scrollable: true),
            ),
          ),
        ],
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

  Widget _buildRecentFeedList({bool scrollable = false}) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: Color(0xFFEA580C)),
        ),
      );
    }

    if (_recentOlps.isEmpty) {
      final emptyWidget = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

      if (scrollable) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: emptyWidget,
        );
      }
      return emptyWidget;
    }

    final filteredOlps = _recentOlps.where((s) {
      final sType = (s['survey_type'] ?? s['checklist_type'] ?? 'barangay').toString().toLowerCase();
      final isH2H = sType == 'house_to_house';
      if (_feedFilter == 'CFPP') return !isH2H;
      if (_feedFilter == 'H2H') return isH2H;
      return true;
    }).toList();

    return ListView.builder(
      shrinkWrap: !scrollable,
      physics: scrollable ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
      padding: scrollable ? const EdgeInsets.fromLTRB(16, 8, 16, 24) : EdgeInsets.zero,
      itemCount: filteredOlps.isEmpty ? 2 : filteredOlps.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          final cfppCount = _recentOlps.where((s) => (s['survey_type'] ?? s['checklist_type'] ?? '').toString().toLowerCase() != 'house_to_house').length;
          final h2hCount = _recentOlps.where((s) => (s['survey_type'] ?? s['checklist_type'] ?? '').toString().toLowerCase() == 'house_to_house').length;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFeedFilterChip('All', 'All (${_recentOlps.length})'),
                      _buildFeedFilterChip('CFPP', 'Barangay CFPP ($cfppCount)'),
                      _buildFeedFilterChip('H2H', 'H2H Household ($h2hCount)'),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (filteredOlps.isEmpty) {
          return Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                'No ${_feedFilter == "CFPP" ? "Barangay CFPP" : "H2H"} submissions found.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          );
        }

        final survey = filteredOlps[index - 1];
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

  Widget _buildFeedFilterChip(String value, String label) {
    final isSelected = _feedFilter == value;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF0F172A),
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _feedFilter = value;
            });
          }
        },
      ),
    );
  }
}
