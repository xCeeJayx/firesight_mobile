import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  Database? _db;
  bool _isProcessing = false;
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  /// Initialize local SQLite database
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    await updatePendingCount();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'firesight_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_queue (
            id TEXT PRIMARY KEY,
            target_table TEXT NOT NULL,
            payload TEXT NOT NULL,
            status TEXT DEFAULT 'pending_sync',
            created_at TEXT NOT NULL
          );
        ''');
      },
    );
  }

  /// Update the live counter of pending items
  Future<int> updatePendingCount() async {
    try {
      final db = await database;
      final countResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM pending_queue WHERE status = 'pending_sync' OR status = 'failed'",
      );
      final count = Sqflite.firstIntValue(countResult) ?? 0;
      pendingCountNotifier.value = count;
      return count;
    } catch (e) {
      debugPrint('Error getting pending count: $e');
      return 0;
    }
  }

  /// Queue a form or audit log payload for offline synchronization
  Future<String> queueForSync({
    required String targetTable,
    required Map<String, dynamic> payload,
    String? id,
  }) async {
    final db = await database;
    final queueId = id ?? 'offline_${DateTime.now().millisecondsSinceEpoch}_${payload['id'] ?? targetTable}';
    final nowStr = DateTime.now().toIso8601String();

    // Ensure payload has an id and timestamp if needed
    final cleanPayload = Map<String, dynamic>.from(payload);
    if (!cleanPayload.containsKey('id') && id != null) {
      cleanPayload['id'] = id;
    }
    if (!cleanPayload.containsKey('created_at')) {
      cleanPayload['created_at'] = nowStr;
    }

    final row = {
      'id': queueId,
      'target_table': targetTable,
      'payload': jsonEncode(cleanPayload),
      'status': 'pending_sync',
      'created_at': nowStr,
    };

    await db.insert(
      'pending_queue',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await updatePendingCount();
    debugPrint('Queued item for sync: $queueId in $targetTable');
    return queueId;
  }

  /// Get list of pending items for UI display (annotated with _is_offline_pending)
  Future<List<Map<String, dynamic>>> getPendingItems({String? targetTable}) async {
    try {
      final db = await database;
      String query = "SELECT * FROM pending_queue WHERE status = 'pending_sync' OR status = 'failed' OR status = 'syncing'";
      List<dynamic> args = [];

      if (targetTable != null && targetTable.isNotEmpty) {
        query += " AND target_table = ?";
        args.add(targetTable);
      }
      query += " ORDER BY created_at DESC";

      final rows = await db.rawQuery(query, args);
      final List<Map<String, dynamic>> items = [];

      for (var row in rows) {
        try {
          final payloadStr = row['payload'] as String;
          final Map<String, dynamic> payloadMap = jsonDecode(payloadStr);
          payloadMap['_is_offline_pending'] = true;
          payloadMap['_pending_queue_id'] = row['id'];
          payloadMap['_pending_status'] = row['status'];
          payloadMap['_pending_created_at'] = row['created_at'];
          payloadMap['_target_table'] = row['target_table'];
          items.add(payloadMap);
        } catch (e) {
          debugPrint('Error decoding pending item payload: $e');
        }
      }

      return items;
    } catch (e) {
      debugPrint('Error fetching pending items: $e');
      return [];
    }
  }

  /// Delete a single queued item
  Future<int> deleteItem(String id) async {
    final db = await database;
    final result = await db.delete('pending_queue', where: 'id = ?', whereArgs: [id]);
    await updatePendingCount();
    return result;
  }

  /// Update the status of a queued item
  Future<int> updateStatus(String id, String status) async {
    final db = await database;
    final result = await db.update(
      'pending_queue',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
    await updatePendingCount();
    return result;
  }

  /// Public method to trigger immediate synchronization manually from UI
  Future<Map<String, dynamic>> syncNow() async {
    final countBefore = await updatePendingCount();
    if (countBefore == 0) {
      return {'success': true, 'synced': 0, 'message': 'All items are already synchronized.'};
    }

    final isOnline = await ConnectivityService().hasInternetConnection();
    if (!isOnline) {
      return {'success': false, 'synced': 0, 'message': 'No internet connection detected.'};
    }

    await processSyncQueue();
    final countAfter = await updatePendingCount();
    final synced = countBefore - countAfter;

    return {
      'success': countAfter == 0,
      'synced': synced,
      'remaining': countAfter,
      'message': countAfter == 0
          ? 'All $synced offline items synchronized successfully.'
          : '$synced items synchronized, $countAfter item(s) pending retry.',
    };
  }

  /// Process the sync queue sequentially upon reconnection
  Future<void> processSyncQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final isOnline = await ConnectivityService().hasInternetConnection();
      if (!isOnline) {
        _isProcessing = false;
        return;
      }

      final db = await database;
      final rows = await db.query(
        'pending_queue',
        where: "status = 'pending_sync' OR status = 'failed' OR status = 'syncing'",
        orderBy: 'created_at ASC',
      );

      if (rows.isEmpty) {
        _isProcessing = false;
        return;
      }

      final client = Supabase.instance.client;
      int successCount = 0;

      for (var row in rows) {
        final queueId = row['id'] as String;
        final targetTable = row['target_table'] as String;
        final payloadStr = row['payload'] as String;

        await updateStatus(queueId, 'syncing');

        try {
          Map<String, dynamic> rawPayload = jsonDecode(payloadStr);

          // 1. Process and upload offline photo attachments if present
          rawPayload = await _processOfflinePhotos(rawPayload);

          // 2. Sanitize payload strictly according to Supabase table schema and constraints
          final sanitizedPayload = _sanitizePayloadForTable(targetTable, rawPayload);

          // 3. Perform Supabase database insertion / upsertion
          if (targetTable == 'inspections') {
            final existingId = sanitizedPayload['id']?.toString();
            if (existingId != null && !existingId.startsWith('offline_')) {
              await client.from('inspections').upsert(sanitizedPayload);
            } else {
              if (existingId != null && existingId.startsWith('offline_')) {
                sanitizedPayload.remove('id');
              }
              await client.from('inspections').insert(sanitizedPayload);
            }
          } else if (targetTable == 'fire_risk_surveys') {
            final existingId = sanitizedPayload['id']?.toString();
            if (existingId != null && existingId.startsWith('offline_')) {
              sanitizedPayload.remove('id');
            }
            await client.from('fire_risk_surveys').insert(sanitizedPayload);
          } else if (targetTable == 'audit_logs') {
            final existingId = sanitizedPayload['id']?.toString();
            if (existingId != null && existingId.startsWith('offline_')) {
              sanitizedPayload.remove('id');
            }
            await client.from('audit_logs').insert(sanitizedPayload);
          } else {
            await client.from(targetTable).insert(sanitizedPayload);
          }

          // 4. Delete from pending_queue upon successful upload
          await db.delete('pending_queue', where: 'id = ?', whereArgs: [queueId]);
          successCount++;

          // 5. Log audit action
          await AuthService().logAuditAction(
            actionType: 'OFFLINE_DATA_SYNCED',
            targetEntity: '$targetTable ($queueId)',
            details: 'Offline queued item synchronized successfully to Supabase.',
          );
        } catch (itemError) {
          debugPrint('Error syncing queue item $queueId to $targetTable: $itemError');
          await updateStatus(queueId, 'failed');
        }
      }

      await updatePendingCount();

      // Show subtle top toast if any items were successfully synchronized
      if (successCount > 0) {
        ConnectivityService().showSyncToast(
          message: 'Offline data synchronized successfully ($successCount item${successCount > 1 ? "s" : ""}).',
        );
      }
    } catch (e) {
      debugPrint('Sync queue process error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Sanitize and format payload to match exact Supabase PostgreSQL schema and CHECK constraints
  Map<String, dynamic> _sanitizePayloadForTable(String targetTable, Map<String, dynamic> raw) {
    final payload = Map<String, dynamic>.from(raw);

    // Remove internal sync helper keys before sending to Supabase
    payload.remove('_is_offline_pending');
    payload.remove('_pending_queue_id');
    payload.remove('_pending_status');
    payload.remove('_pending_created_at');
    payload.remove('_target_table');

    if (targetTable == 'fire_risk_surveys') {
      // 1. fire_risk_surveys does NOT have a 'status' column in Supabase
      payload.remove('status');

      // 2. Normalize risk_level to match Postgres check constraint:
      // CHECK (risk_level = ANY (ARRAY['Low Risk'::text, 'Medium Risk'::text, 'High Risk'::text]))
      final rawRisk = (payload['risk_level'] ?? '').toString().trim().toLowerCase();
      if (rawRisk.contains('high')) {
        payload['risk_level'] = 'High Risk';
      } else if (rawRisk.contains('med')) {
        payload['risk_level'] = 'Medium Risk';
      } else if (rawRisk.contains('low')) {
        payload['risk_level'] = 'Low Risk';
      } else {
        payload['risk_level'] = 'Medium Risk';
      }

      // 3. Normalize survey_type to match Postgres check constraint:
      // CHECK (survey_type = ANY (ARRAY['community_urban'::text, 'house_to_house'::text]))
      final rawType = (payload['survey_type'] ?? '').toString().trim().toLowerCase();
      if (rawType.contains('house') || rawType.contains('h2h')) {
        payload['survey_type'] = 'house_to_house';
      } else {
        payload['survey_type'] = 'community_urban';
      }

      // 4. Ensure numeric calculated_score
      if (payload.containsKey('calculated_score')) {
        final cs = payload['calculated_score'];
        if (cs is String) {
          payload['calculated_score'] = double.tryParse(cs) ?? 0.0;
        } else if (cs is int) {
          payload['calculated_score'] = cs.toDouble();
        }
      }

      // 5. Ensure non-null location details
      payload['municipality'] ??= 'Lingayen';
      payload['province'] ??= 'Pangasinan';
      if (payload['barangay_name'] == null || payload['barangay_name'].toString().trim().isEmpty) {
        payload['barangay_name'] = 'Poblacion';
      }

      // 6. If inspector_id is an invalid placeholder, clean to null or auth user ID
      final inspId = payload['inspector_id']?.toString();
      if (inspId == null || inspId.isEmpty || inspId.startsWith('offline_')) {
        final currentAuthId = Supabase.instance.client.auth.currentUser?.id;
        payload['inspector_id'] = currentAuthId;
      }
    } else if (targetTable == 'inspections') {
      // 1. inspections uses overall_status, NOT status
      if (payload.containsKey('status')) {
        final st = payload['status'].toString();
        if (st == 'Pending Sync' || st == 'pending_sync') {
          payload['overall_status'] ??= 'Completed';
        } else {
          payload['overall_status'] ??= st;
        }
        payload.remove('status');
      }
      if (payload['overall_status'] == 'Pending Sync' || payload['overall_status'] == 'pending_sync') {
        payload['overall_status'] = 'Completed';
      }

      // 2. Normalize checklist_type
      payload['checklist_type'] ??= 'commercial';

      // 3. Ensure inspector_id foreign key validity
      final inspId = payload['inspector_id']?.toString();
      if (inspId == null || inspId.isEmpty || inspId.startsWith('offline_')) {
        final currentAuthId = Supabase.instance.client.auth.currentUser?.id;
        payload['inspector_id'] = currentAuthId;
      }
    } else if (targetTable == 'audit_logs') {
      payload.remove('status');
      final actorId = payload['actor_id']?.toString();
      if (actorId == null || actorId.isEmpty || actorId.startsWith('offline_')) {
        payload['actor_id'] = Supabase.instance.client.auth.currentUser?.id;
      }
    }

    return payload;
  }

  /// Check payload for local image file paths, upload them to Supabase Storage, and swap with public URLs
  Future<Map<String, dynamic>> _processOfflinePhotos(Map<String, dynamic> payload) async {
    final client = Supabase.instance.client;
    final updated = Map<String, dynamic>.from(payload);

    // Check hazard_photo_urls list
    if (updated.containsKey('hazard_photo_urls') && updated['hazard_photo_urls'] is List) {
      final List<dynamic> rawUrls = List.from(updated['hazard_photo_urls']);
      final List<String> finalUrls = [];

      for (var item in rawUrls) {
        final path = item.toString();
        if (_isLocalFilePath(path)) {
          final uploadedUrl = await _uploadLocalFileToStorage(client, path);
          if (uploadedUrl != null) {
            finalUrls.add(uploadedUrl);
          } else {
            finalUrls.add(path); // Keep as fallback
          }
        } else {
          finalUrls.add(path);
        }
      }
      updated['hazard_photo_urls'] = finalUrls;
    }

    // Check photo_url single string
    if (updated.containsKey('photo_url') && updated['photo_url'] != null) {
      final path = updated['photo_url'].toString();
      if (_isLocalFilePath(path)) {
        final uploadedUrl = await _uploadLocalFileToStorage(client, path);
        if (uploadedUrl != null) {
          updated['photo_url'] = uploadedUrl;
        }
      }
    }

    return updated;
  }

  bool _isLocalFilePath(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return false;
    }
    return path.isNotEmpty && (path.startsWith('/') || path.contains(RegExp(r'^[a-zA-Z]:\\')) || path.contains('/data/') || path.contains('/storage/'));
  }

  Future<String?> _uploadLocalFileToStorage(SupabaseClient client, String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('Local photo file not found at path: $localPath');
        return null;
      }

      final fileName = 'offline_${DateTime.now().millisecondsSinceEpoch}_${p.basename(localPath)}';
      final storagePath = 'hazard_photos/$fileName';

      await client.storage.from('hazard-photos').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );

      final publicUrl = client.storage.from('hazard-photos').getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading offline photo: $e');
      return null;
    }
  }
}
