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
      body: SafeArea(
        child: CommercialChecklistWidget(
          assignmentId: assignmentId,
          initialIoNumber: initialIoNumber,
          initialBusinessName: initialBusinessName,
          initialAddress: address,
        ),
      ),
    );
  }
}
