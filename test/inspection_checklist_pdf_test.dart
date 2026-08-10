import 'package:flutter_test/flutter_test.dart';
import 'package:firesight_mobile/models/commercial_checklist_model.dart';
import 'package:firesight_mobile/services/inspection_checklist_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('InspectionChecklistPdfService generates valid 10-page document', () async {
    final model = CommercialChecklistModel(
      ioNumber: 'IO-2026-001',
      dateIssued: '2026-08-01',
      dateInspected: '2026-08-10',
      inspectionNature: 'BusinessPermit',
      buildingName: 'Sunlight Commercial Plaza',
      address: 'Poblacion, Lingayen, Pangasinan',
      businessName: 'Sunlight Mart Inc.',
      natureOfBusiness: 'Retail & Commercial',
      ownerRepresentative: 'Juan Dela Cruz',
      contactNo: '09171234567',
      fsecNo: 'FSEC-2025-089',
      fsecDateIssued: '2025-01-10',
      buildingPermitNo: 'BP-2025-442',
      buildingPermitDateIssued: '2025-01-15',
      fsicNoLatest: 'FSIC-2025-789',
      fsicDateIssued: '2025-08-15',
      fireDrillCertNo: 'FDC-2026-102',
      fireDrillDateIssued: '2026-03-20',
      businessPermitNo: 'BPN-2026-991',
      businessPermitDateIssued: '2026-01-05',
      fireInsurancePolicyNo: 'FIP-998822',
      fireInsuranceDateIssued: '2026-01-01',
      constructionType: 'Type I: Concrete & Steel (Fire Resistive)',
      interiorFinishWalls: 'Class A: Flame spread 0-25',
      interiorFinishFloor: 'Class I: Critical radiant flux >= 0.45 W/cm2',
      groundFloorUsage: 'Main Store & Receiving Area',
      secondFloorUsage: 'Offices & Storage',
      occupancyClassification: 'Business',
      occupantLoad: '75',
      numberOfStories: '2',
      buildingHeight: '8',
      isHighrise: 'No',
      defectsSummary: 'No critical defects observed.',
      recommendationAction: 'FSIC',
      inspectorName: 'FO1 Pedro Penduko BFP',
      teamLeaderName: 'SFO2 Maria Santos BFP',
      fireMarshalName: 'CINSP Juan Luna BFP',
    );

    final pdfDoc = await InspectionChecklistPdfService.buildDocument(model);
    expect(pdfDoc.document.pdfPageList.pages.length, equals(10));

    final bytes = await pdfDoc.save();
    expect(bytes.isNotEmpty, isTrue);
    expect(bytes.length, greaterThan(1000));
  });

  test('InspectionChecklistPdfService parses and generates from Supabase record payload', () async {
    final supabaseRow = {
      'id': '39077eb4-5bec-4b44-b562-4b37bea27a7b',
      'inspection_order_no': 'IO-245753',
      'business_name': 'Magic',
      'address': 'Poblacion, Lingayen, Pangasinan',
      'overall_status': 'Completed',
      'compliance_status': 'FSIC',
      'recommendation': 'FSIC',
      'checklist_data': {
        'ioNumber': 'IO-245753',
        'dateIssued': '2026-07-25',
        'dateInspected': '2026-07-24',
        'inspectionNature': 'FSIC for Business Permit (New/Renewal)',
        'fsmrRequired': 'Yes',
        'fsccrRequired': null,
        'generalInfo': {
          'buildingName': 'Magic',
          'businessName': 'Magic',
          'address': 'Poblacion, Lingayen, Pangasinan',
          'natureOfBusiness': 'Grocery',
          'ownerRepresentative': 'test',
          'contactNo': '09123456789',
          'fsecNo': '1234',
          'fsecDateIssued': '2026-07-01',
          'buildingPermitNo': '1234',
          'buildingPermitDateIssued': '2026-07-01',
          'fsicNoLatest': '123',
          'fsicDateIssued': '2026-07-01',
          'fireDrillCertNo': '1234',
          'fireDrillDateIssued': '2026-07-01',
          'businessPermitNo': '1234',
          'businessPermitDateIssued': '2026-07-01',
          'fireInsurancePolicyNo': '1234',
          'fireInsuranceDateIssued': '2026-07-01',
        },
        'buildingSpecifications': {
          'constructionType': 'Type I: Concrete & Steel (Fire Resistive)',
          'interiorFinishWalls': 'Class A: Flame spread 0-25',
          'interiorFinishFloor': 'Class I: Critical radiant flux >= 0.45 W/cm2',
          'occupancyClassification': 'Business',
          'occupantLoad': '5',
          'numberOfStories': '5',
          'buildingHeight': '30',
          'isHighrise': 'No',
          'sectionalOccupancy': {
            'basement': '1',
            'groundFloor': '1',
            'secondFloor': '2',
            'thirdFloor': '2',
            'fourthFloor': '4',
            'nthFloor': '4',
          },
        },
        'signatories': {
          'inspectorName': 'TEST',
          'teamLeaderName': 'TEST',
          'fireMarshalName': 'TEST',
        },
        'defectsSummary': 'TEST',
        'recommendationAction': 'FSIC',
        'hazardStatus': {
          'Stored in sealed metal containers': 'Passed',
          'Properly dispensed as per SOP': 'Passed',
        },
        'fireProtectionStatus': {
          'Sprinkler Pumps - Check automatic start and pressure': 'Passed',
          'Sprinkler Valves - Valves locked open, no leaks/corrosion': 'Passed',
        },
        'itemDimensions': {
          'Doors': '1',
          'Normal Stairs': '1',
        },
      }
    };

    final combined = Map<String, dynamic>.from(supabaseRow);
    if (supabaseRow['checklist_data'] is Map<String, dynamic>) {
      combined.addAll(supabaseRow['checklist_data'] as Map<String, dynamic>);
    }

    final model = CommercialChecklistModel.fromJson(combined);

    expect(model.businessName, equals('Magic'));
    expect(model.constructionType, contains('Type I'));
    expect(model.interiorFinishWalls, contains('Class A'));
    expect(model.interiorFinishFloor, contains('Class I'));
    expect(model.occupancyClassification, equals('Business'));
    expect(model.inspectorName, equals('TEST'));

    final pdfDoc = await InspectionChecklistPdfService.buildDocument(model);
    expect(pdfDoc.document.pdfPageList.pages.length, equals(10));

    final bytes = await pdfDoc.save();
    expect(bytes.isNotEmpty, isTrue);
  });
}
