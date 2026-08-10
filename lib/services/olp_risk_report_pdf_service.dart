import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OlpRiskReportPdfService {
  static final PdfPageFormat pageFormat = PdfPageFormat.letter.landscape;
  static const pw.EdgeInsets pageMargin = pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24);

  static Future<void> generateAndPrintOlpPdf({
    required List<Map<String, dynamic>> surveys,
    required int highRiskCount,
    required int mediumRiskCount,
    required int lowRiskCount,
    String? officerName,
  }) async {
    final pdf = await buildDocument(
      surveys: surveys,
      highRiskCount: highRiskCount,
      mediumRiskCount: mediumRiskCount,
      lowRiskCount: lowRiskCount,
      officerName: officerName,
    );

    final timestamp = DateTime.now().toIso8601String().split('T').first;
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'BFP_OLP_Risk_Assessment_Report_$timestamp.pdf',
    );
  }

  static Future<pw.Document> buildDocument({
    required List<Map<String, dynamic>> surveys,
    required int highRiskCount,
    required int mediumRiskCount,
    required int lowRiskCount,
    String? officerName,
  }) async {
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

    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pageMargin,
        header: (pw.Context context) => _buildHeader(dilgLogo, bfpLogo),
        footer: (pw.Context context) => _buildFooter(context),
        build: (pw.Context context) => [
          _buildSummaryStats(surveys.length, highRiskCount, mediumRiskCount, lowRiskCount, officerName, dateStr),
          pw.SizedBox(height: 14),
          _buildSurveysTable(surveys),
          pw.SizedBox(height: 20),
          _buildSignatures(officerName),
        ],
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeader(pw.MemoryImage? dilgLogo, pw.MemoryImage? bfpLogo) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (dilgLogo != null)
              pw.Image(dilgLogo, width: 44, height: 44)
            else
              pw.SizedBox(width: 44),
            pw.Column(
              children: [
                pw.Text(
                  'Republic of the Philippines',
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Department of the Interior and Local Government',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  'BUREAU OF FIRE PROTECTION',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                ),
                pw.Text(
                  'Regional Office 1 • Pangasinan Fire District',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  'LINGAYEN MUNICIPAL FIRE STATION',
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange800),
                ),
                pw.Text(
                  'Community Risk & Oplan Ligtas na Pamayanan (OLP) Enforcement Division',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],
            ),
            if (bfpLogo != null)
              pw.Image(bfpLogo, width: 44, height: 44)
            else
              pw.SizedBox(width: 44),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(width: double.infinity, height: 1.5, color: PdfColors.blue900),
        pw.SizedBox(height: 2),
        pw.Container(width: double.infinity, height: 0.5, color: PdfColors.deepOrange800),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            'OPLAN LIGTAS NA PAMAYANAN (OLP) COMMUNITY RISK & VULNERABILITY SUMMARY REPORT',
            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
          ),
        ),
        pw.Center(
          child: pw.Text(
            'Barangay Fire Protection Plan (CFPP) & Household Safety Audit Archive Log',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildSummaryStats(
    int total,
    int high,
    int med,
    int low,
    String? officerName,
    String dateStr,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Reporting Risk Officer: ${officerName != null && officerName.isNotEmpty ? officerName : "Community Risk Officer (CRO)"}',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Municipality of Lingayen • Date Exported: $dateStr',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.Row(
            children: [
              _buildStatPill('Total Surveys', '$total', PdfColors.blue900),
              pw.SizedBox(width: 8),
              _buildStatPill('High Risk Zones', '$high', PdfColors.red800),
              pw.SizedBox(width: 8),
              _buildStatPill('Medium Risk Zones', '$med', PdfColors.amber800),
              pw.SizedBox(width: 8),
              _buildStatPill('Low Risk Zones', '$low', PdfColors.green800),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStatPill(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: color, width: 0.8),
      ),
      child: pw.Row(
        children: [
          pw.Text('$label: ', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _buildSurveysTable(List<Map<String, dynamic>> surveys) {
    if (surveys.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(24),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Text('No OLP community risk surveys recorded matching selected filters.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      );
    }

    final headers = [
      '#',
      'Barangay / Location',
      'Survey Type',
      'Surveyor Name',
      'Date Assessed',
      'Key Findings & Hazards',
      'Vulnerability Rating',
    ];

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blue900),
        children: headers.map((h) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(
              h,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              textAlign: h == '#' ? pw.TextAlign.center : pw.TextAlign.left,
            ),
          );
        }).toList(),
      ),
    ];

    for (int i = 0; i < surveys.length; i++) {
      final s = surveys[i];
      final bgy = (s['barangay'] ?? s['barangay_name'] ?? 'Poblacion').toString();
      final type = (s['survey_type'] ?? s['checklist_type'] ?? 'CFPP Barangay Assessment').toString();
      final surveyor = (s['surveyor_name'] ?? 'Community Risk Officer').toString();
      final dateStr = (s['created_at'] ?? s['date_inspected'] ?? '').toString().split('T').first;
      final risk = (s['risk_level'] ?? s['vulnerability_rating'] ?? 'Medium').toString();
      final findings = (s['findings'] ?? s['hazards_summary'] ?? s['survey_data']?['notes'] ?? 'Standard community assessment').toString();

      final isEven = i % 2 == 0;
      final rowColor = isEven ? PdfColors.white : PdfColors.grey100;

      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: rowColor),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
              child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.center),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
              child: pw.Text('Brgy. $bgy', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
              child: pw.Text(type.replaceAll('_', ' ').toUpperCase(), style: const pw.TextStyle(fontSize: 7)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
              child: pw.Text(surveyor, style: const pw.TextStyle(fontSize: 7.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
              child: pw.Text(dateStr, style: const pw.TextStyle(fontSize: 7.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
              child: pw.Text(
                findings.length > 50 ? '${findings.substring(0, 50)}...' : findings,
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
              child: pw.Text(
                risk.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _getRiskColor(risk),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(22),
        1: pw.FlexColumnWidth(1.8),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.1),
        5: pw.FlexColumnWidth(2.2),
        6: pw.FlexColumnWidth(1.2),
      },
      children: tableRows,
    );
  }

  static pw.Widget _buildSignatures(String? officerName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSignatoryBox('PREPARED BY:', officerName ?? 'Community Risk Officer', 'Community Risk Officer (CRO)'),
        _buildSignatoryBox('VERIFIED BY:', 'SFO1 OLP Focal Person', 'OLP Operations Section'),
        _buildSignatoryBox('REVIEWED BY:', 'INSP Chief FSES, BFP', 'Chief, Fire Safety Enforcement'),
        _buildSignatoryBox('NOTED & APPROVED BY:', 'CINSP BFP Fire Marshal', 'Municipal Fire Marshal'),
      ],
    );
  }

  static pw.Widget _buildSignatoryBox(String heading, String name, String designation) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(heading, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
        pw.SizedBox(height: 22),
        pw.Container(width: 140, height: 0.5, color: PdfColors.black),
        pw.SizedBox(height: 2),
        pw.Text(name, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.Text(designation, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('BFP Lingayen Municipal Fire Station • OLP Community Risk Division', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static PdfColor _getRiskColor(String risk) {
    final r = risk.toUpperCase();
    if (r.contains('HIGH')) return PdfColors.red800;
    if (r.contains('MED')) return PdfColors.amber800;
    return PdfColors.green800;
  }
}
