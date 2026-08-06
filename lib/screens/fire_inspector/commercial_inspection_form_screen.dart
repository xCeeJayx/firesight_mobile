import 'package:flutter/material.dart';
import '../../widgets/commercial_checklist_widget.dart';

class CommercialInspectionFormScreen extends StatelessWidget {
  final String? assignmentId;
  final String? initialIoNumber;
  final String? initialBusinessName;
  final String? initialAddress;
  final String? initialBarangay;

  const CommercialInspectionFormScreen({
    super.key,
    this.assignmentId,
    this.initialIoNumber,
    this.initialBusinessName,
    this.initialAddress,
    this.initialBarangay,
  });

  // Design Tokens
  static const Color colorCanvas = Color(0xFFF8FAFC);
  static const Color colorSurface = Color(0xFFFFFFFF);
  static const Color colorTextPrimary = Color(0xFF0F172A);
  static const Color colorTextSecondary = Color(0xFF475569);
  static const Color colorAccent = Color(0xFFEA580C);
  static const Color colorBorder = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final String address = initialAddress != null && initialAddress!.isNotEmpty
        ? (initialBarangay != null ? '$initialAddress, $initialBarangay' : initialAddress!)
        : (initialBarangay != null ? 'Barangay $initialBarangay, Lingayen' : '');

    return Scaffold(
      backgroundColor: colorCanvas,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fire Safety Inspection Checklist',
              style: TextStyle(color: colorTextPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'BFP Form 061 (Rev. 00 06.17.22) Official Standard',
              style: TextStyle(color: colorTextSecondary, fontSize: 11),
            ),
          ],
        ),
        backgroundColor: colorSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: colorTextPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: colorBorder, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Official BFP Form 061 Header Banner Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colorBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_outlined, color: colorAccent, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'REPUBLIC OF THE PHILIPPINES',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorTextSecondary, letterSpacing: 0.5),
                            ),
                            Text(
                              'BUREAU OF FIRE PROTECTION',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorTextPrimary, letterSpacing: 0.5),
                            ),
                            Text(
                              'BFP-QSF-FSED-061 Rev. ØØ (06.17.22)',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colorAccent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Render exact 11-page BFP Form 061 checklist widget
            CommercialChecklistWidget(
              assignmentId: assignmentId,
              initialIoNumber: initialIoNumber,
              initialBusinessName: initialBusinessName,
              initialAddress: address,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
