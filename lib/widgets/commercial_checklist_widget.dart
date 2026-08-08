import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/commercial_checklist_model.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_sync_service.dart';

class CommercialChecklistWidget extends StatefulWidget {
  final String? assignmentId;
  final String? initialIoNumber;
  final String? initialBusinessName;
  final String? initialAddress;

  const CommercialChecklistWidget({
    super.key,
    this.assignmentId,
    this.initialIoNumber,
    this.initialBusinessName,
    this.initialAddress,
  });

  @override
  State<CommercialChecklistWidget> createState() => _CommercialChecklistWidgetState();
}

class _CommercialChecklistWidgetState extends State<CommercialChecklistWidget> {
  final _model = CommercialChecklistModel();

  // Design Tokens
  final Color primaryColor = const Color(0xFFEA580C);
  final Color successColor = const Color(0xFF16A34A);
  final Color warningColor = const Color(0xFFD97706);
  final Color errorColor = const Color(0xFFDC2626);
  final Color surfaceColor = Colors.white;
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color titleColor = const Color(0xFF0F172A);
  final Color subtitleColor = const Color(0xFF475569);
  final Color inputBgColor = const Color(0xFFF8FAFC);

  final List<String> _photoUrls = [];
  bool _isUploading = false;
  bool _isSubmitting = false;

  // Controllers - Reference & Gen Info
  final _ioNumberCtrl = TextEditingController();
  final _dateIssuedCtrl = TextEditingController();
  final _dateInspectedCtrl = TextEditingController();
  final _natureOthersCtrl = TextEditingController();

  final _buildingNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _natureOfBusinessCtrl = TextEditingController();
  final _ownerRepresentativeCtrl = TextEditingController();
  final _contactNoCtrl = TextEditingController();

  final _fsecNoCtrl = TextEditingController();
  final _fsecDateCtrl = TextEditingController();
  final _buildingPermitNoCtrl = TextEditingController();
  final _buildingPermitDateCtrl = TextEditingController();

  final _fsicNoLatestCtrl = TextEditingController();
  final _fsicDateCtrl = TextEditingController();
  final _fireDrillCertCtrl = TextEditingController();
  final _fireDrillDateCtrl = TextEditingController();
  final _businessPermitNoCtrl = TextEditingController();
  final _businessPermitDateCtrl = TextEditingController();
  final _fireInsurancePolicyNoCtrl = TextEditingController();
  final _fireInsuranceDateCtrl = TextEditingController();

  // Sectional Occupancy Controllers
  final _basementCtrl = TextEditingController();
  final _groundFloorCtrl = TextEditingController();
  final _secondFloorCtrl = TextEditingController();
  final _thirdFloorCtrl = TextEditingController();
  final _fourthFloorCtrl = TextEditingController();
  final _nthFloorCtrl = TextEditingController();

  // Other Info
  final _occupantLoadCtrl = TextEditingController();
  final _numberOfStoriesCtrl = TextEditingController();
  final _buildingHeightCtrl = TextEditingController();

