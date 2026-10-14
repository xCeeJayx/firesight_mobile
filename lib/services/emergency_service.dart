import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/emergency_report_model.dart';
import '../models/user_role.dart';
import '../widgets/emergency/emergency_alert_dialog.dart';
import 'auth_service.dart';

class EmergencyService {
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  /// Global Navigator key for displaying system-wide real-time emergency overlays
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  RealtimeChannel? _realtimeChannel;

  /// Reactive state for active emergency reports
  final ValueNotifier<List<EmergencyReportModel>> reportsNotifier = ValueNotifier<List<EmergencyReportModel>>([]);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);

  /// Track recently alerted incident IDs to avoid duplicate alerts
  final Set<String> _recentlyAlertedIds = {};

  bool isRecentlyAlerted(String id) => _recentlyAlertedIds.contains(id);
  void markAlerted(String id) {
    _recentlyAlertedIds.add(id);
    Future.delayed(const Duration(seconds: 12), () => _recentlyAlertedIds.remove(id));
  }

  bool _isInitialized = false;

  /// Initialize real-time listener and fetch latest emergency reports
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await fetchReports();
    _subscribeToRealtime();
  }

  /// Re-subscribe to realtime channel (e.g. after user signs in)
  void resubscribeRealtime() {
    debugPrint('Resubscribing to emergency_reports realtime stream...');
    _subscribeToRealtime();
    fetchReports();
  }

  /// Subscribe to Postgres changes on public.emergency_reports
  void _subscribeToRealtime() {
    try {
      _realtimeChannel?.unsubscribe();

      _realtimeChannel = _client.channel('public:emergency_reports')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'emergency_reports',
            callback: (payload) {
              _handleRealtimePayload(payload);
            },
          )
          .subscribe((status, [error]) {
            debugPrint('Realtime emergency_reports channel status: $status, error: $error');
          });

      debugPrint('Supabase Realtime Channel subscribed to public:emergency_reports');
    } catch (e) {
      debugPrint('Error subscribing to emergency_reports channel: $e');
    }
  }

  /// Handle incoming Postgres change events (INSERT, UPDATE, DELETE)
  void _handleRealtimePayload(PostgresChangePayload payload) {
    debugPrint('Received emergency_reports realtime event: ${payload.eventType}');

    try {
      final currentList = List<EmergencyReportModel>.from(reportsNotifier.value);

      if (payload.eventType == PostgresChangeEvent.insert) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          final newReport = EmergencyReportModel.fromJson(newRecord);

          // Avoid duplicate insertions
          currentList.removeWhere((item) => item.id == newReport.id);
          currentList.insert(0, newReport);
          reportsNotifier.value = currentList;

          final s = newReport.status.toLowerCase();
          // Sequence Rule 1: When a citizen/guest reports an emergency,
          // officers (Fire Inspector, CRO, Station Officer) get the alert, but NOT the public
          if (s == 'unverified') {
            final isStaff = AuthService().isAuthenticated ||
                (_client.auth.currentUser != null) ||
                (AuthService().currentRole != UserRole.publicGuest);
            if (isStaff) {
              _triggerEmergencyAlert(
                newReport,
                isNew: true,
                customTitle: 'Incoming Emergency Report',
              );
            }
          }
        }
      } else if (payload.eventType == PostgresChangeEvent.update) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          final updatedReport = EmergencyReportModel.fromJson(newRecord);
          final index = currentList.indexWhere((item) => item.id == updatedReport.id);

          final oldReport = index != -1 ? currentList[index] : null;

          if (index != -1) {
            currentList[index] = updatedReport;
          } else {
            currentList.insert(0, updatedReport);
          }
          reportsNotifier.value = currentList;

          final oldStatus = (oldReport?.status ?? '').toLowerCase();
          final newStatus = updatedReport.status.toLowerCase();

          // Sequence Rule 2: When an officer reviews and clicks "Verify Incident",
          // ONLY the public gets the alert (officers already reviewed it, so no alert for officers)
          if ((oldStatus == 'unverified' || oldReport == null) && newStatus == 'verified') {
            final isPublic = AuthService().currentRole == UserRole.publicGuest;
            if (isPublic) {
              _triggerEmergencyAlert(
                updatedReport,
                isNew: false,
                customTitle: 'Verified Emergency Alert',
              );
            }
          }
          // Sequence Rule 3: When an officer clicks dispatch ('responding'/'dispatched'),
          // false alarm ('false alarm'), or resolved ('resolved') -> NO ALERTS!
        }
      } else if (payload.eventType == PostgresChangeEvent.delete) {
        final oldRecord = payload.oldRecord;
        final deletedId = oldRecord['id']?.toString();
        if (deletedId != null) {
          currentList.removeWhere((item) => item.id == deletedId);
          reportsNotifier.value = currentList;
        }
      }
    } catch (e) {
      debugPrint('Error handling realtime payload: $e');
    }
  }

  /// Trigger Pop-up Alert Modal overlay across active screens
  void _triggerEmergencyAlert(
    EmergencyReportModel report, {
    bool isNew = true,
    String? customTitle,
  }) {
    final s = report.status.toLowerCase();

    // Sequence Rule 3: dispatch, false alarm, and resolved -> strictly NO alerts
    if (s == 'responding' || s == 'dispatched' || s == 'false alarm' || s == 'false_alarm' || s == 'resolved') {
      debugPrint('Skipping emergency alert for status: ${report.status}');
      return;
    }

    final isStaff = AuthService().isAuthenticated ||
        (_client.auth.currentUser != null) ||
        (AuthService().currentRole != UserRole.publicGuest);

    // Sequence Rule 1: Unverified reports should ONLY alert staff (officers), never public guests
    if (s == 'unverified' && !isStaff) {
      debugPrint('Skipping emergency popup for public user: report ${report.id} is unverified (status: ${report.status})');
      return;
    }

    // Sequence Rule 2: Verified reports should ONLY alert public guests (officers already reviewed & verified it)
    if (s == 'verified' && isStaff) {
      debugPrint('Skipping verified emergency alert for officer: already reviewed by officers');
      return;
    }

    // Prevent duplicate alert popping for the same report within 10 seconds
    if (_recentlyAlertedIds.contains(report.id)) return;
    _recentlyAlertedIds.add(report.id);
    Future.delayed(const Duration(seconds: 10), () => _recentlyAlertedIds.remove(report.id));

    // Schedule modal presentation on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeContext = navigatorKey.currentContext;
      if (activeContext != null) {
        EmergencyAlertDialog.show(
          activeContext,
          report,
          alertTitle: customTitle ?? (isNew ? 'Incoming Emergency Report' : 'Verified Emergency Alert'),
        );
      } else {
        // Fallback: Retry shortly if context was momentarily unmounted
        Future.delayed(const Duration(milliseconds: 350), () {
          final delayedContext = navigatorKey.currentContext;
          if (delayedContext != null) {
            EmergencyAlertDialog.show(
              delayedContext,
              report,
              alertTitle: customTitle ?? (isNew ? 'Incoming Emergency Report' : 'Verified Emergency Alert'),
            );
          }
        });
      }
    });
  }

  /// Fetch latest emergency reports from Supabase
  Future<List<EmergencyReportModel>> fetchReports({int limit = 25}) async {
    isLoadingNotifier.value = true;
    try {
      final response = await _client
          .from('emergency_reports')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);
      final list = data.map((json) => EmergencyReportModel.fromJson(json)).toList();
      reportsNotifier.value = list;
      return list;
    } catch (e) {
      debugPrint('Error fetching emergency reports: $e');
      return reportsNotifier.value;
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  /// Update the status of an emergency report
  Future<bool> updateReportStatus(String id, String newStatus) async {
    try {
      await _client
          .from('emergency_reports')
          .update({'status': newStatus})
          .eq('id', id);

      // Local optimistic update
      final currentList = List<EmergencyReportModel>.from(reportsNotifier.value);
      final index = currentList.indexWhere((r) => r.id == id);
      EmergencyReportModel? updatedReport;
      if (index != -1) {
        updatedReport = currentList[index].copyWith(status: newStatus);
        currentList[index] = updatedReport;
        reportsNotifier.value = currentList;
      }

      // Note: The database trigger (trigger_notify_emergency_report) automatically
      // dispatches push notifications on emergency_reports status changes via pg_net.
      return true;
    } catch (e) {
      debugPrint('Error updating report status in Supabase: $e');
      return false;
    }
  }

  /// Separate a supporting report from its parent incident (Web Admin / Officer action)
  Future<bool> separateReport(String reportId, String? parentIncidentId) async {
    try {
      await _client
          .from('emergency_reports')
          .update({'parent_incident_id': null, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', reportId);

      if (parentIncidentId != null && parentIncidentId.isNotEmpty) {
        // Decrement parent supporting count if > 0
        final parentRes = await _client
            .from('emergency_reports')
            .select('supporting_reports_count')
            .eq('id', parentIncidentId)
            .maybeSingle();

        if (parentRes != null) {
          final count = (parentRes['supporting_reports_count'] as num?)?.toInt() ?? 0;
          if (count > 0) {
            await _client
                .from('emergency_reports')
                .update({
                  'supporting_reports_count': count - 1,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', parentIncidentId);
          }
        }
      }

      await fetchReports();
      return true;
    } catch (e) {
      debugPrint('Error separating report from parent: $e');
      return false;
    }
  }

  /// Dispose service resources
  void dispose() {
    _realtimeChannel?.unsubscribe();
    reportsNotifier.dispose();
    isLoadingNotifier.dispose();
  }
}
