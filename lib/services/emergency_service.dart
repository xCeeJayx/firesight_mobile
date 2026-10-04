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
          .subscribe();

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

          // Trigger high-priority pop-up overlay alert
          // (Staff receives all alerts; Public guest receives only if verified)
          _triggerEmergencyAlert(
            newReport,
            isNew: true,
            customTitle: newReport.isVerified ? 'Verified Emergency Incident' : 'Incoming Emergency Report',
          );
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

          final wasVerified = oldReport?.isVerified ?? false;
          final isNowVerified = updatedReport.isVerified;

          // Trigger alert on significant status verification / dispatch
          if (!wasVerified && isNowVerified) {
            _triggerEmergencyAlert(
              updatedReport,
              isNew: false,
              customTitle: 'Emergency Verified by BFP',
            );
          } else if (oldReport != null &&
              oldReport.status.toLowerCase() != updatedReport.status.toLowerCase() &&
              isNowVerified) {
            _triggerEmergencyAlert(
              updatedReport,
              isNew: false,
              customTitle: 'Emergency Status: ${updatedReport.status}',
            );
          }
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
    final currentRole = AuthService().currentRole;

    // Public Guest users should ONLY receive verified emergency alerts
    if (currentRole == UserRole.publicGuest && !report.isVerified) {
      debugPrint('Skipping emergency popup for public user: report ${report.id} is unverified (status: ${report.status})');
      return;
    }

    // Prevent duplicate alert popping for the same report within 10 seconds
    if (_recentlyAlertedIds.contains(report.id)) return;
    _recentlyAlertedIds.add(report.id);
    Future.delayed(const Duration(seconds: 10), () => _recentlyAlertedIds.remove(report.id));

    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('Navigator context unavailable for emergency popup alert');
      return;
    }

    // Schedule modal presentation on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null) {
        EmergencyAlertDialog.show(
          navigatorKey.currentContext!,
          report,
          alertTitle: customTitle ?? (isNew ? 'Incoming Emergency Report' : 'Verified Emergency Alert'),
        );
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

  /// Dispose service resources
  void dispose() {
    _realtimeChannel?.unsubscribe();
    reportsNotifier.dispose();
    isLoadingNotifier.dispose();
  }
}
