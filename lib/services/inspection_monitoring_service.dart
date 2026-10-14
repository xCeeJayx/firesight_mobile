import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inspection_monitoring_model.dart';
import 'auth_service.dart';

class InspectionMonitoringService {
  static final InspectionMonitoringService _instance = InspectionMonitoringService._internal();
  factory InspectionMonitoringService() => _instance;
  InspectionMonitoringService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  RealtimeChannel? _realtimeChannel;
  Timer? _locationSyncTimer;

  final ValueNotifier<InspectionMonitoringModel?> activeSessionNotifier =
      ValueNotifier<InspectionMonitoringModel?>(null);

  final ValueNotifier<List<InspectionMonitoringModel>> onSiteInspectorsNotifier =
      ValueNotifier<List<InspectionMonitoringModel>>([]);

  final ValueNotifier<List<InspectionMonitoringModel>> historySessionsNotifier =
      ValueNotifier<List<InspectionMonitoringModel>>([]);

  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);

  bool _isInitialized = false;

  /// Standard Visit Types according to BFP Inspection Standards
  static const List<String> visitTypes = [
    'Regular / Initial Inspection',
    'NTC Verification / Reinspection',
    'NTCV Verification / Reinspection',
    'Abatement Order Verification',
    'Closure / Stoppage Verification',
    'Other Official Inspection',
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await fetchActiveSession();
    await fetchOnSiteInspectors();
    await fetchHistorySessions();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    try {
      _realtimeChannel?.unsubscribe();

      _realtimeChannel = _client.channel('public:inspection_monitoring_sessions')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'inspection_monitoring_sessions',
            callback: (payload) {
              _handleRealtimePayload(payload);
            },
          )
          .subscribe((status, [error]) {
            debugPrint('Realtime inspection_monitoring status: $status, error: $error');
          });
    } catch (e) {
      debugPrint('Error subscribing to inspection_monitoring channel: $e');
    }
  }

  void _handleRealtimePayload(PostgresChangePayload payload) {
    try {
      final currentUserId = _client.auth.currentUser?.id;

      if (payload.eventType == PostgresChangeEvent.insert) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          final model = InspectionMonitoringModel.fromJson(newRecord);

          // If this is the current inspector's active session
          if (model.inspectorId == currentUserId && model.isOnSite) {
            activeSessionNotifier.value = model;
            _startLocationSyncTimer();
          }

          // Update on-site list
          if (model.isOnSite) {
            final list = List<InspectionMonitoringModel>.from(onSiteInspectorsNotifier.value);
            list.removeWhere((i) => i.id == model.id);
            list.insert(0, model);
            onSiteInspectorsNotifier.value = list;
          }
        }
      } else if (payload.eventType == PostgresChangeEvent.update) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          final updated = InspectionMonitoringModel.fromJson(newRecord);

          // Update current inspector's active session
          if (updated.inspectorId == currentUserId) {
            if (updated.isOnSite) {
              activeSessionNotifier.value = updated;
            } else {
              activeSessionNotifier.value = null;
              _stopLocationSyncTimer();
            }
          }

          // Update on-site list for live map
          final list = List<InspectionMonitoringModel>.from(onSiteInspectorsNotifier.value);
          if (updated.isOnSite) {
            final idx = list.indexWhere((i) => i.id == updated.id);
            if (idx != -1) {
              list[idx] = updated;
            } else {
              list.insert(0, updated);
            }
          } else {
            // When completed, inspector disappears from the live map!
            list.removeWhere((i) => i.id == updated.id);
          }
          onSiteInspectorsNotifier.value = list;

          // Update history list
          final historyList = List<InspectionMonitoringModel>.from(historySessionsNotifier.value);
          final hIdx = historyList.indexWhere((i) => i.id == updated.id);
          if (hIdx != -1) {
            historyList[hIdx] = updated;
          } else if (updated.isCompleted) {
            historyList.insert(0, updated);
          }
          historySessionsNotifier.value = historyList;
        }
      } else if (payload.eventType == PostgresChangeEvent.delete) {
        final oldRecord = payload.oldRecord;
        final deletedId = oldRecord['id']?.toString();
        if (deletedId != null) {
          if (activeSessionNotifier.value?.id == deletedId) {
            activeSessionNotifier.value = null;
            _stopLocationSyncTimer();
          }
          final list = List<InspectionMonitoringModel>.from(onSiteInspectorsNotifier.value);
          list.removeWhere((i) => i.id == deletedId);
          onSiteInspectorsNotifier.value = list;
        }
      }
    } catch (e) {
      debugPrint('Error handling inspection_monitoring payload: $e');
    }
  }

  /// Fetch active session for the authenticated inspector
  Future<InspectionMonitoringModel?> fetchActiveSession() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final res = await _client
          .from('inspection_monitoring_sessions')
          .select()
          .eq('inspector_id', user.id)
          .eq('status', 'ON SITE')
          .order('start_time', ascending: false)
          .maybeSingle();

      if (res != null) {
        final model = InspectionMonitoringModel.fromJson(res);
        activeSessionNotifier.value = model;
        _startLocationSyncTimer();
        return model;
      } else {
        activeSessionNotifier.value = null;
        _stopLocationSyncTimer();
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching active session: $e');
      return null;
    }
  }

  /// Fetch all active on-site inspectors for the live map
  Future<List<InspectionMonitoringModel>> fetchOnSiteInspectors() async {
    try {
      final res = await _client
          .from('inspection_monitoring_sessions')
          .select()
          .eq('status', 'ON SITE')
          .order('start_time', ascending: false);

      final list = (res as List).map((j) => InspectionMonitoringModel.fromJson(j)).toList();
      onSiteInspectorsNotifier.value = list;
      return list;
    } catch (e) {
      debugPrint('Error fetching on-site inspectors: $e');
      return onSiteInspectorsNotifier.value;
    }
  }

  /// Start a new Field Monitoring session
  Future<Map<String, dynamic>> startFieldMonitoring({
    required String visitType,
    required String ioReferenceNo,
    String? relatedOrderNo,
    required String barangay,
    String? locationAddress,
    String? establishmentName,
    String? establishmentId,
    double? latitude,
    double? longitude,
  }) async {
    try {
      // 1. Verify single active session constraint
      if (activeSessionNotifier.value != null) {
        return {
          'success': false,
          'error': 'You already have an active ON SITE monitoring session. Please complete or end it before starting a new one.',
        };
      }

      final user = _client.auth.currentUser;
      final profile = AuthService().userProfile;

      // Extract inspector identity
      final String inspectorName = (profile?['full_name'] != null && profile!['full_name'].toString().isNotEmpty)
          ? profile['full_name'].toString()
          : (user?.email?.split('@').first.toUpperCase() ?? 'Fire Inspector');

      final String inspectorRank = profile?['rank']?.toString() ?? 'FO1';
      final String? badgeNumber = profile?['badge_number']?.toString();

      final now = DateTime.now();

      final data = {
        'inspector_id': user?.id,
        'inspector_name': inspectorName,
        'inspector_rank': inspectorRank,
        'inspector_badge': badgeNumber,
        'visit_type': visitType,
        'io_reference_no': ioReferenceNo.trim(),
        'related_order_no': relatedOrderNo?.trim().isNotEmpty == true ? relatedOrderNo!.trim() : null,
        'barangay': barangay,
        'location_address': locationAddress?.trim().isNotEmpty == true ? locationAddress!.trim() : null,
        'establishment_name': establishmentName?.trim().isNotEmpty == true ? establishmentName!.trim() : null,
        'establishment_id': establishmentId,
        'status': 'ON SITE',
        'start_time': now.toUtc().toIso8601String(),
        'start_latitude': latitude,
        'start_longitude': longitude,
        'current_latitude': latitude,
        'current_longitude': longitude,
        'last_location_update': now.toUtc().toIso8601String(),
      };

      final response = await _client
          .from('inspection_monitoring_sessions')
          .insert(data)
          .select()
          .single();

      final model = InspectionMonitoringModel.fromJson(response);
      activeSessionNotifier.value = model;

      // Add to live on-site list
      final onSiteList = List<InspectionMonitoringModel>.from(onSiteInspectorsNotifier.value);
      onSiteList.insert(0, model);
      onSiteInspectorsNotifier.value = onSiteList;

      _startLocationSyncTimer();

      return {'success': true, 'data': model};
    } catch (e) {
      debugPrint('Error starting field monitoring: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// End Field Monitoring session
  Future<Map<String, dynamic>> endFieldMonitoring(
    String sessionId, {
    double? endLatitude,
    double? endLongitude,
    String? remarks,
  }) async {
    try {
      final now = DateTime.now();
      final currentSession = activeSessionNotifier.value;
      final startTime = currentSession?.startTime ?? now;
      final diff = now.difference(startTime);
      final durationMins = diff.isNegative ? 1 : (diff.inMinutes > 0 ? diff.inMinutes : 1);

      final updateData = {
        'status': 'COMPLETED',
        'end_time': now.toUtc().toIso8601String(),
        'end_latitude': endLatitude,
        'end_longitude': endLongitude,
        'duration_minutes': durationMins,
        'remarks': remarks?.trim().isNotEmpty == true ? remarks!.trim() : null,
        'updated_at': now.toUtc().toIso8601String(),
      };

      final response = await _client
          .from('inspection_monitoring_sessions')
          .update(updateData)
          .eq('id', sessionId)
          .select()
          .single();

      final updatedModel = InspectionMonitoringModel.fromJson(response);

      // Clear active session
      activeSessionNotifier.value = null;
      _stopLocationSyncTimer();

      // Remove from on-site live map list!
      final onSiteList = List<InspectionMonitoringModel>.from(onSiteInspectorsNotifier.value);
      onSiteList.removeWhere((i) => i.id == sessionId);
      onSiteInspectorsNotifier.value = onSiteList;

      // Add to history list
      final historyList = List<InspectionMonitoringModel>.from(historySessionsNotifier.value);
      historyList.removeWhere((i) => i.id == sessionId);
      historyList.insert(0, updatedModel);
      historySessionsNotifier.value = historyList;

      return {'success': true, 'data': updatedModel};
    } catch (e) {
      debugPrint('Error ending field monitoring: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Query completed sessions with filters (Date, Inspector, Barangay, Visit Type, Status)
  Future<List<InspectionMonitoringModel>> fetchHistorySessions({
    DateTime? startDate,
    DateTime? endDate,
    String? barangay,
    String? visitType,
    String? inspectorQuery,
    String? status,
    int limit = 50,
  }) async {
    isLoadingNotifier.value = true;
    try {
      var query = _client.from('inspection_monitoring_sessions').select();

      if (status != null && status.isNotEmpty && status != 'All') {
        query = query.eq('status', status);
      } else {
        query = query.eq('status', 'COMPLETED');
      }

      if (barangay != null && barangay.isNotEmpty && barangay != 'All') {
        query = query.eq('barangay', barangay);
      }

      if (visitType != null && visitType.isNotEmpty && visitType != 'All') {
        query = query.eq('visit_type', visitType);
      }

      if (startDate != null) {
        query = query.gte('start_time', startDate.toUtc().toIso8601String());
      }

      if (endDate != null) {
        // Include full end day
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        query = query.lte('start_time', endOfDay.toUtc().toIso8601String());
      }

      final res = await query.order('start_time', ascending: false).limit(limit);
      final list = (res as List).map((j) => InspectionMonitoringModel.fromJson(j)).toList();

      // In-memory filter for inspector name if provided
      if (inspectorQuery != null && inspectorQuery.trim().isNotEmpty) {
        final q = inspectorQuery.trim().toLowerCase();
        historySessionsNotifier.value = list.where((s) => s.inspectorName.toLowerCase().contains(q)).toList();
      } else {
        historySessionsNotifier.value = list;
      }

      return historySessionsNotifier.value;
    } catch (e) {
      debugPrint('Error fetching history sessions: $e');
      return historySessionsNotifier.value;
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  /// Periodic live location sync while monitoring status is ON SITE
  void _startLocationSyncTimer() {
    _locationSyncTimer?.cancel();
    _locationSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final active = activeSessionNotifier.value;
      if (active == null || !active.isOnSite) {
        _stopLocationSyncTimer();
        return;
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );

        await _client.from('inspection_monitoring_sessions').update({
          'current_latitude': position.latitude,
          'current_longitude': position.longitude,
          'last_location_update': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', active.id);
      } catch (e) {
        debugPrint('Periodic location sync skipped: $e');
      }
    });
  }

  void _stopLocationSyncTimer() {
    _locationSyncTimer?.cancel();
    _locationSyncTimer = null;
  }

  void dispose() {
    _stopLocationSyncTimer();
    _realtimeChannel?.unsubscribe();
    activeSessionNotifier.dispose();
    onSiteInspectorsNotifier.dispose();
    historySessionsNotifier.dispose();
    isLoadingNotifier.dispose();
  }
}
