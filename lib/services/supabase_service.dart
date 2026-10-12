import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // BFP Lingayen Official Hotline numbers & Emergency Dialers
  static const String bfpHotlineLandline = '0917-186-1611';
  static const String bfpHotlineMobile = '0917-186-1611';
  static const String bfpEmergencyNumber = '09171861611';
  static const String unified911Number = '911';

  // Cooldown threshold for rate limiting (seconds)
  static const int rateLimitCooldownSeconds = 120; // 2 minutes

  // Lingayen Geographic Reference Point (Town Hall / Poblacion Center)
  static const double lingayenCenterLat = 16.0120;
  static const double lingayenCenterLng = 120.2250;
  static const double lingayenMaxRadiusMeters = 8500.0; // 8.5 km radius

  // Complete list of all 32 Lingayen Barangays
  static const List<String> lingayenBarangays = [
    'Aliwekwek',
    'Baay',
    'Balacing',
    'Capuroan',
    'Domalandan Center',
    'Domalandan East',
    'Domalandan West',
    'Dulag',
    'Estanza',
    'Lasip',
    'Libsong East',
    'Libsong West',
    'Malamban',
    'Malapan',
    'Maniboc',
    'Matalava',
    'Naguillayan',
    'Namolan',
    'Pangapisan North',
    'Pangapisan Sur',
    'Poblacion',
    'Quibaol',
    'Sabangan',
    'Salapor',
    'Samat',
    'San Jose',
    'San Vicente',
    'Talongtog',
    'Tonton',
    'Tumbar',
    'Wawa',
    'Tonton West',
  ];

  /// Launch phone call to BFP Lingayen Hotline
  static Future<bool> callBfpHotline({String phoneNumber = '09171861611'}) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri uri = Uri(scheme: 'tel', path: cleanNumber.isNotEmpty ? cleanNumber : '09171861611');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      } else {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching BFP hotline call: $e');
      return false;
    }
  }

  /// Launch phone call directly to Unified 911 (for emergencies outside Lingayen)
  static Future<bool> callUnified911() async {
    final Uri uri = Uri(scheme: 'tel', path: unified911Number);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      } else {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching Unified 911 call: $e');
      return false;
    }
  }

  /// Check whether the incident GPS coordinates fall within Lingayen jurisdiction.
  /// Rule: The reporter's residence does not determine jurisdiction; the incident GPS does.
  static bool isInsideLingayen(double? latitude, double? longitude, {String? barangay}) {
    if (latitude != null && longitude != null) {
      // Check distance from Lingayen center (approx 8.5 km radius)
      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        lingayenCenterLat,
        lingayenCenterLng,
      );

      // Also check bounding box
      final inBoundingBox = (latitude >= 15.9600 && latitude <= 16.0550) &&
          (longitude >= 120.1700 && longitude <= 120.2800);

      return distance <= lingayenMaxRadiusMeters || inBoundingBox;
    }

    // Fallback if GPS is unavailable: check if reported barangay is in Lingayen
    if (barangay != null && barangay.trim().isNotEmpty) {
      return lingayenBarangays.any(
        (b) => b.toLowerCase() == barangay.trim().toLowerCase(),
      );
    }

    return true; // Default to true if no location info provided
  }

  /// Get or generate a persistent unique Device ID for spam/flooding control
  static Future<String> getOrCreateDeviceId() async {
    try {
      String? deviceId = await _storage.read(key: 'firesight_device_uuid');
      if (deviceId != null && deviceId.isNotEmpty) {
        return deviceId;
      }

      // Generate a persistent pseudorandom ID
      final random = Random.secure();
      final values = List<int>.generate(16, (i) => random.nextInt(256));
      deviceId = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_$deviceId';

      await _storage.write(key: 'firesight_device_uuid', value: deviceId);
      return deviceId;
    } catch (e) {
      debugPrint('Error reading/generating device ID: $e');
      return 'dev_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Check remaining cooldown seconds before a new report can be submitted (Rate Limiting).
  /// Enforces a 2-minute cooldown between submissions from the same device.
  static Future<int> getRemainingCooldownSeconds() async {
    try {
      final lastSubmitStr = await _storage.read(key: 'last_emergency_report_timestamp');
      if (lastSubmitStr == null) return 0;

      final lastSubmitTime = DateTime.tryParse(lastSubmitStr);
      if (lastSubmitTime == null) return 0;

      final elapsed = DateTime.now().difference(lastSubmitTime).inSeconds;
      final remaining = rateLimitCooldownSeconds - elapsed;
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      debugPrint('Error checking report cooldown: $e');
      return 0;
    }
  }

  /// Record the submission timestamp to enforce local rate limiting cooldown
  static Future<void> recordReportSubmissionTimestamp() async {
    try {
      await _storage.write(
        key: 'last_emergency_report_timestamp',
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error storing last submission timestamp: $e');
    }
  }

  /// Check whether the account or device has submitted excessive reports (>3 in 10 minutes)
  /// Flags suspicious device without outright blocking distress calls.
  static Future<bool> checkIfSuspiciousFlooding({
    required String deviceId,
    String? reporterContact,
  }) async {
    try {
      final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String();

      // Query reports from this device in the last 10 minutes
      final response = await _client
          .from('emergency_reports')
          .select('id')
          .gte('created_at', tenMinutesAgo)
          .eq('device_id', deviceId);

      final count = (response as List).length;
      return count >= 3;
    } catch (e) {
      debugPrint('Error checking suspicious flooding: $e');
      return false;
    }
  }

  /// Duplicate incident detection / auto-merge:
  /// Checks whether an incoming report refers to an existing active incident using:
  /// 1. Same incident type
  /// 2. Same or nearby GPS location (within 500 meters)
  /// 3. Close reporting time window (within 1 hour)
  static Future<Map<String, dynamic>?> findMatchingActiveIncident({
    required String incidentType,
    double? latitude,
    double? longitude,
    String? barangay,
  }) async {
    try {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();

      // Query active primary parent incidents within the last 1 hour
      // (parent_incident_id is null ensures we only link to top-level parent incidents)
      final response = await _client
          .from('emergency_reports')
          .select()
          .gte('created_at', oneHourAgo)
          .inFilter('status', ['Unverified', 'Verified', 'Responding'])
          .isFilter('parent_incident_id', null)
          .order('created_at', ascending: false);

      final activeIncidents = List<Map<String, dynamic>>.from(response);

      for (final incident in activeIncidents) {
        final existingType = incident['incident_type']?.toString() ?? '';
        if (existingType.toLowerCase() != incidentType.toLowerCase()) {
          continue;
        }

        // Check GPS proximity if coordinates are present on both
        final exLat = incident['latitude'] != null ? (incident['latitude'] as num).toDouble() : null;
        final exLng = incident['longitude'] != null ? (incident['longitude'] as num).toDouble() : null;

        if (latitude != null && longitude != null && exLat != null && exLng != null) {
          final distanceMeters = Geolocator.distanceBetween(latitude, longitude, exLat, exLng);
          if (distanceMeters <= 500.0) {
            // Found matching active incident within 500m!
            return incident;
          }
        } else if (barangay != null && barangay.isNotEmpty) {
          // Fallback if coordinates missing: match by same barangay
          final exBarangay = incident['barangay']?.toString() ?? '';
          if (exBarangay.toLowerCase() == barangay.toLowerCase()) {
            return incident;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error during duplicate incident lookup: $e');
      return null;
    }
  }

  /// Submit emergency report to Supabase `emergency_reports` table
  /// with duplicate auto-merge, jurisdiction tag, device ID, and spam tracking.
  static Future<Map<String, dynamic>> submitEmergencyReport({
    String? reporterName,
    required String reporterContact,
    required String incidentType,
    required String barangay,
    String? address,
    double? latitude,
    double? longitude,
    String? description,
    File? photoFile,
    Uint8List? photoBytes,
    String? photoName,
    bool photoUnsafe = false,
    bool isOutOfJurisdiction = false,
  }) async {
    try {
      // 1. Get or create persistent device ID
      final deviceId = await getOrCreateDeviceId();

      // 2. Check if device/account should be flagged as suspicious
      final isSuspicious = await checkIfSuspiciousFlooding(
        deviceId: deviceId,
        reporterContact: reporterContact,
      );

      // 3. Upload photo if provided
      String? photoUrl;
      if (!photoUnsafe && (photoFile != null || photoBytes != null)) {
        try {
          final fileName = 'emergency_${DateTime.now().millisecondsSinceEpoch}_${photoName ?? 'evidence.jpg'}';
          final path = 'emergency_reports/$fileName';

          if (photoBytes != null) {
            await _client.storage.from('hazard-photos').uploadBinary(
                  path,
                  photoBytes,
                  fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
                );
          } else if (photoFile != null) {
            await _client.storage.from('hazard-photos').upload(
                  path,
                  photoFile,
                  fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
                );
          }

          photoUrl = _client.storage.from('hazard-photos').getPublicUrl(path);
        } catch (storageError) {
          debugPrint('Storage upload error: $storageError');
          // Proceed with report insertion even if storage fails
        }
      }

      // 4. Duplicate incident detection / auto-merge
      final matchingParent = await findMatchingActiveIncident(
        incidentType: incidentType,
        latitude: latitude,
        longitude: longitude,
        barangay: barangay,
      );

      String? parentIncidentId;
      int updatedSupportingCount = 0;
      bool isAutoMerged = false;

      if (matchingParent != null) {
        parentIncidentId = matchingParent['id']?.toString();
        isAutoMerged = true;
        final currentSupporting = (matchingParent['supporting_reports_count'] as num?)?.toInt() ?? 0;
        updatedSupportingCount = currentSupporting + 1;

        // Increment parent incident supporting_reports_count
        try {
          await _client.from('emergency_reports').update({
            'supporting_reports_count': updatedSupportingCount,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', parentIncidentId!);
        } catch (updateErr) {
          debugPrint('Error updating parent supporting count: $updateErr');
        }
      }

      // 5. Initial report status
      final String initialStatus = isOutOfJurisdiction
          ? 'Out-of-Jurisdiction'
          : (isAutoMerged ? 'Unverified' : 'Unverified');

      final reportData = {
        'reporter_name': (reporterName == null || reporterName.trim().isEmpty) ? 'Anonymous Citizen' : reporterName.trim(),
        'reporter_contact': reporterContact.trim(),
        'incident_type': incidentType,
        'barangay': barangay,
        'address': address?.trim() ?? '',
        'latitude': latitude,
        'longitude': longitude,
        'description': description?.trim() ?? '',
        'photo_url': photoUrl,
        'status': initialStatus,
        'created_at': DateTime.now().toIso8601String(),
        'parent_incident_id': parentIncidentId,
        'supporting_reports_count': 0,
        'is_out_of_jurisdiction': isOutOfJurisdiction,
        'photo_unsafe': photoUnsafe,
        'device_id': deviceId,
        'is_flagged_suspicious': isSuspicious,
      };

      final response = await _client.from('emergency_reports').insert(reportData).select().single();

      // 6. Record local submission timestamp for cooldown
      await recordReportSubmissionTimestamp();

      return {
        'success': true,
        'data': response,
        'isAutoMerged': isAutoMerged,
        'parentIncident': matchingParent,
        'supportingReportsCount': updatedSupportingCount,
        'isOutOfJurisdiction': isOutOfJurisdiction,
      };
    } catch (e) {
      debugPrint('Error inserting emergency report: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
