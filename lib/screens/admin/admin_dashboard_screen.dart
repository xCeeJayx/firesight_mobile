import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/route_guard.dart';
import '../../widgets/common/kpi_stat_card.dart';
import 'user_management_screen.dart';
import 'admin_reports_screen.dart';
import 'audit_logs_screen.dart';

class StationOfficerDashboard extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;
  const StationOfficerDashboard({super.key, this.onSelectTab});

  @override
  State<StationOfficerDashboard> createState() => _StationOfficerDashboardState();
}

class _StationOfficerDashboardState extends State<StationOfficerDashboard> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _badgeController = TextEditingController();

  UserRole _selectedProvisionRole = UserRole.fireInspector;
  bool _isCreatingUser = false;
  int _activeSubModuleIndex = 0; // 0: Overview Dashboard, 1: User Management, 2: Reports & Analytics, 3: Audit Logs

  late Future<Map<String, dynamic>> _dashboardMetricsFuture;
  late Future<List<Map<String, dynamic>>> _inspectionsFeedFuture;
  late Future<List<Map<String, dynamic>>> _criticalAlertsFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
    OfflineSyncService().pendingCountNotifier.addListener(_refreshData);
  }

  @override
  void dispose() {
    OfflineSyncService().pendingCountNotifier.removeListener(_refreshData);
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _dashboardMetricsFuture = _fetchMetrics();
        _inspectionsFeedFuture = _fetchInspectionsFeed();
        _criticalAlertsFuture = _fetchCriticalAlerts();
      });
    }
  }

  Future<Map<String, dynamic>> _fetchMetrics() async {
    final client = Supabase.instance.client;

    int totalInspections = 0;
    int pendingAuditFlags = 0;
    int highRiskBarangays = 0;
    int activePersonnel = 0;
    int inspectorsCount = 0;
    int riskOfficersCount = 0;

    // Fetch Profiles Metrics
    try {
      final profilesRes = await client.from('profiles').select();
      final profilesList = List<Map<String, dynamic>>.from(profilesRes as List);
      activePersonnel = profilesList.where((p) => p['role'] != 'public_guest' && (p['is_active'] ?? true)).length;
      inspectorsCount = profilesList.where((p) => p['role'] == 'fire_inspector').length;
      riskOfficersCount = profilesList.where((p) => p['role'] == 'community_risk_officer').length;
    } catch (e) {
      debugPrint('Error fetching profiles count: $e');
    }

    // Fetch Inspections Metrics
    try {
      final inspectionsRes = await client.from('inspections').select();
      final inspectionsList = List<Map<String, dynamic>>.from(inspectionsRes as List);
      totalInspections = inspectionsList.length;
      pendingAuditFlags = inspectionsList.where((i) {
        final status = (i['compliance_status'] ?? i['overall_status'] ?? '').toString().toLowerCase();
        return status.contains('non-compliant') || status.contains('fail') || status.contains('re-inspection');
      }).length;
    } catch (e) {
      debugPrint('Error fetching inspections count: $e');
    }

    // Fetch Surveys Metrics
    try {
      final surveysRes = await client.from('fire_risk_surveys').select();
      final surveysList = List<Map<String, dynamic>>.from(surveysRes as List);
      highRiskBarangays = surveysList.where((s) {
        final rating = (s['vulnerability_rating'] ?? s['risk_level'] ?? '').toString().toLowerCase();
        return rating.contains('high') || rating.contains('critical');
      }).length;
    } catch (e) {
      debugPrint('Note fetching surveys count: $e');
    }

    return {
      'totalInspections': totalInspections,
      'highRiskBarangays': highRiskBarangays,
      'activePersonnel': activePersonnel,
      'inspectorsCount': inspectorsCount,
      'riskOfficersCount': riskOfficersCount,
      'pendingAuditFlags': pendingAuditFlags,
    };
  }

  Future<List<Map<String, dynamic>>> _fetchInspectionsFeed() async {
    List<Map<String, dynamic>> items = [];

    // Read offline pending items
    try {
      final offline = await OfflineSyncService().getPendingItems(targetTable: 'inspections');
      items.addAll(offline);
    } catch (_) {}

    try {
      final response = await Supabase.instance.client
          .from('inspections')
          .select()
          .order('created_at', ascending: false)
          .limit(10);
      final remote = List<Map<String, dynamic>>.from(response);
      final Set<String> existingIds = items.map((i) => (i['id'] ?? '').toString()).toSet();
      for (var r in remote) {
        final rId = (r['id'] ?? '').toString();
        if (!existingIds.contains(rId)) {
          items.add(r);
        }
      }
      return items;
    } catch (_) {
      return items;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCriticalAlerts() async {
    try {
      final response = await Supabase.instance.client
          .from('inspections')
          .select('business_name, recommendation, compliance_status, overall_status, created_at')
          .order('created_at', ascending: false)
          .limit(15);

      final list = List<Map<String, dynamic>>.from(response);
      final critical = list.where((item) {
        final c = item['compliance_status']?.toString().toLowerCase() ?? '';
        final s = item['overall_status']?.toString().toLowerCase() ?? '';
        return c.contains('non-compliant') || c.contains('fail') || s.contains('fail');
      }).take(5);

      return critical.map((item) {
        return {
          'title': 'Re-Inspection Flag: ${item['business_name'] ?? 'Establishment'}',
          'subtitle': item['recommendation']?.toString() ?? 'Non-Compliant status detected during audit.',
          'time': item['created_at']?.toString().split('T')[0] ?? 'Recent',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void _showProvisioningModal() {
    _emailController.clear();
    _passwordController.clear();
    _fullNameController.clear();
    _badgeController.clear();
    _selectedProvisionRole = UserRole.fireInspector;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.person_add_outlined,
                                  color: Color(0xFFEA580C),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Provision Personnel Account',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Select Staff Role',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Fire Inspector'),
                              avatar: const Icon(Icons.badge_outlined, size: 16),
                              selected: _selectedProvisionRole == UserRole.fireInspector,
                              selectedColor: const Color(0xFFEA580C).withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: _selectedProvisionRole == UserRole.fireInspector
                                    ? const Color(0xFFEA580C)
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() => _selectedProvisionRole = UserRole.fireInspector);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Risk Officer'),
                              avatar: const Icon(Icons.map_outlined, size: 16),
                              selected: _selectedProvisionRole == UserRole.communityRiskOfficer,
                              selectedColor: const Color(0xFF0F172A).withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: _selectedProvisionRole == UserRole.communityRiskOfficer
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() => _selectedProvisionRole = UserRole.communityRiskOfficer);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'e.g. Insp. Juan Cruz',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter full name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _badgeController,
                        decoration: const InputDecoration(
                          labelText: 'Badge / Service ID Number',
                          hintText: 'e.g. BFP-9821',
                          prefixIcon: Icon(Icons.shield_outlined, size: 20),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter badge number' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Official Email Address',
                          hintText: 'officer@bfp.gov.ph',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter email address';
                          if (!val.contains('@')) return 'Enter a valid email address';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Initial Password',
                          hintText: 'At least 6 characters',
                          prefixIcon: Icon(Icons.lock_outline, size: 20),
                        ),
                        validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isCreatingUser ? null : () => _handleCreateStaff(setModalState),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                          ),
                          icon: _isCreatingUser
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_outline, size: 20),
                          label: Text(
                            _isCreatingUser ? 'Provisioning Account...' : 'Create Staff Credentials',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleCreateStaff(StateSetter setModalState) async {
    if (!_formKey.currentState!.validate()) return;

    setModalState(() => _isCreatingUser = true);
    setState(() => _isCreatingUser = true);

    try {
      final res = await AuthService().createStaffAccount(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: _fullNameController.text.trim(),
        badgeNumber: _badgeController.text.trim(),
        role: _selectedProvisionRole,
      );

      if (mounted) {
        setModalState(() => _isCreatingUser = false);
        setState(() => _isCreatingUser = false);

        if (res['success'] == true) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 10),
                  Text('Staff Account Provisioned for ${_fullNameController.text.trim()}'),
                ],
              ),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _refreshData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Failed to provision staff account'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setModalState(() => _isCreatingUser = false);
        setState(() => _isCreatingUser = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleLogout() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(RouteGuard.routeLogin, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _buildStationCommandOverview(),
    );
  }

  Widget _buildStationCommandOverview() {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // High Priority Alert Banner
            _buildAlertBanner(),

            // KPI Grid
            const Text(
              'Station Command Analytics Overview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            _buildKpiGrid(),
            const SizedBox(height: 20),

            // Recent Inspections Feed
            _buildRecentActivitySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBanner() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _criticalAlertsFuture,
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? [];
        if (alerts.isEmpty) return const SizedBox.shrink();

        final topAlert = alerts.first;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'HIGH-PRIORITY COMMAND ALERT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          topAlert['time'] ?? 'Just now',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      topAlert['title'] ?? 'Attention Required',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      topAlert['subtitle'] ?? '',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      },
    );
  }

  Widget _buildKpiGrid() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardMetricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(30.0),
              child: CircularProgressIndicator(color: Color(0xFFEA580C)),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final activePersonnel = data['activePersonnel']?.toString() ?? '12';
        final totalInspections = data['totalInspections']?.toString() ?? '48';
        final highRiskBarangays = data['highRiskBarangays']?.toString() ?? '14';
        final pendingAuditFlags = data['pendingAuditFlags']?.toString() ?? '3';

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            KpiStatCard(
              title: 'Active Personnel',
              value: activePersonnel,
              subtitle: 'Inspectors & CROs Active',
              icon: Icons.people_outline,
              accentColor: const Color(0xFFEA580C),
            ),
            KpiStatCard(
              title: 'Total FSIC Inspections',
              value: totalInspections,
              subtitle: 'Conducted Station-wide',
              icon: Icons.assignment_turned_in_outlined,
              accentColor: const Color(0xFF0F172A),
            ),
            KpiStatCard(
              title: 'High-Risk Barangays',
              value: highRiskBarangays,
              subtitle: 'OLP Assessed Zones',
              icon: Icons.warning_amber_rounded,
              accentColor: const Color(0xFFDC2626),
            ),
            KpiStatCard(
              title: 'Pending Audit Flags',
              value: pendingAuditFlags,
              subtitle: 'Re-inspections Needed',
              icon: Icons.shield_outlined,
              accentColor: const Color(0xFF16A34A),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProvisioningCard() {
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_add_outlined, color: Color(0xFF0F172A), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Personnel Provisioning',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Issue credentials for Fire Inspectors & Risk Officers',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showProvisioningModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Provision Staff', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Station Inspections',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: () {
                if (widget.onSelectTab != null) {
                  widget.onSelectTab!(3);
                }
              },
              child: const Text(
                'View All Logs',
                style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _inspectionsFeedFuture,
          builder: (context, snapshot) {
            final list = snapshot.data ?? [];
            if (list.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'No recent inspections recorded.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return Column(
              children: list.take(5).map((item) {
                final String bName = item['business_name']?.toString() ?? 'Establishment';
                final String status = item['compliance_status']?.toString() ?? item['overall_status']?.toString() ?? 'Passed';
                final isPass = status.toLowerCase().contains('compliant') || status.toLowerCase().contains('pass');
                final bool isOfflinePending = status.toLowerCase() == 'pending sync' || item['_is_offline_pending'] == true;

                return InkWell(
                  onTap: () => _showInspectionDetailsModal(item),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
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
                      children: [
                        Icon(
                          isPass ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                          color: isPass ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isOfflinePending ? 'Form 061 • PENDING SYNC (OFFLINE)' : 'Form 061 • Status: $status',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOfflinePending ? const Color(0xFFB45309) : (isPass ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  void _showInspectionDetailsModal(Map<String, dynamic> item) {
    final String bName = item['business_name']?.toString() ?? 'Establishment Inspection';
    final String status = item['compliance_status']?.toString() ?? item['overall_status']?.toString() ?? 'FSIC Issued';
    final String recommendation = item['recommendation']?.toString() ?? 'No special recommendations recorded.';
    final String dateInspected = item['date_inspected']?.toString() ?? item['created_at']?.toString().split('T')[0] ?? 'N/A';
    final String inspectorId = item['inspector_id']?.toString() ?? 'Assigned BFP Inspector';
    final isPass = status.toLowerCase().contains('compliant') || status.toLowerCase().contains('pass');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isPass ? const Color(0xFF16A34A) : const Color(0xFFDC2626)).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isPass ? Icons.verified_outlined : Icons.warning_amber_rounded,
                          color: isPass ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Inspection Record Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPass ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPass ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Date: $dateInspected',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Inspector Recommendation & Findings',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              Text(
                recommendation,
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                'Inspector Ref: $inspectorId',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close Details', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
