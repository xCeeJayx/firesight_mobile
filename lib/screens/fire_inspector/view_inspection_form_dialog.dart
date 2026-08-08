import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/commercial_checklist_model.dart';

class ViewInspectionFormDialog extends StatefulWidget {
  final String? targetInspectionId;
  final Map<String, dynamic>? initialData;

  const ViewInspectionFormDialog({
    super.key,
    this.targetInspectionId,
    this.initialData,
  });

  @override
  State<ViewInspectionFormDialog> createState() => _ViewInspectionFormDialogState();
}

class _ViewInspectionFormDialogState extends State<ViewInspectionFormDialog> {
  static const Color colorPrimary = Color(0xFF0F172A);
  static const Color colorAccent = Color(0xFFEA580C);
  static const Color colorBorder = Color(0xFF94A3B8);
  static const Color colorSurface = Color(0xFFFFFFFF);
  static const Color colorTextPrimary = Color(0xFF0F172A);

  late Future<CommercialChecklistModel> _modelFuture;

  @override
  void initState() {
    super.initState();
    _modelFuture = _loadInspectionData();
  }

  Future<CommercialChecklistModel> _loadInspectionData() async {
    Map<String, dynamic> rawData = {};

    if (widget.targetInspectionId != null && widget.targetInspectionId!.isNotEmpty) {
      try {
        final client = Supabase.instance.client;
        final res = await client
            .from('inspections')
            .select()
            .eq('id', widget.targetInspectionId!)
            .maybeSingle();

        if (res != null) {
          rawData = Map<String, dynamic>.from(res);
        }
      } catch (e) {
        debugPrint('Error fetching inspection by ID: $e');
      }
    }

    if (rawData.isEmpty && widget.initialData != null) {
      rawData = Map<String, dynamic>.from(widget.initialData!);
    }

    Map<String, dynamic> checklistJson = {};
    if (rawData['checklist_data'] is Map<String, dynamic>) {
      checklistJson = Map<String, dynamic>.from(rawData['checklist_data']);
    }

    CommercialChecklistModel model = CommercialChecklistModel.fromJson(checklistJson);

    if (model.businessName.isEmpty) {
      model.businessName = rawData['business_name']?.toString() ?? 'Commercial Establishment';
    }
    if (model.buildingName.isEmpty) {
      model.buildingName = model.businessName;
    }
    if (model.address.isEmpty) {
      model.address = rawData['address']?.toString() ?? 'Lingayen, Pangasinan';
    }
    if (model.ioNumber.isEmpty) {
      model.ioNumber = rawData['inspection_order_no']?.toString() ?? 'IO-${DateTime.now().year}-001';
    }
    if (model.dateInspected.isEmpty) {
      final dateRaw = rawData['date_inspected'] ?? rawData['created_at'] ?? DateTime.now().toIso8601String();
      model.dateInspected = dateRaw.toString().split('T').first;
    }
    if (model.dateIssued.isEmpty) {
      final createdRaw = rawData['created_at'] ?? DateTime.now().toIso8601String();
      model.dateIssued = createdRaw.toString().split('T').first;
    }
    if (model.defectsSummary.isEmpty && rawData['defects_summary'] != null) {
      model.defectsSummary = rawData['defects_summary'].toString();
    }
    if (model.recommendationAction == null || model.recommendationAction!.isEmpty) {
      model.recommendationAction = rawData['recommendation'] ?? rawData['compliance_status'] ?? 'FSIC';
    }

    return model;
  }

  // PDF Exporter creating exact 10-page BFP Form 061 document matching Word template
  Future<void> _exportPdf(CommercialChecklistModel model) async {
    final pdf = pw.Document();

    const pdfPageFormat = PdfPageFormat.legal;
    const margin = pw.EdgeInsets.only(left: 72, right: 10, top: 40, bottom: 40);

    pw.MemoryImage? bfpLogo;
    pw.MemoryImage? dilgLogo;

    try {
      final bfpBytes = await rootBundle.load('assets/bfp_logo.png');
      bfpLogo = pw.MemoryImage(bfpBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('BFP logo load note: $e');
    }

    try {
      final dilgBytes = await rootBundle.load('assets/dilg_logo.png');
      dilgLogo = pw.MemoryImage(dilgBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('DILG logo load note: $e');
    }

    // PAGE 1 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: pdfPageFormat,
        margin: margin,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfHeader(1, dilgLogo, bfpLogo),
              _pdfSectionHeader('I. REFERENCE:'),
              _pdfUnderlineRow('Inspection Order No. (IO) :', model.ioNumber),
              _pdfUnderlineRow('Date Issued :', model.dateIssued),
              _pdfUnderlineRow('Date Inspected :', model.dateInspected),
              pw.SizedBox(height: 10),

              _pdfSectionHeader('II. NATURE OF INSPECTION CONDUCTED (Check appropriate box)'),
              _pdfCheckboxLine(model.inspectionNature == 'Construction', '1. [   ] Inspection during construction'),
              _pdfCheckboxLine(model.inspectionNature == 'PEZA', '2. [   ] FSIC for Certificate of Annual Inspection (PEZA)'),
              _pdfCheckboxLine(model.inspectionNature == 'Occupancy', '3. [   ] FSIC for Certificate for Occupancy'),
              _pdfCheckboxLine(model.inspectionNature == 'BusinessPermit' || model.inspectionNature == null, '4. [ ✓ ] FSIC for Business Permit (New/Renewal)'),
              _pdfCheckboxLine(
                model.inspectionNature == 'Verification',
                '5. [   ] Verification Inspection for Compliance:\n     [ ${model.verificationType == 'NTC' ? '✓' : ' '} ] NTC / [ ${model.verificationType == 'NTCV' ? '✓' : ' '} ] NTCV / [ ${model.verificationType == 'Abatement' ? '✓' : ' '} ] Abatement [ ${model.verificationType == 'Closure' ? '✓' : ' '} ] Closure',
              ),
              _pdfUnderlineRow('6. Others (Specify) :', model.natureOthersSpecify ?? ''),
              pw.SizedBox(height: 10),

              _pdfSectionHeader('III. REQUIREMENTS'),
              _pdfCheckboxLine(
                model.fsccrRequired != null,
                '1. [   ] FSIC for Occupancy:\n    • Fire Safety Compliance and Commissioning Report (FSCCR) (if applicable)   Yes [ ${model.fsccrRequired == 'Yes' ? '✓' : ' '} ] / No [ ${model.fsccrRequired == 'No' ? '✓' : ' '} ]',
              ),
              _pdfCheckboxLine(
                model.fsmrRequired != null,
                '2. [ ✓ ] FSIC for New / Renewal / Annual Inspection / Others:\n    • Fire Safety Maintenance Report (FSMR) (if applicable)   Yes [ ${model.fsmrRequired == 'Yes' ? '✓' : ' '} ] / No [ ${model.fsmrRequired == 'No' ? '✓' : ' '} ]',
              ),
              pw.SizedBox(height: 10),

              _pdfSectionHeader('IV. GENERAL INFORMATION'),
              _pdfUnderlineRow('Name of Building :', model.buildingName),
              _pdfUnderlineRow('Address :', model.address),
              _pdfUnderlineRow('Business Name :', model.businessName),
              _pdfUnderlineRow('Nature of Business :', model.natureOfBusiness.isNotEmpty ? model.natureOfBusiness : 'Commercial Establishment'),
              _pdfUnderlineRow('Name of owner/Representative :', model.ownerRepresentative.isNotEmpty ? model.ownerRepresentative : 'N/A'),
              _pdfUnderlineRow('Contact No. :', model.contactNo.isNotEmpty ? model.contactNo : 'N/A'),
              pw.SizedBox(height: 8),

              pw.Text('[   ] FSIC for Occupancy:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              _pdfUnderlineRow('• FSEC No. :', '${model.fsecNo}      / Date Issued : ${model.fsecDateIssued}'),
              _pdfUnderlineRow('• Building Permit :', '${model.buildingPermitNo}      / Date Issued : ${model.buildingPermitDateIssued}'),
              pw.SizedBox(height: 8),

              pw.Text('[ ✓ ] FSIC for New / Renewal / Annual Inspection / Others:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              _pdfUnderlineRow('• FSIC No. (Latest) :', '${model.fsicNoLatest}      / Date Issued : ${model.fsicDateIssued}'),
              _pdfUnderlineRow('• Certificate of Fire Drill :', '${model.fireDrillCertNo}      / Date Issued : ${model.fireDrillDateIssued}'),
              _pdfUnderlineRow('• Business Permit No. :', '${model.businessPermitNo}      / Date Issued : ${model.businessPermitDateIssued}'),
              _pdfUnderlineRow('• Fire Insurance Policy No. (If any) :', '${model.fireInsurancePolicyNo}      / Date Issued : ${model.fireInsuranceDateIssued}'),
            ],
          );
        },
      ),
    );

