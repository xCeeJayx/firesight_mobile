import 'package:flutter/material.dart';
import '../../models/inspection_monitoring_model.dart';
import '../../services/inspection_monitoring_service.dart';
import '../../services/supabase_service.dart';

class MonitoringHistoryScreen extends StatefulWidget {
  const MonitoringHistoryScreen({super.key});

  @override
  State<MonitoringHistoryScreen> createState() => _MonitoringHistoryScreenState();
}

class _MonitoringHistoryScreenState extends State<MonitoringHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedBarangay = 'All';
  String _selectedVisitType = 'All';
  String _selectedDateFilter = 'All';

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    _applyDateFilterRange();
    await InspectionMonitoringService().fetchHistorySessions(
      startDate: _startDate,
      endDate: _endDate,
      barangay: _selectedBarangay == 'All' ? null : _selectedBarangay,
      visitType: _selectedVisitType == 'All' ? null : _selectedVisitType,
      inspectorQuery: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
    );
  }

  void _applyDateFilterRange() {
    final now = DateTime.now();
    if (_selectedDateFilter == 'Today') {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedDateFilter == 'Past 7 Days') {
      _startDate = now.subtract(const Duration(days: 7));
      _endDate = now;
    } else if (_selectedDateFilter == 'This Month') {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = now;
    } else {
      _startDate = null;
      _endDate = null;
    }
  }

  void _showSessionDetailsModal(InspectionMonitoringModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.visitTypeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.visitTypeIcon, size: 14, color: item.visitTypeColor),
                        const SizedBox(width: 6),
                        Text(item.visitType, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: item.visitTypeColor)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: const Text('COMPLETED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'IO: ${item.ioReferenceNo}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (item.establishmentName != null && item.establishmentName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.establishmentName!,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildDetailItem('Inspector', '${item.inspectorRank} ${item.inspectorName}'),
              if (item.relatedOrderNo != null)
                _buildDetailItem('Related Order / Notice', item.relatedOrderNo!, valueColor: const Color(0xFFDC2626)),
              _buildDetailItem('Location', 'Brgy. ${item.barangay}${item.locationAddress != null ? ' • ${item.locationAddress}' : ''}'),
              _buildDetailItem('Date', item.formattedDate),
              _buildDetailItem('Start Time', item.formattedStartTime),
              _buildDetailItem('End Time', item.endTime != null ? InspectionMonitoringModel(id: '', inspectorName: '', visitType: '', ioReferenceNo: '', barangay: '', startTime: item.endTime!).formattedStartTime : 'N/A'),
              _buildDetailItem('Total Duration', item.formattedDuration, isBold: true),
              if (item.startLatitude != null)
                _buildDetailItem('Start Coordinates', '${item.startLatitude!.toStringAsFixed(5)}, ${item.startLongitude!.toStringAsFixed(5)}'),
              if (item.endLatitude != null)
                _buildDetailItem('End Coordinates', '${item.endLatitude!.toStringAsFixed(5)}, ${item.endLongitude!.toStringAsFixed(5)}'),
              if (item.remarks != null && item.remarks!.isNotEmpty)
                _buildDetailItem('Remarks', item.remarks!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: valueColor ?? const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Monitoring History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search IO Ref, establishment, inspector...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadHistory();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  onSubmitted: (_) => _loadHistory(),
                ),
                const SizedBox(height: 10),

                // Filter Dropdowns Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Date Filter
                      _buildFilterChip(
                        label: 'Date: $_selectedDateFilter',
                        icon: Icons.calendar_today_rounded,
                        onTap: () {
                          _showOptionsDialog(
                            title: 'Filter by Date',
                            options: ['All', 'Today', 'Past 7 Days', 'This Month'],
                            selected: _selectedDateFilter,
                            onSelect: (val) {
                              setState(() => _selectedDateFilter = val);
                              _loadHistory();
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 8),

                      // Barangay Filter
                      _buildFilterChip(
                        label: _selectedBarangay == 'All' ? 'All Barangays' : 'Brgy. $_selectedBarangay',
                        icon: Icons.location_city_rounded,
                        onTap: () {
                          _showOptionsDialog(
                            title: 'Filter by Barangay',
                            options: ['All', ...SupabaseService.lingayenBarangays],
                            selected: _selectedBarangay,
                            onSelect: (val) {
                              setState(() => _selectedBarangay = val);
                              _loadHistory();
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 8),

                      // Visit Type Filter
                      _buildFilterChip(
                        label: _selectedVisitType == 'All' ? 'All Visit Types' : _selectedVisitType,
                        icon: Icons.category_outlined,
                        onTap: () {
                          _showOptionsDialog(
                            title: 'Filter by Visit Type',
                            options: ['All', ...InspectionMonitoringService.visitTypes],
                            selected: _selectedVisitType,
                            onSelect: (val) {
                              setState(() => _selectedVisitType = val);
                              _loadHistory();
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // History List
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: InspectionMonitoringService().isLoadingNotifier,
              builder: (context, isLoading, _) {
                if (isLoading) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)));
                }

                return ValueListenableBuilder<List<InspectionMonitoringModel>>(
                  valueListenable: InspectionMonitoringService().historySessionsNotifier,
                  builder: (context, historyList, _) {
                    if (historyList.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.history_rounded, size: 48, color: Color(0xFFCBD5E1)),
                              SizedBox(height: 12),
                              Text('No Monitoring Records Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              SizedBox(height: 4),
                              Text('Completed sessions will appear here with full duration logs.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: historyList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final item = historyList[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _showSessionDetailsModal(item),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: item.visitTypeColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.visitType,
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.visitTypeColor),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text(
                                            item.formattedDuration,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item.ioReferenceNo,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  if (item.establishmentName != null && item.establishmentName!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      item.establishmentName!,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.place_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Brgy. ${item.barangay}${item.locationAddress != null ? ' • ${item.locationAddress}' : ''}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${item.inspectorRank} ${item.inspectorName}',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        '${item.formattedDate} • ${item.formattedStartTime}',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required IconData icon, required VoidCallback onTap}) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: const Color(0xFF64748B)),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
      backgroundColor: const Color(0xFFF1F5F9),
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onPressed: onTap,
    );
  }

  void _showOptionsDialog({
    required String title,
    required List<String> options,
    required String selected,
    required Function(String) onSelect,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final opt = options[i];
              final isSel = opt == selected;
              return ListTile(
                dense: true,
                title: Text(
                  opt,
                  style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? const Color(0xFFEA580C) : const Color(0xFF0F172A)),
                ),
                trailing: isSel ? const Icon(Icons.check, size: 18, color: Color(0xFFEA580C)) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  onSelect(opt);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
