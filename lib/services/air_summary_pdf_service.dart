import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AirSummaryPdfService {
  // Use Letter Landscape for tabular log readability
  static final PdfPageFormat pageFormat = PdfPageFormat.letter.landscape;

  static const pw.EdgeInsets pageMargin = pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24);

  static Future<void> generateAndPrintAirSummaryPdf({
    required List<Map<String, dynamic>> reports,
    required Map<String, int> stats,
    String? inspectorName,
  }) async {
    final pdf = await buildDocument(
      reports: reports,
      stats: stats,
      inspectorName: inspectorName,
    );

    final timestamp = DateTime.now().toIso8601String().split('T').first;
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'BFP_AIR_Summary_Report_$timestamp.pdf',
    );
  }

  static Future<pw.Document> buildDocument({
    required List<Map<String, dynamic>> reports,
    required Map<String, int> stats,
    String? inspectorName,
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
        header: (pw.Context context) => _buildHeader(dilgLogo, bfpLogo, dateStr),
        footer: (pw.Context context) => _buildFooter(context),
        build: (pw.Context context) => [
          _buildSummaryStats(stats, inspectorName, dateStr),
          pw.SizedBox(height: 14),
          _buildReportsTable(reports),
          pw.SizedBox(height: 20),
          _buildSignatures(inspectorName),
        ],
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeader(pw.MemoryImage? dilgLogo, pw.MemoryImage? bfpLogo, String dateStr) {
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
                  'Solis Street, Poblacion, Lingayen, Pangasinan | Hotline: (075) 542-7313',
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
        pw.Container(
          width: double.infinity,
          height: 1.5,
          color: PdfColors.blue900,
        ),
        pw.SizedBox(height: 2),
        pw.Container(
          width: double.infinity,
          height: 0.5,
          color: PdfColors.deepOrange800,
        ),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            'COMMERCIAL AFTER-INSPECTION REPORTS (AIR) SUMMARY LOG',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
          ),
        ),
        pw.Center(
          child: pw.Text(
            'Official Station Officer Compliance Review Batch • BFP-QSF-FSED-061 Series',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildSummaryStats(Map<String, int> stats, String? inspectorName, String dateStr) {
    final total = stats['total'] ?? 0;
    final fsic = stats['fsic'] ?? 0;
    final ntc = stats['ntc'] ?? 0;
    final ntcv = stats['ntcv'] ?? 0;

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
                'Reporting Inspector: ${inspectorName != null && inspectorName.isNotEmpty ? inspectorName : "Designated Fire Safety Inspector"}',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Jurisdiction: Lingayen Municipal Fire Station • Date Exported: $dateStr',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.Row(
            children: [
              _buildStatPill('Total Inspected', '$total', PdfColors.blue900),
              pw.SizedBox(width: 8),
              _buildStatPill('FSIC Recommended', '$fsic', PdfColors.green800),
              pw.SizedBox(width: 8),
              _buildStatPill('NTC Issued', '$ntc', PdfColors.amber800),
              pw.SizedBox(width: 8),
              _buildStatPill('NTCV Violation', '$ntcv', PdfColors.red800),
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

  static pw.Widget _buildReportsTable(List<Map<String, dynamic>> reports) {
    if (reports.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(24),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Text('No commercial After-Inspection Reports recorded in this batch.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      );
    }

    final headers = [
      '#',
      'IO Number',
      'Business Establishment',
      'Address / Location',
      'Date Inspected',
      'Occupancy Type',
      'Defects / Findings',
      'Recommendation',
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

    for (int i = 0; i < reports.length; i++) {
      final r = reports[i];
      final ioNo = r['inspection_order_no']?.toString() ?? 'N/A';
      final bName = r['business_name']?.toString() ?? 'Commercial Business';
      final addr = r['address']?.toString() ?? 'Lingayen, Pangasinan';
      final dateStr = (r['date_inspected'] ?? r['created_at'] ?? '').toString().split('T').first;
      final occupancy = r['occupancy_type']?.toString() ?? r['checklist_data']?['occupancyClassification']?.toString() ?? 'Mercantile';
      final defects = (r['defects_summary'] ?? r['checklist_data']?['defectsSummary'] ?? 'No defects noted').toString();
      final rec = (r['recommendation'] ?? r['compliance_status'] ?? 'FSIC').toString();

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
              child: pw.Text(ioNo, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
              child: pw.Text(bName, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
              child: pw.Text(addr, style: const pw.TextStyle(fontSize: 7.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
              child: pw.Text(dateStr, style: const pw.TextStyle(fontSize: 7.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
              child: pw.Text(occupancy, style: const pw.TextStyle(fontSize: 7.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
              child: pw.Text(
                defects.length > 45 ? '${defects.substring(0, 45)}...' : defects,
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
              child: pw.Text(
                rec.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _getRecommendationColor(rec),
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
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(1.8),
        4: pw.FlexColumnWidth(1.0),
        5: pw.FlexColumnWidth(1.1),
        6: pw.FlexColumnWidth(1.8),
        7: pw.FlexColumnWidth(1.1),
      },
      children: tableRows,
    );
  }

  static pw.Widget _buildSignatures(String? inspectorName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSignatoryBox('PREPARED & SUBMITTED BY:', inspectorName ?? 'Fire Safety Inspector', 'Fire Safety Inspector (FSI)'),
        _buildSignatoryBox('CHECKED & VERIFIED BY:', 'SFO2 Team Leader, BFP', 'FSES Team Leader'),
        _buildSignatoryBox('RECOMMENDING APPROVAL:', 'INSP Chief FSES, BFP', 'Chief, Fire Safety Enforcement Section'),
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
          pw.Text('BFP Lingayen Municipal Fire Station • FSED Official Record', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static PdfColor _getRecommendationColor(String rec) {
    final r = rec.toUpperCase();
    if (r.contains('FSIC') || r.contains('PASS')) return PdfColors.green800;
    if (r.contains('NTCV') || r.contains('VIOLATION')) return PdfColors.red800;
    if (r.contains('NTC') || r.contains('COMPLY')) return PdfColors.amber800;
    return PdfColors.blue800;
  }
}
