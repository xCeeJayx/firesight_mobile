import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/offline_sync_service.dart';
import 'commercial_inspection_form_screen.dart';
import 'view_inspection_form_dialog.dart';

class InspectionHubScreen extends StatefulWidget {
  const InspectionHubScreen({super.key});

  @override
  State<InspectionHubScreen> createState() => _InspectionHubScreenState();
}

class _InspectionHubScreenState extends State<InspectionHubScreen> {
  // Design Tokens
  static const Color colorCanvas = Color(0xFFF8FAFC);
  static const Color colorSurface = Color(0xFFFFFFFF);
  static const Color colorTextPrimary = Color(0xFF0F172A);
  static const Color colorTextSecondary = Color(0xFF475569);
  static const Color colorAccent = Color(0xFFEA580C);
  static const Color colorBorder = Color(0xFFE2E8F0);
  static const Color colorSuccess = Color(0xFF16A34A);
  static const Color colorWarning = Color(0xFFD97706);
  static const Color colorInfo = Color(0xFF0284C7);

  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'Assigned';
  late Future<List<Map<String, dynamic>>> _inspectionsFuture;

  final List<String> _filterOptions = ['Assigned', 'In Progress', 'Pending Sync', 'Completed'];

  @override
  void initState() {
    super.initState();
    _refreshInspections();
    OfflineSyncService().pendingCountNotifier.addListener(_refreshInspections);
  }

  @override
  void dispose() {
    OfflineSyncService().pendingCountNotifier.removeListener(_refreshInspections);
    _searchController.dispose();
    super.dispose();
  }

