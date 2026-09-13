import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/commercial_checklist_model.dart';

/// Service for generating the official Bureau of Fire Protection
/// Fire Safety Inspection Checklist (BFP-QSF-FSED-061 Rev. 00 (06.17.22))
/// exact 10-page Folio/Long Bond PDF format matching the official standard.
class InspectionChecklistPdfService {
  // Philippine Long / Folio dimensions: 8.5 x 13.0 inches (215.9mm x 330.2mm)
  static final PdfPageFormat bfpPageFormat = PdfPageFormat(
    215.9 * PdfPageFormat.mm,
    330.2 * PdfPageFormat.mm,
  );

  static const pw.EdgeInsets pageMargin = pw.EdgeInsets.only(
    left: 36,
    right: 36,
    top: 26,
    bottom: 24,
  );

  static const double textSm = 8.0;
  static const double textBase = 8.5;
  static const double textMd = 9.5;
  static const double textLg = 11.5;

  /// Aliases mapping canonical DOCX checklist queries to short UI keys
  static const Map<String, List<String>> _keyAliases = {
    'Any door leaf in a means of egress shall leave not less than one-half of the required width of an aisle, a corridor, a passageway, or a landing unobstructed.': [
      'Door leaf unobstructing corridor / landing width',
      'Door leaf unobstructing corridor',
      'unobstructed',
    ],
    'Any door leaf in a means of egress shall not project more than 180 mm into the required width of an aisle, a corridor, a passageway, or a landing, unless the door leaf is equipped with an approved self-closing device.': [
      'Door leaf projection <= 180 mm into width',
      'Door leaf projection <= 180 mm',
      '180 mm',
    ],
    'At least two (2) means of egress for each room with occupant load >= 50 or with hazard content.': [
      'At least 2 means of egress for room load >= 50 or hazard',
      'At least two (2) means of egress for room load >= 50 or hazard',
      'At least 2 means of egress for room load >= 50',
    ],
    'Each guest door used as means of egress shall at least 20 minutes fire resistant.': [
      'Guest door >= 20 minutes fire resistant',
      'Guest door >= 20 mins fire resistant',
    ],
    'Doors that open directly onto exit access corridors shall be self-closing and self-latching.': [
      'Doors opening onto corridors are self-closing & self-latching',
      'Doors opening onto corridors are self-closing',
    ],
    'There shall no openings in corridor partitions other than door openings.': [
      'No openings in corridor partitions other than doors',
    ],
    'Doors assembly: 60 minutes fire resistant for three (3) communicating level and below.': [
      'Doors assembly: 60 mins fire resistant (<= 3 communicating levels)',
      'Doors assembly: 60 minutes fire resistant (<= 3 communicating levels)',
    ],
    'Doors assembly: 90 minutes fire resistant for four (4) communicating level and above.': [
      'Doors assembly: 90 mins fire resistant (>= 4 communicating levels)',
      'Doors assembly: 90 minutes fire resistant (>= 4 communicating levels)',
    ],
    'Exits Doors provided with Re-entry mechanism at every four (4) storey.': [
      'Exit doors with Re-entry mechanism at every 4 storey',
      'Exits Doors provided with Re-entry mechanism at every 4 storey',
    ],
    'Stair thread: Minimum depth = 280 mm.': [
      'Stair tread: Minimum depth = 280 mm',
      'Stair thread: Minimum depth = 280 mm',
    ],
    'Stair riser: Minimum / Maximum height = 100 mm / 180 mm.': [
      'Stair riser: Height = 100 mm / 180 mm',
      'Stair riser: Minimum / Maximum height = 100 mm / 180 mm',
    ],
    'Minimum stair head room: 2000mm': [
      'Minimum stair headroom: 2000 mm',
      'Minimum stair head room: 2000 mm',
    ],
    'Stair landing shall not be less than the required width of exit door.': [
      'Stair landing >= required width of exit door',
      'Stair landing shall not be less than the required width of exit door',
    ],
    'Exit Doors provided with panic hardware, vision panel, and self-closing mechanism.': [
      'Exit doors with panic hardware, vision panel & self-closing',
      'Exit Doors provided with panic hardware, vision panel & self-closing',
    ],
    'There shall be no enclosed usable space under the stairs in an exit enclosure nor shall the open space under such stairs be used for any purpose.': [
      'No enclosed usable space under stairs',
      'There shall be no enclosed usable space under stairs',
    ],
    'Remoteness of exit discharge not less than 1/2 of length of the overall dimension of the building or area to be served.': [
      'Remoteness of exit discharge >= 1/2 of length of overall dimension',
      'Remoteness of exit discharge >= 1/2 of length',
    ],
    'Remoteness of exit discharge not less than 1/3 of length of the overall dimension of the building or area to be served is the bldg. is protected throughout by ASASS.': [
      'Remoteness >= 1/3 of length if protected throughout by ASASS',
      'Remoteness of exit discharge >= 1/3 if protected by ASASS',
    ],
    'Exterior grounds are kept clear of objects that might impede evacuation or firefighting equipment': [
      'Exterior grounds clear of objects impeding evacuation',
      'Exterior grounds clear of objects',
    ],
    'Terminate directly at a public way or at an exterior exit discharge.': [
      'Terminate directly at a public way or exterior exit discharge',
    ],
    'Sprinkler water flow alarm': [
      'Sprinkler Water Flow Alarm - Open test valve & check manual alarm bell',
      'Sprinkler Water Flow Alarm',
    ],
    'Sprinkler Pumps': [
      'Sprinkler Pumps - Check automatic start and pressure',
    ],
    'Sprinkler Valves': [
      'Sprinkler Valves - Valves locked open, no leaks/corrosion',
    ],
    'Cabinet Door Operative': [
      'Cabinet Door Operative - Unobstructed and opens properly',
    ],
    'Hose Condition': [
      'Hose Condition - Not rotted, wet, or moldy',
    ],
    'Nozzle': [
      'Nozzle - In place and operates correctly',
    ],
    'Hose hung properly': [
      'Hose Hung Properly - Easily un-rolled if needed',
      'Hose Hung Properly',
    ],
    'Valves and valve handles': [
      'Valves & Handles - Handles in place, open position',
      'Valves & Handles',
    ],
    'Pump System': [
      'Pump System - Inspect accuracy of gauges & sensors',
    ],
    'Pipings': [
      'Pipings - Check pipings for leaks',
    ],
    'Motor': [
      'Motor - Check unusual noise or vibrations',
    ],
    'Electrical System': [
      'Electrical System - Check corrosion, wire insulation, leaks',
    ],
    'Fire Detection System': [
      'Fire Detection System - Random test call points & smoke detectors',
    ],
    'Location Signs': [
      'Fire Alarm Facilities - Location signs legible & panels unobstructed',
      'Location signs legible',
    ],
    'Alarm Panels': [
      'Fire Alarm Facilities - Location signs legible & panels unobstructed',
      'panels unobstructed',
    ],
    'Lifts': [
      'Lifts (Elevator) - Home to ground floor, fans & fireman lift operating',
    ],
    'Fans': [
      'Lifts (Elevator) - Home to ground floor, fans & fireman lift operating',
    ],
    'Fireman\'s lift': [
      'Lifts (Elevator) - Home to ground floor, fans & fireman lift operating',
    ],
    'Fire Extinguisher Size': [
      'Extinguishers Size - Minimal sizes meet RA 9514 table 7 & 8',
      'Extinguishers Size',
    ],
    'Minimum number of Extinguisher.': [
      'Extinguishers Quantity - Minimum count meets RA 9514 requirements',
      'Extinguishers Quantity',
    ],
    'Location': [
      'Extinguishers Location & Tags - Proper location, intact seals/tags',
      'Extinguishers Location',
    ],
    'Seals & Tags': [
      'Extinguishers Location & Tags - Proper location, intact seals/tags',
    ],
    'Markings': [
      'Extinguishers Location & Tags - Proper location, intact seals/tags',
    ],
    'Condition': [
      'Extinguishers Location & Tags - Proper location, intact seals/tags',
    ],
    'Pressure': [
      'Extinguishers Pressure - Gauge reads in the "green" area',
      'Extinguishers Pressure',
    ],
    'Battery Lights': [
      'Emergency Lighting Battery - Battery lights turn on on power failure',
      'Emergency Lighting Battery',
    ],
    'Hoods & Vents': [
      'Kitchen Hoods & Vents - Hoods, vents, fans & ducts free from grease',
      'Kitchen Hoods & Vents',
    ],
    'Hood Filters': [
      'Kitchen Hoods & Vents - Hoods, vents, fans & ducts free from grease',
    ],
  };

  static String _cleanKey(String str) {
    return str.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String? _getStatus(Map<String, String> map, String queryKey) {
    if (map.isEmpty) return null;
    if (map.containsKey(queryKey)) {
      return map[queryKey];
    }
    final aliases = _keyAliases[queryKey];
    if (aliases != null) {
      for (final alias in aliases) {
        if (map.containsKey(alias)) {
          return map[alias];
        }
      }
    }
    final qClean = _cleanKey(queryKey);
    for (final entry in map.entries) {
      final kClean = _cleanKey(entry.key);
      if (kClean == qClean) {
        return entry.value;
      }
      if (aliases != null) {
        for (final alias in aliases) {
          if (_cleanKey(alias) == kClean) {
            return entry.value;
          }
        }
      }
    }
    return null;
  }

  /// Returns true ONLY if status is explicitly 'passed' (case-insensitive)
  static bool _isPassed(Map<String, String> map, String queryKey) {
    final s = _getStatus(map, queryKey);
    return s?.trim().toLowerCase() == 'passed';
  }

  /// Returns true ONLY if status is explicitly 'failed' (case-insensitive)
  static bool _isFailed(Map<String, String> map, String queryKey) {
    final s = _getStatus(map, queryKey);
    return s?.trim().toLowerCase() == 'failed';
  }

  /// Generates the complete 10-page checklist document and presents the print/save preview.
  static Future<void> generateAndPrintChecklistPdf(CommercialChecklistModel model) async {
    final pdf = await buildDocument(model);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'BFP_Form_061_${model.ioNumber.isNotEmpty ? model.ioNumber : "Inspection"}.pdf',
    );
  }