  // Defects & Signatures
  final _defectsSummaryCtrl = TextEditingController();
  final _inspectorNameCtrl = TextEditingController();
  final _teamLeaderNameCtrl = TextEditingController();
  final _fireMarshalNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialIoNumber != null && widget.initialIoNumber!.isNotEmpty) {
      _ioNumberCtrl.text = widget.initialIoNumber!;
    }
    if (widget.initialBusinessName != null && widget.initialBusinessName!.isNotEmpty) {
      _businessNameCtrl.text = widget.initialBusinessName!;
    }
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _addressCtrl.text = widget.initialAddress!;
    }
    _dateInspectedCtrl.text = DateTime.now().toString().split(' ')[0];

    if (widget.assignmentId != null && widget.assignmentId!.isNotEmpty) {
      _fetchExistingInspection();
    }
  }

  Future<void> _fetchExistingInspection() async {
    try {
      final response = await Supabase.instance.client
          .from('inspections')
          .select()
          .eq('id', widget.assignmentId!)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          if (response['inspection_order_no'] != null && response['inspection_order_no'].toString().isNotEmpty) {
            _ioNumberCtrl.text = response['inspection_order_no'].toString();
          }
          if (response['business_name'] != null && response['business_name'].toString().isNotEmpty) {
            _businessNameCtrl.text = response['business_name'].toString();
          }
          if (response['address'] != null && response['address'].toString().isNotEmpty) {
            _addressCtrl.text = response['address'].toString();
          }
          if (response['date_issued'] != null) {
            _dateIssuedCtrl.text = response['date_issued'].toString().split('T').first;
          }
          if (response['date_inspected'] != null) {
            _dateInspectedCtrl.text = response['date_inspected'].toString().split('T').first;
          }
          if (response['hazard_photo_urls'] != null) {
            _photoUrls.clear();
            _photoUrls.addAll(List<String>.from(response['hazard_photo_urls']));
          }

          if (response['checklist_data'] != null && response['checklist_data'] is Map<String, dynamic>) {
            final Map<String, dynamic> data = response['checklist_data'];
            final loadedModel = CommercialChecklistModel.fromJson(data);

            _model.ioNumber = loadedModel.ioNumber;
            _model.dateIssued = loadedModel.dateIssued;
            _model.dateInspected = loadedModel.dateInspected;
            _model.inspectionNature = loadedModel.inspectionNature;
            _model.verificationType = loadedModel.verificationType;
            _model.natureOthersSpecify = loadedModel.natureOthersSpecify;
            _model.fsccrRequired = loadedModel.fsccrRequired;
            _model.fsmrRequired = loadedModel.fsmrRequired;

            _model.buildingName = loadedModel.buildingName;
            _model.address = loadedModel.address;
            _model.businessName = loadedModel.businessName;
            _model.natureOfBusiness = loadedModel.natureOfBusiness;
            _model.ownerRepresentative = loadedModel.ownerRepresentative;
            _model.contactNo = loadedModel.contactNo;

            _model.fsecNo = loadedModel.fsecNo;
            _model.fsecDateIssued = loadedModel.fsecDateIssued;
            _model.buildingPermitNo = loadedModel.buildingPermitNo;
            _model.buildingPermitDateIssued = loadedModel.buildingPermitDateIssued;

            _model.fsicNoLatest = loadedModel.fsicNoLatest;
            _model.fsicDateIssued = loadedModel.fsicDateIssued;
            _model.fireDrillCertNo = loadedModel.fireDrillCertNo;
            _model.fireDrillDateIssued = loadedModel.fireDrillDateIssued;
            _model.businessPermitNo = loadedModel.businessPermitNo;
            _model.businessPermitDateIssued = loadedModel.businessPermitDateIssued;
            _model.fireInsurancePolicyNo = loadedModel.fireInsurancePolicyNo;
            _model.fireInsuranceDateIssued = loadedModel.fireInsuranceDateIssued;

            _model.constructionType = loadedModel.constructionType;
            _model.interiorFinishWalls = loadedModel.interiorFinishWalls;
            _model.interiorFinishFloor = loadedModel.interiorFinishFloor;

            _model.basementUsage = loadedModel.basementUsage;
            _model.groundFloorUsage = loadedModel.groundFloorUsage;
            _model.secondFloorUsage = loadedModel.secondFloorUsage;
            _model.thirdFloorUsage = loadedModel.thirdFloorUsage;
            _model.fourthFloorUsage = loadedModel.fourthFloorUsage;
            _model.nthFloorUsage = loadedModel.nthFloorUsage;

            _model.occupancyClassification = loadedModel.occupancyClassification;
            _model.occupantLoad = loadedModel.occupantLoad;
            _model.numberOfStories = loadedModel.numberOfStories;
            _model.buildingHeight = loadedModel.buildingHeight;
            _model.isHighrise = loadedModel.isHighrise;

            _model.egressAccessStatus = loadedModel.egressAccessStatus;
            _model.exitComponentsStatus = loadedModel.exitComponentsStatus;
            _model.egressRequirementsStatus = loadedModel.egressRequirementsStatus;
            _model.exitSignageStatus = loadedModel.exitSignageStatus;
            _model.hazardStatus = loadedModel.hazardStatus;
            _model.fireProtectionStatus = loadedModel.fireProtectionStatus;
            _model.itemDimensions = loadedModel.itemDimensions;

            _model.defectsSummary = loadedModel.defectsSummary;
            _model.recommendationAction = loadedModel.recommendationAction;
            _model.inspectorName = loadedModel.inspectorName;
            _model.teamLeaderName = loadedModel.teamLeaderName;
            _model.fireMarshalName = loadedModel.fireMarshalName;

            if (_model.ioNumber.isNotEmpty) _ioNumberCtrl.text = _model.ioNumber;
            if (_model.dateIssued.isNotEmpty) _dateIssuedCtrl.text = _model.dateIssued;
            if (_model.dateInspected.isNotEmpty) _dateInspectedCtrl.text = _model.dateInspected;
            if (_model.natureOthersSpecify != null && _model.natureOthersSpecify!.isNotEmpty) _natureOthersCtrl.text = _model.natureOthersSpecify!;

            if (_model.buildingName.isNotEmpty) _buildingNameCtrl.text = _model.buildingName;
            if (_model.address.isNotEmpty) _addressCtrl.text = _model.address;
            if (_model.businessName.isNotEmpty) _businessNameCtrl.text = _model.businessName;
            if (_model.natureOfBusiness.isNotEmpty) _natureOfBusinessCtrl.text = _model.natureOfBusiness;
            if (_model.ownerRepresentative.isNotEmpty) _ownerRepresentativeCtrl.text = _model.ownerRepresentative;
            if (_model.contactNo.isNotEmpty) _contactNoCtrl.text = _model.contactNo;

            if (_model.fsecNo.isNotEmpty) _fsecNoCtrl.text = _model.fsecNo;
            if (_model.fsecDateIssued.isNotEmpty) _fsecDateCtrl.text = _model.fsecDateIssued;
            if (_model.buildingPermitNo.isNotEmpty) _buildingPermitNoCtrl.text = _model.buildingPermitNo;
            if (_model.buildingPermitDateIssued.isNotEmpty) _buildingPermitDateCtrl.text = _model.buildingPermitDateIssued;

            if (_model.fsicNoLatest.isNotEmpty) _fsicNoLatestCtrl.text = _model.fsicNoLatest;
            if (_model.fsicDateIssued.isNotEmpty) _fsicDateCtrl.text = _model.fsicDateIssued;
            if (_model.fireDrillCertNo.isNotEmpty) _fireDrillCertCtrl.text = _model.fireDrillCertNo;
            if (_model.fireDrillDateIssued.isNotEmpty) _fireDrillDateCtrl.text = _model.fireDrillDateIssued;
            if (_model.businessPermitNo.isNotEmpty) _businessPermitNoCtrl.text = _model.businessPermitNo;
            if (_model.businessPermitDateIssued.isNotEmpty) _businessPermitDateCtrl.text = _model.businessPermitDateIssued;
            if (_model.fireInsurancePolicyNo.isNotEmpty) _fireInsurancePolicyNoCtrl.text = _model.fireInsurancePolicyNo;
            if (_model.fireInsuranceDateIssued.isNotEmpty) _fireInsuranceDateCtrl.text = _model.fireInsuranceDateIssued;

            if (_model.basementUsage.isNotEmpty) _basementCtrl.text = _model.basementUsage;
            if (_model.groundFloorUsage.isNotEmpty) _groundFloorCtrl.text = _model.groundFloorUsage;
            if (_model.secondFloorUsage.isNotEmpty) _secondFloorCtrl.text = _model.secondFloorUsage;
            if (_model.thirdFloorUsage.isNotEmpty) _thirdFloorCtrl.text = _model.thirdFloorUsage;
            if (_model.fourthFloorUsage.isNotEmpty) _fourthFloorCtrl.text = _model.fourthFloorUsage;
            if (_model.nthFloorUsage.isNotEmpty) _nthFloorCtrl.text = _model.nthFloorUsage;

            if (_model.occupantLoad.isNotEmpty) _occupantLoadCtrl.text = _model.occupantLoad;
            if (_model.numberOfStories.isNotEmpty) _numberOfStoriesCtrl.text = _model.numberOfStories;
            if (_model.buildingHeight.isNotEmpty) _buildingHeightCtrl.text = _model.buildingHeight;

            if (_model.defectsSummary.isNotEmpty) _defectsSummaryCtrl.text = _model.defectsSummary;
            if (_model.inspectorName.isNotEmpty) _inspectorNameCtrl.text = _model.inspectorName;
            if (_model.teamLeaderName.isNotEmpty) _teamLeaderNameCtrl.text = _model.teamLeaderName;
            if (_model.fireMarshalName.isNotEmpty) _fireMarshalNameCtrl.text = _model.fireMarshalName;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching existing inspection: $e');
    }
  }

  @override
  void dispose() {
    _ioNumberCtrl.dispose();
    _dateIssuedCtrl.dispose();
    _dateInspectedCtrl.dispose();
    _natureOthersCtrl.dispose();
    _buildingNameCtrl.dispose();
    _addressCtrl.dispose();
    _businessNameCtrl.dispose();
    _natureOfBusinessCtrl.dispose();
    _ownerRepresentativeCtrl.dispose();
    _contactNoCtrl.dispose();
    _fsecNoCtrl.dispose();
    _fsecDateCtrl.dispose();
    _buildingPermitNoCtrl.dispose();
    _buildingPermitDateCtrl.dispose();
    _fsicNoLatestCtrl.dispose();
    _fsicDateCtrl.dispose();
    _fireDrillCertCtrl.dispose();
    _fireDrillDateCtrl.dispose();
    _businessPermitNoCtrl.dispose();
    _businessPermitDateCtrl.dispose();
    _fireInsurancePolicyNoCtrl.dispose();
    _fireInsuranceDateCtrl.dispose();
    _basementCtrl.dispose();
    _groundFloorCtrl.dispose();
    _secondFloorCtrl.dispose();
    _thirdFloorCtrl.dispose();
    _fourthFloorCtrl.dispose();
    _nthFloorCtrl.dispose();
    _occupantLoadCtrl.dispose();
    _numberOfStoriesCtrl.dispose();
    _buildingHeightCtrl.dispose();
    _defectsSummaryCtrl.dispose();
    _inspectorNameCtrl.dispose();
    _teamLeaderNameCtrl.dispose();
    _fireMarshalNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final isOnline = await ConnectivityService().hasInternetConnection();
      if (isOnline) {
        final file = File(pickedFile.path);
        final fileName = 'commercial_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

        await Supabase.instance.client.storage.from('hazard-photos').upload(fileName, file);
        final publicUrl = Supabase.instance.client.storage.from('hazard-photos').getPublicUrl(fileName);

        setState(() {
          _photoUrls.add(publicUrl);
        });
      } else {
        // Offline: save local image file path for sync
        setState(() {
          _photoUrls.add(pickedFile.path);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo attached locally (Offline). Will upload upon sync.'),
              backgroundColor: Color(0xFFD97706),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Fallback: save local path on upload error
      setState(() {
        _photoUrls.add(pickedFile.path);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo saved locally: $e'), backgroundColor: warningColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _submitReport() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? AuthService().userProfile?['id']?.toString();
    if (userId == null) return;

    setState(() => _isSubmitting = true);

    // Sync controllers to model
    _model.ioNumber = _ioNumberCtrl.text;
    _model.dateIssued = _dateIssuedCtrl.text;
    _model.dateInspected = _dateInspectedCtrl.text;
    _model.natureOthersSpecify = _natureOthersCtrl.text;

    _model.buildingName = _buildingNameCtrl.text;
    _model.address = _addressCtrl.text;
    _model.businessName = _businessNameCtrl.text;
    _model.natureOfBusiness = _natureOfBusinessCtrl.text;
    _model.ownerRepresentative = _ownerRepresentativeCtrl.text;
    _model.contactNo = _contactNoCtrl.text;

    _model.fsecNo = _fsecNoCtrl.text;
    _model.fsecDateIssued = _fsecDateCtrl.text;
    _model.buildingPermitNo = _buildingPermitNoCtrl.text;
    _model.buildingPermitDateIssued = _buildingPermitDateCtrl.text;

    _model.fsicNoLatest = _fsicNoLatestCtrl.text;
    _model.fsicDateIssued = _fsicDateCtrl.text;
    _model.fireDrillCertNo = _fireDrillCertCtrl.text;
    _model.fireDrillDateIssued = _fireDrillDateCtrl.text;
    _model.businessPermitNo = _businessPermitNoCtrl.text;
    _model.businessPermitDateIssued = _businessPermitDateCtrl.text;
    _model.fireInsurancePolicyNo = _fireInsurancePolicyNoCtrl.text;
    _model.fireInsuranceDateIssued = _fireInsuranceDateCtrl.text;

    _model.basementUsage = _basementCtrl.text;
    _model.groundFloorUsage = _groundFloorCtrl.text;
    _model.secondFloorUsage = _secondFloorCtrl.text;
    _model.thirdFloorUsage = _thirdFloorCtrl.text;
    _model.fourthFloorUsage = _fourthFloorCtrl.text;
    _model.nthFloorUsage = _nthFloorCtrl.text;

    _model.occupantLoad = _occupantLoadCtrl.text;
    _model.numberOfStories = _numberOfStoriesCtrl.text;
    _model.buildingHeight = _buildingHeightCtrl.text;

    _model.defectsSummary = _defectsSummaryCtrl.text;
    _model.inspectorName = _inspectorNameCtrl.text;
    _model.teamLeaderName = _teamLeaderNameCtrl.text;
    _model.fireMarshalName = _fireMarshalNameCtrl.text;

    final payloadData = _model.toJson();
    payloadData['checklist_type'] = 'commercial';

    final isOnline = await ConnectivityService().hasInternetConnection();

    final updatePayload = <String, dynamic>{
      'inspector_id': userId,
      'checklist_type': 'commercial',
      'inspection_order_no': _model.ioNumber.isNotEmpty ? _model.ioNumber : 'IO-${DateTime.now().millisecondsSinceEpoch}',
      'date_issued': _model.dateIssued.isNotEmpty ? _model.dateIssued : DateTime.now().toIso8601String().split('T').first,
      'date_inspected': _model.dateInspected.isNotEmpty ? _model.dateInspected : DateTime.now().toIso8601String().split('T').first,
      'business_name': _model.businessName.isNotEmpty ? _model.businessName : (_model.buildingName.isNotEmpty ? _model.buildingName : 'Commercial Business'),
      'address': _model.address.isNotEmpty ? _model.address : 'No address provided',
      'overall_status': isOnline ? 'Completed' : 'Pending Sync',
      'compliance_status': _model.recommendationAction ?? 'Inspected',
      'recommendation': _model.recommendationAction ?? 'Notice to Comply',
      'risk_level': 'Medium',
      'score': 0,
      'rating': _model.recommendationAction ?? 'Inspected',
      'checklist_data': payloadData,
      'hazard_photo_urls': _photoUrls,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (!isOnline) {
      // 1. Save locally with overall_status = 'Pending Sync'
      await OfflineSyncService().queueForSync(
        targetTable: 'inspections',
        payload: updatePayload,
        id: widget.assignmentId,
      );

      await AuthService().logAuditAction(
        actionType: 'COMMERCIAL_INSPECTION_QUEUED_OFFLINE',
        targetEntity: _model.businessName.isNotEmpty ? _model.businessName : 'Commercial Establishment',
        details: 'Queued Commercial Checklist (IO: ${_model.ioNumber}) locally for automatic sync.',
      );

      // 2. Display success feedback to inspector
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally (Offline). Will automatically sync when connected.'),
            backgroundColor: Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    try {
      if (widget.assignmentId != null && widget.assignmentId!.isNotEmpty) {
        await Supabase.instance.client
            .from('inspections')
            .update(updatePayload)
            .eq('id', widget.assignmentId!);
      } else {
        await Supabase.instance.client
            .from('inspections')
            .insert(updatePayload);
      }

      await AuthService().logAuditAction(
        actionType: 'COMMERCIAL_INSPECTION_SUBMITTED',
        targetEntity: _model.businessName.isNotEmpty ? _model.businessName : 'Commercial Establishment',
        details: 'Submitted BFP Form 061 Commercial Fire Safety Checklist (IO: ${_model.ioNumber}, Action: ${_model.recommendationAction ?? 'Inspected'}).',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('BFP Commercial Fire Safety Checklist Submitted Successfully!'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error submitting online, queueing offline: $e');
      final offlinePayload = Map<String, dynamic>.from(updatePayload);
      offlinePayload['overall_status'] = 'Pending Sync';

      await OfflineSyncService().queueForSync(
        targetTable: 'inspections',
        payload: offlinePayload,
        id: widget.assignmentId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally (Offline). Will automatically sync when connected.'),
            backgroundColor: Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('I. Reference & Inspection Nature', Icons.assignment_outlined),
        _buildReferenceSection(),
        _buildSectionHeader('IV. General Information', Icons.storefront_outlined),
        _buildGeneralInfoSection(),
        _buildSectionHeader('Building Specifications & Classification', Icons.architecture_outlined),
        _buildBuildingSpecificationsSection(),
        _buildSectionHeader('V. Means of Egress', Icons.exit_to_app_outlined),
        _buildMeansOfEgressSection(),
        _buildSectionHeader('VI. Signs, Lighting & Exits Signage', Icons.signpost_outlined),
        _buildSignsAndSignageSection(),
        _buildSectionHeader('VII. Hazard Identification', Icons.warning_amber_outlined),
        _buildHazardSection(),
        _buildSectionHeader('VIII. Fire Protection Systems', Icons.fire_extinguisher_outlined),
        _buildFireProtectionSection(),
        _buildSectionHeader('IX. Defects, Recommendations & Signatures', Icons.fact_check_outlined),
        _buildDefectsAndRecommendationsSection(),
        _buildSectionHeader('Photo Documentation', Icons.photo_camera_outlined),
        _buildPhotoDocumentationSection(),
        const SizedBox(height: 28),
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildSectionHeader(String title, [IconData? icon]) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: primaryColor),
            const SizedBox(width: 8),
          ],
          Text(
            title.toUpperCase(),
            style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceSection() {
    final natures = [
      'Inspection during construction',
      'FSIC Annual Inspection (PEZA)',
      'FSIC for Certificate of Occupancy',
      'FSIC for Business Permit (New/Renewal)',
      'Verification Inspection for Compliance',
      'Others',
    ];

    final verificationTypes = ['NTC', 'NTCV', 'Abatement', 'Closure'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Inspection Order No. (IO)', controller: _ioNumberCtrl, hint: 'e.g. IO-2026-001'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildTextField('Date Issued', controller: _dateIssuedCtrl, hint: 'YYYY-MM-DD')),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Date Inspected', controller: _dateInspectedCtrl, hint: 'YYYY-MM-DD')),
            ],
          ),
          const SizedBox(height: 18),
          Text('Nature of Inspection Conducted:', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          ...natures.map((n) {
            final isSel = _model.inspectionNature == n;
            return InkWell(
              onTap: () => setState(() => _model.inspectionNature = n),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      isSel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 18,
                      color: isSel ? primaryColor : subtitleColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        n,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          if (_model.inspectionNature == 'Verification Inspection for Compliance') ...[
            const SizedBox(height: 12),
            Text('Verification Sub-type:', style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: verificationTypes.map((vt) {
                final isSel = _model.verificationType == vt;
                return ChoiceChip(
                  label: Text(vt, style: const TextStyle(fontSize: 12)),
                  selected: isSel,
                  selectedColor: primaryColor,
                  backgroundColor: inputBgColor,
                  side: BorderSide(color: isSel ? primaryColor : borderColor),
                  labelStyle: TextStyle(color: isSel ? Colors.white : titleColor, fontWeight: FontWeight.bold),
                  onSelected: (val) => setState(() => _model.verificationType = val ? vt : null),
                );
              }).toList(),
            ),
          ],

          if (_model.inspectionNature == 'Others') ...[
            const SizedBox(height: 12),
            _buildTextField('Specify Other Nature', controller: _natureOthersCtrl),
          ],

          const SizedBox(height: 20),
          Text('III. Requirements:', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          _buildYesNoToggleRow('FSCCR Report (Occupancy)', _model.fsccrRequired, (v) => setState(() => _model.fsccrRequired = v)),
          const SizedBox(height: 12),
          _buildYesNoToggleRow('FSMR Report (New / Renewal / Annual)', _model.fsmrRequired, (v) => setState(() => _model.fsmrRequired = v)),
        ],
      ),
    );
  }

  Widget _buildGeneralInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildTextField('Name of Building', controller: _buildingNameCtrl),
          const SizedBox(height: 14),
          _buildTextField('Address', controller: _addressCtrl),
          const SizedBox(height: 14),
          _buildTextField('Business Name', controller: _businessNameCtrl),
          const SizedBox(height: 14),
          _buildTextField('Nature of Business', controller: _natureOfBusinessCtrl),
          const SizedBox(height: 14),
          _buildTextField('Name of Owner / Representative', controller: _ownerRepresentativeCtrl),
          const SizedBox(height: 14),
          _buildTextField('Contact No.', controller: _contactNoCtrl, isNum: true),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('FSIC for Occupancy Permits:', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildTextField('FSEC No.', controller: _fsecNoCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Date Issued', controller: _fsecDateCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('Building Permit No.', controller: _buildingPermitNoCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Date Issued', controller: _buildingPermitDateCtrl)),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('FSIC for Business Permit (New/Renewal):', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildTextField('FSIC No. (Latest)', controller: _fsicNoLatestCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Date Issued', controller: _fsicDateCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('Cert. of Fire Drill', controller: _fireDrillCertCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Date Issued', controller: _fireDrillDateCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('Business Permit No.', controller: _businessPermitNoCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Date Issued', controller: _businessPermitDateCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('Fire Insurance Policy', controller: _fireInsurancePolicyNoCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Date Issued', controller: _fireInsuranceDateCtrl)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingSpecificationsSection() {
    final constructionTypes = [
      'Type I: Concrete & Steel (Fire Resistive)',
      'Type II: Concrete & Exposed Steel (Noncombustible)',
      'Type III: Concrete & Wood (Ordinary)',
      'Type IV: Heavy Timber (Large mass wood)',
      'Type V: Wood frame (Lightweight wood)',
    ];

    final wallFinishes = [
      'Class A: Flame spread 0-25',
      'Class B: Flame spread 26-75',
      'Class C: Flame spread 76-200',
    ];

    final floorFinishes = [
      'Class I: Critical radiant flux >= 0.45 W/cm2',
      'Class II: Critical radiant flux 0.22 - 0.45 W/cm2',
    ];

    final occupancies = [
      'Assembly', 'Educational', 'Day Care', 'Health Care',
      'Detention and Correctional', 'Residential', 'Residential Board and Care',
      'Mercantile', 'Business', 'Industrial', 'Storage', 'Special Structure'
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Construction Type:', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          ...constructionTypes.map((ct) {
            final isSel = _model.constructionType == ct;
            return InkWell(
              onTap: () => setState(() => _model.constructionType = ct),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      isSel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 18,
                      color: isSel ? primaryColor : subtitleColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ct,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Text('Walls / Ceiling Interior Finish:', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: wallFinishes.map((wf) {
              final isSel = _model.interiorFinishWalls == wf;
              return ChoiceChip(
                label: Text(wf.split(':')[0], style: const TextStyle(fontSize: 12)),
                selected: isSel,
                selectedColor: primaryColor,
                backgroundColor: inputBgColor,
                side: BorderSide(color: isSel ? primaryColor : borderColor),
                labelStyle: TextStyle(color: isSel ? Colors.white : titleColor, fontWeight: FontWeight.bold),
                onSelected: (val) => setState(() => _model.interiorFinishWalls = val ? wf : null),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Floor Interior Finish:', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: floorFinishes.map((ff) {
              final isSel = _model.interiorFinishFloor == ff;
              return ChoiceChip(
                label: Text(ff.split(':')[0], style: const TextStyle(fontSize: 12)),
                selected: isSel,
                selectedColor: primaryColor,
                backgroundColor: inputBgColor,
                side: BorderSide(color: isSel ? primaryColor : borderColor),
                labelStyle: TextStyle(color: isSel ? Colors.white : titleColor, fontWeight: FontWeight.bold),
                onSelected: (val) => setState(() => _model.interiorFinishFloor = val ? ff : null),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text('General Occupancy Classification:', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: occupancies.map((occ) {
              final isSel = _model.occupancyClassification == occ;
              return ChoiceChip(
                label: Text(occ, style: const TextStyle(fontSize: 12)),
                selected: isSel,
                selectedColor: primaryColor,
                backgroundColor: inputBgColor,
                side: BorderSide(color: isSel ? primaryColor : borderColor),
                labelStyle: TextStyle(color: isSel ? Colors.white : titleColor, fontWeight: FontWeight.bold),
                onSelected: (val) => setState(() => _model.occupancyClassification = val ? occ : null),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text('Sectional Occupancy Usage:', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildTextField('Basement', controller: _basementCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Ground Floor', controller: _groundFloorCtrl)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildTextField('Second Floor', controller: _secondFloorCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Third Floor', controller: _thirdFloorCtrl)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildTextField('Fourth Floor', controller: _fourthFloorCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Nth Floor', controller: _nthFloorCtrl)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Other Building Information:', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildTextField('Max Occupant Load (P/Floor)', controller: _occupantLoadCtrl, isNum: true)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Number of Stories', controller: _numberOfStoriesCtrl, isNum: true)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('Building Height (m)', controller: _buildingHeightCtrl, isNum: true)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Highrise Building?', style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    _buildYesNoToggleRow('', _model.isHighrise, (v) => setState(() => _model.isHighrise = v)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeansOfEgressSection() {
    final exitAccessComponents = [
      'Doors', 'Corridors / Hallways', 'Passageways', 'Lobby / Anteroom',
      'Ramps', 'Common path of travel', 'Dead end', 'Travel distance'
    ];

    final exitAccessRequirements = [
      'Door leaf unobstructing corridor / landing width',
      'Door leaf projection <= 180 mm into width',
      'At least 2 means of egress for room load >= 50 or hazard',
      'Guest door >= 20 minutes fire resistant',
      'Doors opening onto corridors are self-closing & self-latching',
      'No openings in corridor partitions other than doors',
      'Free from any obstruction',
      'No flammable material stored',
    ];

    final exitComponents = [
      'Exits Doors', 'Normal Stairs', 'Curve stairs', 'Winding Stairs',
      'Horizontal Exits', 'Outside Stairs', 'Exit Passageways', 'Fire Escape Stairs',
      'Fire Escape Ladders', 'Slide Escape'
    ];

    final exitRequirements = [
      'At least two (2) means of egress for each floor',
      'Doors assembly: 60 mins fire resistant (<= 3 communicating levels)',
      'Doors assembly: 90 mins fire resistant (>= 4 communicating levels)',
      'Exit doors with Re-entry mechanism at every 4 storey',
      'Stair tread: Minimum depth = 280 mm',
      'Stair riser: Height = 100 mm / 180 mm',
      'Minimum stair headroom: 2000 mm',
      'Stair provided with Guard and Handrails',
      'Maximum handrails projections: 114 mm',
      'Stair landing >= required width of exit door',
      'Exits doors open and close properly',
      'Doors swing in direction of egress',
      'Exit doors with panic hardware, vision panel & self-closing',
      'No enclosed usable space under stairs',
      'Interior finish: Class B',
    ];

    final dischargeRequirements = [
      'Remoteness of exit discharge >= 1/2 of length of overall dimension',
      'Remoteness >= 1/3 of length if protected throughout by ASASS',
      'Exterior grounds clear of objects impeding evacuation',
      'Terminate directly at a public way or exterior exit discharge',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildAccordion(
            title: 'A. Exit Access Components & Dimensions',
            icon: Icons.door_front_door_outlined,
            children: exitAccessComponents.map((comp) => _buildItemWithDimensionToggle(comp, _model.egressAccessStatus)).toList(),
          ),
          _buildAccordion(
            title: 'Exit Access Requirements',
            icon: Icons.fact_check_outlined,
            children: exitAccessRequirements.map((req) => _buildPassFailToggle(req, req, _model.egressRequirementsStatus)).toList(),
          ),
          _buildAccordion(
            title: 'B. Exits Components & Clear Width',
            icon: Icons.stairs_outlined,
            children: exitComponents.map((comp) => _buildItemWithDimensionToggle(comp, _model.exitComponentsStatus)).toList(),
          ),
          _buildAccordion(
            title: 'Exits Requirements (Stairs & Doors)',
            icon: Icons.rule_outlined,
            children: exitRequirements.map((req) => _buildPassFailToggle(req, req, _model.egressRequirementsStatus)).toList(),
          ),
          _buildAccordion(
            title: 'C. Exits Discharge Requirements',
            icon: Icons.directions_run_outlined,
            children: dischargeRequirements.map((req) => _buildPassFailToggle(req, req, _model.egressRequirementsStatus)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSignsAndSignageSection() {
    final egressMarkings = [
      'Minimum letter height, 150 mm',
      'EXIT signs posted along Exit access, Exits and Exit discharge',
      'EXIT signs properly illuminated',
    ];

    final planChecklist = [
      'Posted on strategic & conspicuous location inside building',
      'Photo-luminescent background for power failure visibility',
      'Contains basic markings (You are Here, Exits, Routes, Pull stations, Extinguishers, Emergency Light, First Aid, Call stations, Assembly areas)',
      'Floor area < 50 m² (Size 330.2 x 215.9 mm)',
      'Floor area 50-150 m² (Size 609.6 x 457.2 mm)',
      'Floor area >= 151 m² (Size 609.6 x 914.4 mm)',
    ];

    final illuminationChecklist = [
      'Floors walking surfaces >= 1 ft-candle (10.8 lux)',
      'Assembly occupancies walking surfaces >= 0.2 ft-candle (2.2 lux)',
      'Stairs walking surfaces >= 10 ft-candle (108 lux)',
      'Emergency lighting average 1 ft-candle (min 0.1 ft-candle for 1.5 hr)',
      'Emergency lighting auto-activates on normal power failure',
      'Periodic Testing of Emergency Lighting Equipment (Written record)',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildAccordion(
            title: 'A. Marking of Means of Egress (EXIT)',
            icon: Icons.signpost_outlined,
            children: egressMarkings.map((m) => _buildPassFailToggle(m, m, _model.exitSignageStatus)).toList(),
          ),
          _buildAccordion(
            title: 'B. Emergency Evacuation Plan',
            icon: Icons.map_outlined,
            children: planChecklist.map((item) => _buildPassFailToggle(item, item, _model.exitSignageStatus)).toList(),
          ),
          _buildAccordion(
            title: 'C. Illumination of Means of Egress',
            icon: Icons.lightbulb_outlined,
            children: illuminationChecklist.map((item) => _buildPassFailToggle(item, item, _model.exitSignageStatus)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHazardSection() {
    final flammableLiquids = [
      'Stored in sealed metal containers',
      'Properly dispensed as per SOP',
      'Provided with "NO SMOKING" sign',
    ];

    final miscHazards = [
      'All no smoking areas have adequate signs',
      'Gasoline / Diesel stored in proper place & metal safety can',
    ];

    final housekeeping = [
      'Brooms, mops, rags stored in metal cabinets or approved cans',
      'Paints, solvents stored in metal cabinet; oily rags in metal containers',
      'Dry leaves, shrubbery trimmings kept away from buildings',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildAccordion(
            title: 'A. Other Flammable Liquids (Alcohol, Ether, etc.)',
            icon: Icons.science_outlined,
            children: flammableLiquids.map((item) => _buildPassFailToggle(item, item, _model.hazardStatus)).toList(),
          ),
          _buildAccordion(
            title: 'B. Miscellaneous Hazards (Equipment/Storage)',
            icon: Icons.inventory_2_outlined,
            children: miscHazards.map((item) => _buildPassFailToggle(item, item, _model.hazardStatus)).toList(),
          ),
          _buildAccordion(
            title: 'C. Housekeeping & Waste Disposal',
            icon: Icons.cleaning_services_outlined,
            children: housekeeping.map((item) => _buildPassFailToggle(item, item, _model.hazardStatus)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFireProtectionSection() {
    final sprinklerItems = [
      'Sprinkler Pumps - Check automatic start and pressure',
      'Sprinkler Valves - Valves locked open, no leaks/corrosion',
      'Sprinkler Water Flow Alarm - Open test valve & check manual alarm bell',
    ];

    final hoseCabinetItems = [
      'Cabinet Door Operative - Unobstructed and opens properly',
      'Hose Condition - Not rotted, wet, or moldy',
      'Nozzle - In place and operates correctly',
      'Hose Hung Properly - Easily un-rolled if needed',
      'Valves & Handles - Handles in place, open position',
    ];

    final firePumpItems = [
      'Pump System - Inspect accuracy of gauges & sensors',
      'Pipings - Check pipings for leaks',
      'Motor - Check unusual noise or vibrations',
      'Electrical System - Check corrosion, wire insulation, leaks',
    ];

    final alarmAndExtinguishers = [
      'Fire Detection System - Random test call points & smoke detectors',
      'Fire Alarm Facilities - Location signs legible & panels unobstructed',
      'Lifts (Elevator) - Home to ground floor, fans & fireman lift operating',
      'Extinguishers Size - Minimal sizes meet RA 9514 table 7 & 8',
      'Extinguishers Quantity - Minimum count meets RA 9514 requirements',
      'Extinguishers Location & Tags - Proper location, intact seals/tags',
      'Extinguishers Pressure - Gauge reads in the "green" area',
      'Emergency Lighting Battery - Battery lights turn on on power failure',
      'Kitchen Hoods & Vents - Hoods, vents, fans & ducts free from grease',
      'Fire Wall (FW) - Provided min 2 hrs fire resistance (>=760mm extension)',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildAccordion(
            title: 'A. Automatic Fire Suppression System (Sprinkler)',
            icon: Icons.water_drop_outlined,
            children: sprinklerItems.map((item) => _buildPassFailToggle(item, item, _model.fireProtectionStatus)).toList(),
          ),
          _buildAccordion(
            title: 'B. Wet Standpipe / Fire Hose Cabinet',
            icon: Icons.local_fire_department_outlined,
            children: hoseCabinetItems.map((item) => _buildPassFailToggle(item, item, _model.fireProtectionStatus)).toList(),
          ),
          _buildAccordion(
            title: 'C. Fire Pump Infrastructure',
            icon: Icons.speed_outlined,
            children: firePumpItems.map((item) => _buildPassFailToggle(item, item, _model.fireProtectionStatus)).toList(),
          ),
          _buildAccordion(
            title: 'D-K. Fire Alarms, Extinguishers, Kitchen & Fire Wall',
            icon: Icons.shield_outlined,
            children: alarmAndExtinguishers.map((item) => _buildPassFailToggle(item, item, _model.fireProtectionStatus)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDefectsAndRecommendationsSection() {
    final recommendations = [
      {'label': 'Issuance of FSIC', 'value': 'FSIC'},
      {'label': 'Notice to Comply', 'value': 'NoticeToComply'},
      {'label': 'Notice to Correct Violation', 'value': 'NoticeToCorrectViolation'},
      {'label': 'Closure Order', 'value': 'ClosureOrder'},
      {'label': 'Abatement Order with Administrative Fine', 'value': 'AbatementOrder'},
      {'label': 'Notice of Disapproval (NOD)', 'value': 'NOD'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('DEFECTS / DEFICIENCIES SUMMARY', controller: _defectsSummaryCtrl, maxLines: 3, hint: 'State defects found in Items IV to VIII'),
          const SizedBox(height: 18),
          Text('RECOMMENDATIONS:', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          ...recommendations.map((rec) {
            final isSel = _model.recommendationAction == rec['value'];
            return InkWell(
              onTap: () => setState(() => _model.recommendationAction = rec['value']),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      isSel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 18,
                      color: isSel ? primaryColor : subtitleColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rec['label']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          Text('Signatures & Approvals:', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          _buildTextField('Fire Safety Inspector/s', controller: _inspectorNameCtrl),
          const SizedBox(height: 12),
          _buildTextField('Team Leader', controller: _teamLeaderNameCtrl),
          const SizedBox(height: 12),
          _buildTextField('City / Municipal Fire Marshal', controller: _fireMarshalNameCtrl),
        ],
      ),
    );
  }

  Widget _buildPhotoDocumentationSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          InkWell(
            onTap: _isUploading ? null : _pickAndUploadImage,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                color: inputBgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  if (_isUploading)
                    CircularProgressIndicator(color: primaryColor)
                  else ...[
                    Icon(Icons.camera_alt_outlined, size: 34, color: primaryColor),
                    const SizedBox(height: 8),
                    Text('Tap to capture commercial inspection photos', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('Attach visual evidence for BFP records', style: TextStyle(color: subtitleColor, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ),
          if (_photoUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _photoUrls.length,
              itemBuilder: (context, index) {
                final urlOrPath = _photoUrls[index];
                ImageProvider imgProvider;
                if (urlOrPath.startsWith('http')) {
                  imgProvider = NetworkImage(urlOrPath);
                } else {
                  imgProvider = FileImage(File(urlOrPath));
                }

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                    image: DecorationImage(
                      image: imgProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submitReport,
          icon: _isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.send_outlined, size: 20, color: Colors.white),
          label: Text(
            _isSubmitting ? 'SUBMITTING CHECKLIST...' : 'SUBMIT COMMERCIAL BFP CHECKLIST',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildAccordion({required String title, required List<Widget> children, IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: icon != null ? Icon(icon, size: 20, color: primaryColor) : null,
          title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: children,
        ),
      ),
    );
  }

  Widget _buildItemWithDimensionToggle(String label, Map<String, String> statusMap) {
    final currentStatus = statusMap[label];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextFormField(
                  onChanged: (val) => _model.itemDimensions[label] = val,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 12, color: titleColor, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'Dim (m)',
                    hintStyle: TextStyle(color: subtitleColor.withOpacity(0.5), fontSize: 11),
                    filled: true,
                    fillColor: inputBgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: primaryColor, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: ['Passed', 'Failed', 'N/A'].map((opt) {
                    final isSel = currentStatus == opt;
                    Color bg = const Color(0xFFF1F5F9);
                    Color borderC = borderColor;
                    Color textC = subtitleColor;
                    IconData iconData = Icons.do_not_disturb_on_outlined;

                    if (opt == 'Passed') {
                      bg = isSel ? const Color(0xFFDCFCE7) : surfaceColor;
                      borderC = isSel ? successColor : borderColor;
                      textC = isSel ? const Color(0xFF15803D) : subtitleColor;
                      iconData = Icons.check_circle_outlined;
                    } else if (opt == 'Failed') {
                      bg = isSel ? const Color(0xFFFEE2E2) : surfaceColor;
                      borderC = isSel ? errorColor : borderColor;
                      textC = isSel ? const Color(0xFFB91C1C) : subtitleColor;
                      iconData = Icons.cancel_outlined;
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => statusMap[label] = opt),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: bg,
                            border: Border.all(color: borderC, width: isSel ? 1.5 : 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(iconData, size: 13, color: textC),
                              const SizedBox(width: 4),
                              Text(
                                opt,
                                style: TextStyle(color: textC, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPassFailToggle(String label, String key, Map<String, String> map) {
    final current = map[key];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: ['Passed', 'Failed', 'N/A'].map((opt) {
              final isSel = current == opt;
              Color bg = const Color(0xFFF1F5F9);
              Color borderC = borderColor;
              Color textC = subtitleColor;
              IconData iconData = Icons.do_not_disturb_on_outlined;

              if (opt == 'Passed') {
                bg = isSel ? const Color(0xFFDCFCE7) : surfaceColor;
                borderC = isSel ? successColor : borderColor;
                textC = isSel ? const Color(0xFF15803D) : subtitleColor;
                iconData = Icons.check_circle_outlined;
              } else if (opt == 'Failed') {
                bg = isSel ? const Color(0xFFFEE2E2) : surfaceColor;
                borderC = isSel ? errorColor : borderColor;
                textC = isSel ? const Color(0xFFB91C1C) : subtitleColor;
                iconData = Icons.cancel_outlined;
              }

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => map[key] = opt),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: bg,
                      border: Border.all(color: borderC, width: isSel ? 1.5 : 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(iconData, size: 13, color: textC),
                        const SizedBox(width: 4),
                        Text(
                          opt,
                          style: TextStyle(color: textC, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildYesNoToggleRow(String label, String? currentVal, Function(String) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (label.isNotEmpty)
          Expanded(child: Text(label, style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.w600))),
        Row(
          children: ['Yes', 'No', 'N/A'].map((opt) {
            final isSel = currentVal == opt;
            Color bg = const Color(0xFFF1F5F9);
            Color borderC = borderColor;
            Color textC = subtitleColor;

            if (opt == 'Yes') {
              bg = isSel ? const Color(0xFFDCFCE7) : surfaceColor;
              borderC = isSel ? successColor : borderColor;
              textC = isSel ? const Color(0xFF15803D) : subtitleColor;
            } else if (opt == 'No') {
              bg = isSel ? const Color(0xFFFEE2E2) : surfaceColor;
              borderC = isSel ? errorColor : borderColor;
              textC = isSel ? const Color(0xFFB91C1C) : subtitleColor;
            }

            return GestureDetector(
              onTap: () => onChanged(opt),
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: borderC, width: isSel ? 1.5 : 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  opt,
                  style: TextStyle(color: textC, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, fontSize: 12),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, {required TextEditingController controller, String? hint, bool isNum = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNum ? TextInputType.number : TextInputType.text,
          style: TextStyle(fontSize: 13, color: titleColor),
          decoration: InputDecoration(
            hintText: hint ?? 'Enter $label',
            hintStyle: TextStyle(color: subtitleColor.withOpacity(0.5), fontSize: 12),
            filled: true,
            fillColor: inputBgColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryColor, width: 1.5)),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
