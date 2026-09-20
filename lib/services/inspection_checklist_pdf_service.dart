import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/commercial_checklist_model.dart';

/// Service for generating the official Bureau of Fire Protection
/// Fire Safety Inspection Checklist (BFP-QSF-FSED-061 Rev. 00 (06.17.22))
/// High-fidelity 10-page Folio/Long Bond PDF format matching the official standard.
class InspectionChecklistPdfService {
  // Philippine Long / Folio dimensions: 8.5 x 13.0 inches (612.0 pt x 936.0 pt)
  static final PdfPageFormat bfpPageFormat = PdfPageFormat(
    215.9 * PdfPageFormat.mm,
    330.2 * PdfPageFormat.mm,
  );

  // Exact page margins matching the 150 DPI scanned government template
  static const pw.EdgeInsets pageMargin = pw.EdgeInsets.only(
    left: 54,
    right: 46,
    top: 36,
    bottom: 36,
  );

  // Typography tokens calibrated to official government standard Arial points
  static const double textSm = 8.5;
  static const double textBase = 10.0;
  static const double textMd = 10.5;
  static const double textHeading = 11.5;
  static const double textLg = 13.5;

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

  static bool _isPassed(Map<String, String> map, String queryKey) {
    final s = _getStatus(map, queryKey);
    return s?.trim().toLowerCase() == 'passed';
  }

  static bool _isFailed(Map<String, String> map, String queryKey) {
    final s = _getStatus(map, queryKey);
    return s?.trim().toLowerCase() == 'failed';
  }

  static String _getDimension(Map<String, String> map, String queryKey) {
    if (map.isEmpty) return '';
    if (map.containsKey(queryKey) && map[queryKey]!.trim().isNotEmpty) {
      return map[queryKey]!;
    }
    final aliases = _keyAliases[queryKey];
    if (aliases != null) {
      for (final alias in aliases) {
        if (map.containsKey(alias) && map[alias]!.trim().isNotEmpty) {
          return map[alias]!;
        }
      }
    }
    final qClean = _cleanKey(queryKey);
    for (final entry in map.entries) {
      final kClean = _cleanKey(entry.key);
      if (kClean == qClean && entry.value.trim().isNotEmpty) {
        return entry.value;
      }
      if (aliases != null) {
        for (final alias in aliases) {
          if (_cleanKey(alias) == kClean && entry.value.trim().isNotEmpty) {
            return entry.value;
          }
        }
      }
    }
    return '';
  }

  static String _getRemark(Map<String, String> map, String queryKey) {
    return _getDimension(map, queryKey);
  }

  /// Generates the complete 10-page checklist document and triggers print/PDF preview
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

    final stationName = '(LINGAYEN FIRE STATION)';

