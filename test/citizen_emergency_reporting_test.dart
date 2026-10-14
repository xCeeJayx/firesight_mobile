import 'package:flutter_test/flutter_test.dart';
import 'package:firesight_mobile/models/emergency_report_model.dart';
import 'package:firesight_mobile/services/supabase_service.dart';

void main() {
  group('EmergencyReportModel Tests', () {
    test('Correctly handles auto-merge, jurisdiction, safety photo and suspicious fields', () {
      final json = {
        'id': 'test-uuid-123',
        'reporter_name': 'Citizen Test',
        'reporter_contact': '09171234567',
        'incident_type': 'Structural Fire',
        'barangay': 'Poblacion',
        'address': 'Rizal Avenue',
        'latitude': 16.0120,
        'longitude': 120.2250,
        'description': 'Smoke coming from residential roof',
        'status': 'Unverified',
        'created_at': '2026-10-12T10:00:00.000Z',
        'parent_incident_id': 'parent-uuid-999',
        'supporting_reports_count': 3,
        'is_out_of_jurisdiction': false,
        'photo_unsafe': true,
        'device_id': 'dev_test_device',
        'is_flagged_suspicious': true,
      };

      final report = EmergencyReportModel.fromJson(json);

      expect(report.id, 'test-uuid-123');
      expect(report.parentIncidentId, 'parent-uuid-999');
      expect(report.isSupportingReport, isTrue);
      expect(report.supportingReportsCount, 3);
      expect(report.hasSupportingReports, isTrue);
      expect(report.isOutOfJurisdiction, isFalse);
      expect(report.photoUnsafe, isTrue);
      expect(report.isFlaggedSuspicious, isTrue);
      expect(report.deviceId, 'dev_test_device');

      // Test serialization
      final serialized = report.toJson();
      expect(serialized['parent_incident_id'], 'parent-uuid-999');
      expect(serialized['supporting_reports_count'], 3);
      expect(serialized['photo_unsafe'], isTrue);
      expect(serialized['is_flagged_suspicious'], isTrue);
    });

    test('Identifies out-of-jurisdiction reports accurately', () {
      final report = EmergencyReportModel(
        id: 'out-uuid',
        incidentType: 'Grass / Garbage Fire',
        barangay: 'Dagupan Area',
        isOutOfJurisdiction: true,
        status: 'Out-of-Jurisdiction',
      );

      expect(report.isOutDistrict, isTrue);
      expect(report.statusTextColor, isNotNull);
      expect(report.statusBgColor, isNotNull);
    });
  });

  group('Jurisdiction Logic Tests', () {
    test('Lingayen GPS coordinates are recognized as within jurisdiction', () {
      // Lingayen town center coordinates
      final insideCenter = SupabaseService.isInsideLingayen(16.0120, 120.2250);
      expect(insideCenter, isTrue);

      // Poblacion area
      final insidePoblacion = SupabaseService.isInsideLingayen(16.0200, 120.2300);
      expect(insidePoblacion, isTrue);

      // Domalandan West
      final insideDomalandan = SupabaseService.isInsideLingayen(16.0050, 120.1950);
      expect(insideDomalandan, isTrue);
    });

    test('Coordinates far outside Lingayen are identified as outside jurisdiction', () {
      // Dagupan City Center
      final outsideDagupan = SupabaseService.isInsideLingayen(16.0433, 120.3333);
      expect(outsideDagupan, isFalse);

      // Manila
      final outsideManila = SupabaseService.isInsideLingayen(14.5995, 120.9842);
      expect(outsideManila, isFalse);

      // Baguio City
      final outsideBaguio = SupabaseService.isInsideLingayen(16.4023, 120.5960);
      expect(outsideBaguio, isFalse);
    });

    test('Fallback to Lingayen barangays when coordinates are null', () {
      expect(SupabaseService.isInsideLingayen(null, null, barangay: 'Poblacion'), isTrue);
      expect(SupabaseService.isInsideLingayen(null, null, barangay: 'Maniboc'), isTrue);
      expect(SupabaseService.isInsideLingayen(null, null, barangay: 'Calasiao'), isFalse);
      expect(SupabaseService.isInsideLingayen(null, null, barangay: 'Lucao'), isFalse);
    });
  });

  group('Philippine Mobile Number Validation Tests', () {
    final phMobileRegex = RegExp(r'^(09\d{9}|\+639\d{9}|9\d{9})$');

    test('Accepts valid 09XX numbers and +639XX numbers', () {
      expect(phMobileRegex.hasMatch('09171234567'), isTrue);
      expect(phMobileRegex.hasMatch('+639171234567'), isTrue);
      expect(phMobileRegex.hasMatch('09998765432'), isTrue);
    });

    test('Rejects invalid phone numbers', () {
      expect(phMobileRegex.hasMatch('12345'), isFalse);
      expect(phMobileRegex.hasMatch('08171234567'), isFalse);
      expect(phMobileRegex.hasMatch('0917123456'), isFalse); // 10 digits
      expect(phMobileRegex.hasMatch('abcdefghijk'), isFalse);
    });
  });

  group('Emergency Alert Sequence Policy Tests', () {
    bool shouldTriggerAlert({
      required String status,
      required bool isStaff,
    }) {
      final s = status.toLowerCase();
      // Rule 3: dispatch, false alarm, and resolved -> strictly NO alerts
      if (s == 'responding' || s == 'dispatched' || s == 'false alarm' || s == 'false_alarm' || s == 'resolved') {
        return false;
      }
      // Rule 1: unverified -> ONLY officers get alert, not public
      if (s == 'unverified' && !isStaff) {
        return false;
      }
      // Rule 2: verified -> ONLY public gets alert, not officers
      if (s == 'verified' && isStaff) {
        return false;
      }
      return true;
    }

    test('Unverified report triggers alert for officers but NOT for public', () {
      expect(shouldTriggerAlert(status: 'Unverified', isStaff: true), isTrue);
      expect(shouldTriggerAlert(status: 'Unverified', isStaff: false), isFalse);
    });

    test('Verified report triggers alert for public but NOT for officers', () {
      expect(shouldTriggerAlert(status: 'Verified', isStaff: false), isTrue);
      expect(shouldTriggerAlert(status: 'Verified', isStaff: true), isFalse);
    });

    test('Dispatch, False Alarm, and Resolved statuses trigger NO alerts for anyone', () {
      for (final status in ['Responding', 'Dispatched', 'False Alarm', 'Resolved']) {
        expect(shouldTriggerAlert(status: status, isStaff: true), isFalse, reason: 'Officer alert for $status should be false');
        expect(shouldTriggerAlert(status: status, isStaff: false), isFalse, reason: 'Public alert for $status should be false');
      }
    });
  });
}

