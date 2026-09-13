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
  final _formKey = GlobalKey<FormState>();
  final _model = CommercialChecklistModel();

  int _currentStep = 0; // 0 to 5 (6 Steps)
  final ScrollController _stepScrollController = ScrollController();

  // Design Tokens
  static const Color colorPrimary = Color(0xFFEA580C);
  static const Color colorNavy = Color(0xFF0F172A);
  static const Color colorSuccess = Color(0xFF16A34A);
  static const Color colorWarning = Color(0xFFD97706);
  static const Color colorError = Color(0xFFDC2626);
  static const Color colorSurface = Colors.white;
  static const Color colorBorder = Color(0xFFE2E8F0);
  static const Color colorBg = Color(0xFFF8FAFC);
  static const Color colorTextSecondary = Color(0xFF64748B);

  final List<String> _photoUrls = [];
  bool _isUploading = false;
  bool _isSubmitting = false;

  final List<String> _stepTitles = const [
    'Reference & Profile',
    'Building Specs & Occupancy',
    'Means of Egress',
    'Signs, Lighting & Hazards',
    'Fire Protection Systems',
    'Defects & Signatures',
  ];

  // Controllers - Step 1: Reference & Profile
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

  // Controllers - Step 2: Specs & Sectional Occupancy
  final _basementCtrl = TextEditingController();
  final _groundFloorCtrl = TextEditingController();
  final _secondFloorCtrl = TextEditingController();
  final _thirdFloorCtrl = TextEditingController();
  final _fourthFloorCtrl = TextEditingController();
  final _nthFloorCtrl = TextEditingController();

  final _occupantLoadCtrl = TextEditingController();
  final _numberOfStoriesCtrl = TextEditingController();
  final _buildingHeightCtrl = TextEditingController();

  // Controllers - Step 4: Hazards
  final _hazardContentsCtrl = TextEditingController();
  final _hazardQuantityCtrl = TextEditingController();
  final _hazardPlacardCtrl = TextEditingController();
  final _hazardIdentificationNoCtrl = TextEditingController();
  final _hazardClassCtrl = TextEditingController();
  final _flashPointCtrl = TextEditingController();

  // Controllers - Step 6: Defects & Signatures
  final _defectsSummaryCtrl = TextEditingController();
  final _defectsItemIVCtrl = TextEditingController();
  final _defectsItemVCtrl = TextEditingController();
  final _defectsItemVICtrl = TextEditingController();
  final _defectsItemVIICtrl = TextEditingController();
  final _defectsItemVIIICtrl = TextEditingController();
  final _recommendationNotesCtrl = TextEditingController();

  final _inspectorNameCtrl = TextEditingController();
  final _teamLeaderNameCtrl = TextEditingController();
  final _chiefFsedNameCtrl = TextEditingController();
  final _fireMarshalNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initDefaultValues();
    _loadExistingInspection();
  }

  void _initDefaultValues() {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    _dateIssuedCtrl.text = todayStr;
    _dateInspectedCtrl.text = todayStr;

    if (widget.initialIoNumber != null && widget.initialIoNumber!.isNotEmpty) {
      _ioNumberCtrl.text = widget.initialIoNumber!;
    } else {
      _ioNumberCtrl.text = 'IO-${now.year}-${now.millisecondsSinceEpoch.toString().substring(8)}';
    }

    if (widget.initialBusinessName != null) {
      _businessNameCtrl.text = widget.initialBusinessName!;
      _buildingNameCtrl.text = widget.initialBusinessName!;
    }
    if (widget.initialAddress != null) {
      _addressCtrl.text = widget.initialAddress!;
    }

    _model.inspectionNature = 'BusinessPermit';
    _model.constructionType = 'Type I : Concrete & Steel (Fire Resistive)';
    _model.occupancyClassification = 'Mercantile';
    _model.interiorFinishWalls = 'Class A : Flame spread index, 0–25; smoke developed index, 0–450';
    _model.interiorFinishFloor = 'Class I : Critical radiant flux, not less than 0.45 W/cm2';
    _model.isHighrise = 'No';
    _model.recommendationAction = 'FSIC';

    // Auto-populate logged-in inspector profile
    final userProf = AuthService().userProfile;
    if (userProf != null && userProf['full_name'] != null) {
      _inspectorNameCtrl.text = userProf['full_name'].toString();
    }
    _teamLeaderNameCtrl.text = 'SFO4 Mario D. Ramos, BFP';
    _chiefFsedNameCtrl.text = 'INSP JUAN DELA CRUZ, BFP';
    _fireMarshalNameCtrl.text = 'CINSP ROBERTO P. SANTOS, BFP';
  }

  Future<void> _loadExistingInspection() async {
    if (widget.assignmentId == null || widget.assignmentId!.isEmpty) return;

    try {
      final res = await Supabase.instance.client
          .from('inspections')
          .select()
          .eq('id', widget.assignmentId!)
          .maybeSingle();

      if (res != null && res['checklist_data'] != null && mounted) {
        final data = res['checklist_data'] as Map<String, dynamic>;
        final loaded = CommercialChecklistModel.fromJson(data);

        setState(() {
          // Copy fields into controllers
          if (loaded.ioNumber.isNotEmpty) _ioNumberCtrl.text = loaded.ioNumber;
          if (loaded.dateIssued.isNotEmpty) _dateIssuedCtrl.text = loaded.dateIssued;
          if (loaded.dateInspected.isNotEmpty) _dateInspectedCtrl.text = loaded.dateInspected;
          if (loaded.buildingName.isNotEmpty) _buildingNameCtrl.text = loaded.buildingName;
          if (loaded.address.isNotEmpty) _addressCtrl.text = loaded.address;
          if (loaded.businessName.isNotEmpty) _businessNameCtrl.text = loaded.businessName;
          if (loaded.natureOfBusiness.isNotEmpty) _natureOfBusinessCtrl.text = loaded.natureOfBusiness;
          if (loaded.ownerRepresentative.isNotEmpty) _ownerRepresentativeCtrl.text = loaded.ownerRepresentative;
          if (loaded.contactNo.isNotEmpty) _contactNoCtrl.text = loaded.contactNo;

          if (loaded.fsecNo.isNotEmpty) _fsecNoCtrl.text = loaded.fsecNo;
          if (loaded.fsecDateIssued.isNotEmpty) _fsecDateCtrl.text = loaded.fsecDateIssued;
          if (loaded.buildingPermitNo.isNotEmpty) _buildingPermitNoCtrl.text = loaded.buildingPermitNo;
          if (loaded.buildingPermitDateIssued.isNotEmpty) _buildingPermitDateCtrl.text = loaded.buildingPermitDateIssued;
          if (loaded.fsicNoLatest.isNotEmpty) _fsicNoLatestCtrl.text = loaded.fsicNoLatest;
          if (loaded.fsicDateIssued.isNotEmpty) _fsicDateCtrl.text = loaded.fsicDateIssued;
          if (loaded.fireDrillCertNo.isNotEmpty) _fireDrillCertCtrl.text = loaded.fireDrillCertNo;
          if (loaded.fireDrillDateIssued.isNotEmpty) _fireDrillDateCtrl.text = loaded.fireDrillDateIssued;
          if (loaded.businessPermitNo.isNotEmpty) _businessPermitNoCtrl.text = loaded.businessPermitNo;
          if (loaded.businessPermitDateIssued.isNotEmpty) _businessPermitDateCtrl.text = loaded.businessPermitDateIssued;
          if (loaded.fireInsurancePolicyNo.isNotEmpty) _fireInsurancePolicyNoCtrl.text = loaded.fireInsurancePolicyNo;
          if (loaded.fireInsuranceDateIssued.isNotEmpty) _fireInsuranceDateCtrl.text = loaded.fireInsuranceDateIssued;

          if (loaded.basementUsage.isNotEmpty) _basementCtrl.text = loaded.basementUsage;
          if (loaded.groundFloorUsage.isNotEmpty) _groundFloorCtrl.text = loaded.groundFloorUsage;
          if (loaded.secondFloorUsage.isNotEmpty) _secondFloorCtrl.text = loaded.secondFloorUsage;
          if (loaded.thirdFloorUsage.isNotEmpty) _thirdFloorCtrl.text = loaded.thirdFloorUsage;
          if (loaded.fourthFloorUsage.isNotEmpty) _fourthFloorCtrl.text = loaded.fourthFloorUsage;
          if (loaded.nthFloorUsage.isNotEmpty) _nthFloorCtrl.text = loaded.nthFloorUsage;

          if (loaded.occupantLoad.isNotEmpty) _occupantLoadCtrl.text = loaded.occupantLoad;
          if (loaded.numberOfStories.isNotEmpty) _numberOfStoriesCtrl.text = loaded.numberOfStories;
          if (loaded.buildingHeight.isNotEmpty) _buildingHeightCtrl.text = loaded.buildingHeight;

          if (loaded.hazardContents.isNotEmpty) _hazardContentsCtrl.text = loaded.hazardContents;
          if (loaded.hazardQuantity.isNotEmpty) _hazardQuantityCtrl.text = loaded.hazardQuantity;
          if (loaded.hazardPlacard.isNotEmpty) _hazardPlacardCtrl.text = loaded.hazardPlacard;
          if (loaded.hazardIdentificationNo.isNotEmpty) _hazardIdentificationNoCtrl.text = loaded.hazardIdentificationNo;
          if (loaded.hazardClass.isNotEmpty) _hazardClassCtrl.text = loaded.hazardClass;
          if (loaded.flashPoint.isNotEmpty) _flashPointCtrl.text = loaded.flashPoint;

          if (loaded.defectsItemIV.isNotEmpty) _defectsItemIVCtrl.text = loaded.defectsItemIV;
          if (loaded.defectsItemV.isNotEmpty) _defectsItemVCtrl.text = loaded.defectsItemV;
          if (loaded.defectsItemVI.isNotEmpty) _defectsItemVICtrl.text = loaded.defectsItemVI;
          if (loaded.defectsItemVII.isNotEmpty) _defectsItemVIICtrl.text = loaded.defectsItemVII;
          if (loaded.defectsItemVIII.isNotEmpty) _defectsItemVIIICtrl.text = loaded.defectsItemVIII;
          if (loaded.defectsSummary.isNotEmpty) _defectsSummaryCtrl.text = loaded.defectsSummary;

          if (loaded.inspectorName.isNotEmpty) _inspectorNameCtrl.text = loaded.inspectorName;
          if (loaded.teamLeaderName.isNotEmpty) _teamLeaderNameCtrl.text = loaded.teamLeaderName;
          if (loaded.chiefFsedName.isNotEmpty) _chiefFsedNameCtrl.text = loaded.chiefFsedName;
          if (loaded.fireMarshalName.isNotEmpty) _fireMarshalNameCtrl.text = loaded.fireMarshalName;

          // Copy map & state references
          _model.inspectionNature = loaded.inspectionNature;
          _model.verificationType = loaded.verificationType;
          _model.fsccrRequired = loaded.fsccrRequired;
          _model.fsmrRequired = loaded.fsmrRequired;
          _model.constructionType = loaded.constructionType;
          _model.interiorFinishWalls = loaded.interiorFinishWalls;
          _model.interiorFinishFloor = loaded.interiorFinishFloor;
          _model.occupancyClassification = loaded.occupancyClassification;
          _model.isHighrise = loaded.isHighrise;
          _model.withinMaq = loaded.withinMaq;
          _model.hazardClassification = loaded.hazardClassification;
          _model.bseUtilities = loaded.bseUtilities;
          _model.bseHvac = loaded.bseHvac;
          _model.bseSmokeControl = loaded.bseSmokeControl;
          _model.bseRubbishChutes = loaded.bseRubbishChutes;
          _model.fireWallProvided = loaded.fireWallProvided;
          _model.fireWallExtension = loaded.fireWallExtension;
          _model.fireWallType = loaded.fireWallType;
          _model.recommendationAction = loaded.recommendationAction;

          _model.egressAccessStatus.addAll(loaded.egressAccessStatus);
          _model.exitComponentsStatus.addAll(loaded.exitComponentsStatus);
          _model.egressRequirementsStatus.addAll(loaded.egressRequirementsStatus);
          _model.exitSignageStatus.addAll(loaded.exitSignageStatus);
          _model.hazardStatus.addAll(loaded.hazardStatus);
          _model.fireProtectionStatus.addAll(loaded.fireProtectionStatus);
          _model.itemDimensions.addAll(loaded.itemDimensions);
          _model.itemRemarks.addAll(loaded.itemRemarks);

          if (res['hazard_photo_urls'] is List) {
            _photoUrls.addAll(List<String>.from(res['hazard_photo_urls']));
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching existing inspection: $e');
    }
  }

  @override
  void dispose() {
    _stepScrollController.dispose();
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
    _hazardContentsCtrl.dispose();
    _hazardQuantityCtrl.dispose();
    _hazardPlacardCtrl.dispose();
    _hazardIdentificationNoCtrl.dispose();
    _hazardClassCtrl.dispose();
    _flashPointCtrl.dispose();
    _defectsSummaryCtrl.dispose();
    _defectsItemIVCtrl.dispose();
    _defectsItemVCtrl.dispose();
    _defectsItemVICtrl.dispose();
    _defectsItemVIICtrl.dispose();
    _defectsItemVIIICtrl.dispose();
    _recommendationNotesCtrl.dispose();
    _inspectorNameCtrl.dispose();
    _teamLeaderNameCtrl.dispose();
    _chiefFsedNameCtrl.dispose();
    _fireMarshalNameCtrl.dispose();
    super.dispose();
  }

  void _syncControllersToModel() {
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

    _model.hazardContents = _hazardContentsCtrl.text;
    _model.hazardQuantity = _hazardQuantityCtrl.text;
    _model.hazardPlacard = _hazardPlacardCtrl.text;
    _model.hazardIdentificationNo = _hazardIdentificationNoCtrl.text;
    _model.hazardClass = _hazardClassCtrl.text;
    _model.flashPoint = _flashPointCtrl.text;

    _model.defectsItemIV = _defectsItemIVCtrl.text;
    _model.defectsItemV = _defectsItemVCtrl.text;
    _model.defectsItemVI = _defectsItemVICtrl.text;
    _model.defectsItemVII = _defectsItemVIICtrl.text;
    _model.defectsItemVIII = _defectsItemVIIICtrl.text;
    _model.defectsSummary = _defectsSummaryCtrl.text;
    _model.recommendationNotes = _recommendationNotesCtrl.text;

    _model.inspectorName = _inspectorNameCtrl.text;
    _model.teamLeaderName = _teamLeaderNameCtrl.text;
    _model.chiefFsedName = _chiefFsedNameCtrl.text;
    _model.fireMarshalName = _fireMarshalNameCtrl.text;
  }

  Map<String, dynamic> _buildPayload(bool isOnline, String userId) {
    _syncControllersToModel();
    final payloadData = _model.toJson();
    payloadData['checklist_type'] = 'commercial';

    return <String, dynamic>{
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
  }

  Future<void> _saveDraft() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? AuthService().userProfile?['id']?.toString() ?? 'local_inspector';
    final payload = _buildPayload(false, userId);
    payload['overall_status'] = 'Draft';

    await OfflineSyncService().queueForSync(
      targetTable: 'inspections',
      payload: payload,
      id: widget.assignmentId,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.save_outlined, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Draft saved locally! You can resume anytime.'),
          ],
        ),
        backgroundColor: colorNavy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitInspection() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify required fields before submitting.'),
          backgroundColor: colorError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id ?? AuthService().userProfile?['id']?.toString();
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User session not found. Please log in again.'), backgroundColor: colorError),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final isOnline = await ConnectivityService().hasInternetConnection();
      final payload = _buildPayload(isOnline, userId);

      if (!isOnline) {
        await OfflineSyncService().queueForSync(
          targetTable: 'inspections',
          payload: payload,
          id: widget.assignmentId,
        );

        await AuthService().logAuditAction(
          actionType: 'COMMERCIAL_INSPECTION_QUEUED_OFFLINE',
          targetEntity: _model.businessName,
          details: 'Commercial Checklist (IO: ${_model.ioNumber}) saved offline.',
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally (Offline). Will automatically sync when connected.'),
            backgroundColor: colorWarning,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
        return;
      }

      if (widget.assignmentId != null && widget.assignmentId!.isNotEmpty) {
        await Supabase.instance.client
            .from('inspections')
            .update(payload)
            .eq('id', widget.assignmentId!);
      } else {
        await Supabase.instance.client
            .from('inspections')
            .insert(payload);
      }

      await AuthService().logAuditAction(
        actionType: 'COMMERCIAL_INSPECTION_SUBMITTED',
        targetEntity: _model.businessName,
        details: 'Submitted Commercial Fire Safety Inspection (IO: ${_model.ioNumber}). Recommendation: ${_model.recommendationAction}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Commercial Inspection submitted successfully!')),
            ],
          ),
          backgroundColor: colorSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Submission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e'), backgroundColor: colorError),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
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
        final url = Supabase.instance.client.storage.from('hazard-photos').getPublicUrl(fileName);
        setState(() => _photoUrls.add(url));
      } else {
        setState(() => _photoUrls.add(pickedFile.path));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo stored locally for sync.'), backgroundColor: colorWarning),
          );
        }
      }
    } catch (e) {
      setState(() => _photoUrls.add(pickedFile.path));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _nextStep() {
    if (_currentStep < _stepTitles.length - 1) {
      setState(() => _currentStep++);
      _stepScrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submitInspection();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _stepScrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildStickyHeaderBar(),
          Expanded(
            child: SingleChildScrollView(
              controller: _stepScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: _buildCurrentStepView(),
            ),
          ),
          _buildBottomWizardBar(),
        ],
      ),
    );
  }

  Widget _buildStickyHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colorSurface,
        border: const Border(bottom: BorderSide(color: colorBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEP ${_currentStep + 1} OF 6',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorPrimary, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _stepTitles[_currentStep],
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorNavy),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.description_outlined, size: 14, color: colorPrimary),
                    const SizedBox(width: 4),
                    Text(
                      _ioNumberCtrl.text.isNotEmpty ? _ioNumberCtrl.text : 'BFP 061',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorNavy),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 6,
              backgroundColor: const Color(0xFFF1F5F9),
              color: colorPrimary,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomWizardBar() {
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == _stepTitles.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorSurface,
        border: const Border(top: BorderSide(color: colorBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (!isFirstStep) ...[
              OutlinedButton.icon(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  side: const BorderSide(color: colorBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.arrow_back, size: 16, color: colorNavy),
                label: const Text('Back', style: TextStyle(color: colorNavy, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              onPressed: _saveDraft,
              tooltip: 'Save Draft',
              icon: const Icon(Icons.bookmark_outline, color: colorNavy),
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: colorBorder)),
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastStep ? colorSuccess : colorPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(isLastStep ? Icons.send_outlined : Icons.arrow_forward, size: 16),
                label: Text(
                  _isSubmitting
                      ? 'Submitting...'
                      : isLastStep
                          ? 'Submit Inspection'
                          : 'Next: ${_stepTitles[_currentStep + 1]}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildStep1ReferenceAndProfile();
      case 1:
        return _buildStep2BuildingSpecsAndOccupancy();
      case 2:
        return _buildStep3MeansOfEgress();
      case 3:
        return _buildStep4SignsLightingHazards();
      case 4:
        return _buildStep5FireProtectionSystems();
      case 5:
        return _buildStep6DefectsAndSignatures();
      default:
        return _buildStep1ReferenceAndProfile();
    }
  }

  // ==========================================
  // STEP 1: REFERENCE, NATURE & PROFILE
  // ==========================================
  Widget _buildStep1ReferenceAndProfile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'I. REFERENCE',
          icon: Icons.assignment_outlined,
          child: Column(
            children: [
              TextFormField(
                controller: _ioNumberCtrl,
                decoration: const InputDecoration(labelText: 'Inspection Order No. (IO) *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'IO number required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dateIssuedCtrl,
                      decoration: const InputDecoration(labelText: 'Date Issued', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today, size: 16)),
                      readOnly: true,
                      onTap: () async {
                        final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (d != null) _dateIssuedCtrl.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _dateInspectedCtrl,
                      decoration: const InputDecoration(labelText: 'Date Inspected', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today, size: 16)),
                      readOnly: true,
                      onTap: () async {
                        final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (d != null) _dateInspectedCtrl.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'II. NATURE OF INSPECTION CONDUCTED',
          icon: Icons.checklist_rtl_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChoiceChip('Construction', 'Inspection during construction'),
                  _buildChoiceChip('PEZA', 'FSIC for PEZA Annual'),
                  _buildChoiceChip('Occupancy', 'FSIC for Certificate of Occupancy'),
                  _buildChoiceChip('BusinessPermit', 'FSIC for Business Permit'),
                  _buildChoiceChip('Verification', 'Verification for Compliance'),
                  _buildChoiceChip('Others', 'Others (Specify)'),
                ],
              ),
              if (_model.inspectionNature == 'Verification') ...[
                const SizedBox(height: 12),
                const Text('VERIFICATION ORDER TYPE:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: ['NTC', 'NTCV', 'Abatement', 'Closure'].map((v) {
                    final isSel = _model.verificationType == v;
                    return ChoiceChip(
                      label: Text(v, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : colorNavy)),
                      selected: isSel,
                      selectedColor: colorPrimary,
                      onSelected: (val) => setState(() => _model.verificationType = val ? v : null),
                    );
                  }).toList(),
                ),
              ],
              if (_model.inspectionNature == 'Others') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _natureOthersCtrl,
                  decoration: const InputDecoration(labelText: 'Specify Other Nature', border: OutlineInputBorder()),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'III. REQUIREMENTS',
          icon: Icons.folder_shared_outlined,
          child: Column(
            children: [
              _buildYesNoNaRow(
                'Fire Safety Compliance and Commissioning Report (FSCCR)',
                _model.fsccrRequired,
                (val) => setState(() => _model.fsccrRequired = val),
              ),
              const Divider(height: 18),
              _buildYesNoNaRow(
                'Fire Safety Maintenance Report (FSMR)',
                _model.fsmrRequired,
                (val) => setState(() => _model.fsmrRequired = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'IV. GENERAL INFORMATION & PERMITS',
          icon: Icons.storefront_outlined,
          child: Column(
            children: [
              TextFormField(
                controller: _businessNameCtrl,
                decoration: const InputDecoration(labelText: 'Business Name *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Business name required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _buildingNameCtrl,
                decoration: const InputDecoration(labelText: 'Name of Building', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Address *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Address required' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _natureOfBusinessCtrl,
                      decoration: const InputDecoration(labelText: 'Nature of Business', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _contactNoCtrl,
                      decoration: const InputDecoration(labelText: 'Contact No.', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ownerRepresentativeCtrl,
                decoration: const InputDecoration(labelText: 'Name of Owner / Representative *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('PERMIT NUMBERS & DATES ISSUED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextSecondary)),
              ),
              const SizedBox(height: 8),
              _buildTwoFieldRow('FSEC No.', _fsecNoCtrl, 'Date Issued', _fsecDateCtrl),
              const SizedBox(height: 8),
              _buildTwoFieldRow('Building Permit No.', _buildingPermitNoCtrl, 'Date Issued', _buildingPermitDateCtrl),
              const SizedBox(height: 8),
              _buildTwoFieldRow('Latest FSIC No.', _fsicNoLatestCtrl, 'Date Issued', _fsicDateCtrl),
              const SizedBox(height: 8),
              _buildTwoFieldRow('Cert of Fire Drill No.', _fireDrillCertCtrl, 'Date Issued', _fireDrillDateCtrl),
              const SizedBox(height: 8),
              _buildTwoFieldRow('Business Permit No.', _businessPermitNoCtrl, 'Date Issued', _businessPermitDateCtrl),
              const SizedBox(height: 8),
              _buildTwoFieldRow('Fire Insurance Policy No.', _fireInsurancePolicyNoCtrl, 'Date Issued', _fireInsuranceDateCtrl),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 2: BUILDING SPECS & OCCUPANCY
  // ==========================================
  Widget _buildStep2BuildingSpecsAndOccupancy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'CONSTRUCTION TYPE',
          icon: Icons.apartment_outlined,
          child: Column(
            children: CommercialChecklistModel.constructionTypes.map((type) {
              return RadioListTile<String>(
                title: Text(type, style: const TextStyle(fontSize: 12)),
                value: type,
                groupValue: _model.constructionType,
                dense: true,
                activeColor: colorPrimary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _model.constructionType = val),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'INTERIOR FINISHES',
          icon: Icons.layers_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('WALLS / CEILING FINISH:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextSecondary)),
              ...CommercialChecklistModel.wallsCeilingFinishes.map((f) {
                return RadioListTile<String>(
                  title: Text(f, style: const TextStyle(fontSize: 11.5)),
                  value: f,
                  groupValue: _model.interiorFinishWalls,
                  dense: true,
                  activeColor: colorPrimary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _model.interiorFinishWalls = val),
                );
              }),
              const Divider(height: 16),
              const Text('FLOOR INTERIOR FINISH:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextSecondary)),
              ...CommercialChecklistModel.floorFinishes.map((f) {
                return RadioListTile<String>(
                  title: Text(f, style: const TextStyle(fontSize: 11.5)),
                  value: f,
                  groupValue: _model.interiorFinishFloor,
                  dense: true,
                  activeColor: colorPrimary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _model.interiorFinishFloor = val),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'SECTIONAL OCCUPANCY (USAGE PER FLOOR)',
          icon: Icons.stairs_outlined,
          child: Column(
            children: [
              TextFormField(controller: _basementCtrl, decoration: const InputDecoration(labelText: 'Basement Usage', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12))),
              const SizedBox(height: 8),
              TextFormField(controller: _groundFloorCtrl, decoration: const InputDecoration(labelText: 'Ground Floor Usage', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12))),
              const SizedBox(height: 8),
              TextFormField(controller: _secondFloorCtrl, decoration: const InputDecoration(labelText: 'Second Floor Usage', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12))),
              const SizedBox(height: 8),
              TextFormField(controller: _thirdFloorCtrl, decoration: const InputDecoration(labelText: 'Third Floor Usage', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12))),
              const SizedBox(height: 8),
              TextFormField(controller: _fourthFloorCtrl, decoration: const InputDecoration(labelText: 'Fourth Floor Usage', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12))),
              const SizedBox(height: 8),
              TextFormField(controller: _nthFloorCtrl, decoration: const InputDecoration(labelText: 'Nth Floor Usage', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'OCCUPANCY CLASSIFICATION & SPECS',
          icon: Icons.info_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _model.occupancyClassification,
                decoration: const InputDecoration(labelText: 'General Occupancy Classification', border: OutlineInputBorder()),
                items: CommercialChecklistModel.occupancyClassifications.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _model.occupancyClassification = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _occupantLoadCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max Occupant Load', suffixText: 'P/Flr', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _numberOfStoriesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'No. of Stories', suffixText: 'Storey', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _buildingHeightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Building Height', suffixText: 'm', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _model.isHighrise,
                      decoration: const InputDecoration(labelText: 'Is Highrise?', border: OutlineInputBorder()),
                      items: ['Yes', 'No'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) => setState(() => _model.isHighrise = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 3: MEANS OF EGRESS
  // ==========================================
  Widget _buildStep3MeansOfEgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'V.A EXIT ACCESS - HORIZONTAL COMPONENTS',
          icon: Icons.meeting_room_outlined,
          child: Column(
            children: CommercialChecklistModel.horizontalComponents.map((item) {
              return _buildComponentDimRemarkRow(item, _model.egressAccessStatus, 'm');
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'EXIT ACCESS REQUIREMENTS',
          icon: Icons.fact_check_outlined,
          child: Column(
            children: CommercialChecklistModel.exitAccessRequirements.map((req) {
              final idx = CommercialChecklistModel.exitAccessRequirements.indexOf(req);
              final hasDim = idx < 4;
              return _buildRequirementRow(req, _model.egressRequirementsStatus, hasDim: hasDim, dimUnit: 'm');
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'V.B EXITS - CLEAR WIDTHS & COMPONENTS',
          icon: Icons.door_sliding_outlined,
          child: Column(
            children: CommercialChecklistModel.exitComponentsList.map((comp) {
              return _buildComponentDimRemarkRow(comp, _model.exitComponentsStatus, 'm');
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'EXITS - SPECIFICATIONS & MECHANISMS',
          icon: Icons.rule_outlined,
          child: Column(
            children: CommercialChecklistModel.exitSpecifications.map((spec) {
              final idx = CommercialChecklistModel.exitSpecifications.indexOf(spec);
              final hasDim = idx < 10;
              return _buildRequirementRow(spec, _model.egressRequirementsStatus, hasDim: hasDim, dimUnit: idx >= 4 && idx <= 8 ? 'mm' : 'm');
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'V.C EXITS DISCHARGE',
          icon: Icons.output_outlined,
          child: Column(
            children: CommercialChecklistModel.exitDischargeRequirements.map((item) {
              final idx = CommercialChecklistModel.exitDischargeRequirements.indexOf(item);
              final hasDim = idx < 2;
              return _buildRequirementRow(item, _model.egressRequirementsStatus, hasDim: hasDim, dimUnit: 'm');
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 4: SIGNS, LIGHTING & HAZARDS
  // ==========================================
  Widget _buildStep4SignsLightingHazards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'VI.A MARKING OF MEANS OF EGRESS (EXIT)',
          icon: Icons.lightbulb_outlined,
          child: Column(
            children: CommercialChecklistModel.exitMarkingRequirements.map((item) {
              final hasDim = item.contains('height');
              return _buildRequirementRow(item, _model.exitSignageStatus, hasDim: hasDim, dimUnit: 'mm');
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'VI.B EMERGENCY EVACUATION PLAN & SIZES',
          icon: Icons.map_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPassFailPills('Strategic conspicuous location', _model.exitSignageStatus['strategic'], (v) => setState(() => _model.exitSignageStatus['strategic'] = v)),
              const SizedBox(height: 8),
              _buildPassFailPills('Photo-luminescent background (12 items)', _model.exitSignageStatus['photo-luminescent'], (v) => setState(() => _model.exitSignageStatus['photo-luminescent'] = v)),
              const Divider(height: 18),
              const Text('EVACUATION PLAN STANDARD SIZES:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextSecondary)),
              const SizedBox(height: 8),
              _buildRequirementRow('Floor area < 50 m² (330.2 x 215.9 mm)', _model.exitSignageStatus, customKey: '330.2', hasDim: true, dimUnit: 'mm'),
              _buildRequirementRow('Floor area 50–150 m² (609.6 x 457.2 mm)', _model.exitSignageStatus, customKey: '50-150', hasDim: true, dimUnit: 'mm'),
              _buildRequirementRow('Floor area >= 151 m² (609.6 x 914.4 mm)', _model.exitSignageStatus, customKey: '151', hasDim: true, dimUnit: 'mm'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'VI.C ILLUMINATION OF MEANS OF EGRESS',
          icon: Icons.flare_outlined,
          child: Column(
            children: CommercialChecklistModel.illuminationRequirements.map((item) {
              final hasDim = item.contains('lux') || item.contains('hour');
              return _buildRequirementRow(item, _model.exitSignageStatus, hasDim: hasDim, dimUnit: item.contains('hour') ? 'hrs' : 'lux');
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'VII. HAZARDS IDENTIFICATION',
          icon: Icons.warning_amber_outlined,
          child: Column(
            children: [
              _buildTwoFieldRow('Hazard Contents', _hazardContentsCtrl, 'Quantity (Vol/Wt)', _hazardQuantityCtrl),
              const SizedBox(height: 8),
              _buildTwoFieldRow('Hazard Placard', _hazardPlacardCtrl, 'Hazard ID No.', _hazardIdentificationNoCtrl),
              const SizedBox(height: 8),
              _buildTwoFieldRow('Class', _hazardClassCtrl, 'Flash Point', _flashPointCtrl),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _model.withinMaq,
                      decoration: const InputDecoration(labelText: 'Within MAQ?', border: OutlineInputBorder()),
                      items: ['Yes', 'No'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) => setState(() => _model.withinMaq = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _model.hazardClassification,
                      decoration: const InputDecoration(labelText: 'Hazard Classification', border: OutlineInputBorder()),
                      items: ['Low', 'Ordinary', 'High'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) => setState(() => _model.hazardClassification = v),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              const Text('A. FLAMMABLE LIQUIDS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextSecondary)),
              ...CommercialChecklistModel.flammableLiquidsRequirements.map((i) => _buildRequirementRow(i, _model.hazardStatus)),
              const Divider(height: 16),
              const Text('B. MISCELLANEOUS HAZARDS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextSecondary)),
              ...CommercialChecklistModel.miscHazardsRequirements.map((i) => _buildRequirementRow(i, _model.hazardStatus)),
              const Divider(height: 16),
              const Text('C. HOUSEKEEPING & WASTE DISPOSAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextSecondary)),
              ...CommercialChecklistModel.housekeepingRequirements.map((i) => _buildRequirementRow(i, _model.hazardStatus)),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 5: FIRE PROTECTION SYSTEMS
  // ==========================================
  Widget _buildStep5FireProtectionSystems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'VIII.A-C SPRINKLERS & STANDPIPE & PUMPS',
          icon: Icons.water_drop_outlined,
          child: Column(
            children: [
              _buildFireProtectionItem('Sprinkler Pumps', 'Check automatic start and pressure'),
              _buildFireProtectionItem('Sprinkler Valves', 'Valves locked open, no leaks/corrosion'),
              _buildFireProtectionItem('Sprinkler Water Flow Alarm', 'Test valve & manual alarm bell functions'),
              const Divider(height: 16),
              _buildFireProtectionItem('Cabinet Door Operative', 'Unobstructed and opens properly'),
              _buildFireProtectionItem('Hose Condition', 'Not rotted, wet, or moldy'),
              _buildFireProtectionItem('Nozzle', 'In place and operates correctly'),
              _buildFireProtectionItem('Hose Hung Properly', 'Easily un-rolled if needed'),
              _buildFireProtectionItem('Valves & Handles', 'Handles in place, open position'),
              const Divider(height: 16),
              _buildFireProtectionItem('Pump System', 'Inspect accuracy of gauges & sensors'),
              _buildFireProtectionItem('Pipings', 'Check pipings for leaks'),
              _buildFireProtectionItem('Motor', 'Check unusual noise or vibrations'),
              _buildFireProtectionItem('Electrical System', 'Check corrosion, wire insulation, leaks'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'VIII.D-F DETECTION, ALARM & LIFTS',
          icon: Icons.notifications_active_outlined,
          child: Column(
            children: [
              _buildFireProtectionItem('Fire Detection System', 'Random test call points & smoke detectors'),
              _buildFireProtectionItem('Location Signs', 'Location signs legible and unobstructed'),
              _buildFireProtectionItem('Alarm Panels', 'Alarm panels functioning & unobstructed'),
              const Divider(height: 16),
              _buildFireProtectionItem('Lifts', 'Home to ground floor during alarm test'),
              _buildFireProtectionItem('Fans', 'Lift fans operate correctly'),
              _buildFireProtectionItem('Fireman\'s lift', 'Fireman lift keyed to operate during test'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'VIII.G FIRST AID FIRE PROTECTION (EXTINGUISHERS)',
          icon: Icons.fire_extinguisher_outlined,
          child: Column(
            children: [
              _buildFireProtectionItem('Extinguishers Size', 'Minimal sizes meet RA 9514 table 7 & 8'),
              _buildFireProtectionItem('Extinguishers Quantity', 'Minimum quantity meets RA 9514 requirements'),
              _buildFireProtectionItem('Extinguishers Location', 'All extinguishers in proper location'),
              _buildFireProtectionItem('Extinguishers Location & Tags', 'Seals/tags intact, serviced in last 12 mos'),
              _buildFireProtectionItem('Extinguishers Pressure', 'Pressure gauge reads in green area'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'VIII.H-K LIGHTING, KITCHEN, BSE & FIRE WALL',
          icon: Icons.kitchen_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFireProtectionItem('Emergency Lighting Battery', 'Battery lights turn on upon power outage'),
              const Divider(height: 16),
              _buildFireProtectionItem('Kitchen Hoods & Vents', 'Hoods, vents, fans free from grease'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TextFormField(
                  initialValue: _model.itemDimensions['Hood Filters'] ?? '',
                  decoration: const InputDecoration(labelText: 'Hood Filters - Date of Last Cleaning', border: OutlineInputBorder(), prefixIcon: Icon(Icons.cleaning_services_outlined, size: 16)),
                  onChanged: (v) => _model.itemDimensions['Hood Filters'] = v,
                ),
              ),
              const Divider(height: 16),
              const Text('BUILDING SERVICE EQUIPMENT (BSE):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextSecondary)),
              _buildPassFailPills('1. Utilities (Cooking AKHFSS)', _model.bseUtilities, (v) => setState(() => _model.bseUtilities = v)),
              _buildPassFailPills('2. HVAC (PMEC standard)', _model.bseHvac, (v) => setState(() => _model.bseHvac = v)),
              _buildPassFailPills('3. Smoke Control Systems', _model.bseSmokeControl, (v) => setState(() => _model.bseSmokeControl = v)),
              _buildPassFailPills('4. Rubbish / Laundry Chutes', _model.bseRubbishChutes, (v) => setState(() => _model.bseRubbishChutes = v)),
              const Divider(height: 16),
              const Text('FIRE WALL (FW):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextSecondary)),
              _buildYesNoNaRow('Provided with Fire Wall (min 2-hr fire resistance)', _model.fireWallProvided, (v) => setState(() => _model.fireWallProvided = v)),
              _buildYesNoNaRow('FW extension above roof surface >= 760mm', _model.fireWallExtension, (v) => setState(() => _model.fireWallExtension = v)),
              DropdownButtonFormField<String>(
                value: _model.fireWallType,
                decoration: const InputDecoration(labelText: 'Fire Wall Type', border: OutlineInputBorder()),
                items: [
                  '125mm Solid Concrete',
                  '150mm Solid Masonry',
                  '200mm Hollow Unit Masonry',
                ].map((w) => DropdownMenuItem(value: w, child: Text(w, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setState(() => _model.fireWallType = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 6: DEFECTS, RECOMMENDATIONS & SIGNATURES
  // ==========================================
  Widget _buildStep6DefectsAndSignatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'DEFECTS / DEFICIENCIES (ITEMIZED)',
          icon: Icons.report_problem_outlined,
          child: Column(
            children: [
              TextFormField(controller: _defectsItemIVCtrl, decoration: const InputDecoration(labelText: 'ITEM IV (General Info Defects)', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12))),
              const SizedBox(height: 8),
              TextFormField(controller: _defectsItemVCtrl, decoration: const InputDecoration(labelText: 'ITEM V (Means of Egress Defects)', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12))),
              const SizedBox(height: 8),
              TextFormField(controller: _defectsItemVICtrl, decoration: const InputDecoration(labelText: 'ITEM VI (Signs & Lighting Defects)', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12))),
              const SizedBox(height: 8),
              TextFormField(controller: _defectsItemVIICtrl, decoration: const InputDecoration(labelText: 'ITEM VII (Hazards Defects)', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12))),
              const SizedBox(height: 8),
              TextFormField(controller: _defectsItemVIIICtrl, decoration: const InputDecoration(labelText: 'ITEM VIII (Fire Protection Defects)', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12))),
              const SizedBox(height: 8),
              TextFormField(controller: _defectsSummaryCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Overall Summary / Corrective Directives', border: OutlineInputBorder())),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'ATTACHED PICTURES & EVIDENCE',
          icon: Icons.camera_alt_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Attached Photos (${_photoUrls.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorNavy)),
                  TextButton.icon(
                    onPressed: _isUploading ? null : _pickAndUploadPhoto,
                    icon: _isUploading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_a_photo_outlined, size: 16, color: colorPrimary),
                    label: const Text('Add Photo', style: TextStyle(color: colorPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              if (_photoUrls.isNotEmpty)
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photoUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final url = _photoUrls[idx];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: url.startsWith('http')
                                ? Image.network(url, width: 85, height: 85, fit: BoxFit.cover)
                                : Image.file(File(url), width: 85, height: 85, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => setState(() => _photoUrls.removeAt(idx)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'IX. RECOMMENDATIONS',
          icon: Icons.recommend_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioListTile<String>(
                title: const Text('Comply defects and pay fees for issuance of FSIC', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                value: 'FSIC',
                groupValue: _model.recommendationAction,
                dense: true,
                activeColor: colorSuccess,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _model.recommendationAction = v),
              ),
              const Divider(height: 12),
              const Text('OR FOR ISSUANCE OF:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextSecondary)),
              ...[
                'Notice to Comply',
                'Notice to Correct Violation',
                'Closure Order',
                'Abatement Order with Administrative Fine',
                'Notice of Disapproval (NOD)',
              ].map((opt) {
                return RadioListTile<String>(
                  title: Text(opt, style: const TextStyle(fontSize: 12)),
                  value: opt,
                  groupValue: _model.recommendationAction,
                  dense: true,
                  activeColor: colorError,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _model.recommendationAction = v),
                );
              }),
              const SizedBox(height: 8),
              TextFormField(
                controller: _recommendationNotesCtrl,
                decoration: const InputDecoration(labelText: 'Additional Order Notes / Grace Period', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'SIGNATORIES & OFFICIAL APPROVALS',
          icon: Icons.draw_outlined,
          child: Column(
            children: [
              TextFormField(
                controller: _ownerRepresentativeCtrl,
                decoration: const InputDecoration(labelText: 'Acknowledged By (Owner / Representative) *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _inspectorNameCtrl,
                decoration: const InputDecoration(labelText: 'Fire Safety Inspector/s *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _teamLeaderNameCtrl,
                decoration: const InputDecoration(labelText: 'Team Leader *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _chiefFsedNameCtrl,
                decoration: const InputDecoration(labelText: 'Recommend Approval (Chief, FSES/FSED)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _fireMarshalNameCtrl,
                decoration: const InputDecoration(labelText: 'Approval (City / Municipal Fire Marshal)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // REUSABLE FORM WIDGETS
  // ==========================================
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorNavy, letterSpacing: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String key, String label) {
    final isSelected = _model.inspectionNature == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : colorNavy)),
      selected: isSelected,
      selectedColor: colorPrimary,
      backgroundColor: colorBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? colorPrimary : colorBorder)),
      onSelected: (val) {
        if (val) setState(() => _model.inspectionNature = key);
      },
    );
  }

  Widget _buildTwoFieldRow(String lbl1, TextEditingController ctrl1, String lbl2, TextEditingController ctrl2) {
    return Row(
      children: [
        Expanded(child: TextFormField(controller: ctrl1, decoration: InputDecoration(labelText: lbl1, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)))),
        const SizedBox(width: 8),
        Expanded(child: TextFormField(controller: ctrl2, decoration: InputDecoration(labelText: lbl2, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)))),
      ],
    );
  }

  Widget _buildPassFailPills(String label, String? currentStatus, Function(String) onSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: colorNavy))),
          const SizedBox(width: 8),
          _buildPill('Passed', currentStatus == 'Passed', colorSuccess, () => onSelected('Passed')),
          const SizedBox(width: 4),
          _buildPill('Failed', currentStatus == 'Failed', colorError, () => onSelected('Failed')),
          const SizedBox(width: 4),
          _buildPill('N/A', currentStatus == 'N/A', colorTextSecondary, () => onSelected('N/A')),
        ],
      ),
    );
  }

  Widget _buildPill(String text, bool active, Color activeColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? activeColor : colorBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? activeColor : colorBorder),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: active ? Colors.white : colorNavy),
        ),
      ),
    );
  }

  Widget _buildYesNoNaRow(String label, String? currentVal, Function(String) onSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: colorNavy))),
          const SizedBox(width: 8),
          _buildPill('Yes', currentVal == 'Yes', colorSuccess, () => onSelected('Yes')),
          const SizedBox(width: 4),
          _buildPill('No', currentVal == 'No', colorError, () => onSelected('No')),
          const SizedBox(width: 4),
          _buildPill('N/A', currentVal == 'N/A', colorTextSecondary, () => onSelected('N/A')),
        ],
      ),
    );
  }

  Widget _buildComponentDimRemarkRow(String name, Map<String, String> statusMap, String unit) {
    final status = statusMap[name];
    final dim = _model.itemDimensions[name] ?? '';
    final remark = _model.itemRemarks[name] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorNavy))),
              _buildPill('Passed', status == 'Passed', colorSuccess, () => setState(() => statusMap[name] = 'Passed')),
              const SizedBox(width: 4),
              _buildPill('Failed', status == 'Failed', colorError, () => setState(() => statusMap[name] = 'Failed')),
              const SizedBox(width: 4),
              _buildPill('N/A', status == 'N/A', colorTextSecondary, () => setState(() => statusMap[name] = 'N/A')),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: TextFormField(
                  initialValue: dim,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Dim',
                    suffixText: unit,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) => _model.itemDimensions[name] = val,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: remark,
                  decoration: const InputDecoration(
                    hintText: 'Remarks / Corrective Action',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) => _model.itemRemarks[name] = val,
                ),
              ),
            ],
          ),
          const Divider(height: 14),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String text, Map<String, String> statusMap, {bool hasDim = false, String dimUnit = 'm', String? customKey}) {
    final key = customKey ?? text;
    final status = statusMap[key];
    final dim = _model.itemDimensions[key] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(text, style: const TextStyle(fontSize: 11.5, color: colorNavy))),
              const SizedBox(width: 6),
              _buildPill('Passed', status == 'Passed', colorSuccess, () => setState(() => statusMap[key] = 'Passed')),
              const SizedBox(width: 4),
              _buildPill('Failed', status == 'Failed', colorError, () => setState(() => statusMap[key] = 'Failed')),
              const SizedBox(width: 4),
              _buildPill('N/A', status == 'N/A', colorTextSecondary, () => setState(() => statusMap[key] = 'N/A')),
            ],
          ),
          if (hasDim) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: dim,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'Actual Dim',
                      suffixText: dimUnit,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    style: const TextStyle(fontSize: 11),
                    onChanged: (v) => _model.itemDimensions[key] = v,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 10),
        ],
      ),
    );
  }

  Widget _buildFireProtectionItem(String title, String procedure) {
    final status = _model.fireProtectionStatus[title];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorNavy)),
                    Text(procedure, style: const TextStyle(fontSize: 10.5, color: colorTextSecondary)),
                  ],
                ),
              ),
              _buildPill('Passed', status == 'Passed', colorSuccess, () => setState(() => _model.fireProtectionStatus[title] = 'Passed')),
              const SizedBox(width: 4),
              _buildPill('Failed', status == 'Failed', colorError, () => setState(() => _model.fireProtectionStatus[title] = 'Failed')),
              const SizedBox(width: 4),
              _buildPill('N/A', status == 'N/A', colorTextSecondary, () => setState(() => _model.fireProtectionStatus[title] = 'N/A')),
            ],
          ),
          const Divider(height: 10),
        ],
      ),
    );
  }
}