  void _refreshInspections() {
    if (mounted) {
      setState(() {
        _inspectionsFuture = _fetchInspections();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchInspections() async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;

    List<Map<String, dynamic>> items = [];

    // 1. Fetch offline pending items from local SQLite queue
    try {
      final offlineItems = await OfflineSyncService().getPendingItems(targetTable: 'inspections');
      items.addAll(offlineItems);
    } catch (e) {
      debugPrint('Error reading offline inspection queue: $e');
    }

    // 2. Fetch remote items from Supabase
    try {
      final client = Supabase.instance.client;
      var query = client.from('inspections').select();
      if (userId != null) {
        query = query.eq('inspector_id', userId);
      }
      final response = await query.order('created_at', ascending: false);
      final remoteList = List<Map<String, dynamic>>.from(response);

      // Merge avoiding duplicates if local item updated an existing remote ID
      final Set<String> existingIds = items.map((i) => (i['id'] ?? '').toString()).toSet();
      for (var r in remoteList) {
        final rId = (r['id'] ?? '').toString();
        if (!existingIds.contains(rId)) {
          items.add(r);
        }
      }
    } catch (e) {
      debugPrint('Error fetching inspection hub items from network: $e');
    }

    // 3. Apply filters
    items = items.where((item) {
      final st = (item['overall_status'] ?? '').toString().toLowerCase();
      final targetFilter = _selectedFilter.toLowerCase();
      if (targetFilter == 'assigned') {
        return st == 'assigned' || st == 'pending' || st == 'scheduled';
      }
      if (targetFilter == 'pending sync') {
        return st == 'pending sync' || item['_is_offline_pending'] == true;
      }
      return st == targetFilter;
    }).toList();

    final queryText = _searchController.text.trim().toLowerCase();
    if (queryText.isNotEmpty) {
      items = items.where((item) {
        final bName = (item['business_name'] ?? '').toString().toLowerCase();
        final ioNo = (item['inspection_order_no'] ?? '').toString().toLowerCase();
        final addr = (item['address'] ?? '').toString().toLowerCase();
        return bName.contains(queryText) || ioNo.contains(queryText) || addr.contains(queryText);
      }).toList();
    }

    return items;
  }

  void _openForm([Map<String, dynamic>? item]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CommercialInspectionFormScreen(
          assignmentId: item?['id']?.toString(),
          initialBusinessName: item?['business_name']?.toString(),
          initialAddress: item?['address']?.toString(),
          initialIoNumber: item?['inspection_order_no']?.toString(),
        ),
      ),
    ).then((_) => _refreshInspections());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorCanvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed Top Header & Filter Chips (Sticky / Non-scrolling)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderAndSearch(),
                const SizedBox(height: 12),
                _buildFilterChips(),
              ],
            ),
          ),

          // Scrollable Task List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refreshInspections(),
              color: colorAccent,
              child: _buildTaskList(scrollable: true),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: colorAccent,
        elevation: 4,
        icon: const Icon(Icons.add_task_outlined, color: Colors.white, size: 20),
        label: const Text(
          'New Inspection',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildHeaderAndSearch() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                  color: colorAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fact_check_outlined, color: colorAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Inspection Management Hub',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: colorTextPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Assigned commercial establishment fire safety tasks.',
                      style: TextStyle(fontSize: 11, color: colorTextSecondary),
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
                        '$pendingCount offline item(s) pending sync to Supabase.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final res = await OfflineSyncService().syncNow();
                        _refreshInspections();
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
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (_) => _refreshInspections(),
            style: const TextStyle(fontSize: 13, color: colorTextPrimary),
            decoration: InputDecoration(
              hintText: 'Search business name, IO #, or address...',
              hintStyle: const TextStyle(color: colorTextSecondary, fontSize: 12),
              prefixIcon: const Icon(Icons.search_outlined, size: 20, color: colorTextSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_outlined, size: 18, color: colorTextSecondary),
                      onPressed: () {
                        _searchController.clear();
                        _refreshInspections();
                      },
                    )
                  : null,
              filled: true,
              fillColor: colorCanvas,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: colorBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: colorBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: colorAccent, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filterOptions.map((filter) {
          final isSel = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSel,
              selectedColor: colorAccent,
              backgroundColor: colorSurface,
              side: BorderSide(color: isSel ? colorAccent : colorBorder, width: isSel ? 1.5 : 1),
              labelStyle: TextStyle(
                color: isSel ? Colors.white : colorTextPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                  _refreshInspections();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskList({bool scrollable = false}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _inspectionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(color: colorAccent),
            ),
          );
        }

        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) {
          final emptyWidget = Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.fact_check_outlined, size: 42, color: colorTextSecondary),
                SizedBox(height: 12),
                Text(
                  'No commercial inspection tasks found.',
                  style: TextStyle(color: colorTextPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap "New Inspection" to initialize a BFP Form 061 checklist.',
                  style: TextStyle(color: colorTextSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );

          if (scrollable) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
              child: emptyWidget,
            );
          }
          return emptyWidget;
        }

        return ListView.separated(
          shrinkWrap: !scrollable,
          physics: scrollable ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
          padding: scrollable ? const EdgeInsets.fromLTRB(16, 0, 16, 90) : EdgeInsets.zero,
          itemCount: tasks.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final task = tasks[index];
            final businessName = task['business_name'] ?? 'Commercial Establishment';
            final address = task['address'] ?? 'Lingayen, Pangasinan';
            final ioNo = task['inspection_order_no'] ?? 'N/A';
            final status = task['overall_status'] ?? 'Pending';
            final recommendation = task['recommendation'] ?? task['compliance_status'] ?? 'Assigned';
            final riskLevel = task['risk_level'] ?? 'Medium';
            final isCompleted = status.toString().toLowerCase() == 'completed' || status.toString().toLowerCase() == 'passed';
            final bool isOfflinePending = status.toString().toLowerCase() == 'pending sync' || task['_is_offline_pending'] == true;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colorBorder),
                              ),
                              child: Text(
                                'IO: $ioNo',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getRiskBgColor(riskLevel),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Priority: $riskLevel',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getRiskTextColor(riskLevel)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOfflinePending ? const Color(0xFFFEF3C7) : _getStatusBgColor(status),
                          borderRadius: BorderRadius.circular(12),
                          border: isOfflinePending ? Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)) : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOfflinePending) ...[
                              const Icon(Icons.sync_problem_rounded, size: 12, color: Color(0xFFB45309)),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              isOfflinePending ? 'PENDING SYNC (OFFLINE)' : status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isOfflinePending ? const Color(0xFFB45309) : _getStatusTextColor(status),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    businessName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: colorTextSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(fontSize: 12, color: colorTextSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: colorBorder),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Status: $recommendation',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (isCompleted) {
                            showDialog(
                              context: context,
                              builder: (context) => ViewInspectionFormDialog(
                                targetInspectionId: task['id']?.toString(),
                                initialData: task,
                              ),
                            );
                          } else {
                            _openForm(task);
                          }
                        },
                        icon: Icon(
                          isCompleted ? Icons.description_outlined : Icons.edit_note_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: Text(
                          isCompleted ? 'View Form' : 'Launch Inspection',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCompleted ? colorInfo : colorAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'passed':
        return const Color(0xFFDCFCE7);
      case 'in progress':
        return const Color(0xFFE0F2FE);
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'passed':
        return colorSuccess;
      case 'in progress':
        return colorInfo;
      default:
        return colorWarning;
    }
  }

  Color _getRiskBgColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return const Color(0xFFFEE2E2);
      case 'medium':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFDCFCE7);
    }
  }

  Color _getRiskTextColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return const Color(0xFFB91C1C);
      case 'medium':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF15803D);
    }
  }
}
