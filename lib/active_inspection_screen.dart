import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'models/bfp_checklist_model.dart';
import 'widgets/common/inspection_choice_tile.dart';

class ActiveInspectionScreen extends StatefulWidget {
  final String assignmentId;

  const ActiveInspectionScreen({
    super.key,
    required this.assignmentId,
  });

  @override
  State<ActiveInspectionScreen> createState() => _ActiveInspectionScreenState();
}

class _ActiveInspectionScreenState extends State<ActiveInspectionScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  int _currentStep = 0;

  // IO Consent & NTC variables
  String _ownerConsentStatus = 'pending'; // 'pending', 'granted', 'refused'
  String? _refusalReason;
  bool _ntcIssued = false;
  DateTime? _ntcExpiryDate;

  late BfpChecklistModel _checklistData;
  List<String> _hazardPhotoUrls = [];
  final PageController _pageController = PageController();

  // Controllers for General Info & Signatures
  final _businessNameController = TextEditingController();
  final _ownersNameController = TextEditingController();
  final _ioTrackingController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _inspectorNotesController = TextEditingController();

  final List<String> _stepTitles = [
    'Establishment Details & Sign-in',
    'Exterior & Hydrant Assessment',
    'Electrical & Exit Compliance',
    'Suppression Systems',
    'Photo Evidence & Signature',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _businessNameController.dispose();
    _ownersNameController.dispose();
    _ioTrackingController.dispose();
    _contactNumberController.dispose();
    _inspectorNotesController.dispose();
    super.dispose();
  }

  bool get _hasFailedItems {
    return _checklistData.meansOfEgress.corridorsClearance == CheckStatus.fail ||
        _checklistData.fireProtectionSystems.sprinklerInfrastructure == CheckStatus.fail ||
        _checklistData.meansOfEgress.exitDoorsWidth == CheckStatus.fail ||
        _checklistData.meansOfEgress.stairwayClearance == CheckStatus.fail ||
        _checklistData.fireProtectionSystems.fireAlarms == CheckStatus.fail ||
        _checklistData.fireProtectionSystems.extinguisherPressureLogs == CheckStatus.fail;
  }

  int get _ntcRemainingDays {
    final expiry = _ntcExpiryDate ?? DateTime.now().add(const Duration(days: 14));
    final diff = expiry.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  Future<void> _fetchData() async {
    try {
      final response = await Supabase.instance.client
          .from('inspections')
          .select('checklist_data, hazard_photo_urls, owner_consent_status, refusal_reason, ntc_issued, ntc_expiry_date')
          .eq('id', widget.assignmentId)
          .maybeSingle();

      if (response != null) {
        if (response['checklist_data'] != null) {
          _checklistData = BfpChecklistModel.fromJson(response['checklist_data']);
        } else {
          _checklistData = BfpChecklistModel();
        }

        if (response['hazard_photo_urls'] != null) {
          _hazardPhotoUrls = List<String>.from(response['hazard_photo_urls']);
        }

        _ownerConsentStatus = response['owner_consent_status']?.toString() ?? 'pending';
        _refusalReason = response['refusal_reason']?.toString();
        _ntcIssued = response['ntc_issued'] == true;
        if (response['ntc_expiry_date'] != null) {
          _ntcExpiryDate = DateTime.tryParse(response['ntc_expiry_date'].toString());
        }
      } else {
        _checklistData = BfpChecklistModel();
      }

      _businessNameController.text = _checklistData.generalInfo.businessName ?? '';
      _ownersNameController.text = _checklistData.generalInfo.ownersName ?? '';
      _ioTrackingController.text = _checklistData.generalInfo.ioTrackingNumber ?? '';
      _contactNumberController.text = _checklistData.generalInfo.contactNumber ?? '';

    } catch (e) {
      _showToast('Failed to load inspection data: $e', isError: true);
      _checklistData = BfpChecklistModel();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGrantConsent() async {
    setState(() {
      _ownerConsentStatus = 'granted';
    });
    try {
      await Supabase.instance.client.from('inspections').update({
        'owner_consent_status': 'granted',
      }).eq('id', widget.assignmentId);
      _showToast('Owner consent granted!', isError: false);
    } catch (e) {
      debugPrint('Failed to update consent status: $e');
    }
  }

  Future<void> _handleRefusal() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Owner Refusal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Owner refused entry for inspection. Enter a mandatory reason to flag for FSES Head escalation.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter reason for refusal (e.g. Owner absent, Entry denied, Premises locked)...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('LOG REFUSAL', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      setState(() {
        _ownerConsentStatus = 'refused';
        _refusalReason = reason;
        _isSaving = true;
      });

      try {
        await Supabase.instance.client.from('inspections').update({
          'owner_consent_status': 'refused',
          'overall_status': 'refused',
          'approval_stage': 'flagged_for_fses_head',
          'refusal_reason': reason,
        }).eq('id', widget.assignmentId);

        _showToast('Inspection marked Refused & Flagged for FSES Head', isError: true);
      } catch (e) {
        _showToast('Failed to record refusal: $e', isError: true);
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  Future<void> _saveChecklistData({bool isCompleting = false}) async {
    setState(() {
      _isSaving = true;
    });

    _checklistData.generalInfo.businessName = _businessNameController.text;
    _checklistData.generalInfo.ownersName = _ownersNameController.text;
    _checklistData.generalInfo.ioTrackingNumber = _ioTrackingController.text;
    _checklistData.generalInfo.contactNumber = _contactNumberController.text;

    final bool nonCompliant = _hasFailedItems;
    final bool issueNtc = nonCompliant || _ntcIssued;

    if (issueNtc && _ntcExpiryDate == null) {
      _ntcExpiryDate = DateTime.now().add(const Duration(days: 14));
      _ntcIssued = true;
    }

    try {
      final updatePayload = <String, dynamic>{
        'checklist_data': _checklistData.toJson(),
        'business_name': _businessNameController.text,
        'owner_consent_status': _ownerConsentStatus,
        if (_refusalReason != null) 'refusal_reason': _refusalReason,
        'ntc_issued': issueNtc,
        if (_ntcExpiryDate != null) 'ntc_expiry_date': _ntcExpiryDate!.toIso8601String(),
      };

      if (issueNtc) {
        updatePayload['compliance_status'] = 'Non-Compliant';
        updatePayload['approval_stage'] = 'flagged_for_fses_head';
      } else if (isCompleting) {
        updatePayload['overall_status'] = 'Completed';
        updatePayload['compliance_status'] = 'Compliant';
      }

      await Supabase.instance.client
          .from('inspections')
          .update(updatePayload)
          .eq('id', widget.assignmentId);

      if (isCompleting) {
        _showToast(issueNtc ? 'Inspection Completed: NTC Issued (Non-Compliant)' : 'Inspection Completed & Saved!', isError: issueNtc);
        if (mounted) Navigator.of(context).pop();
      } else {
        _showToast('Draft saved successfully!', isError: false);
      }
    } catch (e) {
      _showToast('Failed to save checklist: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _captureAndUploadPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final file = File(pickedFile.path);
      final fileName = '${widget.assignmentId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await Supabase.instance.client.storage
          .from('hazard-photos')
          .upload(fileName, file);

      final publicUrl = Supabase.instance.client.storage
          .from('hazard-photos')
          .getPublicUrl(fileName);

      setState(() {
        _hazardPhotoUrls.add(publicUrl);
      });

      await Supabase.instance.client
          .from('inspections')
          .update({'hazard_photo_urls': _hazardPhotoUrls})
          .eq('id', widget.assignmentId);

      _showToast('Photo uploaded!', isError: false);
    } catch (e) {
      _showToast('Failed to upload photo: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  void _showToast(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InspectionChoice _checkStatusToChoice(CheckStatus? status) {
    if (status == CheckStatus.pass) return InspectionChoice.pass;
    if (status == CheckStatus.fail) return InspectionChoice.fail;
    return InspectionChoice.notApplicable;
  }

  CheckStatus? _choiceToCheckStatus(InspectionChoice? choice) {
    if (choice == InspectionChoice.pass) return CheckStatus.pass;
    if (choice == InspectionChoice.fail) return CheckStatus.fail;
    if (choice == InspectionChoice.notApplicable) return CheckStatus.notApplicable;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inspection Wizard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Step ${_currentStep + 1} of ${_stepTitles.length}: ${_stepTitles[_currentStep]}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded, color: Color(0xFFD84315)),
            onPressed: _isSaving ? null : () => _saveChecklistData(),
            tooltip: 'Save Draft',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _stepTitles.length,
            backgroundColor: const Color(0xFFE2E8F0),
            color: const Color(0xFFD84315),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD84315)))
          : Column(
              children: [
                if (_hasFailedItems || _ntcIssued) _buildNtcCountdownBanner(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (idx) => setState(() => _currentStep = idx),
                    children: [
                      _buildStep1EstablishmentInfo(),
                      _buildStep2ExteriorAssessment(),
                      _buildStep3ElectricalAndExits(),
                      _buildStep4SuppressionSystems(),
                      _buildStep5PhotoEvidence(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildStickyFooter(),
    );
  }

  Widget _buildNtcCountdownBanner() {
    final remainingDays = _ntcRemainingDays;
    final expiryFormatted = _ntcExpiryDate != null
        ? '${_ntcExpiryDate!.year}-${_ntcExpiryDate!.month.toString().padLeft(2, '0')}-${_ntcExpiryDate!.day.toString().padLeft(2, '0')}'
        : '14 Days';

    return Container(
      width: double.infinity,
      color: const Color(0xFFFEF2F2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.timer_outlined, color: Color(0xFFDC2626), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ NOTICE TO COMPLY (NTC) ISSUED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF991B1B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Re-inspection countdown: $remainingDays days remaining (Deadline: $expiryFormatted)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerConsentCard() {
    if (_ownerConsentStatus == 'refused') {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF87171)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 20),
                SizedBox(width: 8),
                Text(
                  'ENTRY REFUSED BY OWNER',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Reason: ${_refusalReason ?? "Owner denied entry."}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF7F1D1D)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Status: Flagged for FSES Head Review',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
            ),
          ],
        ),
      );
    }

    if (_ownerConsentStatus == 'granted') {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Owner Consent Granted — Entry Authorized',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534), fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _handleRefusal,
              child: const Text('Change to Refused', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_ind_outlined, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 8),
              Text(
                'Owner Entry Consent Checklist',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Confirm owner consent prior to physical inspection assessment.',
            style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleRefusal,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('REFUSE ENTRY'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _handleGrantConsent,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('GRANT ENTRY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep1EstablishmentInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 1: Establishment Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Verify baseline metadata before proceeding to physical hazard assessment.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          _buildOwnerConsentCard(),
          _buildTextField('Business Name', _businessNameController, Icons.business),
          const SizedBox(height: 12),
          _buildTextField('Owner / Administrator', _ownersNameController, Icons.person_outline),
          const SizedBox(height: 12),
          _buildTextField('Inspection Order (IO) No.', _ioTrackingController, Icons.assignment_outlined),
          const SizedBox(height: 12),
          _buildTextField('Contact Phone', _contactNumberController, Icons.phone_outlined, isPhone: true),
        ],
      ),
    );
  }

  Widget _buildStep2ExteriorAssessment() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 2: Exterior & Hydrant Assessment',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Audit fire lane clearance, hydrant proximity, and building exterior safety.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          InspectionChoiceTile(
            title: 'Fire Lane Access & Clear Way',
            subtitle: 'Minimum 4-meter unobstructed width for engine access',
            selectedValue: _checkStatusToChoice(_checklistData.meansOfEgress.corridorsClearance),
            onChanged: (val) => setState(() => _checklistData.meansOfEgress.corridorsClearance = _choiceToCheckStatus(val)),
            onAddPhoto: _captureAndUploadPhoto,
          ),
          InspectionChoiceTile(
            title: 'Hydrant Clearance & Water Connection',
            subtitle: 'Operational pressure & 1.5m perimeter clear from obstruction',
            selectedValue: _checkStatusToChoice(_checklistData.fireProtectionSystems.sprinklerInfrastructure),
            onChanged: (val) => setState(() => _checklistData.fireProtectionSystems.sprinklerInfrastructure = _choiceToCheckStatus(val)),
            onAddPhoto: _captureAndUploadPhoto,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3ElectricalAndExits() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 3: Electrical & Means of Egress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Check exit width, emergency illumination, and main electrical panel safety.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          InspectionChoiceTile(
            title: 'Exit Door Width Compliance',
            subtitle: 'Unobstructed panic hardware and minimum exit door clearance width',
            selectedValue: _checkStatusToChoice(_checklistData.meansOfEgress.exitDoorsWidth),
            onChanged: (val) => setState(() => _checklistData.meansOfEgress.exitDoorsWidth = _choiceToCheckStatus(val)),
            onAddPhoto: _captureAndUploadPhoto,
          ),
          InspectionChoiceTile(
            title: 'Stairwell & Passage Clearance',
            subtitle: 'Free of combustible debris and clearly lit',
            selectedValue: _checkStatusToChoice(_checklistData.meansOfEgress.stairwayClearance),
            onChanged: (val) => setState(() => _checklistData.meansOfEgress.stairwayClearance = _choiceToCheckStatus(val)),
            onAddPhoto: _captureAndUploadPhoto,
          ),
        ],
      ),
    );
  }

  Widget _buildStep4SuppressionSystems() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 4: Fire Suppression & Alarms',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Verify fire alarm control panel, smoke detectors, and portable extinguishers.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          InspectionChoiceTile(
            title: 'Fire Alarm & Detection Panel',
            subtitle: 'Operable main control unit and audible alarm verification',
            selectedValue: _checkStatusToChoice(_checklistData.fireProtectionSystems.fireAlarms),
            onChanged: (val) => setState(() => _checklistData.fireProtectionSystems.fireAlarms = _choiceToCheckStatus(val)),
            onAddPhoto: _captureAndUploadPhoto,
          ),
          InspectionChoiceTile(
            title: 'Extinguisher Pressure & Maintenance Log',
            subtitle: 'Current annual inspection tag & gauge in green zone',
            selectedValue: _checkStatusToChoice(_checklistData.fireProtectionSystems.extinguisherPressureLogs),
            onChanged: (val) => setState(() => _checklistData.fireProtectionSystems.extinguisherPressureLogs = _choiceToCheckStatus(val)),
            onAddPhoto: _captureAndUploadPhoto,
          ),
        ],
      ),
    );
  }

  Widget _buildStep5PhotoEvidence() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 5: Photo Evidence & Final Signatures',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Attach mandatory hazard photographs and record inspector field notes.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // Photo Gallery
          if (_hazardPhotoUrls.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _hazardPhotoUrls.length,
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(_hazardPhotoUrls[index], fit: BoxFit.cover),
                );
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text('No hazard photos captured yet.', style: TextStyle(color: Color(0xFF64748B))),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isUploadingPhoto ? null : _captureAndUploadPhoto,
            icon: const Icon(Icons.camera_alt_rounded),
            label: Text(_isUploadingPhoto ? 'UPLOADING...' : 'TAKE HAZARD PHOTO'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _inspectorNotesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Add inspector notes or non-compliance observations...',
              labelText: 'Inspector Observations',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isPhone = false}) {
    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFD84315)),
      ),
    );
  }

  Widget _buildStickyFooter() {
    final bool isLastStep = _currentStep == _stepTitles.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                child: const Text('BACK', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      if (isLastStep) {
                        _saveChecklistData(isCompleting: true);
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastStep ? const Color(0xFF16A34A) : const Color(0xFFD84315),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _isSaving
                    ? 'SAVING...'
                    : (isLastStep ? 'COMPLETE AUDIT' : 'NEXT STEP'),
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
