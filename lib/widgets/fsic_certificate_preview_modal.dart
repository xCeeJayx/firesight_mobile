import 'package:flutter/material.dart';

class FsicCertificatePreviewModal extends StatelessWidget {
  final String businessName;
  final String address;
  final String ownerName;
  final String occupancyType;
  final String ioNumber;
  final String? fsicNumber;
  final String? dateIssued;

  const FsicCertificatePreviewModal({
    super.key,
    required this.businessName,
    required this.address,
    required this.ownerName,
    required this.occupancyType,
    required this.ioNumber,
    this.fsicNumber,
    this.dateIssued,
  });

  static const Color colorPrimary = Color(0xFF0F172A);
  static const Color colorAccent = Color(0xFFEA580C);
  static const Color colorGold = Color(0xFFD97706);
  static const Color colorBorder = Color(0xFFE2E8F0);
  static const Color colorTextSecondary = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    final String formattedDate = dateIssued ?? DateTime.now().toString().split(' ').first;
    final String certificateNo = fsicNumber ?? 'FSIC-${DateTime.now().year}-${(businessName.hashCode.abs() % 90000 + 10000)}';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorGold, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Certificate Header Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: colorPrimary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.workspace_premium_outlined, color: colorGold, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'BUREAU OF FIRE PROTECTION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'OFFICIAL FIRE SAFETY INSPECTION CERTIFICATE',
                            style: TextStyle(
                              color: colorGold,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_outlined, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Printable Certificate Document Frame
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorGold.withOpacity(0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      // Header Seal & Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colorAccent.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield_outlined, color: colorAccent, size: 26),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            children: const [
                              Text(
                                'Republic of the Philippines',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorTextSecondary),
                              ),
                              Text(
                                'Department of the Interior and Local Government',
                                style: TextStyle(fontSize: 9, color: colorTextSecondary),
                              ),
                              Text(
                                'BUREAU OF FIRE PROTECTION',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorPrimary),
                              ),
                              Text(
                                'Lingayen Fire Station, Pangasinan',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colorAccent),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: colorGold, thickness: 1.5),
                      const SizedBox(height: 12),

                      // Serial FSIC Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colorGold),
                        ),
                        child: Text(
                          'FSIC NO: $certificateNo',
                          style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'FIRE SAFETY INSPECTION CERTIFICATE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorPrimary,
                          letterSpacing: 0.8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'TO WHOM IT MAY CONCERN:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextSecondary),
                      ),
                      const SizedBox(height: 10),

                      Text(
                        'By virtue of the provisions of Republic Act No. 9514 (Fire Code of the Philippines of 2008) and its Implementing Rules and Regulations, this FIRE SAFETY INSPECTION CERTIFICATE is hereby issued to:',
                        style: TextStyle(fontSize: 11, color: colorTextSecondary.withOpacity(0.9), height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Business & Owner Details Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colorBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Establishment Name', businessName.toUpperCase(), isBold: true),
                            const SizedBox(height: 6),
                            _buildInfoRow('Business Address', address),
                            const SizedBox(height: 6),
                            _buildInfoRow('Owner / Representative', ownerName),
                            const SizedBox(height: 6),
                            _buildInfoRow('Occupancy Type', occupancyType),
                            const SizedBox(height: 6),
                            _buildInfoRow('Inspection Order (IO)', ioNumber),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'for having COMPLIED with the mandatory fire safety rules, regulations, and protective standards prescribed under RA 9514.',
                        style: TextStyle(fontSize: 11, color: colorTextSecondary, fontStyle: FontStyle.italic, height: 1.3),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Dates & Payment Grid
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colorBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  const Text('Date Issued', style: TextStyle(fontSize: 9, color: colorTextSecondary)),
                                  const SizedBox(height: 2),
                                  Text(formattedDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorPrimary)),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 26, color: colorBorder),
                            Expanded(
                              child: Column(
                                children: [
                                  const Text('Valid Until', style: TextStyle(fontSize: 9, color: colorTextSecondary)),
                                  const SizedBox(height: 2),
                                  const Text('Dec 31, 2026', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 26, color: colorBorder),
                            Expanded(
                              child: Column(
                                children: [
                                  const Text('Fee Paid / OR #', style: TextStyle(fontSize: 9, color: colorTextSecondary)),
                                  const SizedBox(height: 2),
                                  const Text('₱ 1,850.00 / OR-9821', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorPrimary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Signatures Area
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('RECOMMENDING APPROVAL:', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colorTextSecondary)),
                              SizedBox(height: 24),
                              Text('INSP JOHN DOE, BFP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorPrimary)),
                              Text('Chief, Fire Safety Enforcement Section', style: TextStyle(fontSize: 8, color: colorTextSecondary)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: const [
                              Text('APPROVED BY:', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colorTextSecondary)),
                              SizedBox(height: 24),
                              Text('CINSP MARSHAL BFP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorPrimary)),
                              Text('City / Municipal Fire Marshal', style: TextStyle(fontSize: 8, color: colorTextSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Downloading FSIC Official PDF Document...'),
                              backgroundColor: Color(0xFF0F172A),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.download_outlined, size: 18, color: colorPrimary),
                        label: const Text('Download PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorPrimary)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: colorBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sending FSIC to printer...'),
                              backgroundColor: Color(0xFF16A34A),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.print_outlined, size: 18, color: Colors.white),
                        label: const Text('Print FSIC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            '$label:',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colorTextSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: colorPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
