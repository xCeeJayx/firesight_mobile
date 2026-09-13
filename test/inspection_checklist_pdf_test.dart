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

  test('InspectionChecklistPdfService strictly handles N/A and uninspected items without defaulting to passed', () async {
    final model = CommercialChecklistModel(
      ioNumber: 'IO-NA-TEST',
      dateIssued: '2026-08-01',
      dateInspected: '2026-08-10',
      inspectionNature: 'BusinessPermit',
      buildingName: 'NA Test Building',
      address: 'Lingayen, Pangasinan',
      businessName: 'NA Test Shop',
      natureOfBusiness: 'Retail',
      ownerRepresentative: 'Test Owner',
      contactNo: '09123456789',
      // Explicit N/A and uninspected items
      egressAccessStatus: {
        'Doors': 'Passed',
        'Ramps': 'Failed',
        'Dead end': 'N/A',
        'Lobby / Anteroom': '', // Uninspected
      },
      exitSignageStatus: {
        'Minimum letter height, 150 mm': 'N/A',
        'EXIT signs properly illuminated': 'Passed',
      },
      fireProtectionStatus: {
        'Hose Condition - Not rotted, wet, or moldy': 'N/A',
        'Sprinkler Pumps - Check automatic start and pressure': 'Passed',
      },
      hazardStatus: {
        'Properly dispensed as per SOP': 'N/A',
      },
      // Recommendation is Notice of Disapproval (NOD)
      recommendationAction: 'NOD',
      defectsSummary: 'Defects found during inspection',
      defectsItemIV: 'Defect in Means of Egress',
      defectsItemV: 'Defect in Compartmentation',
      defectsItemVI: 'Defect in Fire Protection',
      defectsItemVII: 'Defect in Hazards',
      defectsItemVIII: 'Defect in Miscellaneous',
      // Section VII Hazards
      hazardContents: 'Diesel and Lubricant Oil',
      hazardQuantity: '200 Liters',
      hazardPlacard: 'Class 3 Flammable Liquid',
      withinMaq: 'Yes',
      hazardIdentificationNo: 'UN 1202',
      hazardClassification: 'Flammable Liquid',
      hazardClass: 'Class II',
      flashPoint: '55°C',
      // Section VIII.J Building Service Equipment
      bseUtilities: 'Passed',
      bseHvac: 'Passed',
      bseSmokeControl: 'Failed',
      bseRubbishChutes: 'N/A',
      // Section VIII.K Fire Wall
      fireWallProvided: 'Yes',
      fireWallExtension: '1000 mm',
      fireWallType: '2-hour fire resistive concrete',
      // Signatories policy: Empty marshal name (to be approved on web admin)
      inspectorName: 'FO1 John Doe',
      teamLeaderName: '',
      fireMarshalName: '',
    );

    // Verify model fields
    expect(model.bseUtilities, equals('Passed'));
    expect(model.bseSmokeControl, equals('Failed'));
    expect(model.bseRubbishChutes, equals('N/A'));
    expect(model.fireWallProvided, equals('Yes'));
    expect(model.hazardContents, equals('Diesel and Lubricant Oil'));
    expect(model.withinMaq, equals('Yes'));
    expect(model.fireMarshalName, isEmpty);

    // Verify JSON serialization and deserialization
    final json = model.toJson();
    final restoredModel = CommercialChecklistModel.fromJson(json);
    expect(restoredModel.bseUtilities, equals('Passed'));
    expect(restoredModel.bseSmokeControl, equals('Failed'));
    expect(restoredModel.bseRubbishChutes, equals('N/A'));
    expect(restoredModel.hazardContents, equals('Diesel and Lubricant Oil'));
    expect(restoredModel.fireWallProvided, equals('Yes'));
    expect(restoredModel.defectsItemIV, equals('Defect in Means of Egress'));
    expect(restoredModel.fireMarshalName, isEmpty);

    // Build PDF and verify all 10 pages render cleanly
    final pdfDoc = await InspectionChecklistPdfService.buildDocument(model);
    expect(pdfDoc.document.pdfPageList.pages.length, equals(10));

    final bytes = await pdfDoc.save();
    expect(bytes.isNotEmpty, isTrue);
    expect(bytes.length, greaterThan(1000));
  });

  test('InspectionChecklistPdfService parses and builds Batangina Liptint Shop Supabase payload with NOD recommendation', () async {
    final batanginaRow = {
      'id': '7b8d0f9d-3d7a-4d48-83d7-9861dc039d0b',
      'inspection_order_no': 'IO-2026-004',
      'business_name': 'Batangina Liptint Shop',
      'overall_status': 'Completed',
      'compliance_status': 'NOD',
      'recommendation': 'NOD',
      'checklist_data': {
        'ioNumber': 'IO-2026-004',
        'dateIssued': '2026-08-20',
        'dateInspected': '2026-08-28',
        'checklist_type': 'commercial',
        'inspectionNature': 'FSIC for Business Permit (New/Renewal)',
        'fsmrRequired': 'No',
        'fsccrRequired': 'No',
        'generalInfo': {
          'buildingName': 'Mami Oni Bldg',
          'businessName': 'Batangina Liptint Shop',
          'address': 'Ramos St. Poblacion, Lingayen Pangasinan',
          'natureOfBusiness': 'Retail',
          'ownerRepresentative': 'Baby Jean',
          'contactNo': '09123456789',
          'fsecNo': '',
          'fsecDateIssued': '',
          'buildingPermitNo': '',
          'buildingPermitDateIssued': '',
          'fsicNoLatest': '',
          'fsicDateIssued': '',
          'fireDrillCertNo': '',
          'fireDrillDateIssued': '',
          'businessPermitNo': '',
          'businessPermitDateIssued': '',
          'fireInsurancePolicyNo': '',
          'fireInsuranceDateIssued': '',
        },
        'buildingSpecifications': {
          'constructionType': 'Type II: Concrete & Exposed Steel (Noncombustible)',
          'interiorFinishWalls': 'Class B: Flame spread 26-75',
          'interiorFinishFloor': 'Class II: Critical radiant flux 0.22 - 0.45 W/cm2',
          'occupancyClassification': 'Mercantile',
          'occupantLoad': '',
          'numberOfStories': '',
          'buildingHeight': '',
          'isHighrise': 'No',
          'sectionalOccupancy': {
            'basement': '',
            'groundFloor': '',
            'secondFloor': '',
            'thirdFloor': '',
            'fourthFloor': '',
            'nthFloor': '',
          },
        },
        'signatories': {
          'inspectorName': 'Song Kang Kong',
          'teamLeaderName': 'King Badger',
          'fireMarshalName': 'Xian Gaza',
        },
        'defectsSummary': 'test',
        'recommendationAction': 'NOD',
        'hazardStatus': {
          'Properly dispensed as per SOP': 'Failed',
          'Provided with "NO SMOKING" sign': 'Failed',
          'Stored in sealed metal containers': 'Failed',
          'All no smoking areas have adequate signs': 'Failed',
          'Dry leaves, shrubbery trimmings kept away from buildings': 'Failed',
          'Gasoline / Diesel stored in proper place & metal safety can': 'Failed',
          'Brooms, mops, rags stored in metal cabinets or approved cans': 'Failed',
          'Paints, solvents stored in metal cabinet; oily rags in metal containers': 'Failed',
        },
        'itemDimensions': {
          'Doors': '5',
          'Passageways': '55',
          'Corridors / Hallways': '5',
        },
        'egressAccessStatus': {
          'Doors': 'Failed',
          'Ramps': 'Failed',
          'Dead end': 'Failed',
          'Passageways': 'Failed',
          'Travel distance': 'Failed',
          'Lobby / Anteroom': 'Failed',
          'Corridors / Hallways': 'Failed',
          'Common path of travel': 'Failed',
        },
      }
    };

    final combined = Map<String, dynamic>.from(batanginaRow);
    if (batanginaRow['checklist_data'] is Map<String, dynamic>) {
      combined.addAll(batanginaRow['checklist_data'] as Map<String, dynamic>);
    }

    final model = CommercialChecklistModel.fromJson(combined);

    expect(model.businessName, equals('Batangina Liptint Shop'));
    expect(model.recommendationAction, equals('NOD'));
    expect(model.occupantLoad, isEmpty);
    expect(model.numberOfStories, isEmpty);
    expect(model.buildingHeight, isEmpty);
    expect(model.inspectorName, equals('Song Kang Kong'));
    expect(model.egressAccessStatus['Doors'], equals('Failed'));
    expect(model.hazardStatus['Properly dispensed as per SOP'], equals('Failed'));

    final pdfDoc = await InspectionChecklistPdfService.buildDocument(model);
    expect(pdfDoc.document.pdfPageList.pages.length, equals(10));

    final bytes = await pdfDoc.save();
    expect(bytes.isNotEmpty, isTrue);
  });
}

