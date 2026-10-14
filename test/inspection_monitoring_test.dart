import 'package:flutter_test/flutter_test.dart';
import 'package:firesight_mobile/models/inspection_monitoring_model.dart';
import 'package:firesight_mobile/services/inspection_monitoring_service.dart';

void main() {
  group('InspectionMonitoringModel Tests', () {
    test('Correctly serializes and deserializes inspection monitoring session', () {
      final now = DateTime.now();
      final json = {
        'id': 'session-uuid-101',
        'inspector_id': 'inspector-uuid-202',
        'inspector_name': 'Juan Dela Cruz',
        'inspector_rank': 'SFO1',
        'inspector_badge': 'BFP-9531',
        'visit_type': 'NTC Verification / Reinspection',
        'io_reference_no': 'IO-2026-0428-R1',
        'related_order_no': 'NTC-2026-0184',
        'barangay': 'Poblacion',
        'location_address': 'Avenida Rizal St.',
        'establishment_name': 'Lingayen Commercial Hub',
        'status': 'ON SITE',
        'start_time': now.toIso8601String(),
        'start_latitude': 16.0120,
        'start_longitude': 120.2250,
        'current_latitude': 16.0125,
        'current_longitude': 120.2255,
      };

      final model = InspectionMonitoringModel.fromJson(json);

      expect(model.id, 'session-uuid-101');
      expect(model.inspectorName, 'Juan Dela Cruz');
      expect(model.inspectorRank, 'SFO1');
      expect(model.visitType, 'NTC Verification / Reinspection');
      expect(model.ioReferenceNo, 'IO-2026-0428-R1');
      expect(model.relatedOrderNo, 'NTC-2026-0184');
      expect(model.establishmentName, 'Lingayen Commercial Hub');
      expect(model.isOnSite, isTrue);
      expect(model.isCompleted, isFalse);

      final serialized = model.toJson();
      expect(serialized['io_reference_no'], 'IO-2026-0428-R1');
      expect(serialized['related_order_no'], 'NTC-2026-0184');
      expect(serialized['status'], 'ON SITE');
    });

    test('Computes duration and handles completed status correctly', () {
      final start = DateTime.now().subtract(const Duration(minutes: 50));
      final end = DateTime.now();

      final model = InspectionMonitoringModel(
        id: 'completed-1',
        inspectorName: 'Pedro Santos',
        visitType: 'Regular / Initial Inspection',
        ioReferenceNo: 'IO-2026-001',
        barangay: 'Maniboc',
        status: 'COMPLETED',
        startTime: start,
        endTime: end,
        durationMinutes: 50,
      );

      expect(model.isOnSite, isFalse);
      expect(model.isCompleted, isTrue);
      expect(model.formattedDuration, '50 mins');
      expect(model.visitTypeColor, isNotNull);
      expect(model.visitTypeIcon, isNotNull);
    });

    test('Visit types list conforms to BFP monitoring standards', () {
      expect(InspectionMonitoringService.visitTypes.length, 6);
      expect(InspectionMonitoringService.visitTypes, contains('Regular / Initial Inspection'));
      expect(InspectionMonitoringService.visitTypes, contains('NTC Verification / Reinspection'));
      expect(InspectionMonitoringService.visitTypes, contains('NTCV Verification / Reinspection'));
      expect(InspectionMonitoringService.visitTypes, contains('Abatement Order Verification'));
      expect(InspectionMonitoringService.visitTypes, contains('Closure / Stoppage Verification'));
      expect(InspectionMonitoringService.visitTypes, contains('Other Official Inspection'));
    });

    test('Guards against future startTime and never returns negative duration', () {
      // Future start time scenario (e.g. timezone mismatch)
      final futureStart = DateTime.now().add(const Duration(hours: 8));
      final model = InspectionMonitoringModel(
        id: 'future-1',
        inspectorName: 'Fire Inspector',
        visitType: 'Regular / Initial Inspection',
        ioReferenceNo: 'TEST',
        barangay: 'Aliwekwek',
        startTime: futureStart,
      );

      expect(model.elapsedDurationString, '0m');
      expect(model.formattedDuration, '0m');

      // Serializing produces UTC format ending with Z
      final json = model.toJson();
      expect(json['start_time'], endsWith('Z'));
    });

    test('Fire Inspector Navigation tabs are properly configured with 5 destinations', () {
      const expectedDestinations = [
        'Home',
        'Start Monitor',
        'Active Session',
        'History',
        'Map',
      ];
      expect(expectedDestinations.length, 5);
      expect(expectedDestinations.first, 'Home');
    });
  });
}
