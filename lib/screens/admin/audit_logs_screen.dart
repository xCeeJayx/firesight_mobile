import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedActionFilter = 'All';
  late Future<List<Map<String, dynamic>>> _auditLogsFuture;

  final List<Map<String, String>> _actionFilters = [
    {'value': 'All', 'label': 'All System Events'},
    {'value': 'USER_ROLE_UPDATED', 'label': 'Role Updated'},
    {'value': 'USER_STATUS_TOGGLED', 'label': 'Status Changed'},
    {'value': 'USER_PROVISIONED', 'label': 'User Provisioned'},
    {'value': 'INSPECTION_SUBMITTED', 'label': 'Inspection Submitted'},
    {'value': 'REPORT_GENERATED', 'label': 'Report Generated'},
    {'value': 'OFFLINE_DATA_SYNCED', 'label': 'Offline Data Synced'},
  ];

  static String formatActionType(String rawAction) {
    if (rawAction.isEmpty) return 'System Event';
    final upper = rawAction.toUpperCase().trim();

    const Map<String, String> friendlyNames = {
      'REPORT_GENERATED': 'Report Generated',
      'OFFLINE_DATA_SYNCED': 'Offline Data Synced',
      'USER_ROLE_UPDATED': 'User Role Updated',
      'USER_STATUS_TOGGLED': 'User Status Changed',
      'USER_PROVISIONED': 'User Provisioned',
      'INSPECTION_SUBMITTED': 'Inspection Submitted',
      'FIRE_RISK_SURVEY_SUBMITTED': 'Risk Survey Submitted',
      'PASSWORD_RESET_REQUESTED': 'Password Reset',
      'OFFLINE_INSPECTION_QUEUED': 'Offline Inspection Queued',
      'OFFLINE_SURVEY_QUEUED': 'Offline Survey Queued',
      'LOGIN_SUCCESS': 'User Login',
      'LOGOUT': 'User Logout',
    };

    if (friendlyNames.containsKey(upper)) {
      return friendlyNames[upper]!;
    }

    // Default beautifier: replace underscores and Title Case
    return upper
        .split(RegExp(r'[_\s]+'))
        .where((w) => w.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshLogs() {
    setState(() {
      _auditLogsFuture = AuthService().fetchAuditLogs(
        searchQuery: _searchController.text,
        actionFilter: _selectedActionFilter,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed Top Search Header & Filter Chips (Sticky / Non-scrolling)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 12),
                _buildFilterChips(),
              ],
            ),
          ),

          // Scrollable Audit Logs Stream
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refreshLogs(),
              color: const Color(0xFFEA580C),
              child: _buildLogStream(scrollable: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history_edu_outlined, color: Color(0xFFEA580C), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Audit Trail & Activity Logs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'System-wide tracking of critical officer & profile actions',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (_) => _refreshLogs(),
            decoration: InputDecoration(
              hintText: 'Search by Officer, Target Entity, or Details...',
              prefixIcon: const Icon(Icons.search_outlined, color: Color(0xFF64748B)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _refreshLogs();
                      },
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: _actionFilters.map((filter) {
          final filterVal = filter['value']!;
          final filterLabel = filter['label']!;
          final isSelected = _selectedActionFilter == filterVal;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filterLabel),
              selected: isSelected,
              selectedColor: const Color(0xFFEA580C).withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedActionFilter = filterVal;
                    _refreshLogs();
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLogStream({bool scrollable = false}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _auditLogsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Color(0xFFEA580C)),
            ),
          );
        }

        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          final emptyWidget = Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.rule_folder_outlined, size: 48, color: Color(0xFF94A3B8)),
                SizedBox(height: 12),
                Text(
                  'No Audit Log Records',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 4),
                Text(
                  'No activity logs matched your active search and filter criteria.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          );

          if (scrollable) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: emptyWidget,
            );
          }
          return emptyWidget;
        }

        return ListView.separated(
          shrinkWrap: !scrollable,
          physics: scrollable ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
          padding: scrollable ? const EdgeInsets.fromLTRB(16, 0, 16, 24) : EdgeInsets.zero,
          itemCount: logs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final logItem = logs[index];
            return _buildAuditLogCard(logItem);
          },
        );
      },
    );
  }

  Widget _buildAuditLogCard(Map<String, dynamic> item) {
    final String timestamp = item['created_at']?.toString() ?? '';
    final String performer = item['performer_name']?.toString() ?? 'System Officer';
    final String rawAction = (item['action_type'] ?? 'EVENT').toString();
    final String formattedTitle = formatActionType(rawAction);
    final String actionType = rawAction.toUpperCase();
    final String target = item['target_entity']?.toString() ?? 'General';
    final String details = item['details']?.toString() ?? '';

    Color badgeColor;
    IconData actionIcon;

    if (actionType.contains('USER_PROVISIONED') || actionType.contains('CREATED')) {
      badgeColor = const Color(0xFF16A34A);
      actionIcon = Icons.person_add_outlined;
    } else if (actionType.contains('USER_ROLE') || actionType.contains('UPDATED')) {
      badgeColor = const Color(0xFFEA580C);
      actionIcon = Icons.manage_accounts_outlined;
    } else if (actionType.contains('STATUS') || actionType.contains('TOGGLED')) {
      badgeColor = const Color(0xFFDC2626);
      actionIcon = Icons.shield_outlined;
    } else if (actionType.contains('REPORT')) {
      badgeColor = const Color(0xFF0284C7);
      actionIcon = Icons.picture_as_pdf_outlined;
    } else if (actionType.contains('SYNC') || actionType.contains('OFFLINE')) {
      badgeColor = const Color(0xFF0D9488);
      actionIcon = Icons.cloud_done_outlined;
    } else if (actionType.contains('INSPECTION')) {
      badgeColor = const Color(0xFFD84315);
      actionIcon = Icons.assignment_turned_in_outlined;
    } else {
      badgeColor = const Color(0xFF0F172A);
      actionIcon = Icons.history_outlined;
    }

    String formattedTime = 'Recent';
    try {
      if (timestamp.isNotEmpty) {
        final dt = DateTime.parse(timestamp).toLocal();
        formattedTime = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(actionIcon, color: badgeColor, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            formattedTitle,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formattedTime,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    performer,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_right_alt_rounded, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    target,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  details,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
