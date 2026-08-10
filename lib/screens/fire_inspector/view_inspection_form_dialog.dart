import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/commercial_checklist_model.dart';
import '../../services/inspection_checklist_pdf_service.dart';

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
  static const Color colorCanvas = Color(0xFFF8FAFC);
  static const Color colorSurface = Color(0xFFFFFFFF);
  static const Color colorBorder = Color(0xFFE2E8F0);
  static const Color colorTextPrimary = Color(0xFF0F172A);
  static const Color colorTextSecondary = Color(0xFF64748B);
  static const Color colorSuccess = Color(0xFF16A34A);
  static const Color colorWarning = Color(0xFFD97706);
  static const Color colorDanger = Color(0xFFDC2626);

  late Future<CommercialChecklistModel> _modelFuture;
  bool _isExporting = false;

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

    Map<String, dynamic> combinedJson = Map<String, dynamic>.from(rawData);
    if (rawData['checklist_data'] is Map<String, dynamic>) {
      combinedJson.addAll(Map<String, dynamic>.from(rawData['checklist_data']));
    }

    CommercialChecklistModel model = CommercialChecklistModel.fromJson(combinedJson);

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

  Future<void> _exportPdf(CommercialChecklistModel model) async {
    setState(() => _isExporting = true);
    try {
      await InspectionChecklistPdfService.generateAndPrintChecklistPdf(model);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
          maxWidth: 720,
        ),
        decoration: BoxDecoration(
          color: colorCanvas,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: FutureBuilder<CommercialChecklistModel>(
            future: _modelFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 320,
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
                      const Icon(Icons.error_outline_rounded, size: 48, color: colorDanger),
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
                  // Sleek Modern Header
                  _buildHeader(model),

                  // Scrollable Modern Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Business Overview Hero Card
                          _buildBusinessHeroCard(model),
                          const SizedBox(height: 14),

                          // Section 1: Reference & Schedule
                          _buildSectionCard(
                            title: 'Inspection Reference & Schedule',
                            icon: Icons.receipt_long_outlined,
                            children: [
                              _buildKeyValueRow('Inspection Order (IO) #', model.ioNumber, isBold: true),
                              _buildKeyValueRow('Date Issued', model.dateIssued),
                              _buildKeyValueRow('Date Inspected', model.dateInspected),
                              _buildKeyValueRow('Inspection Nature', _formatNature(model.inspectionNature, model.verificationType, model.natureOthersSpecify)),
                              if (model.fsmrRequired != null)
                                _buildKeyValueRow('FSMR Required', model.fsmrRequired!),
                              if (model.fsccrRequired != null)
                                _buildKeyValueRow('FSCCR Required', model.fsccrRequired!),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Section 2: Establishment Info
                          _buildSectionCard(
                            title: 'Establishment Information',
                            icon: Icons.business_outlined,
                            children: [
                              _buildKeyValueRow('Business Name', model.businessName, isBold: true),
                              _buildKeyValueRow('Building Name', model.buildingName),
                              _buildKeyValueRow('Address / Location', model.address),
                              _buildKeyValueRow('Owner / Representative', model.ownerRepresentative.isNotEmpty ? model.ownerRepresentative : 'N/A'),
                              _buildKeyValueRow('Contact Number', model.contactNo.isNotEmpty ? model.contactNo : 'N/A'),
                              _buildKeyValueRow('Nature of Business', model.natureOfBusiness.isNotEmpty ? model.natureOfBusiness : 'Commercial Establishment'),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Section 3: Building Specifications
                          _buildSectionCard(
                            title: 'Building Specifications & Occupancy',
                            icon: Icons.apartment_outlined,
                            children: [
                              _buildKeyValueRow('Occupancy Classification', model.occupancyClassification ?? 'Mercantile', badgeColor: Colors.blue.shade700),
                              _buildKeyValueRow('Construction Type', model.constructionType ?? 'Type I : Concrete & Steel (Fire Resistive)'),
                              _buildKeyValueRow('Number of Stories', '${model.numberOfStories.isNotEmpty ? model.numberOfStories : '2'} Storey'),
                              _buildKeyValueRow('Building Height', '${model.buildingHeight.isNotEmpty ? model.buildingHeight : '6'} meters'),
                              _buildKeyValueRow('Occupant Load', '${model.occupantLoad.isNotEmpty ? model.occupantLoad : '50'} persons/floor'),
                              _buildKeyValueRow('High-Rise Building', model.isHighrise == 'Yes' ? 'Yes' : 'No'),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Section 4: Permits & Regulatory Clearances
                          _buildSectionCard(
                            title: 'Permits & Clearances',
                            icon: Icons.verified_outlined,
                            children: [
                              _buildKeyValueRow('Latest FSIC #', model.fsicNoLatest.isNotEmpty ? '${model.fsicNoLatest} (${model.fsicDateIssued})' : 'N/A'),
                              _buildKeyValueRow('Business Permit #', model.businessPermitNo.isNotEmpty ? '${model.businessPermitNo} (${model.businessPermitDateIssued})' : 'N/A'),
                              _buildKeyValueRow('Fire Drill Cert #', model.fireDrillCertNo.isNotEmpty ? '${model.fireDrillCertNo} (${model.fireDrillDateIssued})' : 'N/A'),
                              _buildKeyValueRow('FSEC #', model.fsecNo.isNotEmpty ? '${model.fsecNo} (${model.fsecDateIssued})' : 'N/A'),
                              _buildKeyValueRow('Building Permit #', model.buildingPermitNo.isNotEmpty ? '${model.buildingPermitNo} (${model.buildingPermitDateIssued})' : 'N/A'),
                              _buildKeyValueRow('Fire Insurance Policy', model.fireInsurancePolicyNo.isNotEmpty ? '${model.fireInsurancePolicyNo} (${model.fireInsuranceDateIssued})' : 'None / N/A'),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Section 5: Deficiencies & Findings
                          _buildDeficienciesCard(model),
                          const SizedBox(height: 14),

                          // Section 6: Recommendations
                          _buildRecommendationsCard(model),
                          const SizedBox(height: 14),

                          // Section 7: Signatories
                          _buildSignatoriesCard(model),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Footer
                  _buildFooter(model),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(CommercialChecklistModel model) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: colorPrimary,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BFP Form 061 Checklist',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Inspection Order: ${model.ioNumber}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessHeroCard(CommercialChecklistModel model) {
    final status = model.recommendationAction ?? 'FSIC';
    final bool isPassed = status.toUpperCase().contains('FSIC') || status.toUpperCase().contains('PASS');
    final Color badgeColor = isPassed ? colorSuccess : colorWarning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.businessName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: colorTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: colorTextSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            model.address,
                            style: const TextStyle(fontSize: 12, color: colorTextSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _formatRecommendationBadge(status),
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: colorBorder),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTag(Icons.category_outlined, model.occupancyClassification ?? 'Mercantile'),
              _buildTag(Icons.calendar_today_outlined, 'Inspected: ${model.dateInspected}'),
              _buildTag(Icons.person_outline_rounded, model.ownerRepresentative.isNotEmpty ? model.ownerRepresentative : 'Owner'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildKeyValueRow(String label, String value, {bool isBold = false, Color? badgeColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 155,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: colorTextSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: badgeColor != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        value,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeColor),
                      ),
                    ),
                  )
                : Text(
                    value.isNotEmpty ? value : 'N/A',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                      color: colorTextPrimary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeficienciesCard(CommercialChecklistModel model) {
    final bool hasDefects = model.defectsSummary.trim().isNotEmpty &&
        !model.defectsSummary.toLowerCase().contains('none') &&
        !model.defectsSummary.toLowerCase().contains('no major');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasDefects ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDefects ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasDefects ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                color: hasDefects ? colorDanger : colorSuccess,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                hasDefects ? 'Defects / Deficiencies Noted' : 'Compliance Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: hasDefects ? colorDanger : colorSuccess,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasDefects ? model.defectsSummary : 'Zero critical fire safety deficiencies noted during this inspection. Fully compliant with RA 9514.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: hasDefects ? const Color(0xFF991B1B) : const Color(0xFF166534),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(CommercialChecklistModel model) {
    final rec = model.recommendationAction ?? 'FSIC';
    final bool isFsic = rec.toUpperCase().contains('FSIC') || rec.toUpperCase().contains('PASS');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.gavel_outlined, size: 18, color: colorAccent),
              SizedBox(width: 8),
              Text(
                'Inspector Recommendation & Decision',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isFsic ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: isFsic ? colorSuccess : colorWarning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isFsic
                        ? 'Recommendation: Issuance of Fire Safety Inspection Certificate (FSIC) upon settlement of statutory fire code fees.'
                        : 'Recommendation: Issuance of Notice to Comply (NTC) / Correct Violations within prescribed statutory period.',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorTextPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatoriesCard(CommercialChecklistModel model) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.draw_outlined, size: 18, color: colorAccent),
              SizedBox(width: 8),
              Text(
                'Authorized Officers & Signatories',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSignatoryBox(
                  'Owner / Representative',
                  model.ownerRepresentative.isNotEmpty ? model.ownerRepresentative : 'Owner Signature',
                  Icons.person_pin_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSignatoryBox(
                  'Fire Safety Inspector',
                  model.inspectorName.isNotEmpty ? model.inspectorName : 'Inspector on Duty',
                  Icons.badge_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSignatoryBox(
                  'FSES Team Leader',
                  model.teamLeaderName.isNotEmpty ? model.teamLeaderName : 'Team Leader',
                  Icons.shield_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSignatoryBox(
                  'City / Municipal Fire Marshal',
                  model.fireMarshalName.isNotEmpty ? model.fireMarshalName : 'CINSP Fire Marshal',
                  Icons.military_tech_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignatoryBox(String role, String name, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: colorTextSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  role,
                  style: const TextStyle(fontSize: 10, color: colorTextSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorTextPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(CommercialChecklistModel model) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorSurface,
        border: const Border(top: BorderSide(color: colorBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : () => _exportPdf(model),
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.white),
              label: Text(
                _isExporting ? 'Generating Document...' : 'Export Official 10-Page PDF',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: colorBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Close',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorTextSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorTextSecondary),
          ),
        ],
      ),
    );
  }

  String _formatNature(String? nature, String? verificationType, String? specify) {
    if (nature == 'BusinessPermit' || nature == null) return 'FSIC for Business Permit (New/Renewal)';
    if (nature == 'Occupancy') return 'FSIC for Certificate of Occupancy';
    if (nature == 'Construction') return 'Inspection During Construction';
    if (nature == 'PEZA') return 'FSIC for Annual Inspection (PEZA)';
    if (nature == 'Verification') return 'Verification for Compliance (${verificationType ?? 'NTC'})';
    if (nature == 'Others' && specify != null && specify.isNotEmpty) return 'Others: $specify';
    return nature;
  }

  String _formatRecommendationBadge(String status) {
    final s = status.toUpperCase();
    if (s.contains('FSIC') || s.contains('PASS')) return 'FSIC RECOMMENDED';
    if (s.contains('NTCV')) return 'NOTICE TO CORRECT VIOLATION';
    if (s.contains('NTC')) return 'NOTICE TO COMPLY';
    if (s.contains('CLOSURE')) return 'CLOSURE ORDER';
    if (s.contains('ABATEMENT')) return 'ABATEMENT ORDER';
    return status;
  }
}