    // PAGE 2 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: pdfPageFormat,
        margin: margin,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfHeader(2, dilgLogo, bfpLogo),
              _pdfSectionHeader('CONSTRUCTION TYPE'),
              _pdfCheckboxLine(model.constructionType == 'Type I' || model.constructionType == null, '[ ✓ ] Type I : Concrete & Steel (Fire Resistive)'),
              _pdfCheckboxLine(model.constructionType == 'Type II', '[   ] Type II : Concrete & Exposed Steel (Noncombustible)'),
              _pdfCheckboxLine(model.constructionType == 'Type III', '[   ] Type III : Concrete & Wood (Ordinary)'),
              _pdfCheckboxLine(model.constructionType == 'Type IV', '[   ] Type IV : Heavy Timber (Large mass wood)'),
              _pdfCheckboxLine(model.constructionType == 'Type V', '[   ] Type V : Wood frame (Lightweight wood)'),
              pw.SizedBox(height: 8),

              _pdfSectionHeader('WALLS / CEILING INTERIOR FINISH'),
              _pdfCheckboxLine(model.interiorFinishWalls == 'Class A' || model.interiorFinishWalls == null, '[ ✓ ] Class A : Flame spread index, 0–25; smoke developed index, 0–450'),
              _pdfCheckboxLine(model.interiorFinishWalls == 'Class B', '[   ] Class B : Flame spread index, 26–75; smoke developed index, 0–450'),
              _pdfCheckboxLine(model.interiorFinishWalls == 'Class C', '[   ] Class C : Flame spread index, 76–200; smoke developed index, 0–450'),
              pw.Text('(Note: Flame Spread Index can be seen in the technical specification of the product)', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
              pw.SizedBox(height: 10),

              _pdfSectionHeader('FLOOR INTERIOR FINISH'),
              _pdfCheckboxLine(model.interiorFinishFloor == 'Class I' || model.interiorFinishFloor == null, '[ ✓ ] Class I : Critical radiant flux, not less than 0.45 W/cm2.'),
              _pdfCheckboxLine(model.interiorFinishFloor == 'Class II', '[   ] Class II : Critical radiant flux, not more than 0.22 W/cm2, but less than 0.45 W/cm2'),
              pw.Text('(Note: Flame Spread Index can be seen in the technical specification of the product)', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
              pw.SizedBox(height: 10),

              _pdfSectionHeader('SECTIONAL OCCUPANCY (INDICATE SPECIFIC USAGE OF EACH FLOOR, PART OR PORTION OF THE BUILDING)'),
              _pdfUnderlineRow('Basement :', model.basementUsage),
              _pdfUnderlineRow('Ground floor :', model.groundFloorUsage.isNotEmpty ? model.groundFloorUsage : 'Commercial Retail / Main Entrance'),
              _pdfUnderlineRow('Second floor :', model.secondFloorUsage),
              _pdfUnderlineRow('Third floor :', model.thirdFloorUsage),
              _pdfUnderlineRow('Fourth Floor :', model.fourthFloorUsage),
              _pdfUnderlineRow('Nth Floor :', model.nthFloorUsage),
              pw.Text('Use separate sheet if necessary', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
              pw.SizedBox(height: 10),

              _pdfSectionHeader('GENERAL OCCUPANCY CLASSIFICATION'),
              _pdfCheckboxLine(model.occupancyClassification == 'Assembly', '[   ] Assembly / [   ] Educational / [   ] Day Care / [   ] Health Care'),
              _pdfCheckboxLine(model.occupancyClassification == 'Residential', '[   ] Detention and Correctional / [   ] Residential / [   ] Residential Board and Care'),
              _pdfCheckboxLine(model.occupancyClassification == 'Mercantile' || model.occupancyClassification == null, '[ ✓ ] Mercantile / [   ] Business / [   ] Industrial / [   ] Storage / [   ] Special Structure.'),
              pw.SizedBox(height: 10),

              _pdfSectionHeader('OTHER INFORMATION'),
              _pdfUnderlineRow('Maximum Occupant Load :', '${model.occupantLoad.isNotEmpty ? model.occupantLoad : '50'} P/Floor'),
              _pdfUnderlineRow('Number of Stories :', '${model.numberOfStories.isNotEmpty ? model.numberOfStories : '2'} Storey'),
              _pdfUnderlineRow('Building Height :', '${model.buildingHeight.isNotEmpty ? model.buildingHeight : '6'} m'),
              _pdfUnderlineRow('Highrise :', 'Highrise: [   ] Yes / [ ✓ ] No'),
            ],
          );
        },
      ),
    );

    // PAGE 3 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: pdfPageFormat,
        margin: margin,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfHeader(3, dilgLogo, bfpLogo),
              _pdfSectionHeader('V. MEANS OF EGRESS'),
              pw.Text('A. EXIT ACCESS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('[ ] Doors  /  [ ] Corridors  /  [ ] Hallways  /  [ ] Passageways  /  [ ] Anterooms  /  [ ] Ramps', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 8),

              _pdfEgressHorizontalTable(model),
              pw.SizedBox(height: 10),

              _pdfEgressRequirementsTable(model),
              pw.SizedBox(height: 10),

              pw.Text('B. EXITS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('[ ] Normal Stairs  /  [ ] Curved Stairs  /  [ ] Spiral Stairs  /  [ ] Winding Stairs', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('[ ] Horizontal Exits  /  [ ] Outside Stairs / Exit Passageways / Fire Escape Stairs', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('[ ] Fire Escape Ladder (for 1 & 2 family dwelling only)', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('[ ] Slide Escape (for Industrial Occupancy Only)', style: const pw.TextStyle(fontSize: 10)),
            ],
          );
        },
      ),
    );

    // PAGE 4 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: pdfPageFormat,
        margin: margin,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfHeader(4, dilgLogo, bfpLogo),
              _pdfSectionHeader('EXITS COMPONENTS CLEAR WIDTH TABLE'),
              _pdfExitsComponentsTable(model),
              pw.SizedBox(height: 10),

              _pdfSectionHeader('EXITS SPECIFICATIONS & STAIR REQUIREMENTS'),
              _pdfStairsSpecificationsTable(model),
            ],
          );
        },
      ),
    );

    // PAGE 5 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: pdfPageFormat,
        margin: margin,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfHeader(5, dilgLogo, bfpLogo),
              _pdfSectionHeader('C. EXITS DISCHARGE'),
              _pdfExitsDischargeTable(model),
              pw.SizedBox(height: 10),

              _pdfSectionHeader('VI. SIGNS, LIGHTING, AND EXITS SIGNAGE'),
              pw.Text('A. MARKING OF MEANS OF EGRESS (EXIT)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              _pdfExitMarkingTable(model),
              pw.SizedBox(height: 10),

              pw.Text('B. MARKING OF MEANS OF EGRESS (EMERGENCY EVACUATION PLAN)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              _pdfEvacuationPlanTable(model),
            ],
          );
        },
      ),
    );

    // PAGE 6 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: pdfPageFormat,
        margin: margin,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfHeader(6, dilgLogo, bfpLogo),
              _pdfSectionHeader('EMERGENCY EVACUATION PLAN SIZES'),
              _pdfEvacuationPlanSizesTable(model),
              pw.SizedBox(height: 10),

              _pdfSectionHeader('C. ILLUMINATION OF MEANS OF EGRESS (All Data Below Shall be Referred from Manufacturers Specifications)'),
              _pdfIlluminationTable(model),
            ],
          );
        },
      ),
    );

    // PAGE 7 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: pdfPageFormat,
        margin: margin,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfHeader(7, dilgLogo, bfpLogo),
              _pdfSectionHeader('VII. HAZARD'),
              _pdfUnderlineRow('Hazard Contents :', 'None / Low Combustible'),
              _pdfUnderlineRow('Quantity (Vol. / Weight) :', 'Standard Commercial Storage'),
              _pdfUnderlineRow('Hazard Identification Placard :', 'Posted / Compliant   Within MAQ: [ ✓ ] Yes / [   ] No'),
              _pdfUnderlineRow('Hazard Identification No. :', 'N/A   Hazard Classification: [ ✓ ] Low / [   ] Ordinary / [   ] High'),
              _pdfUnderlineRow('Class :', 'Class A   Flash Point: N/A'),
              pw.SizedBox(height: 8),
              pw.Text('Low hazard contents shall be classified as those of such low combustibility that no self-propagating fire therein can occur.', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
              pw.Text('Ordinary hazard contents shall be classified as those that are likely to burn with moderate rapidity or to give off a considerable volume of smoke.', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
              pw.Text('High hazard contents shall be classified as those that are likely to burn with extreme rapidity or from which explosions are likely.', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
              pw.SizedBox(height: 10),

              _pdfSectionHeader('A. OTHER FLAMMABLE LIQUIDS (I.E. ALCOHOL, ETHER, ETC…)'),
              _pdfHazardTableA(model),
              pw.SizedBox(height: 10),

              _pdfSectionHeader('B. MISCELLANEOUS HAZARDS (MECHANICAL EQUIPMENT ROOM, STORAGE, SUPPLY ROOM)'),
              _pdfHazardTableB(model),
              pw.SizedBox(height: 10),

              _pdfSectionHeader('C. HOUSEKEEPING, MAINTENANCE, STORAGE & WASTE DISPOSAL'),
              _pdfHazardTableC(model),
            ],
          );
        },
      ),
    );

    // PAGE 8 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: pdfPageFormat,
        margin: margin,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfHeader(8, dilgLogo, bfpLogo),
              _pdfSectionHeader('VIII. FIRE PROTECTION'),
              pw.Text('A. Automatic Fire Suppression System (Sprinkler)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              _pdfFireProtectionTableA(model),
              pw.SizedBox(height: 8),

              pw.Text('B. Wet Standpipe/Fire Hose Cabinet', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              _pdfFireProtectionTableB(model),
              pw.SizedBox(height: 8),

              pw.Text('C. Fire Pump', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              _pdfFireProtectionTableC(model),
              pw.SizedBox(height: 8),

              pw.Text('D. Fire Detection System', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              _pdfFireProtectionTableD(model),
              pw.SizedBox(height: 8),

              pw.Text('E. Fire Alarm Facilities', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              _pdfFireProtectionTableE(model),
              pw.SizedBox(height: 8),

              pw.Text('F. Lifts (Elevator)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              _pdfFireProtectionTableF(model),
            ],
          );
        },
      ),
    );

    // PAGE 9 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: pdfPageFormat,
        margin: margin,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfHeader(9, dilgLogo, bfpLogo),
              pw.Text('G. First Aid Fire Protection (Fire Extinguishers)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              _pdfFireProtectionTableG(model),
              pw.SizedBox(height: 8),

              pw.Text('H. Emergency Lighting Systems', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              _pdfFireProtectionTableH(model),
              pw.SizedBox(height: 8),

              pw.Text('I. Kitchen', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              _pdfFireProtectionTableI(model),
              pw.SizedBox(height: 8),

              _pdfSectionHeader('J. BUILDING SERVICE EQUIPMENT'),
              _pdfBuildingServiceEquipmentTable(model),
            ],
          );
        },
      ),
    );

    // PAGE 10 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: pdfPageFormat,
        margin: margin,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfHeader(10, dilgLogo, bfpLogo),
              _pdfSectionHeader('K. FIRE WALL (FW) (if required)'),
              _pdfFireWallTable(model),
              pw.SizedBox(height: 8),

              _pdfSectionHeader('DEFECTS/DEFICIENCIES (Attached pictures, sketch and others)'),
              _pdfUnderlineRow('ITEM IV :', ''),
              _pdfUnderlineRow('ITEM V :', ''),
              _pdfUnderlineRow('ITEM VI :', ''),
              _pdfUnderlineRow('ITEM VII :', ''),
              _pdfUnderlineRow('ITEM VIII :', model.defectsSummary.isNotEmpty ? model.defectsSummary : 'No defects noted during fire safety inspection.'),
              pw.SizedBox(height: 10),

              _pdfSectionHeader('IX. RECOMMENDATIONS'),
              _pdfCheckboxLine(
                model.recommendationAction?.toUpperCase().contains('FSIC') ?? true,
                '[ ✓ ] Comply the following DEFECTS/DEFICIENCIES stated above and pay the corresponding Fire Code Fees including the Storage Clearance Fee, Conveyance Clearance Fee before the issuance of Fire Safety Inspection Certificate (FSIC)',
              ),
              _pdfCheckboxLine(
                model.recommendationAction?.toUpperCase().contains('NTC') ?? false,
                '[   ] For issuance of      [   ] Notice to Comply',
              ),
              _pdfCheckboxLine(
                model.recommendationAction?.toUpperCase().contains('NTCV') ?? false,
                '                                    [   ] Notice to Correct Violation',
              ),
              _pdfCheckboxLine(
                model.recommendationAction?.toUpperCase().contains('CLOSURE') ?? false,
                '                                    [   ] Closure Order',
              ),
              _pdfCheckboxLine(false, '                                    [   ] Abatement Order with Administrative Fine'),
              _pdfCheckboxLine(false, '                                    [   ] Closure Order for the non-payment of Administrative Fine'),
              _pdfCheckboxLine(false, '                                    [   ] Notice of Disapproval (NOD)'),
              pw.SizedBox(height: 14),

              _pdfSectionHeader('ACKNOWLEDGED BY:'),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfSignatoryColumn('Signature Over Printed Name of\nOwner/ Representative', model.ownerRepresentative.isNotEmpty ? model.ownerRepresentative : 'N/A'),
                  _pdfSignatoryColumn('Fire Safety Inspector/s', model.inspectorName.isNotEmpty ? model.inspectorName : 'BFP Fire Inspector'),
                  _pdfSignatoryColumn('Team Leader', model.teamLeaderName.isNotEmpty ? model.teamLeaderName : 'Inspector Team Leader'),
                ],
              ),
              pw.SizedBox(height: 6),
              _pdfUnderlineRow('Date & Time :', '${model.dateInspected} 10:00 AM'),
              pw.SizedBox(height: 12),

              pw.Center(child: pw.Text('RECOMMEND APPROVAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.SizedBox(height: 10),
              pw.Center(child: _pdfSignatoryColumn('CHIEF, FIRE SAFETY ENFORCEMENT SECTION/UNIT', model.fireMarshalName.isNotEmpty ? model.fireMarshalName : 'Chief FSED')),
              pw.SizedBox(height: 12),

              pw.Center(child: pw.Text('APPROVAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.SizedBox(height: 10),
              pw.Center(child: _pdfSignatoryColumn('CITY/ MUNICIPAL FIRE MARSHAL', 'CINSP BFP Fire Marshal')),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'BFP_Form_061_${model.ioNumber}.pdf',
    );
  }

  // Official PDF Header with DILG & BFP Logos
  pw.Widget _pdfHeader(int pageNum, pw.MemoryImage? dilgLogo, pw.MemoryImage? bfpLogo) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (dilgLogo != null)
              pw.Container(
                width: 55,
                height: 55,
                child: pw.Image(dilgLogo, fit: pw.BoxFit.contain),
              )
            else
              pw.SizedBox(width: 55, height: 55),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Republic of the Philippines',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'Department of the Interior and Local Government',
                    style: const pw.TextStyle(fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'BUREAU OF FIRE PROTECTION',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF0F172A),
                      letterSpacing: 0.5,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    '(LINGAYEN FIRE STATION - PANGASINAN)',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFFC2410C),
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
            if (bfpLogo != null)
              pw.Container(
                width: 55,
                height: 55,
                child: pw.Image(bfpLogo, fit: pw.BoxFit.contain),
              )
            else
              pw.SizedBox(width: 55, height: 55),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Divider(thickness: 0.5, color: PdfColors.grey700),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('BFP-QSF-FSED-061 Rev. ØØ (06.17.22)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.Text('Page $pageNum of 10', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(
            'FIRE SAFETY INSPECTION CHECKLIST',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  pw.Widget _pdfSectionHeader(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 4, bottom: 3),
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: PdfColors.grey300,
      width: double.infinity,
      child: pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _pdfUnderlineRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 200, child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
              padding: const pw.EdgeInsets.only(bottom: 1),
              child: pw.Text(value.isNotEmpty ? value : '__________________________________________________', style: const pw.TextStyle(fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfCheckboxLine(bool isChecked, String label) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  pw.Widget _pdfSignatoryColumn(String title, String name) {
    return pw.Column(
      children: [
        pw.Container(width: 160, child: pw.Divider(thickness: 0.5)),
        pw.Text(name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text(title, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
      ],
    );
  }

  // Tables for PDF Pages 3 - 9
  pw.Widget _pdfEgressHorizontalTable(CommercialChecklistModel model) {
    const items = ['Doors', 'Corridors / Hallways', 'Passageways', 'Lobby / Anteroom', 'Ramps', 'Common path of travel', 'Dead end', 'Travel distance'];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(1), 4: pw.FlexColumnWidth(3)},
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeaderCell('Horizontal components'),
            _tableHeaderCell('Actual Dimensions'),
            _tableHeaderCell('Passed'),
            _tableHeaderCell('Failed'),
            _tableHeaderCell('Remarks / Corrective Action'),
          ],
        ),
        ...items.map((item) {
          final st = model.egressAccessStatus[item] ?? 'Passed';
          final isPass = st.toLowerCase() != 'failed';
          final dim = model.itemDimensions[item] ?? '1.2m';
          return pw.TableRow(
            children: [
              _tableCell(item),
              _tableCell('$dim m'),
              _tableCell(isPass ? '[ ✓ ]' : '[   ]'),
              _tableCell(!isPass ? '[ ✓ ]' : '[   ]'),
              _tableCell(isPass ? 'Compliant' : 'Needs clearance'),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _pdfEgressRequirementsTable(CommercialChecklistModel model) {
    const rows = [
      'Any door leaf in a means of egress shall leave not less than one-half of the required width of an aisle, a corridor, a passageway, or a landing unobstructed.',
      'Any door leaf in a means of egress shall not project more than 180 mm into the required width of an aisle, a corridor, a passageway, or a landing, unless the door leaf is equipped with an approved self-closing device.',
      'At least two (2) means of egress for each room with occupant load ≥ 50 or with hazard content.',
      'Each guest door used as means of egress shall at least 20 minutes fire resistant.',
      'Doors that open directly onto exit access corridors shall be self-closing and self-latching.',
      'There shall no openings in corridor partitions other than door openings.',
      'Free from any obstruction.',
      'No flammable material stored.',
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: const {0: pw.FlexColumnWidth(6), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(1)},
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeaderCell('Requirement Description'),
            _tableHeaderCell('Actual Dim.'),
            _tableHeaderCell('Passed'),
            _tableHeaderCell('Failed'),
          ],
        ),
        ...rows.map((r) => pw.TableRow(
              children: [
                _tableCell(r),
                _tableCell('Standard'),
                _tableCell('[ ✓ ]'),
                _tableCell('[   ]'),
              ],
            )),
      ],
    );
  }

  pw.Widget _pdfExitsComponentsTable(CommercialChecklistModel model) {
    const components = ['Exits Doors', 'Normal Stairs', 'Curve stairs', 'Winding Stairs', 'Horizontal Exits', 'Outside Stairs', 'Exit Passageways', 'Fire Escape Stairs', 'Fire Escape Ladders', 'Slide Escape'];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(1), 4: pw.FlexColumnWidth(3)},
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeaderCell('Components'),
            _tableHeaderCell('Clear Width'),
            _tableHeaderCell('Passed'),
            _tableHeaderCell('Failed'),
            _tableHeaderCell('Remarks / Corrective Action'),
          ],
        ),
        ...components.map((c) => pw.TableRow(
              children: [
                _tableCell(c),
                _tableCell('1.10 m'),
                _tableCell('[ ✓ ]'),
                _tableCell('[   ]'),
                _tableCell('Compliant'),
              ],
            )),
      ],
    );
  }

  pw.Widget _pdfStairsSpecificationsTable(CommercialChecklistModel model) {
    const specs = [
      'At least two (2) means of egress for each floor.',
      'Doors assembly: 60 minutes fire resistant for three (3) communicating level and below.',
      'Doors assembly: 90 minutes fire resistant for four (4) communicating level and above.',
      'Exits Doors provided with Re-entry mechanism at every four (4) storey.',
      'Stair thread: Minimum depth = 280 mm.',
      'Stair riser: Minimum / Maximum height = 100 mm / 180 mm.',
      'Minimum stair head room: 2000mm',
      'Stair provided with Guard and Handrails.',
      'Maximum handrails projections: 114 mm.',
      'Stair landing shall not be less than the required width of exit door.',
      'Exits doors open and close properly',
      'Doors swing in direction of egress.',
      'Exit Doors provided with panic hardware, vision panel, and self-closing mechanism.',
      'There shall be no enclosed usable space under the stairs in an exit enclosure nor shall the open space under such stairs be used for any purpose.',
      'Interior finish: Class B',
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: const {0: pw.FlexColumnWidth(6), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(1)},
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeaderCell('Requirement / Specification'),
            _tableHeaderCell('Actual Dim.'),
            _tableHeaderCell('Passed'),
            _tableHeaderCell('Failed'),
          ],
        ),
        ...specs.map((s) => pw.TableRow(
              children: [
                _tableCell(s),
                _tableCell('Compliant'),
                _tableCell('[ ✓ ]'),
                _tableCell('[   ]'),
              ],
            )),
      ],
    );
  }

  pw.Widget _pdfExitsDischargeTable(CommercialChecklistModel model) {
    const items = [
      'Remoteness of exit discharge not less than ½ of length of the overall dimension of the building or area to be served.',
      'Remoteness of exit discharge not less than 1/3 of length of the overall dimension of the building or area to be served is the bldg. is protected throughout by ASASS.',
      'Exterior grounds are kept clear of objects that might impede evacuation or firefighting equipment',
      'Terminate directly at a public way or at an exterior exit discharge.',
    ];
    return _pdfSimpleChecklistTable(items);
  }

  pw.Widget _pdfExitMarkingTable(CommercialChecklistModel model) {
    const items = [
      'Minimum letter height, 150 mm',
      'EXIT signs are posted along Exit access, Exits and Exit discharge',
      'EXIT signs are properly illuminated',
    ];
    return _pdfSimpleChecklistTable(items);
  }

  pw.Widget _pdfEvacuationPlanTable(CommercialChecklistModel model) {
    const items = [
      'Posted on strategic and conspicuous location inside the building',
      'Drawn with a photo-luminescent background to be readable in case of power failure.',
      'Containing basic emergency information (Fire Exits, Routes, Extinguishers, Alarms, Call Stations)',
    ];
    return _pdfSimpleChecklistTable(items);
  }

  pw.Widget _pdfEvacuationPlanSizesTable(CommercialChecklistModel model) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: const {0: pw.FlexColumnWidth(6), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(1)},
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [_tableHeaderCell('Plan Size Requirement'), _tableHeaderCell('Actual Dim.'), _tableHeaderCell('Passed'), _tableHeaderCell('Failed')],
        ),
        pw.TableRow(children: [_tableCell('[ ✓ ] Size 330.2 mm wide * 215.9 mm height (Floor area < 50 m²) • Room or spaces'), _tableCell('Compliant'), _tableCell('[ ✓ ]'), _tableCell('[   ]')]),
        pw.TableRow(children: [_tableCell('[   ] Size 609.6 mm wide * 457.2 mm height (Floor area = 50 – 150 m²) • Lobbies/Hallways'), _tableCell('N/A'), _tableCell('[   ]'), _tableCell('[   ]')]),
        pw.TableRow(children: [_tableCell('[   ] Size 609.6 mm wide * 457.2 mm height (Floor area ≥ 151m²) • Auditorium/Gym'), _tableCell('N/A'), _tableCell('[   ]'), _tableCell('[   ]')]),
      ],
    );
  }

  pw.Widget _pdfIlluminationTable(CommercialChecklistModel model) {
    const items = [
      'Floors and other walking surfaces: shall be at least 1 ft-candle (10.8 lux), measured at the floor.',
      'In assembly occupancies: walking surfaces of exit access shall be at least 0.2 ft-candle (2.2 lux)',
      'Stairs: shall be at least 10 ft-candle (108 lux), measured at the walking surfaces.',
      'Emergency Lighting: Illumination average 1 ft-candle (10.8 lux), minimum 0.1 ft-candle (1.1 lux)',
      'Emergency lighting system arranged automatically upon power failure for at least 1.5-hour.',
      'Periodic Testing of Emergency Lighting Equipment (Written record)',
    ];
    return _pdfSimpleChecklistTable(items);
  }

  pw.Widget _pdfHazardTableA(CommercialChecklistModel model) {
    const items = ['Stored in sealed metal containers', 'Properly dispensed as per SOP', 'Provided with "NO SMOKING" sign.'];
    return _pdfSimpleChecklistTable(items);
  }

  pw.Widget _pdfHazardTableB(CommercialChecklistModel model) {
    const items = ['All no smoking areas has adequate signs.', 'Gasoline/ Diesel is stored in the proper place and in a metal safety can.'];
    return _pdfSimpleChecklistTable(items);
  }

  pw.Widget _pdfHazardTableC(CommercialChecklistModel model) {
    const items = [
      'Brooms, mops, rags and other cleaning supplies stored in metal cabinets or approved cans',
      'Paints, solvents and other flammables stored in metal cabinet: oily rags in metal containers',
      'Dry leaves, shrubbery trimmings and other combustibles kept away from buildings',
    ];
    return _pdfSimpleChecklistTable(items);
  }

  pw.Widget _pdfFireProtectionTableA(CommercialChecklistModel model) {
    const items = [
      ['Sprinkler Pumps', 'Check automatic start and pressure.'],
      ['Sprinkler Valves', 'Valves locked in open position, no leaks or corrosion.'],
      ['Sprinkler water flow alarm', 'Open test valve and ensure manual bell & pump start.'],
    ];
    return _pdfTwoColChecklistTable(items);
  }

  pw.Widget _pdfFireProtectionTableB(CommercialChecklistModel model) {
    const items = [
      ['Cabinet Door Operative', 'Check door is unobstructed and opens properly.'],
      ['Hose Condition', 'Check hose is not rotted, wet, or moldy.'],
      ['Nozzle', 'Check nozzle is in place and operates correctly.'],
      ['Hose hung properly', 'Check hose is hung properly for easy un-rolling.'],
      ['Valves and valve handles', 'Check handles in place and valves operate properly.'],
    ];
    return _pdfTwoColChecklistTable(items);
  }

  pw.Widget _pdfFireProtectionTableC(CommercialChecklistModel model) {
    const items = [
      ['Pump System', 'Inspect accuracy of pressure gauges and sensors'],
      ['Pipings', 'Check pipings if there is leak'],
      ['Motor', 'Check unusual noise or vibrations'],
      ['Electrical System', 'Check PCBs, cable insulation, and water leaks'],
    ];
    return _pdfTwoColChecklistTable(items);
  }

  pw.Widget _pdfFireProtectionTableD(CommercialChecklistModel model) {
    const items = [
      ['Fire Detection System', 'Random Test of call points and smoke detectors.'],
    ];
    return _pdfTwoColChecklistTable(items);
  }

  pw.Widget _pdfFireProtectionTableE(CommercialChecklistModel model) {
    const items = [
      ['Location Signs', 'Check all signs are in place and legible.'],
      ['Alarm Panels', 'Check all alarm panels function correctly.'],
    ];
    return _pdfTwoColChecklistTable(items);
  }

  pw.Widget _pdfFireProtectionTableF(CommercialChecklistModel model) {
    const items = [
      ['Lifts', 'All lifts home to ground floor during fire test.'],
      ['Fans', 'All lift fans operate correctly.'],
      ['Fireman\'s lift', 'Fireman\'s lift key operated during fire test.'],
    ];
    return _pdfTwoColChecklistTable(items);
  }

  pw.Widget _pdfFireProtectionTableG(CommercialChecklistModel model) {
    const items = [
      ['Fire Extinguisher Size', 'Minimal sizes based on table 7 & 8 of RIRR RA 9514.'],
      ['Minimum number of Extinguisher', 'Sufficient number based on table 7 & 8.'],
      ['Location', 'All extinguishers in proper location.'],
      ['Seals & Tags', 'Seals/tags intact, serviced in last 12 months.'],
      ['Markings', 'Proper marking to indicate fire type.'],
      ['Condition', 'No leaks, corrosion or defects noticed.'],
      ['Pressure', 'Pressure gauge reads in green area.'],
    ];
    return _pdfTwoColChecklistTable(items);
  }

  pw.Widget _pdfFireProtectionTableH(CommercialChecklistModel model) {
    const items = [
      ['Battery Lights', 'All battery powered lights turn on upon power removal.'],
    ];
    return _pdfTwoColChecklistTable(items);
  }

  pw.Widget _pdfFireProtectionTableI(CommercialChecklistModel model) {
    const items = [
      ['Hoods & Vents', 'Hoods, vents, fans free from grease.'],
      ['Hood Filters', 'Cleaned regularly per schedule.'],
    ];
    return _pdfTwoColChecklistTable(items);
  }

  pw.Widget _pdfBuildingServiceEquipmentTable(CommercialChecklistModel model) {
    const items = [
      '1. Utilities: Cooking equipment protected by AKHFSS (Occupant Load > 50p)',
      '2. Heating, Ventilating and Air-conditioning: Design & Installation per PMEC',
      '3. Smoke Control Systems/Smoke Management provided in high-rise / atrium facilities',
      '4. Rubbish Chutes, Laundry Chutes, and Flue-Fed Incinerators enclosed',
    ];
    return _pdfSimpleChecklistTable(items);
  }

  pw.Widget _pdfFireWallTable(CommercialChecklistModel model) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: const {0: pw.FlexColumnWidth(6), 1: pw.FlexColumnWidth(4)},
      children: [
        pw.TableRow(children: [_tableCell('Provided with Fire Wall (minimum 2 hours fire resistance)'), _tableCell('[ ✓ ] Yes / [   ] No')]),
        pw.TableRow(children: [_tableCell('FW extension above roof surface not less than 760mm'), _tableCell('[ ✓ ] Yes / [   ] No')]),
        pw.TableRow(children: [_tableCell('Wall type: [ ✓ ] 125mm Solid Concrete / [   ] 150mm Solid Masonry / [   ] 200mm Hallow Unit'), _tableCell('Compliant')]),
      ],
    );
  }

  pw.Widget _pdfSimpleChecklistTable(List<String> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: const {0: pw.FlexColumnWidth(7), 1: pw.FlexColumnWidth(1.5), 2: pw.FlexColumnWidth(1.5)},
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [_tableHeaderCell('Requirement Item'), _tableHeaderCell('Passed'), _tableHeaderCell('Failed')],
        ),
        ...items.map((item) => pw.TableRow(
              children: [_tableCell(item), _tableCell('[ ✓ ]'), _tableCell('[   ]')],
            )),
      ],
    );
  }

  pw.Widget _pdfTwoColChecklistTable(List<List<String>> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(5), 2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(1)},
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [_tableHeaderCell('Item to Inspect'), _tableHeaderCell('Procedure How to Inspect'), _tableHeaderCell('Passed'), _tableHeaderCell('Failed')],
        ),
        ...items.map((row) => pw.TableRow(
              children: [_tableCell(row[0]), _tableCell(row[1]), _tableCell('[ ✓ ]'), _tableCell('[   ]')],
            )),
      ],
    );
  }

  pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.94,
          maxWidth: 820,
        ),
        decoration: BoxDecoration(
          color: colorSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FutureBuilder<CommercialChecklistModel>(
          future: _modelFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 300,
                child: Center(
                  child: CircularProgressIndicator(color: colorAccent),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 44, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Failed to load inspection record: ${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            }

            final model = snapshot.data!;

            return Column(
              children: [
                // Clean Responsive Dialog Top Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: colorPrimary,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorAccent.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.description_outlined, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'BFP Form 061',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Official Checklist • IO: ${model.ioNumber}',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: () => _exportPdf(model),
                        icon: const Icon(Icons.print_outlined, size: 14, color: Colors.white),
                        label: const Text(
                          'Export PDF',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Dialog Paper Sheet Preview: Page 1 Only
                Expanded(
                  child: Container(
                    color: const Color(0xFFF1F5F9),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 760),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFormHeader(),
                              const SizedBox(height: 14),

                              _buildFormSectionTitle('I. REFERENCE:'),
                              _buildFormLine('Inspection Order No. (IO) :', model.ioNumber),
                              _buildFormLine('Date Issued :', model.dateIssued),
                              _buildFormLine('Date Inspected :', model.dateInspected),
                              const SizedBox(height: 12),

                              _buildFormSectionTitle('II. NATURE OF INSPECTION CONDUCTED (Check appropriate box)'),
                              _buildFormCheckbox(model.inspectionNature == 'Construction', '1. [   ] Inspection during construction'),
                              _buildFormCheckbox(model.inspectionNature == 'PEZA', '2. [   ] FSIC for Certificate of Annual Inspection (PEZA)'),
                              _buildFormCheckbox(model.inspectionNature == 'Occupancy', '3. [   ] FSIC for Certificate for Occupancy'),
                              _buildFormCheckbox(model.inspectionNature == 'BusinessPermit' || model.inspectionNature == null, '4. [ ✓ ] FSIC for Business Permit (New/Renewal)'),
                              _buildFormCheckbox(
                                model.inspectionNature == 'Verification',
                                '5. [   ] Verification Inspection for Compliance: [ ${model.verificationType == 'NTC' ? '✓' : ' '} ] NTC / [ ${model.verificationType == 'NTCV' ? '✓' : ' '} ] NTCV / [ ${model.verificationType == 'Abatement' ? '✓' : ' '} ] Abatement / [ ${model.verificationType == 'Closure' ? '✓' : ' '} ] Closure',
                              ),
                              _buildFormLine('6. Others (Specify) :', model.natureOthersSpecify ?? ''),
                              const SizedBox(height: 12),

                              _buildFormSectionTitle('III. REQUIREMENTS'),
                              _buildFormCheckbox(
                                model.fsccrRequired != null,
                                '1. [   ] FSIC for Occupancy: Fire Safety Compliance & Commissioning Report (FSCCR)   Yes [ ${model.fsccrRequired == 'Yes' ? '✓' : ' '} ] / No [ ${model.fsccrRequired == 'No' ? '✓' : ' '} ]',
                              ),
                              _buildFormCheckbox(
                                model.fsmrRequired != null,
                                '2. [ ✓ ] FSIC for New / Renewal / Annual Inspection: Fire Safety Maintenance Report (FSMR)   Yes [ ${model.fsmrRequired == 'Yes' ? '✓' : ' '} ] / No [ ${model.fsmrRequired == 'No' ? '✓' : ' '} ]',
                              ),
                              const SizedBox(height: 12),

                              _buildFormSectionTitle('IV. GENERAL INFORMATION'),
                              _buildFormLine('Name of Building :', model.buildingName),
                              _buildFormLine('Address :', model.address),
                              _buildFormLine('Business Name :', model.businessName),
                              _buildFormLine('Nature of Business :', model.natureOfBusiness.isNotEmpty ? model.natureOfBusiness : 'Commercial Establishment'),
                              _buildFormLine('Name of owner/Representative :', model.ownerRepresentative.isNotEmpty ? model.ownerRepresentative : 'N/A'),
                              _buildFormLine('Contact No. :', model.contactNo.isNotEmpty ? model.contactNo : 'N/A'),
                              const SizedBox(height: 8),

                              const Text('[   ] FSIC for Occupancy:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colorTextPrimary)),
                              _buildFormLine('• FSEC No. :', '${model.fsecNo}      / Date Issued : ${model.fsecDateIssued}'),
                              _buildFormLine('• Building Permit :', '${model.buildingPermitNo}      / Date Issued : ${model.buildingPermitDateIssued}'),
                              const SizedBox(height: 8),

                              const Text('[ ✓ ] FSIC for New / Renewal / Annual Inspection / Others:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colorTextPrimary)),
                              _buildFormLine('• FSIC No. (Latest) :', '${model.fsicNoLatest}      / Date Issued : ${model.fsicDateIssued}'),
                              _buildFormLine('• Certificate of Fire Drill :', '${model.fireDrillCertNo}      / Date Issued : ${model.fireDrillDateIssued}'),
                              _buildFormLine('• Business Permit No. :', '${model.businessPermitNo}      / Date Issued : ${model.businessPermitDateIssued}'),
                              _buildFormLine('• Fire Insurance Policy No. (If any) :', '${model.fireInsurancePolicyNo}      / Date Issued : ${model.fireInsuranceDateIssued}'),
                              const SizedBox(height: 12),

                              _buildFormSectionTitle('CONSTRUCTION TYPE'),
                              _buildFormCheckbox(model.constructionType == 'Type I' || model.constructionType == null, '[ ✓ ] Type I : Concrete & Steel (Fire Resistive)'),
                              _buildFormCheckbox(model.constructionType == 'Type II', '[   ] Type II : Concrete & Exposed Steel (Noncombustible)'),
                              _buildFormCheckbox(model.constructionType == 'Type III', '[   ] Type III : Concrete & Wood (Ordinary)'),
                              _buildFormCheckbox(model.constructionType == 'Type IV', '[   ] Type IV : Heavy Timber (Large mass wood)'),
                              _buildFormCheckbox(model.constructionType == 'Type V', '[   ] Type V : Wood frame (Lightweight wood)'),
                              const SizedBox(height: 10),

                              _buildFormSectionTitle('GENERAL OCCUPANCY CLASSIFICATION'),
                              _buildFormCheckbox(model.occupancyClassification == 'Mercantile' || model.occupancyClassification == null, '[ ✓ ] Mercantile / [   ] Business / [   ] Industrial / [   ] Storage'),
                              _buildFormCheckbox(model.occupancyClassification == 'Assembly', '[   ] Assembly / [   ] Educational / [   ] Day Care / [   ] Health Care'),
                              const SizedBox(height: 10),

                              _buildFormSectionTitle('OTHER INFORMATION'),
                              _buildFormLine('Maximum Occupant Load :', '${model.occupantLoad.isNotEmpty ? model.occupantLoad : '50'} P/Floor'),
                              _buildFormLine('Number of Stories :', '${model.numberOfStories.isNotEmpty ? model.numberOfStories : '2'} Storey'),
                              _buildFormLine('Building Height :', '${model.buildingHeight.isNotEmpty ? model.buildingHeight : '6'} m'),
                              _buildFormLine('Highrise :', 'Highrise: [   ] Yes / [ ✓ ] No'),
                              const SizedBox(height: 14),

                              _buildFormSectionTitle('DEFECTS / DEFICIENCIES NOTED'),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: colorBorder),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  model.defectsSummary.isNotEmpty ? model.defectsSummary : 'No major fire safety deficiencies noted during inspection.',
                                  style: const TextStyle(fontSize: 11, color: colorTextPrimary),
                                ),
                              ),
                              const SizedBox(height: 14),

                              _buildFormSectionTitle('IX. RECOMMENDATIONS'),
                              _buildFormCheckbox(
                                model.recommendationAction?.toUpperCase().contains('FSIC') ?? true,
                                '[ ✓ ] Comply the following DEFECTS/DEFICIENCIES stated above and pay the corresponding Fire Code Fees before issuance of FSIC',
                              ),
                              _buildFormCheckbox(
                                model.recommendationAction?.toUpperCase().contains('NTC') ?? false,
                                '[   ] For issuance of [   ] Notice to Comply',
                              ),
                              const SizedBox(height: 20),

                              _buildFormSectionTitle('ACKNOWLEDGED BY:'),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: _buildUiSignatory('Signature Over Printed Name of\nOwner / Representative', model.ownerRepresentative)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildUiSignatory('Fire Safety Inspector/s', model.inspectorName)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildUiSignatory('Team Leader', model.teamLeaderName)),
                                ],
                              ),
                              const SizedBox(height: 18),

                              const Center(child: Text('RECOMMEND APPROVAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colorTextPrimary))),
                              const SizedBox(height: 12),
                              Center(child: SizedBox(width: 260, child: _buildUiSignatory('CHIEF, FIRE SAFETY ENFORCEMENT SECTION/UNIT', model.fireMarshalName))),
                              const SizedBox(height: 18),

                              const Center(child: Text('APPROVAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colorTextPrimary))),
                              const SizedBox(height: 12),
                              Center(child: SizedBox(width: 260, child: _buildUiSignatory('CITY / MUNICIPAL FIRE MARSHAL', 'CINSP BFP Fire Marshal'))),
                              const SizedBox(height: 20),

                              // Bottom Page Indicator Badge
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.layers_outlined, size: 13, color: Color(0xFF64748B)),
                                      SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Page 1 of 1 • Full 10-Page Document via Export PDF',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormHeader() {
    return Column(
      children: [
        const Text('Republic of the Philippines', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colorTextPrimary)),
        const Text('Department of the Interior and Local Government', style: TextStyle(fontSize: 9.5, color: Color(0xFF475569))),
        const Text('BUREAU OF FIRE PROTECTION', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorPrimary, letterSpacing: 0.5)),
        const Text('(LINGAYEN FIRE STATION - PANGASINAN)', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: colorAccent)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('BFP-QSF-FSED-061 Rev. ØØ (06.17.22)', style: TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
            Text('Official Form 061', style: TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
          ],
        ),
        const Divider(height: 10, color: colorBorder),
        const SizedBox(height: 2),
        const Text('FIRE SAFETY INSPECTION CHECKLIST', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorPrimary, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildFormSectionTitle(String title) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      color: const Color(0xFFE2E8F0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colorPrimary),
      ),
    );
  }

  Widget _buildFormLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colorTextPrimary)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 1.5),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF475569), width: 0.8)),
              ),
              child: Text(
                value.isNotEmpty ? value : '________________________________________',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCheckbox(bool isChecked, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isChecked ? '[ ✓ ]  ' : '[   ]  ', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colorPrimary)),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 10.5, color: colorTextPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildUiSignatory(String title, String name) {
    return Column(
      children: [
        Container(height: 1, color: colorTextPrimary, width: 140),
        const SizedBox(height: 3),
        Text(
          name.isNotEmpty ? name : 'Signature',
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: colorTextPrimary),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
