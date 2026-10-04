import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // BFP Lingayen Official Hotline numbers
  static const String bfpHotlineLandline = '0917-186-1611';
  static const String bfpHotlineMobile = '0917-186-1611';
  static const String bfpEmergencyNumber = '09171861611';

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
        // Direct fallback launch attempt
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching hotline call: $e');
      return false;
    }
  }

  /// Submit emergency report to Supabase `emergency_reports` table
  static Future<Map<String, dynamic>> submitEmergencyReport({
    String? reporterName,
    String? reporterContact,
    required String incidentType,
    required String barangay,
    String? address,
    double? latitude,
    double? longitude,
    String? description,
    File? photoFile,
    Uint8List? photoBytes,
    String? photoName,
  }) async {
    try {
      String? photoUrl;

      // Upload photo if provided
      if (photoFile != null || photoBytes != null) {
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

      final reportData = {
        'reporter_name': (reporterName == null || reporterName.trim().isEmpty) ? 'Anonymous Citizen' : reporterName.trim(),
        'reporter_contact': (reporterContact == null || reporterContact.trim().isEmpty) ? 'N/A' : reporterContact.trim(),
        'incident_type': incidentType,
        'barangay': barangay,
        'address': address?.trim() ?? '',
        'latitude': latitude,
        'longitude': longitude,
        'description': description?.trim() ?? '',
        'photo_url': photoUrl,
        'status': 'Unverified',
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _client.from('emergency_reports').insert(reportData).select().single();

      // Note: The database trigger (trigger_notify_emergency_report) automatically
      // dispatches push notifications on emergency_reports INSERT via pg_net.

      return {'success': true, 'data': response};
    } catch (e) {
      debugPrint('Error inserting emergency report: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
