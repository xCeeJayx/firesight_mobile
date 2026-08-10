import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/route_guard.dart';
import '../../widgets/emergency/emergency_reports_feed.dart';
import '../../services/emergency_service.dart';
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
        _criticalAlertsFuture = _fetchCriticalAlerts();
      });
      EmergencyService().fetchReports();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed Top Header & Overview Cards (Sticky / Non-scrolling)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAlertBanner(),
              const Text(
                'Station Command Analytics Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              _buildKpiGrid(),
            ],
          ),
        ),

        // Scrollable Live Emergency Reports Feed
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _refreshData(),
            color: const Color(0xFFEA580C),
            child: const EmergencyReportsFeed(
              isExpanded: true,
              padding: EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
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
                        const Expanded(
                          child: Text(
                            'HIGH-PRIORITY COMMAND ALERT',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFDC2626),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final data = snapshot.data ?? {};
        final activePersonnel = data['activePersonnel']?.toString() ?? '12';
        final totalInspections = data['totalInspections']?.toString() ?? '48';
        final highRiskBarangays = data['highRiskBarangays']?.toString() ?? '14';

        return Row(
          children: [
            _buildKpiCard(
              title: 'Active Personnel',
              value: isLoading ? '...' : activePersonnel,
              subtitle: 'Inspectors & CROs',
              icon: Icons.people_outline,
              color: const Color(0xFFEA580C),
            ),
            const SizedBox(width: 10),
            _buildKpiCard(
              title: 'FSIC Inspections',
              value: isLoading ? '...' : totalInspections,
              subtitle: 'Station-wide',
              icon: Icons.assignment_turned_in_outlined,
              color: const Color(0xFF0F172A),
            ),
            const SizedBox(width: 10),
            _buildKpiCard(
              title: 'High-Risk Zones',
              value: isLoading ? '...' : highRiskBarangays,
              subtitle: 'OLP Assessed',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFDC2626),
            ),
          ],
        );
      },
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
              value,
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
}
