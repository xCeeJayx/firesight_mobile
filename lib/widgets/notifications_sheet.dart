import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../active_inspection_screen.dart';
import '../services/push_notification_service.dart';

class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton>
    with WidgetsBindingObserver {
  int _unreadCount = 0;
  RealtimeChannel? _channel;
  Timer? _periodicTimer;
  StreamSubscription? _pushSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUnreadCount();
    _subscribeNotifications();

    // 1. Fallback periodic sync every 15s to guarantee fresh count
    _periodicTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _fetchUnreadCount();
    });

    // 2. Immediate sync when foreground push notification arrives
    _pushSubscription = PushNotificationService().onNotificationReceived.listen((_) {
      if (mounted) _fetchUnreadCount();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _fetchUnreadCount();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    _pushSubscription?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final res = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      if (mounted) {
        setState(() {
          _unreadCount = (res as List).length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching unread notification count: $e');
    }
  }

  void _subscribeNotifications() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Listen to all changes on notifications table; RLS automatically restricts rows to user
      _channel = Supabase.instance.client
          .channel('public:notifications:${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty && newRecord['user_id'] != null) {
                if (newRecord['user_id'] != user.id) return;
              }
              _fetchUnreadCount();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to notifications channel: $e');
    }
  }

  void _openNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationsSheet(),
    ).then((_) => _fetchUnreadCount());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0F172A), size: 24),
          onPressed: _openNotificationsSheet,
          tooltip: 'Inspection Notifications',
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 8,
            top: 10,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unreadCount > 9 ? '9+' : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _notifications = [];
  RealtimeChannel? _sheetChannel;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeSheetRealtime();
  }

  @override
  void dispose() {
    _sheetChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeSheetRealtime() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      _sheetChannel = Supabase.instance.client
          .channel('public:sheet_notifications:${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            callback: (payload) {
              if (mounted) _loadNotifications();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing sheet to notifications: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      final res = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id);

      await _loadNotifications();
    } catch (e) {
      debugPrint('Error marking notifications read: $e');
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notif) async {
    try {
      // Mark as read
      if (notif['is_read'] != true && notif['id'] != null) {
        await Supabase.instance.client
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notif['id']);
      }

      final data = notif['data'] as Map<String, dynamic>?;
      final inspectionId = data?['inspection_id']?.toString() ?? data?['assignmentId']?.toString();

      if (!mounted) return;
      Navigator.pop(context); // Close bottom sheet

      if (inspectionId != null && inspectionId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActiveInspectionScreen(assignmentId: inspectionId),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error opening notification target: $e');
    }
  }

  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Color(0xFFD84315), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                if (_notifications.any((n) => n['is_read'] != true))
                  TextButton(
                    onPressed: _markAllAsRead,
                    child: const Text(
                      'Mark all as read',
                      style: TextStyle(color: Color(0xFFD84315), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD84315)))
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.notifications_off_outlined, size: 48, color: Color(0xFF94A3B8)),
                            SizedBox(height: 12),
                            Text(
                              'No notifications yet',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _notifications.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 68),
                        itemBuilder: (context, index) {
                          final notif = _notifications[index];
                          final bool isUnread = notif['is_read'] != true;
                          final String title = notif['title'] ?? 'Inspection Update';
                          final String body = notif['body'] ?? '';
                          final String timeAgo = _formatTimeAgo(notif['created_at']);

                          return ListTile(
                            tileColor: isUnread ? const Color(0xFFFFF7ED) : Colors.transparent,
                            leading: CircleAvatar(
                              backgroundColor: isUnread ? const Color(0xFFFFEDD5) : const Color(0xFFF1F5F9),
                              child: Icon(
                                Icons.calendar_month_rounded,
                                color: isUnread ? const Color(0xFFD84315) : const Color(0xFF64748B),
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 14,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                if (timeAgo.isNotEmpty)
                                  Text(
                                    timeAgo,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                body,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                              ),
                            ),
                            onTap: () => _handleNotificationTap(notif),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