  /// Builds the complete pw.Document for all 10 pages.
  static Future<pw.Document> buildDocument(CommercialChecklistModel model) async {
    final pdf = pw.Document();

    pw.MemoryImage? bfpLogo;
    pw.MemoryImage? dilgLogo;

    try {
      final bfpBytes = await rootBundle.load('assets/bfp_logo.png');
      bfpLogo = pw.MemoryImage(bfpBytes.buffer.asUint8List());
    } catch (_) {}

    try {
      final dilgBytes = await rootBundle.load('assets/dilg_logo.png');
      dilgLogo = pw.MemoryImage(dilgBytes.buffer.asUint8List());
    } catch (_) {}

    // PAGE 1 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage1(model, dilgLogo, bfpLogo),
      ),
    );

    // PAGE 2 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage2(model, dilgLogo, bfpLogo),
      ),
    );

    // PAGE 3 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage3(model, dilgLogo, bfpLogo),
      ),
    );

    // PAGE 4 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage4(model, dilgLogo, bfpLogo),
      ),
    );

    // PAGE 5 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage5(model, dilgLogo, bfpLogo),
      ),
    );

    // PAGE 6 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage6(model, dilgLogo, bfpLogo),
      ),
    );

    // PAGE 7 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage7(model, dilgLogo, bfpLogo),
      ),
    );

    // PAGE 8 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage8(model, dilgLogo, bfpLogo),
      ),
    );

    // PAGE 9 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage9(model, dilgLogo, bfpLogo),
      ),
    );

    // PAGE 10 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage10(model, dilgLogo, bfpLogo),
      ),
    );

    return pdf;
  }

  // ==========================================
  // SHARED HEADER & FOOTER
  // ==========================================
  static pw.Widget _header(pw.MemoryImage? dilgLogo, pw.MemoryImage? bfpLogo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (dilgLogo != null)
          pw.Container(width: 48, height: 48, child: pw.Image(dilgLogo, fit: pw.BoxFit.contain))
        else
          pw.SizedBox(width: 48, height: 48),
        pw.Expanded(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'Republic of the Philippines',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Department of the Interior and Local Government',
                style: const pw.TextStyle(fontSize: 9.5),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'BUREAU OF FIRE PROTECTION',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                '(LINGAYEN FIRE STATION - PANGASINAN)',
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
        if (bfpLogo != null)
          pw.Container(width: 48, height: 48, child: pw.Image(bfpLogo, fit: pw.BoxFit.contain))
        else
          pw.SizedBox(width: 48, height: 48),
      ],
    );
  }

  static pw.Widget _footer(int pageNum) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'BFP-QSF-FSED-061 Rev. 00 (06.17.22) Page $pageNum of 10',
        style: const pw.TextStyle(fontSize: textSm, color: PdfColors.black),
      ),
    );
  }

  // ==========================================
  // SHARED UI PRIMITIVES
  // ==========================================
  static pw.Widget _sectionTitle(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: textMd, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _underlineRow(String label, String value, {double labelWidth = 180}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.SizedBox(
            width: labelWidth,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(label, style: const pw.TextStyle(fontSize: textBase)),
                pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
              ],
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)),
              ),
              padding: const pw.EdgeInsets.only(left: 4, bottom: 0.5),
              child: pw.Text(
                value,
                style: pw.TextStyle(fontSize: textBase, fontWeight: value.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _bracketCheck(bool isChecked, {String? content}) {
    if (content != null) {
      return pw.Text('[ $content ]', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold));
    }
    if (!isChecked) {
      return pw.Text('[   ]', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold));
    }
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('[ ', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
        pw.CustomPaint(
          size: const PdfPoint(6.5, 6.5),
          painter: (PdfGraphics canvas, PdfPoint size) {
            canvas
              ..setColor(PdfColors.black)
              ..setLineWidth(1.1)
              ..moveTo(0, 3.2)
              ..lineTo(2.3, 0.5)
              ..lineTo(6.2, 6.2)
              ..strokePath();
          },
        ),
        pw.Text(' ]', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  // ==========================================
  // PAGE 1 BUILDER
  // ==========================================
  static pw.Widget _buildPage1(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp) {
    final natureLower = (model.inspectionNature ?? '').toLowerCase();
    final isConstruction = natureLower.contains('construction') || natureLower == '1';
    final isPeza = natureLower.contains('peza') || natureLower == '2';
    final isOccupancy = natureLower.contains('occupancy') || natureLower == '3';
    final isBusinessPermit = natureLower.contains('business') || natureLower.contains('permit') || natureLower.contains('renewal') || natureLower == '4';
    final isVerification = natureLower.contains('verification') || natureLower == '5';
    final isOthers = natureLower.contains('other') || natureLower == '6' || (model.natureOthersSpecify != null && model.natureOthersSpecify!.isNotEmpty);

    final verUpper = (model.verificationType ?? '').toUpperCase();
    final isNtc = verUpper == 'NTC';
    final isNtcv = verUpper == 'NTCV';
    final isAbatement = verUpper == 'ABATEMENT';
    final isClosure = verUpper == 'CLOSURE';

    final isFsccrYes = model.fsccrRequired?.toLowerCase() == 'yes';
    final isFsccrNo = model.fsccrRequired?.toLowerCase() == 'no';
    final isFsmrYes = model.fsmrRequired?.toLowerCase() == 'yes';
    final isFsmrNo = model.fsmrRequired?.toLowerCase() == 'no';

    final isOccupancyReq = isOccupancy || (model.fsccrRequired != null && model.fsccrRequired!.isNotEmpty && model.fsccrRequired!.toLowerCase() != 'n/a');
    final isRenewalReq = isBusinessPermit || isPeza || (model.fsmrRequired != null && model.fsmrRequired!.isNotEmpty && model.fsmrRequired!.toLowerCase() != 'n/a');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(dilg, bfp),
        pw.SizedBox(height: 12),
        pw.Center(
          child: pw.Text(
            'FIRE SAFETY INSPECTION CHECKLIST',
            style: pw.TextStyle(fontSize: textLg, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 8),

        // I. REFERENCE
        _sectionTitle('I.        REFERENCE:'),
        _underlineRow('Inspection Order No. (IO)', model.ioNumber, labelWidth: 160),
        _underlineRow('Date Issued', model.dateIssued, labelWidth: 160),
        _underlineRow('Date Inspected', model.dateInspected, labelWidth: 160),
        pw.SizedBox(height: 6),

        // II. NATURE OF INSPECTION CONDUCTED
        _sectionTitle('II.       NATURE OF INSPECTION CONDUCTED (Check appropriate box)'),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [_bracketCheck(isConstruction), pw.SizedBox(width: 4), pw.Text('1. Inspection during construction', style: const pw.TextStyle(fontSize: textBase))]),
              pw.SizedBox(height: 1.5),
              pw.Row(children: [_bracketCheck(isPeza), pw.SizedBox(width: 4), pw.Text('2. FSIC for Certificate of Annual Inspection (PEZA)', style: const pw.TextStyle(fontSize: textBase))]),
              pw.SizedBox(height: 1.5),
              pw.Row(children: [_bracketCheck(isOccupancy), pw.SizedBox(width: 4), pw.Text('3. FSIC for Certificate for Occupancy', style: const pw.TextStyle(fontSize: textBase))]),
              pw.SizedBox(height: 1.5),
              pw.Row(children: [_bracketCheck(isBusinessPermit && !isConstruction && !isPeza && !isOccupancy && !isVerification && !isOthers), pw.SizedBox(width: 4), pw.Text('4. FSIC for Business Permit (New/Renewal)', style: const pw.TextStyle(fontSize: textBase))]),
              pw.SizedBox(height: 1.5),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _bracketCheck(isVerification),
                  pw.SizedBox(width: 4),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('5. Verification Inspection for Compliance:', style: const pw.TextStyle(fontSize: textBase)),
                      pw.SizedBox(height: 1.5),
                      pw.Row(
                        children: [
                          _bracketCheck(isNtc),
                          pw.Text(' NTC / ', style: const pw.TextStyle(fontSize: textBase)),
                          _bracketCheck(isNtcv),
                          pw.Text(' NTCV / ', style: const pw.TextStyle(fontSize: textBase)),
                          _bracketCheck(isAbatement),
                          pw.Text(' Abatement ', style: const pw.TextStyle(fontSize: textBase)),
                          _bracketCheck(isClosure),
                          pw.Text(' Closure', style: const pw.TextStyle(fontSize: textBase)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 1.5),
              pw.Row(
                children: [
                  pw.Text('6. Others (Specify) : ', style: const pw.TextStyle(fontSize: textBase)),
                  pw.Expanded(
                    child: pw.Container(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)),
                      ),
                      padding: const pw.EdgeInsets.only(left: 4, bottom: 0.5),
                      child: pw.Text(model.natureOthersSpecify != null && model.natureOthersSpecify!.isNotEmpty ? model.natureOthersSpecify! : '', style: const pw.TextStyle(fontSize: textBase)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),

        // III. REQUIREMENTS
        _sectionTitle('III.      REQUIREMENTS'),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [_bracketCheck(isOccupancyReq), pw.SizedBox(width: 4), pw.Text('1. FSIC for Occupancy:', style: const pw.TextStyle(fontSize: textBase))]),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 20, top: 1, bottom: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('- Fire Safety Compliance and Commissioning Report (FSCCR)', style: const pw.TextStyle(fontSize: textBase)),
                          pw.Text('  (if applicable)', style: const pw.TextStyle(fontSize: textBase)),
                        ],
                      ),
                    ),
                    pw.Row(
                      children: [
                        pw.Text('Yes ', style: const pw.TextStyle(fontSize: textBase)),
                        _bracketCheck(isFsccrYes),
                        pw.Text(' / No ', style: const pw.TextStyle(fontSize: textBase)),
                        _bracketCheck(isFsccrNo),
                      ],
                    ),
                  ],
                ),
              ),
              pw.Row(children: [_bracketCheck(isRenewalReq), pw.SizedBox(width: 4), pw.Text('2. FSIC for New / Renewal / Annual Inspection / Others:', style: const pw.TextStyle(fontSize: textBase))]),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 20, top: 1, bottom: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('- Fire Safety Maintenance Report (FSMR) (if applicable)', style: const pw.TextStyle(fontSize: textBase)),
                    pw.Row(
                      children: [
                        pw.Text('Yes ', style: const pw.TextStyle(fontSize: textBase)),
                        _bracketCheck(isFsmrYes),
                        pw.Text(' / No ', style: const pw.TextStyle(fontSize: textBase)),
                        _bracketCheck(isFsmrNo),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),

        // IV. GENERAL INFORMATION
        _sectionTitle('IV.     GENERAL INFORMATION'),
        _underlineRow('Name of Building', model.buildingName, labelWidth: 180),
        _underlineRow('Address', model.address, labelWidth: 180),
        _underlineRow('Business Name', model.businessName, labelWidth: 180),
        _underlineRow('Nature of Business', model.natureOfBusiness, labelWidth: 180),
        _underlineRow('Name of owner/Representative', model.ownerRepresentative, labelWidth: 180),
        _underlineRow('Contact No.', model.contactNo, labelWidth: 180),
        pw.SizedBox(height: 4),

        pw.Row(children: [_bracketCheck(isOccupancy || (model.fsecNo.trim().isNotEmpty && model.fsecNo.trim().toUpperCase() != 'N/A')), pw.SizedBox(width: 4), pw.Text('FSIC for Occupancy:', style: const pw.TextStyle(fontSize: textBase))]),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, top: 1, bottom: 1),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 130, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('- FSEC No.', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fsecNo, style: const pw.TextStyle(fontSize: textBase)))),
              pw.SizedBox(width: 10),
              pw.Text('/ Date Issued', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fsecDateIssued, style: const pw.TextStyle(fontSize: textBase)))),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, top: 1, bottom: 2),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 130, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('- Building Permit', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.buildingPermitNo, style: const pw.TextStyle(fontSize: textBase)))),
              pw.SizedBox(width: 10),
              pw.Text('/ Date Issued', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.buildingPermitDateIssued, style: const pw.TextStyle(fontSize: textBase)))),
            ],
          ),
        ),

        pw.Row(children: [_bracketCheck(isBusinessPermit || isPeza || (model.fsicNoLatest.trim().isNotEmpty && model.fsicNoLatest.trim().toUpperCase() != 'N/A')), pw.SizedBox(width: 4), pw.Text('FSIC for New / Renewal / Annual Inspection / Others:', style: const pw.TextStyle(fontSize: textBase))]),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, top: 1, bottom: 1),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 130, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('- FSIC No. (Latest)', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fsicNoLatest, style: const pw.TextStyle(fontSize: textBase)))),
              pw.SizedBox(width: 10),
              pw.Text('/ Date Issued', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fsicDateIssued, style: const pw.TextStyle(fontSize: textBase)))),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, top: 1, bottom: 1),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 130, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('- Certificate of Fire Drill', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fireDrillCertNo, style: const pw.TextStyle(fontSize: textBase)))),
              pw.SizedBox(width: 10),
              pw.Text('/ Date Issued', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fireDrillDateIssued, style: const pw.TextStyle(fontSize: textBase)))),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, top: 1, bottom: 1),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 130, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('- Business Permit No.', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.businessPermitNo, style: const pw.TextStyle(fontSize: textBase)))),
              pw.SizedBox(width: 10),
              pw.Text('/ Date Issued', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.businessPermitDateIssued, style: const pw.TextStyle(fontSize: textBase)))),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, top: 1, bottom: 1),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 130, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('- Fire Insurance Policy No.', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fireInsurancePolicyNo, style: const pw.TextStyle(fontSize: textBase)))),
              pw.SizedBox(width: 10),
              pw.Text('/ Date Issued', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fireInsuranceDateIssued, style: const pw.TextStyle(fontSize: textBase)))),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 20),
          child: pw.Text('(If any)', style: const pw.TextStyle(fontSize: textSm)),
        ),

        pw.Spacer(),
        _footer(1),
      ],
    );
  }

  // ==========================================
  // PAGE 2 BUILDER
  // ==========================================
  static pw.Widget _buildPage2(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp) {
    final ct = model.constructionType ?? '';
    final isTypeI = ct.contains('Type I');
    final isTypeII = ct.contains('Type II');
    final isTypeIII = ct.contains('Type III');
    final isTypeIV = ct.contains('Type IV');
    final isTypeV = ct.contains('Type V');

    final iw = model.interiorFinishWalls ?? '';
    final isClassA = iw.contains('Class A');
    final isClassB = iw.contains('Class B');
    final isClassC = iw.contains('Class C');

    final ifl = model.interiorFinishFloor ?? '';
    final isFloorClassI = ifl.contains('Class I');
    final isFloorClassII = ifl.contains('Class II');

    final occ = model.occupancyClassification ?? '';
    final isAssembly = occ.contains('Assembly');
    final isEducational = occ.contains('Educational');
    final isDayCare = occ.contains('Day Care');
    final isHealthCare = occ.contains('Health Care');
    final isDetention = occ.contains('Detention');
    final isResidentialBoard = occ.contains('Residential Board') || occ.contains('Board and Care');
    final isResidential = occ.contains('Residential') && !isResidentialBoard;
    final isMercantile = occ.contains('Mercantile');
    final isBusiness = occ.contains('Business');
    final isIndustrial = occ.contains('Industrial');
    final isStorage = occ.contains('Storage');
    final isSpecial = occ.contains('Special Structure') || occ.contains('Special');

    final isHighriseYes = model.isHighrise?.toLowerCase() == 'yes';
    final isHighriseNo = model.isHighrise?.toLowerCase() == 'no';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(dilg, bfp),
        pw.SizedBox(height: 14),

        // CONSTRUCTION TYPE
        _sectionTitle('CONSTRUCTION TYPE'),
        pw.SizedBox(height: 2),
        pw.Row(children: [_bracketCheck(isTypeI), pw.SizedBox(width: 4), pw.Text('Type I : Concrete & Steel (Fire Resistive)', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 3),
        pw.Row(children: [_bracketCheck(isTypeII), pw.SizedBox(width: 4), pw.Text('Type II : Concrete & Exposed Steel (Noncombustible)', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 3),
        pw.Row(children: [_bracketCheck(isTypeIII), pw.SizedBox(width: 4), pw.Text('Type III : Concrete & Wood (Ordinary)', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 3),
        pw.Row(children: [_bracketCheck(isTypeIV), pw.SizedBox(width: 4), pw.Text('Type IV : Heavy Timber (Large mass wood)', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 3),
        pw.Row(children: [_bracketCheck(isTypeV), pw.SizedBox(width: 4), pw.Text('Type V : Wood frame (Lightweight wood)', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 12),

        // WALLS / CEILING INTERIOR FINISH
        _sectionTitle('WALLS / CEILING INTERIOR FINISH'),
        pw.SizedBox(height: 2),
        pw.Row(children: [_bracketCheck(isClassA), pw.SizedBox(width: 4), pw.Text('Class A : Flame spread index, 0-25;smoke developed index, 0-450', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 3),
        pw.Row(children: [_bracketCheck(isClassB), pw.SizedBox(width: 4), pw.Text('Class B : Flame spread index, 26-75; smoke developed index, 0-450', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 3),
        pw.Row(children: [_bracketCheck(isClassC), pw.SizedBox(width: 4), pw.Text('Class C : Flame spread index, 76-200; smoke developed index, 0-450', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 2),
        pw.Text('(Note: Flame Spread Index can be seen in the technical specification of the product)', style: pw.TextStyle(fontSize: textSm, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 12),

        // FLOOR INTERIOR FINISH
        _sectionTitle('FLOOR INTERIOR FINISH'),
        pw.SizedBox(height: 2),
        pw.Row(children: [_bracketCheck(isFloorClassI), pw.SizedBox(width: 4), pw.Text('Class I : Critical radiant flux, not less than 0.45 W/cm2.', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 3),
        pw.Row(children: [_bracketCheck(isFloorClassII), pw.SizedBox(width: 4), pw.Text('Class II : Critical radiant flux, not more than 0.22 W/cm2, but less than 0.45W/cm2', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 2),
        pw.Text('(Note: Flame Spread Index can be seen in the technical specification of the product)', style: pw.TextStyle(fontSize: textSm, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 12),

        // SECTIONAL OCCUPANCY
        _sectionTitle('SECTIONAL OCCUPANCY (INDICATE SPECIFIC USAGE OF EACH FLOOR, PART OR PORTION OF THE BUILDING)'),
        _underlineRow('Basement', model.basementUsage, labelWidth: 90),
        _underlineRow('Ground floor', model.groundFloorUsage, labelWidth: 90),
        _underlineRow('Second floor', model.secondFloorUsage, labelWidth: 90),
        _underlineRow('Third floor', model.thirdFloorUsage, labelWidth: 90),
        _underlineRow('Fourth Floor', model.fourthFloorUsage, labelWidth: 90),
        _underlineRow('Nth Floor', model.nthFloorUsage, labelWidth: 90),
        pw.SizedBox(height: 2),
        pw.Text('Use separate sheet if necessary', style: pw.TextStyle(fontSize: textSm, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 12),

        // GENERAL OCCUPANCY CLASSIFICATION
        _sectionTitle('GENERAL OCCUPANCY CLASSIFICATION'),
        pw.SizedBox(height: 2),
        pw.Row(
          children: [
            _bracketCheck(isAssembly),
            pw.Text(' Assembly / ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isEducational),
            pw.Text(' Educational / ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isDayCare),
            pw.Text(' Day Care / ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isHealthCare),
            pw.Text(' Health Care', style: const pw.TextStyle(fontSize: textBase)),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Row(
          children: [
            _bracketCheck(isDetention),
            pw.Text(' Detention and Correctional / ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isResidential),
            pw.Text(' Residential / ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isResidentialBoard),
            pw.Text(' Residential Board and Care', style: const pw.TextStyle(fontSize: textBase)),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Row(
          children: [
            _bracketCheck(isMercantile),
            pw.Text(' Mercantile / ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isBusiness),
            pw.Text(' Business / ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isIndustrial),
            pw.Text(' Industrial / ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isStorage),
            pw.Text(' Storage / ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isSpecial),
            pw.Text(' Special Structure.', style: const pw.TextStyle(fontSize: textBase)),
          ],
        ),
        pw.SizedBox(height: 12),

        // OTHER INFORMATION
        _sectionTitle('OTHER INFORMATION'),
        pw.SizedBox(height: 2),
        pw.Row(
          children: [
            pw.Text('Maximum Occupant Load: ', style: const pw.TextStyle(fontSize: textBase)),
            pw.Container(
              width: 100,
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
              child: pw.Text(model.occupantLoad, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
            ),
            pw.Text(' P/Floor', style: const pw.TextStyle(fontSize: textBase)),
            pw.SizedBox(width: 24),
            pw.Text('Number of Stories: ', style: const pw.TextStyle(fontSize: textBase)),
            pw.Container(
              width: 100,
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
              child: pw.Text(model.numberOfStories, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
            ),
            pw.Text(' Storey', style: const pw.TextStyle(fontSize: textBase)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            pw.Text('Building Height          : ', style: const pw.TextStyle(fontSize: textBase)),
            pw.Container(
              width: 100,
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
              child: pw.Text(model.buildingHeight, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
            ),
            pw.Text(' m', style: const pw.TextStyle(fontSize: textBase)),
            pw.SizedBox(width: 32),
            pw.Text('Highrise: ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isHighriseYes),
            pw.Text(' Yes / ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isHighriseNo),
            pw.Text(' No', style: const pw.TextStyle(fontSize: textBase)),
          ],
        ),

        pw.Spacer(),
        _footer(2),
      ],
    );
  }

  // ==========================================
  // PAGE 3 BUILDER
  // ==========================================
  static pw.Widget _buildPage3(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp) {
    const horizontalItems = [
      'Doors',
      'Corridors / Hallways',
      'Passageways',
      'Lobby / Anteroom',
      'Ramps',
      'Common path of travel',
      'Dead end',
      'Travel distance',
    ];

    const requirements = [
      'Any door leaf in a means of egress shall leave not less than one-half of the required width of an aisle, a corridor, a passageway, or a landing unobstructed.',
      'Any door leaf in a means of egress shall not project more than 180 mm into the required width of an aisle, a corridor, a passageway, or a landing, unless the door leaf is equipped with an approved self-closing device.',
      'At least two (2) means of egress for each room with occupant load >= 50 or with hazard content.',
      'Each guest door used as means of egress shall at least 20 minutes fire resistant.',
      'Doors that open directly onto exit access corridors shall be self-closing and self-latching.',
      'There shall no openings in corridor partitions other than door openings.',
      'Free from any obstruction.',
      'No flammable material stored.',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(dilg, bfp),
        pw.SizedBox(height: 8),

        _sectionTitle('V.        MEANS OF EGRESS'),
        pw.Text('A.    EXIT ACCESS', style: pw.TextStyle(fontSize: textMd, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 24),
          child: pw.Row(
            children: [
              _bracketCheck(_isPassed(model.egressAccessStatus, 'Doors')),
              pw.Text(' Doors / ', style: const pw.TextStyle(fontSize: textBase)),
              _bracketCheck(_isPassed(model.egressAccessStatus, 'Corridors') || _isPassed(model.egressAccessStatus, 'Corridors / Hallways')),
              pw.Text(' Corridors / ', style: const pw.TextStyle(fontSize: textBase)),
              _bracketCheck(_isPassed(model.egressAccessStatus, 'Hallways') || _isPassed(model.egressAccessStatus, 'Corridors / Hallways')),
              pw.Text(' Hallways / ', style: const pw.TextStyle(fontSize: textBase)),
              _bracketCheck(_isPassed(model.egressAccessStatus, 'Passageways')),
              pw.Text(' Passageways / ', style: const pw.TextStyle(fontSize: textBase)),
              _bracketCheck(_isPassed(model.egressAccessStatus, 'Lobby / Anteroom') || _isPassed(model.egressAccessStatus, 'Anterooms')),
              pw.Text(' Anterooms / ', style: const pw.TextStyle(fontSize: textBase)),
              _bracketCheck(_isPassed(model.egressAccessStatus, 'Ramps')),
              pw.Text(' Ramps', style: const pw.TextStyle(fontSize: textBase)),
            ],
          ),
        ),
        pw.SizedBox(height: 6),

        // Horizontal components 5-col row listing
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 120, child: pw.Text('Horizontal components', style: const pw.TextStyle(fontSize: textSm))),
              pw.SizedBox(width: 60, child: pw.Text('Actual\nDimensions', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textSm))),
              pw.SizedBox(width: 35, child: pw.Text('Passed', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textSm))),
              pw.SizedBox(width: 35, child: pw.Text('Failed', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textSm))),
              pw.SizedBox(width: 10),
              pw.Expanded(child: pw.Text('Remarks / Corrective Action', style: const pw.TextStyle(fontSize: textSm))),
            ],
          ),
        ),
        pw.SizedBox(height: 2),
        ...horizontalItems.map((item) {
          final isPass = _isPassed(model.egressAccessStatus, item);
          final isFail = _isFailed(model.egressAccessStatus, item);
          final dim = model.itemDimensions[item] ?? '';
          final remark = model.itemRemarks[item] ?? '';
          return pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, top: 1, bottom: 1),
            child: pw.Row(
              children: [
                pw.SizedBox(width: 120, child: pw.Text(item, style: const pw.TextStyle(fontSize: textBase))),
                pw.SizedBox(
                  width: 60,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
                      pw.Container(
                        width: 38,
                        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                        child: pw.Text(dim, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
                      ),
                      pw.Text(dim.isNotEmpty ? 'm' : ' ', style: const pw.TextStyle(fontSize: textBase)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 35, child: pw.Center(child: _bracketCheck(isPass))),
                pw.SizedBox(width: 35, child: pw.Center(child: _bracketCheck(isFail))),
                pw.SizedBox(width: 10),
                pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
                pw.SizedBox(width: 2),
                pw.Expanded(
                  child: pw.Container(
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                    child: pw.Text(remark, style: const pw.TextStyle(fontSize: textBase)),
                  ),
                ),
              ],
            ),
          );
        }),
        pw.SizedBox(height: 6),

        // Grid Table
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(8),
            1: pw.FixedColumnWidth(65),
            2: pw.FixedColumnWidth(48),
            3: pw.FixedColumnWidth(48),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Container(height: 22),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Text('Actual\nDim.', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Text('Passed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Text('Failed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            ...List.generate(requirements.length, (i) {
              final req = requirements[i];
              final hasDim = i < 4;
              final isPass = _isPassed(model.egressRequirementsStatus, req);
              final isFail = _isFailed(model.egressRequirementsStatus, req);
              return pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(req, style: const pw.TextStyle(fontSize: textBase))),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.all(3),
                    child: hasDim
                        ? pw.Container(
                            width: 50,
                            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                            child: pw.Text('', style: const pw.TextStyle(fontSize: textBase)),
                          )
                        : pw.SizedBox(),
                  ),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(isPass)),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(isFail)),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 6),

        pw.Text('B.    EXITS', style: pw.TextStyle(fontSize: textMd, fontWeight: pw.FontWeight.bold)),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8, top: 1),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  _bracketCheck(_isPassed(model.exitComponentsStatus, 'Normal Stairs')),
                  pw.Text(' Normal Stairs / ', style: const pw.TextStyle(fontSize: textBase)),
                  _bracketCheck(_isPassed(model.exitComponentsStatus, 'Curve stairs') || _isPassed(model.exitComponentsStatus, 'Curved Stairs')),
                  pw.Text(' Curved Stairs / ', style: const pw.TextStyle(fontSize: textBase)),
                  _bracketCheck(_isPassed(model.exitComponentsStatus, 'Spiral Stairs')),
                  pw.Text(' Spiral Stairs / ', style: const pw.TextStyle(fontSize: textBase)),
                  _bracketCheck(_isPassed(model.exitComponentsStatus, 'Winding Stairs')),
                  pw.Text(' Winding Stairs', style: const pw.TextStyle(fontSize: textBase)),
                ],
              ),
              pw.SizedBox(height: 1.5),
              pw.Row(
                children: [
                  _bracketCheck(_isPassed(model.exitComponentsStatus, 'Horizontal Exits')),
                  pw.Text(' Horizontal Exits / ', style: const pw.TextStyle(fontSize: textBase)),
                  _bracketCheck(_isPassed(model.exitComponentsStatus, 'Outside Stairs') || _isPassed(model.exitComponentsStatus, 'Exit Passageways') || _isPassed(model.exitComponentsStatus, 'Fire Escape Stairs')),
                  pw.Text(' Outside Stairs / Exit Passageways / Fire Escape Stairs', style: const pw.TextStyle(fontSize: textBase)),
                ],
              ),
              pw.SizedBox(height: 1.5),
              pw.Row(
                children: [
                  _bracketCheck(_isPassed(model.exitComponentsStatus, 'Fire Escape Ladders') || _isPassed(model.exitComponentsStatus, 'Fire Escape Ladder')),
                  pw.Text(' Fire Escape Ladder (for 1 & 2 family dwelling only)', style: const pw.TextStyle(fontSize: textBase)),
                ],
              ),
              pw.SizedBox(height: 1.5),
              pw.Row(
                children: [
                  _bracketCheck(_isPassed(model.exitComponentsStatus, 'Slide Escape')),
                  pw.Text(' Slide Escape (for Industrial Occupancy Only)', style: const pw.TextStyle(fontSize: textBase)),
                ],
              ),
            ],
          ),
        ),

        pw.Spacer(),
        _footer(3),
      ],
    );
  }

  // ==========================================
  // PAGE 4 BUILDER
  // ==========================================
  static pw.Widget _buildPage4(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp) {
    const exitComponents = [
      'Exits Doors',
      'Normal Stairs',
      'Curve stairs',
      'Winding Stairs',
      'Horizontal Exits',
      'Outside Stairs',
      'Exit Passageways',
      'Fire Escape Stairs',
      'Fire Escape Ladders',
      'Slide Escape',
    ];

    const stairSpecs = [
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

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(dilg, bfp),
        pw.SizedBox(height: 8),

        // 10 Components Top Listing
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 120, child: pw.Text('Components', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(width: 70, child: pw.Text('Clear Width', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(width: 35, child: pw.Text('Passed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(width: 35, child: pw.Text('Failed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(width: 10),
              pw.Expanded(child: pw.Text('Remarks / Corrective Action', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
            ],
          ),
        ),
        pw.SizedBox(height: 2),
        ...exitComponents.map((c) {
          final isPass = _isPassed(model.exitComponentsStatus, c);
          final isFail = _isFailed(model.exitComponentsStatus, c);
          final width = model.itemDimensions[c] ?? '';
          final remark = model.itemRemarks[c] ?? '';
          return pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, top: 0.8, bottom: 0.8),
            child: pw.Row(
              children: [
                pw.SizedBox(width: 120, child: pw.Text(c, style: const pw.TextStyle(fontSize: textBase))),
                pw.SizedBox(
                  width: 70,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
                      pw.Container(
                        width: 44,
                        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                        child: pw.Text(width, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
                      ),
                      pw.Text(width.isNotEmpty ? 'm' : ' ', style: const pw.TextStyle(fontSize: textBase)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 35, child: pw.Center(child: _bracketCheck(isPass))),
                pw.SizedBox(width: 35, child: pw.Center(child: _bracketCheck(isFail))),
                pw.SizedBox(width: 10),
                pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
                pw.SizedBox(width: 2),
                pw.Expanded(
                  child: pw.Container(
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                    child: pw.Text(remark, style: const pw.TextStyle(fontSize: textBase)),
                  ),
                ),
              ],
            ),
          );
        }),
        pw.SizedBox(height: 6),

        // Grid Table (15 Specs)
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(8),
            1: pw.FixedColumnWidth(65),
            2: pw.FixedColumnWidth(48),
            3: pw.FixedColumnWidth(48),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Container(height: 20),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Text('Actual\nDim.', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Text('Passed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Text('Failed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            ...List.generate(stairSpecs.length, (i) {
              final spec = stairSpecs[i];
              final hasDim = i < 10;
              final isPass = _isPassed(model.egressRequirementsStatus, spec);
              final isFail = _isFailed(model.egressRequirementsStatus, spec);
              return pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(spec, style: const pw.TextStyle(fontSize: textBase))),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.all(2.5),
                    child: hasDim
                        ? pw.Container(
                            width: 50,
                            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                            child: pw.Text('', style: const pw.TextStyle(fontSize: textBase)),
                          )
                        : pw.SizedBox(),
                  ),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(2.5), child: _bracketCheck(isPass)),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(2.5), child: _bracketCheck(isFail)),
                ],
              );
            }),
          ],
        ),

        pw.Spacer(),
        _footer(4),
      ],
    );
  }

  // ==========================================
  // PAGE 5 BUILDER
  // ==========================================
  static pw.Widget _buildPage5(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp) {
    const dischargeItems = [
      'Remoteness of exit discharge not less than 1/2 of length of the overall dimension of the building or area to be served.',
      'Remoteness of exit discharge not less than 1/3 of length of the overall dimension of the building or area to be served is the bldg. is protected throughout by ASASS.',
      'Exterior grounds are kept clear of objects that might impede evacuation or firefighting equipment',
      'Terminate directly at a public way or at an exterior exit discharge.',
    ];

    const markingItems = [
      'Minimum letter height, 150 mm',
      'EXIT signs are posted along Exit access, Exits and Exit discharge',
      'EXIT signs are properly illuminated',
    ];

    const evacItems = [
      '1. "You Are Here/ room number/ building" Marking',
      '2. Fire Exits',
      '3. Primary Route to Exit (Nearest to the viewer)',
      '4. Secondary Route to Exit (Second nearest to the viewer)',
      '5. Fire alarm pull stations and annunciators',
      '6. Fire extinguishers/ hose cabinets',
      '7. Emergency Light',
      '8. First Aid Kits locations (if applicable)',
      '9. Emergency Call stations (if applicable)',
      '10. Areas of safe refuge (for high-rise building)',
      '11. Assembly areas instructions',
      '12. "In Case of Emergency" instructions',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(dilg, bfp),
        pw.SizedBox(height: 8),

        // C. EXITS DISCHARGE
        pw.Text('C.    EXITS DISCHARGE', style: pw.TextStyle(fontSize: textMd, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(8),
            1: pw.FixedColumnWidth(65),
            2: pw.FixedColumnWidth(48),
            3: pw.FixedColumnWidth(48),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Container(height: 20),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Actual\nDim.', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Passed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Failed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            ...List.generate(dischargeItems.length, (i) {
              final item = dischargeItems[i];
              final isPass = _isPassed(model.egressRequirementsStatus, item);
              final isFail = _isFailed(model.egressRequirementsStatus, item);
              return pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(item, style: const pw.TextStyle(fontSize: textBase))),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.all(3),
                    child: i < 2
                        ? pw.Container(width: 50, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text('', style: const pw.TextStyle(fontSize: textBase)))
                        : pw.SizedBox(),
                  ),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(isPass)),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(isFail)),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 10),

        // VI. SIGNS, LIGHTING, AND EXITS SIGNAGE
        _sectionTitle('VI.     SIGNS, LIGHTING, AND EXITS SIGNAGE'),
        pw.Text('A.    MARKING OF MEANS OF EGRESS (EXIT)', style: pw.TextStyle(fontSize: textMd, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(8),
            1: pw.FixedColumnWidth(65),
            2: pw.FixedColumnWidth(48),
            3: pw.FixedColumnWidth(48),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Container(height: 20),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Actual\nDim.', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Passed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Failed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            ...List.generate(markingItems.length, (i) {
              final item = markingItems[i];
              final isPass = _isPassed(model.exitSignageStatus, item);
              final isFail = _isFailed(model.exitSignageStatus, item);
              return pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(item, style: const pw.TextStyle(fontSize: textBase))),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.all(3),
                    child: i == 0
                        ? pw.Container(width: 50, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text('', style: const pw.TextStyle(fontSize: textBase)))
                        : pw.SizedBox(),
                  ),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(isPass)),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(isFail)),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 10),

        // B. MARKING OF MEANS OF EGRESS (EMERGENCY EVACUATION PLAN)
        pw.Text('B.    MARKING OF MEANS OF EGRESS (EMERGENCY EVACUATION PLAN)', style: pw.TextStyle(fontSize: textMd, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(8),
            1: pw.FixedColumnWidth(48),
            2: pw.FixedColumnWidth(48),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Container(height: 18),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Passed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Failed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Posted on strategic and conspicuous location inside the building', style: const pw.TextStyle(fontSize: textBase))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isPassed(model.exitSignageStatus, 'strategic'))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isFailed(model.exitSignageStatus, 'strategic'))),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Drawn with a photo-luminescent background to be readable in case of power failure.', style: const pw.TextStyle(fontSize: textBase))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isPassed(model.exitSignageStatus, 'photo-luminescent'))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isFailed(model.exitSignageStatus, 'photo-luminescent'))),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Containing the following basic information below', style: const pw.TextStyle(fontSize: textBase)),
                      ...evacItems.map((item) => pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 12, top: 0.5),
                            child: pw.Text(item, style: const pw.TextStyle(fontSize: textBase)),
                          )),
                    ],
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isPassed(model.exitSignageStatus, 'basic markings'))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isFailed(model.exitSignageStatus, 'basic markings'))),
              ],
            ),
          ],
        ),

        pw.Spacer(),
        _footer(5),
      ],
    );
  }

  // ==========================================
  // PAGE 6 BUILDER
  // ==========================================
  static pw.Widget _buildPage6(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp) {
    const illuminationItems = [
      'Floors and other walking surfaces: shall be at least 1 ft-candle (10.8 lux), measured at the floor.',
      'In assembly occupancies: walking surfaces of exit access shall be at least 0.2 ft-candle (2.2 lux)',
      'Stairs: shall be at least 10 ft-candle (108 lux), measured at the walking surfaces.',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(dilg, bfp),
        pw.SizedBox(height: 8),

        // Emergency Evacuation Plan Sizes
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(8),
            1: pw.FixedColumnWidth(65),
            2: pw.FixedColumnWidth(48),
            3: pw.FixedColumnWidth(48),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Container(height: 20),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Actual\nDim.', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Passed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Failed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Emergency Evacuation Plan:', style: const pw.TextStyle(fontSize: textBase)),
                      pw.SizedBox(height: 2),
                      pw.Row(children: [_bracketCheck(_isPassed(model.exitSignageStatus, '330.2')), pw.SizedBox(width: 4), pw.Text('Size 330.2 mm wide * 215.9 mm height (Floor area < 50 m2)', style: const pw.TextStyle(fontSize: textBase))]),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 18), child: pw.Text('- Room or spaces', style: const pw.TextStyle(fontSize: textBase))),
                    ],
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: pw.Container(width: 50, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isPassed(model.exitSignageStatus, '330.2'))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isFailed(model.exitSignageStatus, '330.2'))),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(children: [_bracketCheck(_isPassed(model.exitSignageStatus, '50-150')), pw.SizedBox(width: 4), pw.Text('Size 609.6 mm wide * 457.2 mm height (Floor area = 50 - 150 m2)', style: const pw.TextStyle(fontSize: textBase))]),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 18),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('- Room or spaces', style: const pw.TextStyle(fontSize: textBase)),
                            pw.Text('- Building lobbies upon entry.', style: const pw.TextStyle(fontSize: textBase)),
                            pw.Text('- Elevator lobbies at every floor.', style: const pw.TextStyle(fontSize: textBase)),
                            pw.Text('- Hallways and corridors.', style: const pw.TextStyle(fontSize: textBase)),
                            pw.Text('- On every bend/corner Or every 15m interval in the case of long hallway.', style: const pw.TextStyle(fontSize: textBase)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: pw.Container(width: 50, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isPassed(model.exitSignageStatus, '50-150'))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isFailed(model.exitSignageStatus, '50-150'))),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(children: [_bracketCheck(_isPassed(model.exitSignageStatus, '151')), pw.SizedBox(width: 4), pw.Text('Size 609.6 mm wide * 457.2 mm height (Floor area >= 151m2)', style: const pw.TextStyle(fontSize: textBase))]),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 18),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('- Room or spaces', style: const pw.TextStyle(fontSize: textBase)),
                            pw.Text('- Upon entry of the building', style: const pw.TextStyle(fontSize: textBase)),
                            pw.Text('- Area of assembly or every 25m interval in the case auditorium & gymnasium.', style: const pw.TextStyle(fontSize: textBase)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: pw.Container(width: 50, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isPassed(model.exitSignageStatus, '151'))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isFailed(model.exitSignageStatus, '151'))),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text('Symbols/icons/logos to be used for the marking shall be in accordance with NFPA 170, Standard for Signs and Symbols.', style: const pw.TextStyle(fontSize: textBase)),
                ),
                pw.Container(),
                pw.Container(),
                pw.Container(),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),

        // C. ILLUMINATION OF MEANS OF EGRESS
        pw.Text('C.    ILLUMINATION OF MEANS OF EGRESS', style: pw.TextStyle(fontSize: textMd, fontWeight: pw.FontWeight.bold)),
        pw.Text('(All Data Below Shall be Referred from Manufacturers Specifications)', style: pw.TextStyle(fontSize: textMd, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(8),
            1: pw.FixedColumnWidth(65),
            2: pw.FixedColumnWidth(48),
            3: pw.FixedColumnWidth(48),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Container(height: 20),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Actual\nLux/Time', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Passed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Failed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            ...illuminationItems.map((item) {
              final isPass = _isPassed(model.exitSignageStatus, item);
              final isFail = _isFailed(model.exitSignageStatus, item);
              return pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(item, style: const pw.TextStyle(fontSize: textBase))),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: pw.Container(width: 50, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))))),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(isPass)),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(isFail)),
                ],
              );
            }),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Emergency Lighting', style: const pw.TextStyle(fontSize: textBase)),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _bracketCheck(_isPassed(model.exitSignageStatus, 'Emergency lighting average')),
                          pw.SizedBox(width: 4),
                          pw.Expanded(
                            child: pw.Text(
                              'Illumination not less than an average of 1 ft-candle (10.8 lux) and, at any point, not less than 0.1 ft-candle (1.1 lux), measured along the path of egress at floor level.',
                              style: const pw.TextStyle(fontSize: textBase),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: pw.Container(width: 50, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isPassed(model.exitSignageStatus, 'Emergency lighting average'))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isFailed(model.exitSignageStatus, 'Emergency lighting average'))),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _bracketCheck(_isPassed(model.exitSignageStatus, 'auto-activates')),
                      pw.SizedBox(width: 4),
                      pw.Expanded(
                        child: pw.Text(
                          'Emergency lighting system shall be arranged to provide the required illumination automatically in the event of any interruption of normal lighting (e.g. Failure of a public utility, ect..)\nfor a period at least 1.5-hour.',
                          style: const pw.TextStyle(fontSize: textBase),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: pw.Container(width: 50, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isPassed(model.exitSignageStatus, 'auto-activates'))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isFailed(model.exitSignageStatus, 'auto-activates'))),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Row(
                    children: [
                      _bracketCheck(_isPassed(model.exitSignageStatus, 'Periodic Testing')),
                      pw.SizedBox(width: 4),
                      pw.Text('Periodic Testing of Emergency Lighting Equipment (Written record)', style: const pw.TextStyle(fontSize: textBase)),
                    ],
                  ),
                ),
                pw.Container(),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isPassed(model.exitSignageStatus, 'Periodic Testing'))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isFailed(model.exitSignageStatus, 'Periodic Testing'))),
              ],
            ),
          ],
        ),

        pw.Spacer(),
        _footer(6),
      ],
    );
  }

  // ==========================================
  // PAGE 7 BUILDER
  // ==========================================
  static pw.Widget _buildPage7(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(dilg, bfp),
        pw.SizedBox(height: 8),

        _sectionTitle('VII.     HAZARD'),
        pw.SizedBox(height: 2),
        pw.Row(
          children: [
            pw.SizedBox(width: 140, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Hazard Contents', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
            pw.SizedBox(width: 4),
            pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.hazardContents, style: const pw.TextStyle(fontSize: textBase)))),
            pw.SizedBox(width: 10),
            pw.SizedBox(width: 130, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Quantity (Vol. / Weight)', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
            pw.SizedBox(width: 4),
            pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.hazardQuantity, style: const pw.TextStyle(fontSize: textBase)))),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 140,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Hazard Identification', style: const pw.TextStyle(fontSize: textBase)),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Placard', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))]),
                ],
              ),
            ),
            pw.SizedBox(width: 4),
            pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.hazardPlacard, style: const pw.TextStyle(fontSize: textBase)))),
            pw.SizedBox(width: 10),
            pw.SizedBox(width: 130, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Within MAQ', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
            pw.SizedBox(width: 4),
            pw.Expanded(
              flex: 3,
              child: pw.Row(
                children: [
                  _bracketCheck(model.withinMaq?.trim().toLowerCase() == 'yes'),
                  pw.Text(' Yes / ', style: const pw.TextStyle(fontSize: textBase)),
                  _bracketCheck(model.withinMaq?.trim().toLowerCase() == 'no'),
                  pw.Text(' No', style: const pw.TextStyle(fontSize: textBase)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 140, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Hazard\nIdentification No.', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
            pw.SizedBox(width: 4),
            pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.hazardIdentificationNo, style: const pw.TextStyle(fontSize: textBase)))),
            pw.SizedBox(width: 10),
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Hazard Classification:', style: const pw.TextStyle(fontSize: textBase)),
                  pw.SizedBox(height: 1),
                  pw.Row(
                    children: [
                      _bracketCheck((model.hazardClassification ?? '').trim().toLowerCase() == 'low'),
                      pw.Text(' Low / ', style: const pw.TextStyle(fontSize: textBase)),
                      _bracketCheck((model.hazardClassification ?? '').trim().toLowerCase() == 'ordinary'),
                      pw.Text(' Ordinary / ', style: const pw.TextStyle(fontSize: textBase)),
                      _bracketCheck((model.hazardClassification ?? '').trim().toLowerCase() == 'high'),
                      pw.Text(' High', style: const pw.TextStyle(fontSize: textBase)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          children: [
            pw.SizedBox(width: 140, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Class', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
            pw.SizedBox(width: 4),
            pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.hazardClass, style: const pw.TextStyle(fontSize: textBase)))),
            pw.SizedBox(width: 10),
            pw.SizedBox(width: 130, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Flash Point', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
            pw.SizedBox(width: 4),
            pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.flashPoint, style: const pw.TextStyle(fontSize: textBase)))),
          ],
        ),
        pw.SizedBox(height: 8),

        pw.Text('Low hazard contents shall be classified as those of such low combustibility that no self-propagating fire therein can occur.', style: pw.TextStyle(fontSize: textSm, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 3),
        pw.Text('Ordinary hazard contents shall be classified as those that are likely to burn with moderate rapidity or to give off a considerable volume of smoke.', style: pw.TextStyle(fontSize: textSm, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 3),
        pw.Text('High hazard contents shall be classified as those that are likely to burn with extreme rapidity or from which explosions are likely.', style: pw.TextStyle(fontSize: textSm, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 10),

        // A. OTHER FLAMMABLE LIQUIDS
        pw.Text('A.    OTHER FLAMMABLE LIQUIDS (I.E. ALCOHOL, ETHER, ETC...)', style: pw.TextStyle(fontSize: textMd, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        _buildDynamicHazardTable([
          'Stored in sealed metal containers',
          'Properly dispensed as per SOP',
          'Provided with "NO SMOKING" sign',
        ], model.hazardStatus),
        pw.SizedBox(height: 8),

        // B. MISCELLANEOUS HAZARDS
        pw.Text('B.    MISCELLANEOUS HAZARDS (MECHANICAL EQUIPMENT ROOM, STORAGE, SUPPLY ROOM)', style: pw.TextStyle(fontSize: textMd, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        _buildDynamicHazardTable([
          'All no smoking areas has adequate signs',
          'Gasoline / Diesel stored in proper place & metal safety can',
        ], model.hazardStatus),
        pw.SizedBox(height: 8),

        // C. HOUSEKEEPING
        pw.Text('C.    HOUSEKEEPING, MAINTENANCE, STORAGE & WASTE DISPOSAL', style: pw.TextStyle(fontSize: textMd, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        _buildDynamicHazardTable([
          'Brooms, mops, rags stored in metal cabinets or approved cans',
          'Paints, solvents stored in metal cabinet; oily rags in metal containers',
          'Dry leaves, shrubbery trimmings kept away from buildings',
        ], model.hazardStatus),

        pw.Spacer(),
        _footer(7),
      ],
    );
  }

  // ==========================================
  // PAGE 8 BUILDER
  // ==========================================
  static pw.Widget _buildPage8(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(dilg, bfp),
        pw.SizedBox(height: 6),

        _sectionTitle('VIII.   FIRE PROTECTION'),
        pw.SizedBox(height: 2),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(150),
            1: pw.FlexColumnWidth(8),
            2: pw.FixedColumnWidth(48),
            3: pw.FixedColumnWidth(48),
          },
          children: [
            // A. Header
            _tableSectionHeaderRow('A.    Automatic Fire Suppression System (Sprinkler)'),
            _tableSubHeaderRow(),
            _tableTwoColRow('Sprinkler Pumps', 'Check automatic start and pressure.', _isPassed(model.fireProtectionStatus, 'Sprinkler Pumps'), _isFailed(model.fireProtectionStatus, 'Sprinkler Pumps')),
            _tableTwoColRow('Sprinkler Valves', 'Valves are locked in the open position, no leaks, corrosion, or other defects noted.', _isPassed(model.fireProtectionStatus, 'Sprinkler Valves'), _isFailed(model.fireProtectionStatus, 'Sprinkler Valves')),
            _tableTwoColRow('Sprinkler water flow alarm', 'Open test valve and ensure manual alarm bell functions and sprinkler pumps start.', _isPassed(model.fireProtectionStatus, 'Sprinkler Water Flow Alarm'), _isFailed(model.fireProtectionStatus, 'Sprinkler Water Flow Alarm')),

            // B. Header
            _tableSectionHeaderRow('B.    Wet Standpipe/Fire Hose Cabinet'),
            _tableTwoColRow('Cabinet Door Operative', 'Check that door is unobstructed and opens properly.', _isPassed(model.fireProtectionStatus, 'Cabinet Door Operative'), _isFailed(model.fireProtectionStatus, 'Cabinet Door Operative')),
            _tableTwoColRow('Hose Condition', 'Check that hose is not rotted, wet, moldy, etc.', _isPassed(model.fireProtectionStatus, 'Hose Condition'), _isFailed(model.fireProtectionStatus, 'Hose Condition')),
            _tableTwoColRow('Nozzle', 'Check that nozzle is in place and operates correctly.', _isPassed(model.fireProtectionStatus, 'Nozzle'), _isFailed(model.fireProtectionStatus, 'Nozzle')),
            _tableTwoColRow('Hose hung properly', 'Check that hose is hung properly so that it can easily be un-rolled if needed.', _isPassed(model.fireProtectionStatus, 'Hose Hung Properly'), _isFailed(model.fireProtectionStatus, 'Hose Hung Properly')),
            _tableTwoColRow('Valves and valve handles', 'Check that valve handles are in place and that valves operate properly and are in the open position.', _isPassed(model.fireProtectionStatus, 'Valves & Handles'), _isFailed(model.fireProtectionStatus, 'Valves & Handles')),

            // C. Header
            _tableSectionHeaderRow('C.    Fire Pump'),
            _tableTwoColRow('Pump System', 'Inspect accuracy of pressure gauges and sensors', _isPassed(model.fireProtectionStatus, 'Pump System'), _isFailed(model.fireProtectionStatus, 'Pump System')),
            _tableTwoColRow('Pipings', 'Check pipings if there is leak', _isPassed(model.fireProtectionStatus, 'Pipings'), _isFailed(model.fireProtectionStatus, 'Pipings')),
            _tableTwoColRow('Motor', 'Check unusual noise or vibrations', _isPassed(model.fireProtectionStatus, 'Motor'), _isFailed(model.fireProtectionStatus, 'Motor')),
            _tableTwoColRow('Electrical System', 'Check if there is corrosion in PCBs, cracked cable/wire insulation, leak in plumbing parts, sign of water in electrical part', _isPassed(model.fireProtectionStatus, 'Electrical System'), _isFailed(model.fireProtectionStatus, 'Electrical System')),

            // D. Header
            _tableSectionHeaderRow('D.    Fire Detection System'),
            _tableTwoColRow('Fire Detection System', 'Random Test of call points and smoke detectors.', _isPassed(model.fireProtectionStatus, 'Fire Detection System'), _isFailed(model.fireProtectionStatus, 'Fire Detection System')),

            // E. Header
            _tableSectionHeaderRow('E.    Fire Alarm Facilities'),
            _tableTwoColRow('Location Signs', 'Check all signs are in place and legible.', _isPassed(model.fireProtectionStatus, 'Location Signs'), _isFailed(model.fireProtectionStatus, 'Location Signs')),
            _tableTwoColRow('Alarm Panels', 'Check that all alarm panels are functioning correctly and are unobstructed.', _isPassed(model.fireProtectionStatus, 'Alarm Panels'), _isFailed(model.fireProtectionStatus, 'Alarm Panels')),

            // F. Header
            _tableSectionHeaderRow('F.    Lifts (Elevator)'),
            _tableTwoColRow('Lifts', 'All lifts "home" to ground floor during fire test, doors open and lift stops.', _isPassed(model.fireProtectionStatus, 'Lifts'), _isFailed(model.fireProtectionStatus, 'Lifts')),
            _tableTwoColRow('Fans', 'All lift fans operate correctly.', _isPassed(model.fireProtectionStatus, 'Lifts'), _isFailed(model.fireProtectionStatus, 'Lifts')),
            _tableTwoColRow('Fireman\'s lift', 'Fireman\'s lift can be keyed to operate during fire alarm test.', _isPassed(model.fireProtectionStatus, 'Lifts'), _isFailed(model.fireProtectionStatus, 'Lifts')),
          ],
        ),

        pw.Spacer(),
        _footer(8),
      ],
    );
  }

  // ==========================================
  // PAGE 9 BUILDER
  // ==========================================
  static pw.Widget _buildPage9(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(dilg, bfp),
        pw.SizedBox(height: 6),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(150),
            1: pw.FlexColumnWidth(8),
            2: pw.FixedColumnWidth(48),
            3: pw.FixedColumnWidth(48),
          },
          children: [
            // G. Header
            _tableSectionHeaderRow('G.    First Aid Fire Protection (Fire Extinguishers)'),
            _tableTwoColRow('Fire Extinguisher Size', 'Minimal sizes of fire extinguishers for the listed grades of hazards shall be provided on the basis of table 7 & 8 of RIRR of RA 9514.', _isPassed(model.fireProtectionStatus, 'Extinguishers Size'), _isFailed(model.fireProtectionStatus, 'Extinguishers Size')),
            _tableTwoColRow('Minimum number of Extinguisher.', 'The minimum number of extinguishers shall be sufficient to meet the requirements of table 7 & 8 of RIRR of RA 9514.', _isPassed(model.fireProtectionStatus, 'Extinguishers Quantity'), _isFailed(model.fireProtectionStatus, 'Extinguishers Quantity')),
            _tableTwoColRow('Location', 'All extinguishers are in their proper location.', _isPassed(model.fireProtectionStatus, 'Extinguishers Location'), _isFailed(model.fireProtectionStatus, 'Extinguishers Location')),
            _tableTwoColRow('Seals & Tags', 'Extinguisher seals and tags are intact and extinguisher was serviced in the last 12 months.', _isPassed(model.fireProtectionStatus, 'Extinguishers Location & Tags'), _isFailed(model.fireProtectionStatus, 'Extinguishers Location & Tags')),
            _tableTwoColRow('Markings', 'Proper marking on extinguisher to indicate the type of fire the extinguisher can be used on.', _isPassed(model.fireProtectionStatus, 'Extinguishers Location & Tags'), _isFailed(model.fireProtectionStatus, 'Extinguishers Location & Tags')),
            _tableTwoColRow('Condition', 'No leaks, corrosion or other defects noticed.', _isPassed(model.fireProtectionStatus, 'Extinguishers Location & Tags'), _isFailed(model.fireProtectionStatus, 'Extinguishers Location & Tags')),
            _tableTwoColRow('Pressure', 'Pressure gauge reads in the "green" area.', _isPassed(model.fireProtectionStatus, 'Extinguishers Pressure'), _isFailed(model.fireProtectionStatus, 'Extinguishers Pressure')),

            // H. Header
            _tableSectionHeaderRow('H.    Emergency Lighting Systems'),
            _tableTwoColRow('Battery Lights', 'All battery powered emergency lighting turns on when mains power is removed', _isPassed(model.fireProtectionStatus, 'Emergency Lighting Battery'), _isFailed(model.fireProtectionStatus, 'Emergency Lighting Battery')),

            // I. Header
            _tableSectionHeaderRow('I.    Kitchen'),
            _tableTwoColRow('Hoods & Vents', 'Hoods, vents, fans and ducts in good condition and free from grease', _isPassed(model.fireProtectionStatus, 'Kitchen Hoods & Vents'), _isFailed(model.fireProtectionStatus, 'Kitchen Hoods & Vents')),
            _tableTwoColRow('Hood Filters', 'Date of Last Cleaning', _isPassed(model.fireProtectionStatus, 'Kitchen Hoods & Vents'), _isFailed(model.fireProtectionStatus, 'Kitchen Hoods & Vents')),
          ],
        ),
        pw.SizedBox(height: 8),

        // J. BUILDING SERVICE EQUIPMENT
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(28),
            1: pw.FlexColumnWidth(8),
            2: pw.FixedColumnWidth(48),
            3: pw.FixedColumnWidth(48),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Text('J.', style: pw.TextStyle(fontSize: textMd, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text('BUILDING SERVICE EQUIPMENT', style: pw.TextStyle(fontSize: textMd, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Passed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Failed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Container(alignment: pw.Alignment.topCenter, padding: const pw.EdgeInsets.only(top: 3), child: pw.Text('1.', style: const pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Utilities:', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Cooking equipment protected by AKHFSS (Restaurant and similar establishment with Occupant Load > 50p)', style: const pw.TextStyle(fontSize: textBase)),
                    ],
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck((model.bseUtilities ?? '').trim().toLowerCase() == 'passed')),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck((model.bseUtilities ?? '').trim().toLowerCase() == 'failed')),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Container(alignment: pw.Alignment.topCenter, padding: const pw.EdgeInsets.only(top: 3), child: pw.Text('2.', style: const pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Heating, Ventilating and Air-conditioning:', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Design & Installation in accordance with PMEC', style: const pw.TextStyle(fontSize: textBase)),
                    ],
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck((model.bseHvac ?? '').trim().toLowerCase() == 'passed')),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck((model.bseHvac ?? '').trim().toLowerCase() == 'failed')),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Container(alignment: pw.Alignment.topCenter, padding: const pw.EdgeInsets.only(top: 3), child: pw.Text('3.', style: const pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Smoke Control Systems/Smoke Management shall be provided in the following:', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Row(children: [_bracketCheck(false), pw.SizedBox(width: 4), pw.Expanded(child: pw.Text('All high-rise buildings (stairwells, at least 1 elevator shaft, zoned smoke control, and vestibule).', style: const pw.TextStyle(fontSize: textBase)))]),
                      pw.Row(children: [_bracketCheck(false), pw.SizedBox(width: 4), pw.Text('Pressurization of smoke refuge area.', style: const pw.TextStyle(fontSize: textBase))]),
                      pw.Row(children: [_bracketCheck(false), pw.SizedBox(width: 4), pw.Expanded(child: pw.Text('Every Atrium of covered mall of over 2- levels / Other type of Occupancy over 3 - levels.', style: const pw.TextStyle(fontSize: textBase)))]),
                      pw.Row(children: [_bracketCheck(false), pw.SizedBox(width: 4), pw.Text('Underground structure and windowless facilities.', style: const pw.TextStyle(fontSize: textBase))]),
                      pw.Row(children: [_bracketCheck(false), pw.SizedBox(width: 4), pw.Text('All movie houses.', style: const pw.TextStyle(fontSize: textBase))]),
                      pw.Row(children: [_bracketCheck(false), pw.SizedBox(width: 4), pw.Expanded(child: pw.Text('All other buildings or structures with at least 1,115m2 single floor area.', style: const pw.TextStyle(fontSize: textBase)))]),
                    ],
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck((model.bseSmokeControl ?? '').trim().toLowerCase() == 'passed')),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck((model.bseSmokeControl ?? '').trim().toLowerCase() == 'failed')),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Container(alignment: pw.Alignment.topCenter, padding: const pw.EdgeInsets.only(top: 3), child: pw.Text('4.', style: const pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Rubbish Chutes, Laundry Chutes, and Flue-Fed Incinerators:', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                      pw.Text('(not apply to detached single- or two-family dwelling)', style: const pw.TextStyle(fontSize: textBase)),
                      pw.SizedBox(height: 2),
                      pw.Row(children: [_bracketCheck(false), pw.SizedBox(width: 4), pw.Text('Chutes & Incinerators shall be enclosed.', style: const pw.TextStyle(fontSize: textBase))]),
                      pw.Row(children: [_bracketCheck(false), pw.SizedBox(width: 4), pw.Text('Design and Maintained in accordance with the latest edition of PMEC.', style: const pw.TextStyle(fontSize: textBase))]),
                    ],
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck((model.bseRubbishChutes ?? '').trim().toLowerCase() == 'passed')),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck((model.bseRubbishChutes ?? '').trim().toLowerCase() == 'failed')),
              ],
            ),
          ],
        ),

        pw.Spacer(),
        _footer(9),
      ],
    );
  }

  // ==========================================
  // PAGE 10 BUILDER
  // ==========================================
  static pw.Widget _buildPage10(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp) {
    final recRaw = model.recommendationAction ?? '';
    final recNorm = recRaw.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final isNod = recNorm.contains('DISAPPROVAL') || recNorm == 'NOD';
    final isNtc = recNorm.contains('NOTICETOCOMPLY') || recNorm == 'NTC';
    final isNtcv = recNorm.contains('CORRECTVIOLATION') || recNorm == 'NTCV';
    final isClosure = recNorm.contains('CLOSURE');
    final isAbatement = recNorm.contains('ABATEMENT');
    final isNonFsic = isNod || isNtc || isNtcv || isClosure || isAbatement;
    final isFsic = (recNorm.contains('FSIC') || recNorm == 'INSPECTED') || (!isNonFsic && recNorm.isNotEmpty);

    final fwProv = (model.fireWallProvided ?? '').trim().toLowerCase();
    final fwExt = (model.fireWallExtension ?? '').trim().toLowerCase();
    final fwType = (model.fireWallType ?? '').toLowerCase();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(dilg, bfp),
        pw.SizedBox(height: 6),

        // Section K Table
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(28),
            1: pw.FlexColumnWidth(8),
            2: pw.FixedColumnWidth(110),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Text('K.', style: pw.TextStyle(fontSize: textMd, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text('FIRE WALL (FW) (if required)', style: pw.TextStyle(fontSize: textMd, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Container(),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Container(),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Provided with Fire Wall (minimum 2 hours fire resistance)', style: const pw.TextStyle(fontSize: textBase))),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      _bracketCheck(fwProv == 'yes'),
                      pw.Text(' Yes / ', style: const pw.TextStyle(fontSize: textBase)),
                      _bracketCheck(fwProv == 'no'),
                      pw.Text(' No', style: const pw.TextStyle(fontSize: textBase)),
                    ],
                  ),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Container(),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FW extension above the roof surface shall not be less than 760mm', style: const pw.TextStyle(fontSize: textBase)),
                      pw.Text('(See MC No. 2021-064 dated 28 June 2021 for Alternative)', style: pw.TextStyle(fontSize: textSm, fontStyle: pw.FontStyle.italic)),
                    ],
                  ),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      _bracketCheck(fwExt == 'yes'),
                      pw.Text(' Yes / ', style: const pw.TextStyle(fontSize: textBase)),
                      _bracketCheck(fwExt == 'no'),
                      pw.Text(' No', style: const pw.TextStyle(fontSize: textBase)),
                    ],
                  ),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Container(),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Row(
                    children: [
                      pw.Text('Wall type: ', style: const pw.TextStyle(fontSize: textBase)),
                      _bracketCheck(fwType.contains('125mm') || fwType.contains('concrete')),
                      pw.Text(' 125mm Solid Concrete / ', style: const pw.TextStyle(fontSize: textBase)),
                      _bracketCheck(fwType.contains('150mm') || fwType.contains('solid masonry')),
                      pw.Text(' 150mm Solid Masonry / ', style: const pw.TextStyle(fontSize: textBase)),
                      _bracketCheck(fwType.contains('200mm') || fwType.contains('hallow')),
                      pw.Text(' 200mm Hallow Unit Masonry', style: const pw.TextStyle(fontSize: textBase)),
                    ],
                  ),
                ),
                pw.Container(),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),

        // DEFECTS/DEFICIENCIES
        _sectionTitle('DEFECTS/DEFICIENCIES'),
        pw.SizedBox(height: 2),
        _defectsRow('ITEM IV:', model.defectsItemIV),
        _defectsRow('ITEM V:', model.defectsItemV),
        _defectsRow('ITEM VI:', model.defectsItemVI),
        _defectsRow('ITEM VII:', model.defectsItemVII),
        _defectsRow('ITEM VIII:', model.defectsItemVIII.isNotEmpty ? model.defectsItemVIII : model.defectsSummary),
        pw.SizedBox(height: 6),

        // IX. RECOMMENDATIONS
        _sectionTitle('IX.        RECOMMENDATIONS'),
        pw.SizedBox(height: 2),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _bracketCheck(isFsic),
            pw.SizedBox(width: 4),
            pw.Expanded(
              child: pw.Text(
                'Comply the following DEFECTS/DEFICIENCIES stated above and pay the corresponding Fire Code Fees including the Storage Clearance Fee , Conveyance Clearance Fee before the issuance of Fire Safety Inspection Certificate (FSIC)',
                style: const pw.TextStyle(fontSize: textBase),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _bracketCheck(isNonFsic),
            pw.SizedBox(width: 4),
            pw.Text('For issuance of', style: const pw.TextStyle(fontSize: textBase)),
            pw.SizedBox(width: 24),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(children: [_bracketCheck(isNod), pw.SizedBox(width: 4), pw.Text('Notice of Disapproval (NOD)', style: const pw.TextStyle(fontSize: textBase))]),
                pw.SizedBox(height: 1),
                pw.Row(children: [_bracketCheck(isNtc), pw.SizedBox(width: 4), pw.Text('Notice to Comply', style: const pw.TextStyle(fontSize: textBase))]),
                pw.SizedBox(height: 1),
                pw.Row(children: [_bracketCheck(isNtcv), pw.SizedBox(width: 4), pw.Text('Notice to Correct Violation', style: const pw.TextStyle(fontSize: textBase))]),
                pw.SizedBox(height: 1),
                pw.Row(children: [_bracketCheck(isClosure), pw.SizedBox(width: 4), pw.Text('Closure Order', style: const pw.TextStyle(fontSize: textBase))]),
                pw.SizedBox(height: 1),
                pw.Row(children: [_bracketCheck(isAbatement), pw.SizedBox(width: 4), pw.Text('Abatement Order with Administrative Fine', style: const pw.TextStyle(fontSize: textBase))]),
                pw.SizedBox(height: 1),
                pw.Row(children: [_bracketCheck(false), pw.SizedBox(width: 4), pw.Text('Closure Order for the non-payment of Administrative Fine', style: const pw.TextStyle(fontSize: textBase))]),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),

        // ACKNOWLEDGED BY:
        _sectionTitle('ACKNOWLEDGED BY:'),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _signatoryBox(
              'Signature Over Printed Name of\nOwner/ Representative',
              model.ownerRepresentative.isNotEmpty ? model.ownerRepresentative : '',
            ),
            _signatoryBox(
              'Fire Safety Inspector/s',
              model.inspectorName.isNotEmpty ? model.inspectorName : '',
            ),
            _signatoryBox(
              'Team Leader',
              model.teamLeaderName.isNotEmpty ? model.teamLeaderName : '',
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Text('Date & Time: ', style: const pw.TextStyle(fontSize: textBase)),
            pw.Container(
              width: 140,
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
              child: pw.Text(model.dateInspected.isNotEmpty ? model.dateInspected : '', style: const pw.TextStyle(fontSize: textBase)),
            ),
          ],
        ),
        pw.SizedBox(height: 8),

        // RECOMMEND APPROVAL:
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 250,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RECOMMEND APPROVAL:', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 16),
                pw.Container(
                  width: 240,
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                  child: pw.Text(model.chiefFsedName.isNotEmpty ? model.chiefFsedName : '', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 2),
                pw.Center(child: pw.Text('CHIEF, FIRE SAFETY ENFORCEMENT SECTION/UNIT', style: pw.TextStyle(fontSize: textSm, fontWeight: pw.FontWeight.bold))),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 8),

        // APPROVAL:
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 250,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('APPROVAL:', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 16),
                pw.Container(
                  width: 240,
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                  child: pw.Text(model.fireMarshalName.isNotEmpty ? model.fireMarshalName : '', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 2),
                pw.Center(child: pw.Text('CITY/ MUNICIPAL FIRE MARSHAL', style: pw.TextStyle(fontSize: textSm, fontWeight: pw.FontWeight.bold))),
              ],
            ),
          ),
        ),

        pw.Spacer(),
        _footer(10),
      ],
    );
  }

  // ==========================================
  // TABLE HELPER WIDGETS
  // ==========================================
  static pw.Widget _buildDynamicHazardTable(List<String> items, Map<String, String> statusMap) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(8),
        1: pw.FixedColumnWidth(48),
        2: pw.FixedColumnWidth(48),
      },
      children: [
        pw.TableRow(
          children: [
            pw.Container(height: 18),
            pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Passed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
            pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Failed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        ...items.map((item) => pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(item, style: const pw.TextStyle(fontSize: textBase))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isPassed(statusMap, item))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(_isFailed(statusMap, item))),
              ],
            )),
      ],
    );
  }

  static pw.TableRow _tableSectionHeaderRow(String title) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(title, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Container(),
        pw.Container(),
        pw.Container(),
      ],
    );
  }

  static pw.TableRow _tableSubHeaderRow() {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text('Item to Inspect', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text('Procedure How to Inspect', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Passed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
        pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('Failed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
      ],
    );
  }

  static pw.TableRow _tableTwoColRow(String item, String procedure, bool isPassed, bool isFailed) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(item, style: const pw.TextStyle(fontSize: textBase))),
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(procedure, style: const pw.TextStyle(fontSize: textBase))),
        pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(isPassed)),
        pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(3), child: _bracketCheck(isFailed)),
      ],
    );
  }

  static pw.Widget _defectsRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 70, child: pw.Text(label, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
              padding: const pw.EdgeInsets.only(left: 4, bottom: 0.5),
              child: pw.Text(value, style: const pw.TextStyle(fontSize: textBase)),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _signatoryBox(String title, String name) {
    return pw.Container(
      width: 155,
      child: pw.Column(
        children: [
          pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
            padding: const pw.EdgeInsets.only(bottom: 1),
            child: pw.Text(name, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 2),
          pw.Text(title, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textSm)),
        ],
      ),
    );
  }
}
