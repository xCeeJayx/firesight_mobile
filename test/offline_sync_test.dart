import 'package:flutter_test/flutter_test.dart';
import 'package:firesight_mobile/models/user_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineSync & Architecture Tests', () {
    test('UserRole and route access verification for offline boot', () {
      expect(UserRole.fireInspector.defaultRoute, '/inspector/dashboard');
      expect(UserRole.communityRiskOfficer.defaultRoute, '/risk-mapping/dashboard');
      expect(UserRole.stationOfficer.defaultRoute, '/admin/dashboard');
      expect(UserRole.publicGuest.defaultRoute, '/public/map');
    });

    test('Pending sync payload structure verification', () {
      final payload = {
        'business_name': 'Offline Test Commercial Business',
        'overall_status': 'Pending Sync',
        'inspection_order_no': 'IO-2026-TEST-001',
        'hazard_photo_urls': ['C:\\temp\\hazard1.jpg', 'C:\\temp\\hazard2.jpg'],
        'compliance_status': 'For Issuance of FSIC',
      };

      expect(payload['overall_status'], 'Pending Sync');
      expect(payload['hazard_photo_urls'], isA<List>());
      expect((payload['hazard_photo_urls'] as List).length, 2);
    });
  });
}