    // PAGE 1 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage1(model, dilgLogo, bfpLogo, stationName),
      ),
    );

    // PAGE 2 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage2(model, dilgLogo, bfpLogo, stationName),
      ),
    );

    // PAGE 3 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage3(model, dilgLogo, bfpLogo, stationName),
      ),
    );

    // PAGE 4 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage4(model, dilgLogo, bfpLogo, stationName),
      ),
    );

    // PAGE 5 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage5(model, dilgLogo, bfpLogo, stationName),
      ),
    );

    // PAGE 6 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage6(model, dilgLogo, bfpLogo, stationName),
      ),
    );

    // PAGE 7 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage7(model, dilgLogo, bfpLogo, stationName),
      ),
    );

    // PAGE 8 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage8(model, dilgLogo, bfpLogo, stationName),
      ),
    );

    // PAGE 9 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage9(model, dilgLogo, bfpLogo, stationName),
      ),
    );

    // PAGE 10 OF 10
    pdf.addPage(
      pw.Page(
        pageFormat: bfpPageFormat,
        margin: pageMargin,
        build: (pw.Context context) => _buildPage10(model, dilgLogo, bfpLogo, stationName),
      ),
    );

    return pdf;
  }

  // ==========================================
  // SHARED HEADER & FOOTER
  // ==========================================
  static pw.Widget _header(pw.MemoryImage? dilgLogo, pw.MemoryImage? bfpLogo, String stationName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (dilgLogo != null)
          pw.Container(width: 56, height: 56, child: pw.Image(dilgLogo, fit: pw.BoxFit.contain))
        else
          pw.SizedBox(width: 56, height: 56),
        pw.Expanded(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'Republic of the Philippines',
                style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                'Department of the Interior and Local Government',
                style: const pw.TextStyle(fontSize: 9.5),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                'BUREAU OF FIRE PROTECTION',
                style: pw.TextStyle(fontSize: 12.0, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                stationName,
                style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
        if (bfpLogo != null)
          pw.Container(width: 56, height: 56, child: pw.Image(bfpLogo, fit: pw.BoxFit.contain))
        else
          pw.SizedBox(width: 56, height: 56),
      ],
    );
  }

  static pw.Widget _footer(int pageNum) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      margin: const pw.EdgeInsets.only(top: 6),
      child: pw.Text(
        'BFP-QSF-FSED-061 Rev. 00 (06.17.22) Page $pageNum of 10',
        style: const pw.TextStyle(fontSize: 8.0, color: PdfColors.black),
      ),
    );
  }

  // ==========================================
  // SHARED UI PRIMITIVES
  // ==========================================
  static pw.Widget _sectionTitle(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: textHeading, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  /// Bracket checkmark rendering [ ✓ ] or empty [   ]
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
          size: const PdfPoint(7.0, 7.0),
          painter: (PdfGraphics canvas, PdfPoint size) {
            canvas
              ..setColor(PdfColors.black)
              ..setLineWidth(1.2)
              ..moveTo(0.5, 3.8)
              ..lineTo(2.6, 1.0)
              ..lineTo(6.8, 6.8)
              ..strokePath();
          },
        ),
        pw.Text(' ]', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  /// Full-width underline row with fixed colon tab stop
  static pw.Widget _underlineRow(String label, String value, {double labelWidth = 195, double verticalPadding = 4.5}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: verticalPadding),
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

  // ==========================================
  // PAGE 1 BUILDER
  // ==========================================
  static pw.Widget _buildPage1(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp, String stationName) {
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
        _header(dilg, bfp, stationName),
        pw.SizedBox(height: 14),
        pw.Center(
          child: pw.Text(
            'FIRE SAFETY INSPECTION CHECKLIST',
            style: pw.TextStyle(fontSize: textLg, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 14),

        // I. REFERENCE
        _sectionTitle('I.        REFERENCE:'),
        _underlineRow('Inspection Order No. (IO)', model.ioNumber, labelWidth: 195, verticalPadding: 4.5),
        _underlineRow('Date Issued', model.dateIssued, labelWidth: 195, verticalPadding: 4.5),
        _underlineRow('Date Inspected', model.dateInspected, labelWidth: 195, verticalPadding: 4.5),
        pw.SizedBox(height: 14),

        // II. NATURE OF INSPECTION CONDUCTED
        _sectionTitle('II.       NATURE OF INSPECTION CONDUCTED (Check appropriate box)'),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [
                pw.Text('1. ', style: const pw.TextStyle(fontSize: textBase)),
                _bracketCheck(isConstruction),
                pw.SizedBox(width: 4),
                pw.Text('Inspection during construction', style: const pw.TextStyle(fontSize: textBase)),
              ]),
              pw.SizedBox(height: 5),
              pw.Row(children: [
                pw.Text('2. ', style: const pw.TextStyle(fontSize: textBase)),
                _bracketCheck(isPeza),
                pw.SizedBox(width: 4),
                pw.Text('FSIC for Certificate of Annual Inspection (PEZA)', style: const pw.TextStyle(fontSize: textBase)),
              ]),
              pw.SizedBox(height: 5),
              pw.Row(children: [
                pw.Text('3. ', style: const pw.TextStyle(fontSize: textBase)),
                _bracketCheck(isOccupancy),
                pw.SizedBox(width: 4),
                pw.Text('FSIC for Certificate for Occupancy', style: const pw.TextStyle(fontSize: textBase)),
              ]),
              pw.SizedBox(height: 5),
              pw.Row(children: [
                pw.Text('4. ', style: const pw.TextStyle(fontSize: textBase)),
                _bracketCheck(isBusinessPermit && !isConstruction && !isPeza && !isOccupancy && !isVerification && !isOthers),
                pw.SizedBox(width: 4),
                pw.Text('FSIC for Business Permit (New/Renewal)', style: const pw.TextStyle(fontSize: textBase)),
              ]),
              pw.SizedBox(height: 5),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('5. ', style: const pw.TextStyle(fontSize: textBase)),
                  _bracketCheck(isVerification),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Verification Inspection for Compliance:', style: const pw.TextStyle(fontSize: textBase)),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            pw.SizedBox(width: 14),
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
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                children: [
                  pw.Text('6. Others (Specify) : ', style: const pw.TextStyle(fontSize: textBase)),
                  pw.Expanded(
                    child: pw.Container(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)),
                      ),
                      padding: const pw.EdgeInsets.only(left: 4, bottom: 0.5),
                      child: pw.Text(
                        model.natureOthersSpecify ?? '',
                        style: const pw.TextStyle(fontSize: textBase),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),

        // III. REQUIREMENTS
        _sectionTitle('III.      REQUIREMENTS'),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [
                pw.Text('1. ', style: const pw.TextStyle(fontSize: textBase)),
                _bracketCheck(isOccupancyReq),
                pw.SizedBox(width: 4),
                pw.Text('FSIC for Occupancy:', style: const pw.TextStyle(fontSize: textBase)),
              ]),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 18, top: 3.5, bottom: 3.5),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('-  Fire Safety Compliance and Commissioning Report (FSCCR)', style: const pw.TextStyle(fontSize: textBase)),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 12, top: 1),
                            child: pw.Text('(if applicable)', style: const pw.TextStyle(fontSize: textSm)),
                          ),
                        ],
                      ),
                    ),
                    pw.Row(
                      children: [
                        pw.Text('Yes ', style: const pw.TextStyle(fontSize: textBase)),
                        _bracketCheck(isFsccrYes),
                        pw.Text(' / No ', style: const pw.TextStyle(fontSize: textBase)),
                        _bracketCheck(isFsccrNo),
                        pw.SizedBox(width: 32),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Row(children: [
                pw.Text('2. ', style: const pw.TextStyle(fontSize: textBase)),
                _bracketCheck(isRenewalReq),
                pw.SizedBox(width: 4),
                pw.Text('FSIC for New / Renewal / Annual Inspection / Others:', style: const pw.TextStyle(fontSize: textBase)),
              ]),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 18, top: 3.5, bottom: 3.5),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text('-  Fire Safety Maintenance Report (FSMR) (if applicable)', style: const pw.TextStyle(fontSize: textBase)),
                    ),
                    pw.Row(
                      children: [
                        pw.Text('Yes ', style: const pw.TextStyle(fontSize: textBase)),
                        _bracketCheck(isFsmrYes),
                        pw.Text(' / No ', style: const pw.TextStyle(fontSize: textBase)),
                        _bracketCheck(isFsmrNo),
                        pw.SizedBox(width: 32),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),

        // IV. GENERAL INFORMATION
        _sectionTitle('IV.      GENERAL INFORMATION'),
        _underlineRow('Name of Building', model.buildingName, labelWidth: 195, verticalPadding: 4.5),
        _underlineRow('Address', model.address, labelWidth: 195, verticalPadding: 4.5),
        _underlineRow('Business Name', model.businessName, labelWidth: 195, verticalPadding: 4.5),
        _underlineRow('Nature of Business', model.natureOfBusiness, labelWidth: 195, verticalPadding: 4.5),
        _underlineRow('Name of owner/Representative', model.ownerRepresentative, labelWidth: 195, verticalPadding: 4.5),
        _underlineRow('Contact No.', model.contactNo, labelWidth: 195, verticalPadding: 4.5),
        pw.SizedBox(height: 6),

        pw.Row(children: [
          _bracketCheck(isOccupancy || (model.fsecNo.trim().isNotEmpty && model.fsecNo.trim().toUpperCase() != 'N/A')),
          pw.SizedBox(width: 4),
          pw.Text('FSIC for Occupancy:', style: const pw.TextStyle(fontSize: textBase)),
        ]),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 14, top: 3.5, bottom: 3.5),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 140, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('- FSEC No.', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fsecNo, style: pw.TextStyle(fontSize: textBase, fontWeight: model.fsecNo.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)))),
              pw.SizedBox(width: 12),
              pw.Text('/ Date Issued', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fsecDateIssued, style: pw.TextStyle(fontSize: textBase, fontWeight: model.fsecDateIssued.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)))),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 14, top: 3.5, bottom: 3.5),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 140, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('- Building Permit', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.buildingPermitNo, style: pw.TextStyle(fontSize: textBase, fontWeight: model.buildingPermitNo.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)))),
              pw.SizedBox(width: 12),
              pw.Text('/ Date Issued', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.buildingPermitDateIssued, style: pw.TextStyle(fontSize: textBase, fontWeight: model.buildingPermitDateIssued.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)))),
            ],
          ),
        ),
        pw.SizedBox(height: 5),

        pw.Row(children: [
          _bracketCheck(isBusinessPermit || isPeza || (model.fsicNoLatest.trim().isNotEmpty && model.fsicNoLatest.trim().toUpperCase() != 'N/A')),
          pw.SizedBox(width: 4),
          pw.Text('FSIC for New / Renewal / Annual Inspection / Others:', style: const pw.TextStyle(fontSize: textBase)),
        ]),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 14, top: 3.5, bottom: 3.5),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 140, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('- FSIC No. (Latest)', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fsicNoLatest, style: pw.TextStyle(fontSize: textBase, fontWeight: model.fsicNoLatest.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)))),
              pw.SizedBox(width: 12),
              pw.Text('/ Date Issued', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fsicDateIssued, style: pw.TextStyle(fontSize: textBase, fontWeight: model.fsicDateIssued.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)))),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 14, top: 3.5, bottom: 3.5),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 140, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('- Certificate of Fire Drill', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fireDrillCertNo, style: pw.TextStyle(fontSize: textBase, fontWeight: model.fireDrillCertNo.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)))),
              pw.SizedBox(width: 12),
              pw.Text('/ Date Issued', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fireDrillDateIssued, style: pw.TextStyle(fontSize: textBase, fontWeight: model.fireDrillDateIssued.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)))),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 14, top: 3.5, bottom: 3.5),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 140, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('- Business Permit No.', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.businessPermitNo, style: pw.TextStyle(fontSize: textBase, fontWeight: model.businessPermitNo.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)))),
              pw.SizedBox(width: 12),
              pw.Text('/ Date Issued', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.businessPermitDateIssued, style: pw.TextStyle(fontSize: textBase, fontWeight: model.businessPermitDateIssued.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)))),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 14, top: 3.5, bottom: 3.5),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 140, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('- Fire Insurance Policy No.', style: const pw.TextStyle(fontSize: textBase)), pw.Text(':', style: const pw.TextStyle(fontSize: textBase))])),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fireInsurancePolicyNo, style: pw.TextStyle(fontSize: textBase, fontWeight: model.fireInsurancePolicyNo.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)))),
              pw.SizedBox(width: 12),
              pw.Text('/ Date Issued', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.fireInsuranceDateIssued, style: pw.TextStyle(fontSize: textBase, fontWeight: model.fireInsuranceDateIssued.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)))),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 24, top: 2),
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
  static pw.Widget _buildPage2(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp, String stationName) {
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
        _header(dilg, bfp, stationName),
        pw.SizedBox(height: 14),

        // CONSTRUCTION TYPE
        _sectionTitle('CONSTRUCTION TYPE'),
        pw.SizedBox(height: 3),
        pw.Row(children: [_bracketCheck(isTypeI), pw.SizedBox(width: 4), pw.Text('Type I : Concrete & Steel (Fire Resistive)', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 5),
        pw.Row(children: [_bracketCheck(isTypeII), pw.SizedBox(width: 4), pw.Text('Type II : Concrete & Exposed Steel (Noncombustible)', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 5),
        pw.Row(children: [_bracketCheck(isTypeIII), pw.SizedBox(width: 4), pw.Text('Type III : Concrete & Wood (Ordinary)', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 5),
        pw.Row(children: [_bracketCheck(isTypeIV), pw.SizedBox(width: 4), pw.Text('Type IV : Heavy Timber (Large mass wood)', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 5),
        pw.Row(children: [_bracketCheck(isTypeV), pw.SizedBox(width: 4), pw.Text('Type V : Wood frame (Lightweight wood)', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 14),

        // WALLS / CEILING INTERIOR FINISH
        _sectionTitle('WALLS / CEILING INTERIOR FINISH'),
        pw.SizedBox(height: 3),
        pw.Row(children: [_bracketCheck(isClassA), pw.SizedBox(width: 4), pw.Text('Class A : Flame spread index, 0-25;smoke developed index, 0-450', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 5),
        pw.Row(children: [_bracketCheck(isClassB), pw.SizedBox(width: 4), pw.Text('Class B : Flame spread index, 26-75; smoke developed index, 0-450', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 5),
        pw.Row(children: [_bracketCheck(isClassC), pw.SizedBox(width: 4), pw.Text('Class C : Flame spread index, 76-200; smoke developed index, 0-450', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 3),
        pw.Text('(Note: Flame Spread Index can be seen in the technical specification of the product)', style: pw.TextStyle(fontSize: textSm, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 14),

        // FLOOR INTERIOR FINISH
        _sectionTitle('FLOOR INTERIOR FINISH'),
        pw.SizedBox(height: 3),
        pw.Row(children: [_bracketCheck(isFloorClassI), pw.SizedBox(width: 4), pw.Text('Class I : Critical radiant flux, not less than 0.45 W/cm2.', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 5),
        pw.Row(children: [_bracketCheck(isFloorClassII), pw.SizedBox(width: 4), pw.Text('Class II : Critical radiant flux, not more than 0.22 W/cm2, but less than 0.45W/cm2', style: const pw.TextStyle(fontSize: textBase))]),
        pw.SizedBox(height: 3),
        pw.Text('(Note: Flame Spread Index can be seen in the technical specification of the product)', style: pw.TextStyle(fontSize: textSm, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 14),

        // SECTIONAL OCCUPANCY
        _sectionTitle('SECTIONAL OCCUPANCY (INDICATE SPECIFIC USAGE OF EACH FLOOR, PART OR PORTION OF THE BUILDING)'),
        _underlineRow('Basement', model.basementUsage, labelWidth: 105, verticalPadding: 4.0),
        _underlineRow('Ground floor', model.groundFloorUsage, labelWidth: 105, verticalPadding: 4.0),
        _underlineRow('Second floor', model.secondFloorUsage, labelWidth: 105, verticalPadding: 4.0),
        _underlineRow('Third floor', model.thirdFloorUsage, labelWidth: 105, verticalPadding: 4.0),
        _underlineRow('Fourth Floor', model.fourthFloorUsage, labelWidth: 105, verticalPadding: 4.0),
        _underlineRow('Nth Floor', model.nthFloorUsage, labelWidth: 105, verticalPadding: 4.0),
        pw.SizedBox(height: 3),
        pw.Text('Use separate sheet if necessary', style: pw.TextStyle(fontSize: textSm, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 14),

        // GENERAL OCCUPANCY CLASSIFICATION
        _sectionTitle('GENERAL OCCUPANCY CLASSIFICATION'),
        pw.SizedBox(height: 3),
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
        pw.SizedBox(height: 5),
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
        pw.SizedBox(height: 5),
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
        pw.SizedBox(height: 14),

        // OTHER INFORMATION
        _sectionTitle('OTHER INFORMATION'),
        pw.SizedBox(height: 3),
        pw.Row(
          children: [
            pw.Text('Maximum Occupant Load: ', style: const pw.TextStyle(fontSize: textBase)),
            pw.Container(
              width: 105,
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
              child: pw.Text(model.occupantLoad, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: model.occupantLoad.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ),
            pw.Text(' P/Floor', style: const pw.TextStyle(fontSize: textBase)),
            pw.SizedBox(width: 24),
            pw.Text('Number of Stories: ', style: const pw.TextStyle(fontSize: textBase)),
            pw.Container(
              width: 105,
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
              child: pw.Text(model.numberOfStories, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: model.numberOfStories.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ),
            pw.Text(' Storey', style: const pw.TextStyle(fontSize: textBase)),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Text('Building Height          : ', style: const pw.TextStyle(fontSize: textBase)),
            pw.Container(
              width: 105,
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
              child: pw.Text(model.buildingHeight, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: model.buildingHeight.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)),
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
  static pw.Widget _buildPage3(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp, String stationName) {
    final horizontalComponents = [
      'Doors',
      'Corridors / Hallways',
      'Passageways',
      'Lobby / Anteroom',
      'Ramps',
      'Common path of travel',
      'Dead end',
      'Travel distance',
    ];

    final tableCriteria = [
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
        _header(dilg, bfp, stationName),
        pw.SizedBox(height: 12),

        _sectionTitle('V.        MEANS OF EGRESS'),
        _sectionTitle('A.       EXIT ACCESS'),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8, bottom: 8),
          child: pw.Text('[   ] Doors / [   ] Corridors / [   ] Hallways / [   ] Passageways / [   ] Anterooms / [   ] Ramps', style: const pw.TextStyle(fontSize: textBase)),
        ),

        // Unbordered Aligned Horizontal Components List
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8, bottom: 4),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 140, child: pw.Text('Horizontal components', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(width: 90, child: pw.Text('Actual\nDimensions', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
              pw.SizedBox(width: 45, child: pw.Text('Passed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
              pw.SizedBox(width: 45, child: pw.Text('Failed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
              pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.only(left: 8), child: pw.Text('Remarks / Corrective Action', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)))),
            ],
          ),
        ),
        ...horizontalComponents.map((item) {
          final isPass = _isPassed(model.exitWayStatus, item);
          final isFail = _isFailed(model.exitWayStatus, item);
          final dim = _getDimension(model.itemDimensions, item);
          final remark = _getRemark(model.itemRemarks, item);

          return pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, bottom: 3.5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(
                  width: 140,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(item, style: const pw.TextStyle(fontSize: textBase)),
                      pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 4),
                pw.Container(
                  width: 60,
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                  child: pw.Text(dim, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
                ),
                pw.SizedBox(width: 4),
                pw.SizedBox(width: 22, child: pw.Text('m', style: const pw.TextStyle(fontSize: textBase))),
                pw.SizedBox(width: 45, child: pw.Center(child: _bracketCheck(isPass))),
                pw.SizedBox(width: 45, child: pw.Center(child: _bracketCheck(isFail))),
                pw.SizedBox(width: 8),
                pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
                pw.SizedBox(width: 4),
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

        pw.SizedBox(height: 10),

        // Bordered Table
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(5.5),
            1: pw.FlexColumnWidth(1.4),
            2: pw.FlexColumnWidth(1.0),
            3: pw.FlexColumnWidth(1.0),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('', style: const pw.TextStyle(fontSize: textBase))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Actual\nDim.', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Passed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Failed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            ...tableCriteria.map((item) {
              final isPass = _isPassed(model.exitWayStatus, item);
              final isFail = _isFailed(model.exitWayStatus, item);
              final dim = _getDimension(model.itemDimensions, item);
              final hasDim = item.contains('unobstructed') || item.contains('180 mm') || item.contains('load >= 50') || item.contains('20 minutes');

              return pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text(item, style: const pw.TextStyle(fontSize: textBase))),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                    child: hasDim
                        ? pw.Container(
                            width: 50,
                            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                            child: pw.Text(dim, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
                          )
                        : pw.SizedBox(),
                  ),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isPass)),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isFail)),
                ],
              );
            }),
          ],
        ),

        pw.SizedBox(height: 10),

        // B. EXITS
        _sectionTitle('B.       EXITS'),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('[   ] Normal Stairs /  [   ] Curved Stairs /  [   ] Spiral Stairs /  [   ] Winding Stairs', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(height: 4),
              pw.Text('[   ] Horizontal Exits /  [   ] Outside Stairs / Exit Passageways / Fire Escape Stairs', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(height: 4),
              pw.Text('[   ] Fire Escape Ladder (for 1 & 2 family dwelling only)', style: const pw.TextStyle(fontSize: textBase)),
              pw.SizedBox(height: 4),
              pw.Text('[   ] Slide Escape (for Industrial Occupancy Only)', style: const pw.TextStyle(fontSize: textBase)),
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
  static pw.Widget _buildPage4(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp, String stationName) {
    final exitComponents = [
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

    final tableCriteria = [
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
        _header(dilg, bfp, stationName),
        pw.SizedBox(height: 12),

        // Unbordered Aligned Components List
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8, bottom: 4),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 140, child: pw.Text('Components', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(width: 90, child: pw.Text('Clear Width', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
              pw.SizedBox(width: 45, child: pw.Text('Passed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
              pw.SizedBox(width: 45, child: pw.Text('Failed', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
              pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.only(left: 8), child: pw.Text('Remarks / Corrective Action', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)))),
            ],
          ),
        ),
        ...exitComponents.map((item) {
          final isPass = _isPassed(model.exitWayStatus, item);
          final isFail = _isFailed(model.exitWayStatus, item);
          final dim = _getDimension(model.itemDimensions, item);
          final remark = _getRemark(model.itemRemarks, item);

          return pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, bottom: 2.5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(
                  width: 140,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(item, style: const pw.TextStyle(fontSize: textBase)),
                      pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 4),
                pw.Container(
                  width: 60,
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                  child: pw.Text(dim, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
                ),
                pw.SizedBox(width: 4),
                pw.SizedBox(width: 22, child: pw.Text('m', style: const pw.TextStyle(fontSize: textBase))),
                pw.SizedBox(width: 45, child: pw.Center(child: _bracketCheck(isPass))),
                pw.SizedBox(width: 45, child: pw.Center(child: _bracketCheck(isFail))),
                pw.SizedBox(width: 8),
                pw.Text(':', style: const pw.TextStyle(fontSize: textBase)),
                pw.SizedBox(width: 4),
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

        pw.SizedBox(height: 8),

        // Bordered Table
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(5.5),
            1: pw.FlexColumnWidth(1.4),
            2: pw.FlexColumnWidth(1.0),
            3: pw.FlexColumnWidth(1.0),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.0), child: pw.Text('', style: const pw.TextStyle(fontSize: textBase))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.0), child: pw.Text('Actual\nDim.', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.0), child: pw.Text('Passed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.0), child: pw.Text('Failed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            ...tableCriteria.map((item) {
              final isPass = _isPassed(model.exitWayStatus, item);
              final isFail = _isFailed(model.exitWayStatus, item);
              final dim = _getDimension(model.itemDimensions, item);
              final hasDim = !item.contains('open and close') && !item.contains('swing in direction') && !item.contains('panic hardware') && !item.contains('usable space') && !item.contains('Class B');

              return pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.0), child: pw.Text(item, style: const pw.TextStyle(fontSize: textBase))),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.0),
                    child: hasDim
                        ? pw.Container(
                            width: 50,
                            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                            child: pw.Text(dim, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
                          )
                        : pw.SizedBox(),
                  ),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.0), child: _bracketCheck(isPass)),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.0), child: _bracketCheck(isFail)),
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
  static pw.Widget _buildPage5(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp, String stationName) {
    final exitDischargeCriteria = [
      'Remoteness of exit discharge not less than 1/2 of length of the overall dimension of the building or area to be served.',
      'Remoteness of exit discharge not less than 1/3 of length of the overall dimension of the building or area to be served is the bldg. is protected throughout by ASASS.',
      'Exterior grounds are kept clear of objects that might impede evacuation or firefighting equipment',
      'Terminate directly at a public way or at an exterior exit discharge.',
    ];

    final egressMarkingCriteria = [
      'Minimum letter height, 150 mm',
      'EXIT signs are posted along Exit access, Exits and Exit discharge',
      'EXIT signs are properly illuminated',
    ];

    final evacuationPlanCriteria = [
      'Posted on strategic and conspicuous location inside the building',
      'Drawn with a photo-luminescent background to be readable in case of power failure.',
    ];

    final basicInfoItems = [
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
        _header(dilg, bfp, stationName),
        pw.SizedBox(height: 12),

        // C. EXITS DISCHARGE
        _sectionTitle('C.       EXITS DISCHARGE'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(5.5),
            1: pw.FlexColumnWidth(1.4),
            2: pw.FlexColumnWidth(1.0),
            3: pw.FlexColumnWidth(1.0),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('', style: const pw.TextStyle(fontSize: textBase))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Actual\nDim.', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Passed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Failed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            ...exitDischargeCriteria.map((item) {
              final isPass = _isPassed(model.exitWayStatus, item);
              final isFail = _isFailed(model.exitWayStatus, item);
              final dim = _getDimension(model.itemDimensions, item);
              final hasDim = item.contains('Remoteness');

              return pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text(item, style: const pw.TextStyle(fontSize: textBase))),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                    child: hasDim
                        ? pw.Container(
                            width: 50,
                            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                            child: pw.Text(dim, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
                          )
                        : pw.SizedBox(),
                  ),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isPass)),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isFail)),
                ],
              );
            }),
          ],
        ),

        pw.SizedBox(height: 12),

        // VI. SIGNS, LIGHTING, AND EXITS SIGNAGE
        _sectionTitle('VI.      SIGNS, LIGHTING, AND EXITS SIGNAGE'),
        _sectionTitle('A.       MARKING OF MEANS OF EGRESS (EXIT)'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(5.5),
            1: pw.FlexColumnWidth(1.4),
            2: pw.FlexColumnWidth(1.0),
            3: pw.FlexColumnWidth(1.0),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('', style: const pw.TextStyle(fontSize: textBase))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Actual\nDim.', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Passed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Failed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            ...egressMarkingCriteria.map((item) {
              final isPass = _isPassed(model.exitSignageStatus, item);
              final isFail = _isFailed(model.exitSignageStatus, item);
              final dim = _getDimension(model.itemDimensions, item);
              final hasDim = item.contains('150 mm');

              return pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text(item, style: const pw.TextStyle(fontSize: textBase))),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                    child: hasDim
                        ? pw.Container(
                            width: 50,
                            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                            child: pw.Text(dim, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
                          )
                        : pw.SizedBox(),
                  ),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isPass)),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isFail)),
                ],
              );
            }),
          ],
        ),

        pw.SizedBox(height: 12),

        // B. MARKING OF MEANS OF EGRESS (EMERGENCY EVACUATION PLAN)
        _sectionTitle('B.       MARKING OF MEANS OF EGRESS (EMERGENCY EVACUATION PLAN)'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(6.9),
            1: pw.FlexColumnWidth(1.0),
            2: pw.FlexColumnWidth(1.0),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('', style: const pw.TextStyle(fontSize: textBase))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Passed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Failed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            ...evacuationPlanCriteria.map((item) {
              final isPass = _isPassed(model.exitSignageStatus, item);
              final isFail = _isFailed(model.exitSignageStatus, item);
              return pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text(item, style: const pw.TextStyle(fontSize: textBase))),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isPass)),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isFail)),
                ],
              );
            }),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Containing the following basic information below', style: const pw.TextStyle(fontSize: textBase)),
                      pw.SizedBox(height: 2),
                      ...basicInfoItems.map((line) => pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8, bottom: 1),
                            child: pw.Text(line, style: const pw.TextStyle(fontSize: textSm)),
                          )),
                    ],
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(_isPassed(model.exitSignageStatus, 'Containing the following basic information below'))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(_isFailed(model.exitSignageStatus, 'Containing the following basic information below'))),
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
  static pw.Widget _buildPage6(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp, String stationName) {
    final isPassedP1 = _isPassed(model.exitSignageStatus, '330.2');
    final isFailedP1 = _isFailed(model.exitSignageStatus, '330.2');
    final isPassedP2 = _isPassed(model.exitSignageStatus, '50-150');
    final isFailedP2 = _isFailed(model.exitSignageStatus, '50-150');
    final isPassedP3 = _isPassed(model.exitSignageStatus, '151');
    final isFailedP3 = _isFailed(model.exitSignageStatus, '151');

    final illuminationCriteria = [
      'Floors and other walking surfaces: shall be at least 1 ft-candle (10.8 lux), measured at the floor.',
      'In assembly occupancies: walking surfaces of exit access shall be at least 0.2 ft-candle (2.2 lux)',
      'Stairs: shall be at least 10 ft-candle (108 lux), measured at the walking surfaces.',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(dilg, bfp, stationName),
        pw.SizedBox(height: 12),

        // Emergency Evacuation Plan Table (Continuation)
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(5.5),
            1: pw.FlexColumnWidth(1.4),
            2: pw.FlexColumnWidth(1.0),
            3: pw.FlexColumnWidth(1.0),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Emergency Evacuation Plan:', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Actual\nDim.', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Passed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Failed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('[   ] Size 330.2 mm wide * 215.9 mm height (Floor area < 50 m2)', style: const pw.TextStyle(fontSize: textBase)),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 12), child: pw.Text('-  Room or spaces', style: const pw.TextStyle(fontSize: textSm))),
                    ],
                  ),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Container(
                    width: 50,
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                    child: pw.Text(_getDimension(model.itemDimensions, '330.2'), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isPassedP1)),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isFailedP1)),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('[   ] Size 609.6 mm wide * 457.2 mm height (Floor area = 50 - 150 m2)', style: const pw.TextStyle(fontSize: textBase)),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 12), child: pw.Text('-  Room or spaces', style: const pw.TextStyle(fontSize: textSm))),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 12), child: pw.Text('-  Building lobbies upon entry.', style: const pw.TextStyle(fontSize: textSm))),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 12), child: pw.Text('-  Elevator lobbies at every floor.', style: const pw.TextStyle(fontSize: textSm))),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 12), child: pw.Text('-  Hallways and corridors.', style: const pw.TextStyle(fontSize: textSm))),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 12), child: pw.Text('-  On every bend/corner Or every 15m interval in the case of long hallway.', style: const pw.TextStyle(fontSize: textSm))),
                    ],
                  ),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Container(
                    width: 50,
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                    child: pw.Text(_getDimension(model.itemDimensions, '50-150'), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isPassedP2)),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isFailedP2)),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('[   ] Size 609.6 mm wide * 457.2 mm height (Floor area >= 151m2)', style: const pw.TextStyle(fontSize: textBase)),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 12), child: pw.Text('-  Room or spaces', style: const pw.TextStyle(fontSize: textSm))),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 12), child: pw.Text('-  Upon entry of the building', style: const pw.TextStyle(fontSize: textSm))),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 12), child: pw.Text('-  Area of assembly or every 25m interval in the case auditorium & gymnasium.', style: const pw.TextStyle(fontSize: textSm))),
                    ],
                  ),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Container(
                    width: 50,
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                    child: pw.Text(_getDimension(model.itemDimensions, '151'), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isPassedP3)),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isFailedP3)),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Symbols/icons/logos to be used for the marking shall be in accordance with NFPA 170, Standard for Signs and Symbols.', style: const pw.TextStyle(fontSize: textSm)),
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
        _sectionTitle('C.       ILLUMINATION OF MEANS OF EGRESS'),
        pw.Text('(All Data Below Shall be Referred from Manufacturers Specifications)', style: pw.TextStyle(fontSize: textSm, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 4),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(5.5),
            1: pw.FlexColumnWidth(1.4),
            2: pw.FlexColumnWidth(1.0),
            3: pw.FlexColumnWidth(1.0),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('', style: const pw.TextStyle(fontSize: textBase))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Actual\nLux/Time', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Passed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Failed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            ...illuminationCriteria.map((item) {
              final isPass = _isPassed(model.exitSignageStatus, item);
              final isFail = _isFailed(model.exitSignageStatus, item);
              final dim = _getDimension(model.itemDimensions, item);

              return pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text(item, style: const pw.TextStyle(fontSize: textBase))),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                    child: pw.Container(
                      width: 50,
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                      child: pw.Text(dim, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
                    ),
                  ),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isPass)),
                  pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isFail)),
                ],
              );
            }),
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Emergency Lighting', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Container(),
                pw.Container(),
                pw.Container(),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Text('[   ] Illumination not less than an average of 1 ft-candle (10.8 lux) and, at any point, not less than 0.1 ft-candle (1.1 lux), measured along the path of egress at floor level.', style: const pw.TextStyle(fontSize: textBase)),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Container(
                    width: 50,
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                    child: pw.Text(_getDimension(model.itemDimensions, 'Emergency lighting average'), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(_isPassed(model.exitSignageStatus, 'Emergency lighting average'))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(_isFailed(model.exitSignageStatus, 'Emergency lighting average'))),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Text('[   ] Emergency lighting system shall be arranged to provide the required illumination automatically in the event of any interruption of normal lighting (e.g. Failure of a public utility, ect..) for a period at least 1.5-hour.', style: const pw.TextStyle(fontSize: textBase)),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Container(
                    width: 50,
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                    child: pw.Text(_getDimension(model.itemDimensions, 'auto-activates'), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(_isPassed(model.exitSignageStatus, 'auto-activates'))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(_isFailed(model.exitSignageStatus, 'auto-activates'))),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Text('[   ] Periodic Testing of Emergency Lighting Equipment (Written record)', style: const pw.TextStyle(fontSize: textBase)),
                ),
                pw.Container(),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(_isPassed(model.exitSignageStatus, 'Periodic Testing of Emergency Lighting Equipment (Written record)'))),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(_isFailed(model.exitSignageStatus, 'Periodic Testing of Emergency Lighting Equipment (Written record)'))),
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
  static pw.Widget _buildPage7(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp, String stationName) {
    final isMaqYes = model.withinMaq?.toLowerCase() == 'yes';
    final isMaqNo = model.withinMaq?.toLowerCase() == 'no';

    final hc = model.hazardClassification?.toLowerCase() ?? '';
    final isLow = hc == 'low';
    final isOrdinary = hc == 'ordinary';
    final isHigh = hc == 'high';

    final flammableLiquidsCriteria = [
      'Stored in sealed metal containers',
      'Properly dispensed as per SOP',
      'Provided with "NO SMOKING" sign.',
    ];

    final miscHazardsCriteria = [
      'All no smoking areas has adequate signs.',
      'Gasoline/ Diesel is stored in the proper place and in a metal safety can.',
    ];

    final housekeepingCriteria = [
      'Brooms, mops, rags and other cleaning supplies stored in metal cabinets or approved cans',
      'Paints, solvents and other flammables stored in metal cabinet: oily rags in metal containers',
      'Dry leaves, shrubbery trimmings and other combustibles kept away from buildings',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(dilg, bfp, stationName),
        pw.SizedBox(height: 12),

        _sectionTitle('VII.     HAZARD'),
        pw.SizedBox(height: 6),

        // 2-column underlined fields
        pw.Row(
          children: [
            pw.Text('Hazard Contents            : ', style: const pw.TextStyle(fontSize: textBase)),
            pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.only(bottom: 1.5), decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.hazardContents, style: const pw.TextStyle(fontSize: textBase)))),
            pw.SizedBox(width: 14),
            pw.Text('Quantity (Vol. / Weight) : ', style: const pw.TextStyle(fontSize: textBase)),
            pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.only(bottom: 1.5), decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.hazardQuantity, style: const pw.TextStyle(fontSize: textBase)))),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          children: [
            pw.Text('Hazard Identification     : ', style: const pw.TextStyle(fontSize: textBase)),
            pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.only(bottom: 1.5), decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.hazardPlacard, style: const pw.TextStyle(fontSize: textBase)))),
            pw.SizedBox(width: 14),
            pw.Text('Within MAQ                     : ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isMaqYes),
            pw.Text(' Yes / ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isMaqNo),
            pw.Text(' No', style: const pw.TextStyle(fontSize: textBase)),
            pw.Spacer(),
          ],
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 4),
          child: pw.Text('Placard', style: const pw.TextStyle(fontSize: textSm)),
        ),
        pw.SizedBox(height: 3),
        pw.Row(
          children: [
            pw.Text('Hazard                           : ', style: const pw.TextStyle(fontSize: textBase)),
            pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.only(bottom: 1.5), decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.hazardIdentificationNo, style: const pw.TextStyle(fontSize: textBase)))),
            pw.SizedBox(width: 14),
            pw.Text('Hazard Classification: ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isLow),
            pw.Text(' Low / ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isOrdinary),
            pw.Text(' Ordinary / ', style: const pw.TextStyle(fontSize: textBase)),
            _bracketCheck(isHigh),
            pw.Text(' High', style: const pw.TextStyle(fontSize: textBase)),
          ],
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 4),
          child: pw.Text('Identification No.', style: const pw.TextStyle(fontSize: textSm)),
        ),
        pw.SizedBox(height: 3),
        pw.Row(
          children: [
            pw.Text('Class                               : ', style: const pw.TextStyle(fontSize: textBase)),
            pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.only(bottom: 1.5), decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.hazardClass, style: const pw.TextStyle(fontSize: textBase)))),
            pw.SizedBox(width: 14),
            pw.Text('Flash Point                      : ', style: const pw.TextStyle(fontSize: textBase)),
            pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.only(bottom: 1.5), decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))), child: pw.Text(model.flashPoint, style: const pw.TextStyle(fontSize: textBase)))),
          ],
        ),

        pw.SizedBox(height: 8),
        pw.Text('Low hazard contents shall be classified as those of such low combustibility that no self-propagating fire therein can occur.', style: pw.TextStyle(fontSize: textSm, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 3),
        pw.Text('Ordinary hazard contents shall be classified as those that are likely to burn with moderate rapidity or to give off a considerable volume of smoke.', style: pw.TextStyle(fontSize: textSm, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 3),
        pw.Text('High hazard contents shall be classified as those that are likely to burn with extreme rapidity or from which explosions are likely.', style: pw.TextStyle(fontSize: textSm, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 12),

        // A. OTHER FLAMMABLE LIQUIDS
        _sectionTitle('A.       OTHER FLAMMABLE LIQUIDS (I.E. ALCOHOL, ETHER, ETC...)'),
        pw.SizedBox(height: 4),
        _buildSimpleCheckTable(flammableLiquidsCriteria, model.fireProtectionStatus),
        pw.SizedBox(height: 12),

        // B. MISCELLANEOUS HAZARDS
        _sectionTitle('B.       MISCELLANEOUS HAZARDS (MECHANICAL EQUIPMENT ROOM, STORAGE, SUPPLY ROOM)'),
        pw.SizedBox(height: 4),
        _buildSimpleCheckTable(miscHazardsCriteria, model.fireProtectionStatus),
        pw.SizedBox(height: 12),

        // C. HOUSEKEEPING, MAINTENANCE, STORAGE & WASTE DISPOSAL
        _sectionTitle('C.       HOUSEKEEPING, MAINTENANCE, STORAGE & WASTE DISPOSAL'),
        pw.SizedBox(height: 4),
        _buildSimpleCheckTable(housekeepingCriteria, model.fireProtectionStatus),

        pw.Spacer(),
        _footer(7),
      ],
    );
  }

  static pw.Widget _buildSimpleCheckTable(List<String> items, Map<String, String> statusMap) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(6.9),
        1: pw.FlexColumnWidth(1.0),
        2: pw.FlexColumnWidth(1.0),
      },
      children: [
        pw.TableRow(
          children: [
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('', style: const pw.TextStyle(fontSize: textBase))),
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Passed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Failed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        ...items.map((item) {
          final isPass = _isPassed(statusMap, item);
          final isFail = _isFailed(statusMap, item);
          return pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text(item, style: const pw.TextStyle(fontSize: textBase))),
              pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isPass)),
              pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(isFail)),
            ],
          );
        }),
      ],
    );
  }

  // ==========================================
  // PAGE 8 BUILDER
  // ==========================================
  static pw.Widget _buildPage8(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp, String stationName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(dilg, bfp, stationName),
        pw.SizedBox(height: 10),

        _sectionTitle('VIII.    FIRE PROTECTION'),
        pw.SizedBox(height: 4),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.6),
            1: pw.FlexColumnWidth(4.5),
            2: pw.FlexColumnWidth(1.0),
            3: pw.FlexColumnWidth(1.0),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.0), child: pw.Text('Item to Inspect', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.0), child: pw.Text('Procedure How to Inspect', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.0), child: pw.Text('Passed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.0), child: pw.Text('Failed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              ],
            ),

            // A. Automatic Fire Suppression System (Sprinkler)
            _tableSectionHeaderRow('A.    Automatic Fire Suppression System (Sprinkler)'),
            _tableRow4Col('Sprinkler Pumps', 'Check automatic start and pressure.', _isPassed(model.fireProtectionStatus, 'Sprinkler Pumps'), _isFailed(model.fireProtectionStatus, 'Sprinkler Pumps')),
            _tableRow4Col('Sprinkler Valves', 'Valves are locked in the open position, no leaks, corrosion, or other defects noted.', _isPassed(model.fireProtectionStatus, 'Sprinkler Valves'), _isFailed(model.fireProtectionStatus, 'Sprinkler Valves')),
            _tableRow4Col('Sprinkler water flow alarm', 'Open test valve and ensure manual alarm bell functions and sprinkler pumps start.', _isPassed(model.fireProtectionStatus, 'Sprinkler water flow alarm'), _isFailed(model.fireProtectionStatus, 'Sprinkler water flow alarm')),

            // B. Wet Standpipe/Fire Hose Cabinet
            _tableSectionHeaderRow('B.    Wet Standpipe/Fire Hose Cabinet'),
            _tableRow4Col('Cabinet Door Operative', 'Check that door is unobstructed and opens properly.', _isPassed(model.fireProtectionStatus, 'Cabinet Door Operative'), _isFailed(model.fireProtectionStatus, 'Cabinet Door Operative')),
            _tableRow4Col('Hose Condition', 'Check that hose is not rotted, wet, moldy, etc.', _isPassed(model.fireProtectionStatus, 'Hose Condition'), _isFailed(model.fireProtectionStatus, 'Hose Condition')),
            _tableRow4Col('Nozzle', 'Check that nozzle is in place and operates correctly.', _isPassed(model.fireProtectionStatus, 'Nozzle'), _isFailed(model.fireProtectionStatus, 'Nozzle')),
            _tableRow4Col('Hose hung properly', 'Check that hose is hung properly so that it can easily be un-rolled if needed.', _isPassed(model.fireProtectionStatus, 'Hose hung properly'), _isFailed(model.fireProtectionStatus, 'Hose hung properly')),
            _tableRow4Col('Valves and valve handles', 'Check that valve handles are in place and that valves operate properly and are in the open position.', _isPassed(model.fireProtectionStatus, 'Valves and valve handles'), _isFailed(model.fireProtectionStatus, 'Valves and valve handles')),

            // C. Fire Pump
            _tableSectionHeaderRow('C.    Fire Pump'),
            _tableRow4Col('Pump System', 'Inspect accuracy of pressure gauges and sensors', _isPassed(model.fireProtectionStatus, 'Pump System'), _isFailed(model.fireProtectionStatus, 'Pump System')),
            _tableRow4Col('Pipings', 'Check pipings if there is leak', _isPassed(model.fireProtectionStatus, 'Pipings'), _isFailed(model.fireProtectionStatus, 'Pipings')),
            _tableRow4Col('Motor', 'Check unusual noise or vibrations', _isPassed(model.fireProtectionStatus, 'Motor'), _isFailed(model.fireProtectionStatus, 'Motor')),
            _tableRow4Col('Electrical System', 'Check if there is corrosion in PCBs, cracked cable/wire insulation, leak in plumbing parts, sign of water in electrical part', _isPassed(model.fireProtectionStatus, 'Electrical System'), _isFailed(model.fireProtectionStatus, 'Electrical System')),

            // D. Fire Detection System
            _tableSectionHeaderRow('D.    Fire Detection System'),
            _tableRow4Col('Fire Detection System', 'Random Test of call points and smoke detectors.', _isPassed(model.fireProtectionStatus, 'Fire Detection System'), _isFailed(model.fireProtectionStatus, 'Fire Detection System')),

            // E. Fire Alarm Facilities
            _tableSectionHeaderRow('E.    Fire Alarm Facilities'),
            _tableRow4Col('Location Signs', 'Check all signs are in place and legible.', _isPassed(model.fireProtectionStatus, 'Location Signs'), _isFailed(model.fireProtectionStatus, 'Location Signs')),
            _tableRow4Col('Alarm Panels', 'Check that all alarm panels are functioning correctly and are unobstructed.', _isPassed(model.fireProtectionStatus, 'Alarm Panels'), _isFailed(model.fireProtectionStatus, 'Alarm Panels')),

            // F. Lifts (Elevator)
            _tableSectionHeaderRow('F.    Lifts (Elevator)'),
            _tableRow4Col('Lifts', 'All lifts "home" to ground floor during fire test, doors open and lift stops.', _isPassed(model.fireProtectionStatus, 'Lifts'), _isFailed(model.fireProtectionStatus, 'Lifts')),
            _tableRow4Col('Fans', 'All lift fans operate correctly.', _isPassed(model.fireProtectionStatus, 'Fans'), _isFailed(model.fireProtectionStatus, 'Fans')),
            _tableRow4Col('Fireman\'s lift', 'Fireman\'s lift can be keyed to operate during fire alarm test.', _isPassed(model.fireProtectionStatus, 'Fireman\'s lift'), _isFailed(model.fireProtectionStatus, 'Fireman\'s lift')),
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
  static pw.Widget _buildPage9(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp, String stationName) {
    final bse1Pass = _isPassed(model.bseStatus, 'Utilities AKHFSS');
    final bse1Fail = _isFailed(model.bseStatus, 'Utilities AKHFSS');
    final bse2Pass = _isPassed(model.bseStatus, 'HVAC PMEC');
    final bse2Fail = _isFailed(model.bseStatus, 'HVAC PMEC');
    final bse3Pass = _isPassed(model.bseStatus, 'Smoke Control System');
    final bse3Fail = _isFailed(model.bseStatus, 'Smoke Control System');
    final bse4Pass = _isPassed(model.bseStatus, 'Rubbish Chutes');
    final bse4Fail = _isFailed(model.bseStatus, 'Rubbish Chutes');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(dilg, bfp, stationName),
        pw.SizedBox(height: 10),

        // Section VIII Table Continuation
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.6),
            1: pw.FlexColumnWidth(4.5),
            2: pw.FlexColumnWidth(1.0),
            3: pw.FlexColumnWidth(1.0),
          },
          children: [
            // G. First Aid Fire Protection (Fire Extinguishers)
            _tableSectionHeaderRow('G.    First Aid Fire Protection (Fire Extinguishers)'),
            _tableRow4Col('Fire Extinguisher Size', 'Minimal sizes of fire extinguishers for the listed grades of hazards shall be provided on the basis of table 7 & 8 of RIRR of RA 9514.', _isPassed(model.fireProtectionStatus, 'Fire Extinguisher Size'), _isFailed(model.fireProtectionStatus, 'Fire Extinguisher Size')),
            _tableRow4Col('Minimum number of Extinguisher.', 'The minimum number of extinguishers shall be sufficient to meet the requirements of table 7 & 8 of RIRR of RA 9514.', _isPassed(model.fireProtectionStatus, 'Minimum number of Extinguisher.'), _isFailed(model.fireProtectionStatus, 'Minimum number of Extinguisher.')),
            _tableRow4Col('Location', 'All extinguishers are in their proper location.', _isPassed(model.fireProtectionStatus, 'Location'), _isFailed(model.fireProtectionStatus, 'Location')),
            _tableRow4Col('Seals & Tags', 'Extinguisher seals and tags are intact and extinguisher was serviced in the last 12 months.', _isPassed(model.fireProtectionStatus, 'Seals & Tags'), _isFailed(model.fireProtectionStatus, 'Seals & Tags')),
            _tableRow4Col('Markings', 'Proper marking on extinguisher to indicate the type of fire the extinguisher can be used on.', _isPassed(model.fireProtectionStatus, 'Markings'), _isFailed(model.fireProtectionStatus, 'Markings')),
            _tableRow4Col('Condition', 'No leaks, corrosion or other defects noticed.', _isPassed(model.fireProtectionStatus, 'Condition'), _isFailed(model.fireProtectionStatus, 'Condition')),
            _tableRow4Col('Pressure', 'Pressure gauge reads in the "green" area.', _isPassed(model.fireProtectionStatus, 'Pressure'), _isFailed(model.fireProtectionStatus, 'Pressure')),

            // H. Emergency Lighting Systems
            _tableSectionHeaderRow('H.    Emergency Lighting Systems'),
            _tableRow4Col('Battery Lights', 'All battery powered emergency lighting turns on when mains power is removed', _isPassed(model.fireProtectionStatus, 'Battery Lights'), _isFailed(model.fireProtectionStatus, 'Battery Lights')),

            // I. Kitchen
            _tableSectionHeaderRow('I.    Kitchen'),
            _tableRow4Col('Hoods & Vents', 'Hoods, vents, fans and ducts in good condition and free from grease', _isPassed(model.fireProtectionStatus, 'Kitchen Hoods & Vents'), _isFailed(model.fireProtectionStatus, 'Kitchen Hoods & Vents')),
            _tableRow4Col('Hood Filters', _getDimension(model.itemDimensions, 'Hood Filters').isNotEmpty ? 'Date of Last Cleaning: ${_getDimension(model.itemDimensions, 'Hood Filters')}' : 'Date of Last Cleaning', _isPassed(model.fireProtectionStatus, 'Kitchen Hoods & Vents'), _isFailed(model.fireProtectionStatus, 'Kitchen Hoods & Vents')),
          ],
        ),

        pw.SizedBox(height: 14),

        // J. BUILDING SERVICE EQUIPMENT
        _sectionTitle('J.        BUILDING SERVICE EQUIPMENT'),
        pw.SizedBox(height: 6),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(6.9),
            1: pw.FlexColumnWidth(1.0),
            2: pw.FlexColumnWidth(1.0),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('', style: const pw.TextStyle(fontSize: textBase))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Passed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Failed', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('1.  Utilities:', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 14),
                        child: pw.Text('Cooking equipment protected by AKHFSS (Restaurant and similar establishment with Occupant Load > 50p)', style: const pw.TextStyle(fontSize: textBase)),
                      ),
                    ],
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(bse1Pass)),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(bse1Fail)),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('2.  Heating, Ventilating and Air-conditioning:', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 14),
                        child: pw.Text('Design & Installation in accordance with PMEC', style: const pw.TextStyle(fontSize: textBase)),
                      ),
                    ],
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(bse2Pass)),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(bse2Fail)),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('3.  Smoke Control Systems/Smoke Management shall be provided in the following:', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 14), child: pw.Text('[   ] All high-rise buildings (stairwells, at least 1 elevator shaft, zoned smoke control, and vestibule).', style: const pw.TextStyle(fontSize: textSm))),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 14), child: pw.Text('[   ] Pressurization of smoke refuge area.', style: const pw.TextStyle(fontSize: textSm))),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 14), child: pw.Text('[   ] Every Atrium of covered mall of over 2- levels / Other type of Occupancy over 3 - levels.', style: const pw.TextStyle(fontSize: textSm))),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 14), child: pw.Text('[   ] Underground structure and windowless facilities.', style: const pw.TextStyle(fontSize: textSm))),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 14), child: pw.Text('[   ] All movie houses.', style: const pw.TextStyle(fontSize: textSm))),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 14), child: pw.Text('[   ] All other buildings or structures with at least 1,115m2 single floor area.', style: const pw.TextStyle(fontSize: textSm))),
                    ],
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(bse3Pass)),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(bse3Fail)),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('4.  Rubbish Chutes, Laundry Chutes, and Flue-Fed Incinerators:', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 14), child: pw.Text('(not apply to detached single- or two-family dwelling)', style: const pw.TextStyle(fontSize: textSm))),
                      pw.SizedBox(height: 2),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 14), child: pw.Text('[   ] Chutes & Incinerators shall be enclosed.', style: const pw.TextStyle(fontSize: textSm))),
                      pw.Padding(padding: const pw.EdgeInsets.only(left: 14), child: pw.Text('[   ] Design and Maintained in accordance with the latest edition of PMEC.', style: const pw.TextStyle(fontSize: textSm))),
                    ],
                  ),
                ),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(bse4Pass)),
                pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: _bracketCheck(bse4Fail)),
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
  static pw.Widget _buildPage10(CommercialChecklistModel model, pw.MemoryImage? dilg, pw.MemoryImage? bfp, String stationName) {
    final isFwYes = model.fireWallProvided?.toLowerCase() == 'yes';
    final isFwNo = model.fireWallProvided?.toLowerCase() == 'no';
    final isExtYes = model.fireWallExtension?.toLowerCase() == 'yes';
    final isExtNo = model.fireWallExtension?.toLowerCase() == 'no';

    final wt = model.fireWallType?.toLowerCase() ?? '';
    final isConcrete = wt.contains('concrete') || wt.contains('125');
    final isMasonry = wt.contains('masonry') || wt.contains('150');
    final isChb = wt.contains('hallow') || wt.contains('chb') || wt.contains('200');

    final rec = (model.recommendationAction ?? 'FSIC').toUpperCase();
    final isFsicRec = rec.contains('FSIC') || rec.contains('PASS') || rec.contains('COMPLY');
    final isNtc = rec == 'NTC';
    final isNtcv = rec == 'NTCV';
    final isClosure = rec.contains('CLOSURE');
    final isAbatement = rec.contains('ABATEMENT');

    // Categorized defects
    final defectsIV = _getDefectsLine(model, 'IV');
    final defectsV = _getDefectsLine(model, 'V');
    final defectsVI = _getDefectsLine(model, 'VI');
    final defectsVII = _getDefectsLine(model, 'VII');
    final defectsVIII = _getDefectsLine(model, 'VIII');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(dilg, bfp, stationName),
        pw.SizedBox(height: 10),

        // K. FIRE WALL (FW) (if required)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('K.      ', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
            pw.Expanded(
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(6.0),
                  1: pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('FIRE WALL (FW) (if required)', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                      pw.Container(),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5), child: pw.Text('Provided with Fire Wall (minimum 2 hours fire resistance)', style: const pw.TextStyle(fontSize: textBase))),
                      pw.Container(
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            _bracketCheck(isFwYes),
                            pw.Text(' Yes / ', style: const pw.TextStyle(fontSize: textBase)),
                            _bracketCheck(isFwNo),
                            pw.Text(' No', style: const pw.TextStyle(fontSize: textBase)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
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
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            _bracketCheck(isExtYes),
                            pw.Text(' Yes / ', style: const pw.TextStyle(fontSize: textBase)),
                            _bracketCheck(isExtNo),
                            pw.Text(' No', style: const pw.TextStyle(fontSize: textBase)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                        child: pw.Row(
                          children: [
                            pw.Text('Wall type: ', style: const pw.TextStyle(fontSize: textBase)),
                            _bracketCheck(isConcrete),
                            pw.Text(' 125mm Solid Concrete / ', style: const pw.TextStyle(fontSize: textBase)),
                            _bracketCheck(isMasonry),
                            pw.Text(' 150mm Solid Masonry / ', style: const pw.TextStyle(fontSize: textBase)),
                            _bracketCheck(isChb),
                            pw.Text(' 200mm Hallow Unit Masonry', style: const pw.TextStyle(fontSize: textBase)),
                          ],
                        ),
                      ),
                      pw.Container(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 10),

        // DEFECTS / DEFICIENCIES
        pw.Text('DEFECTS/DEFICIENCIES', style: pw.TextStyle(fontSize: textHeading, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),

        _buildDefectUnderlineRow('ITEM IV:', defectsIV[0]),
        _buildDefectUnderlineRow('ITEM V:', defectsV[0]),
        _buildDefectUnderlineRow('', defectsV.length > 1 ? defectsV[1] : ''),
        _buildDefectUnderlineRow('ITEM VI:', defectsVI[0]),
        _buildDefectUnderlineRow('', defectsVI.length > 1 ? defectsVI[1] : ''),
        _buildDefectUnderlineRow('ITEM VII:', defectsVII[0]),
        _buildDefectUnderlineRow('ITEM VIII:', defectsVIII[0]),
        _buildDefectUnderlineRow('', defectsVIII.length > 1 ? defectsVIII[1] : ''),

        pw.SizedBox(height: 10),

        // IX. RECOMMENDATIONS
        _sectionTitle('IX.      RECOMMENDATIONS'),
        pw.SizedBox(height: 4),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _bracketCheck(isFsicRec),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Text(
                      'Comply the following DEFFECTS/DEFICIENCIES stated above and pay the corresponding Fire Code Fees including the Storage Clearance Fee , Conveyance Clearance Fee before the issuance of Fire Safety Inspection Certificate (FSIC)',
                      style: const pw.TextStyle(fontSize: textBase),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _bracketCheck(!isFsicRec),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('For issuance of', style: const pw.TextStyle(fontSize: textBase)),
                        pw.SizedBox(height: 2.5),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 20),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(children: [_bracketCheck(isNtc), pw.SizedBox(width: 4), pw.Text('Notice to Comply', style: const pw.TextStyle(fontSize: textBase))]),
                              pw.SizedBox(height: 2),
                              pw.Row(children: [_bracketCheck(isNtcv), pw.SizedBox(width: 4), pw.Text('Notice to Correct Violation', style: const pw.TextStyle(fontSize: textBase))]),
                              pw.SizedBox(height: 2),
                              pw.Row(children: [_bracketCheck(isClosure && !rec.contains('NON-PAYMENT')), pw.SizedBox(width: 4), pw.Text('Closure Order', style: const pw.TextStyle(fontSize: textBase))]),
                              pw.SizedBox(height: 2),
                              pw.Row(children: [_bracketCheck(isAbatement), pw.SizedBox(width: 4), pw.Text('Abatement Order with Administrative Fine', style: const pw.TextStyle(fontSize: textBase))]),
                              pw.SizedBox(height: 2),
                              pw.Row(children: [_bracketCheck(rec.contains('NON-PAYMENT')), pw.SizedBox(width: 4), pw.Text('Closure Order for the non-payment of Administrative Fine', style: const pw.TextStyle(fontSize: textBase))]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 12),

        // ACKNOWLEDGED BY
        pw.Text('ACKNOWLEDGED BY:', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 16),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Container(
                    width: 155,
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                    child: pw.Text(
                      model.ownerRepresentative.isNotEmpty ? model.ownerRepresentative : ' ',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text('Signature Over Printed Name of\nOwner/ Representative', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textSm)),
                ],
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Container(
                    width: 155,
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                    child: pw.Text(
                      model.inspectorName.isNotEmpty ? model.inspectorName : ' ',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text('Fire Safety Inspector/s\n ', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textSm)),
                ],
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Container(
                    width: 155,
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                    child: pw.Text(
                      model.teamLeaderName.isNotEmpty ? model.teamLeaderName : ' ',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text('Team Leader\n ', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textSm)),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Text('Date & Time: ', style: const pw.TextStyle(fontSize: textBase)),
            pw.Container(
              width: 140,
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
              child: pw.Text(model.dateInspected, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: textBase)),
            ),
          ],
        ),

        pw.SizedBox(height: 12),

        // RECOMMEND APPROVAL
        pw.Row(
          children: [
            pw.Spacer(flex: 2),
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text('RECOMMEND APPROVAL:', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(height: 14),
                  pw.Container(
                    width: double.infinity,
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                    child: pw.Text(
                      model.chiefFsesName.isNotEmpty ? model.chiefFsesName : ' ',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text('CHIEF, FIRE SAFETY ENFORCEMENT SECTION/UNIT', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textSm, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 12),

        // APPROVAL
        pw.Row(
          children: [
            pw.Spacer(flex: 2),
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text('APPROVAL:', style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(height: 14),
                  pw.Container(
                    width: double.infinity,
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                    child: pw.Text(
                      model.fireMarshalName.isNotEmpty ? model.fireMarshalName : ' ',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text('CITY/ MUNICIPAL FIRE MARSHAL', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: textSm, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),

        pw.Spacer(),
        _footer(10),
      ],
    );
  }

  static pw.Widget _buildDefectUnderlineRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (label.isNotEmpty)
            pw.SizedBox(
              width: 65,
              child: pw.Text(label, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
            )
          else
            pw.SizedBox(width: 65),
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)),
              ),
              padding: const pw.EdgeInsets.only(left: 4, bottom: 1.0),
              child: pw.Text(
                value,
                style: const pw.TextStyle(fontSize: textBase),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<String> _getDefectsLine(CommercialChecklistModel model, String section) {
    final List<String> findings = [];

    // Check failed items in this section
    if (section == 'IV') {
      if (model.fsicNoLatest.isEmpty) findings.add('No Latest FSIC presented');
      if (model.fireDrillCertNo.isEmpty) findings.add('No Certificate of Fire Drill on file');
    } else if (section == 'V') {
      model.exitWayStatus.forEach((k, v) {
        if (v.toLowerCase() == 'failed') findings.add(k);
      });
    } else if (section == 'VI') {
      model.exitSignageStatus.forEach((k, v) {
        if (v.toLowerCase() == 'failed') findings.add(k);
      });
    } else if (section == 'VII') {
      if (model.hazardContents.isNotEmpty && (model.withinMaq == 'No' || model.hazardPlacard.isEmpty)) {
        findings.add('Hazardous materials stored exceed MAQ or missing placards');
      }
    } else if (section == 'VIII') {
      model.fireProtectionStatus.forEach((k, v) {
        if (v.toLowerCase() == 'failed') findings.add(k);
      });
      model.bseStatus.forEach((k, v) {
        if (v.toLowerCase() == 'failed') findings.add(k);
      });
    }

    if (findings.isEmpty && model.defectsSummary.isNotEmpty && section == 'V') {
      return [model.defectsSummary, ''];
    }

    if (findings.isEmpty) {
      return ['None noted / Compliant', ''];
    }

    final line1 = findings.take(2).join('; ');
    final line2 = findings.length > 2 ? findings.skip(2).join('; ') : '';
    return [line1, line2];
  }

  // ==========================================
  // TABLE HELPER ROWS FOR SECTION VIII
  // ==========================================
  static pw.TableRow _tableSectionHeaderRow(String title) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
          child: pw.Text(title, style: pw.TextStyle(fontSize: textBase, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Container(),
        pw.Container(),
        pw.Container(),
      ],
    );
  }

  static pw.TableRow _tableRow4Col(String item, String procedure, bool isPassed, bool isFailed) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.8), child: pw.Text(item, style: const pw.TextStyle(fontSize: textBase))),
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.8), child: pw.Text(procedure, style: const pw.TextStyle(fontSize: textSm))),
        pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.8), child: _bracketCheck(isPassed)),
        pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.8), child: _bracketCheck(isFailed)),
      ],
    );
  }
}
