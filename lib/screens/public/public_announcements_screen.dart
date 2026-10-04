import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/emergency_service.dart';

class PublicAnnouncementsScreen extends StatefulWidget {
  const PublicAnnouncementsScreen({super.key});

  /// Static method to display the announcement dialog globally from anywhere (e.g. push notification tap or realtime alert)
  static void showAnnouncementModal({
    required BuildContext context,
    required String title,
    required String content,
    String? priority,
    String? dateStr,
    String? createdBy,
  }) {
    final String cleanPriority = (priority ?? 'normal').toLowerCase();
    final bool isUrgent = cleanPriority == 'urgent';
    final bool isHigh = cleanPriority == 'high';

    final Color headerColor = isUrgent
        ? const Color(0xFFDC2626)
        : (isHigh ? const Color(0xFFEA580C) : const Color(0xFF0284C7));

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [headerColor, headerColor.withValues(alpha: 0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isUrgent ? Icons.warning_amber_rounded : Icons.campaign_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUrgent ? 'URGENT SAFETY ADVISORY' : (isHigh ? 'HIGH PRIORITY NOTICE' : 'BFP BULLETIN'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Text(
                              'Bureau of Fire Protection • Lingayen Station',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),

                // Content Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (dateStr != null && dateStr.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.schedule, size: 14, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text(
                                dateStr,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Text(
                          content,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF334155),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Official Footer Stamp
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: Color(0xFFD84315), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Official BFP Public Notice',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      createdBy != null && createdBy.isNotEmpty
                                          ? 'Authorized by: $createdBy'
                                          : 'Fire Safety Enforcement Section • Lingayen',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Understood / Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  State<PublicAnnouncementsScreen> createState() => _PublicAnnouncementsScreenState();
}

class _PublicAnnouncementsScreenState extends State<PublicAnnouncementsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _announcements = [];
  String _selectedPriorityFilter = 'All'; // All, Urgent, High, Normal
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
    _subscribeToAnnouncements();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchAnnouncements() async {
    try {
      final res = await Supabase.instance.client
          .from('public_announcements')
          .select()
          .eq('is_published', true)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _announcements = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToAnnouncements() {
    try {
      _realtimeChannel = Supabase.instance.client
          .channel('public:public_announcements')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'public_announcements',
            callback: (payload) {
              if (payload.eventType == PostgresChangeEvent.insert) {
                final newRecord = payload.newRecord;
                if (newRecord.isNotEmpty && newRecord['is_published'] == true) {
                  _fetchAnnouncements();

                  // If urgent notice comes in while using app, pop up alert
                  final String priority = (newRecord['priority'] ?? '').toString().toLowerCase();
                  if (priority == 'urgent' || priority == 'high') {
                    final navContext = EmergencyService.navigatorKey.currentContext;
                    if (navContext != null) {
                      PublicAnnouncementsScreen.showAnnouncementModal(
                        context: navContext,
                        title: newRecord['title']?.toString() ?? 'Emergency Advisory',
                        content: newRecord['content']?.toString() ?? '',
                        priority: priority,
                        dateStr: 'Just now',
                        createdBy: newRecord['created_by']?.toString(),
                      );
                    }
                  }
                }
              } else {
                _fetchAnnouncements();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to public_announcements: $e');
    }
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[dt.month - 1];
      final day = dt.day;
      final year = dt.year;
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$month $day, $year • $hour:$minute $period';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _announcements.where((a) {
      if (_selectedPriorityFilter == 'All') return true;
      final p = (a['priority'] ?? 'normal').toString().toLowerCase();
      return p == _selectedPriorityFilter.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: const Color(0xFFD84315),
        onRefresh: _fetchAnnouncements,
        child: CustomScrollView(
          slivers: [
            // Top App Bar Banner
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD84315).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.campaign_rounded, color: Color(0xFFD84315), size: 26),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Public Advisories & Bulletins',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'BFP Lingayen Fire Safety & Emergency Information',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'Urgent', 'High', 'Normal'].map((filter) {
                          final bool isSelected = _selectedPriorityFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                filter == 'Normal' ? 'General' : filter,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF0F172A),
                              backgroundColor: const Color(0xFFF1F5F9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              onSelected: (_) => setState(() => _selectedPriorityFilter = filter),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content List
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFFD84315))),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.mark_chat_read_outlined, size: 52, color: Color(0xFF94A3B8)),
                      SizedBox(height: 12),
                      Text(
                        'No announcements published yet',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Public safety bulletins from BFP will appear here.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = filtered[index];
                      final String title = item['title'] ?? 'Notice';
                      final String content = item['content'] ?? '';
                      final String priority = (item['priority'] ?? 'normal').toString().toLowerCase();
                      final String dateStr = _formatTimestamp(item['created_at']);
                      final String createdBy = item['created_by'] ?? 'BFP Lingayen';

                      final bool isUrgent = priority == 'urgent';
                      final bool isHigh = priority == 'high';

                      final Color badgeBg = isUrgent
                          ? const Color(0xFFFEE2E2)
                          : (isHigh ? const Color(0xFFFFEDD5) : const Color(0xFFE0F2FE));
                      final Color badgeText = isUrgent
                          ? const Color(0xFFDC2626)
                          : (isHigh ? const Color(0xFFEA580C) : const Color(0xFF0369A1));

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isUrgent ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                            width: isUrgent ? 1.5 : 1,
                          ),
                        ),
                        color: Colors.white,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => PublicAnnouncementsScreen.showAnnouncementModal(
                            context: context,
                            title: title,
                            content: content,
                            priority: priority,
                            dateStr: dateStr,
                            createdBy: createdBy,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isUrgent ? Icons.error_outline : (isHigh ? Icons.warning_amber_rounded : Icons.info_outline),
                                            size: 13,
                                            color: badgeText,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            priority.toUpperCase(),
                                            style: TextStyle(
                                              color: badgeText,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    if (dateStr.isNotEmpty)
                                      Text(
                                        dateStr,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  content,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    const Text(
                                      'View full advisory',
                                      style: TextStyle(
                                        color: Color(0xFFD84315),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFD84315)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
