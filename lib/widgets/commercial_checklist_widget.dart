import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/commercial_checklist_model.dart';

class CommercialChecklistWidget extends StatefulWidget {
  const CommercialChecklistWidget({super.key});

  @override
  State<CommercialChecklistWidget> createState() => _CommercialChecklistWidgetState();
}

class _CommercialChecklistWidgetState extends State<CommercialChecklistWidget> {
  final _model = CommercialChecklistModel();

  // Color theme
  final Color primaryColor = const Color(0xFFF95921);
  final Color successColor = const Color(0xFF10B981);
  final Color warningColor = const Color(0xFFF59E0B);
  final Color errorColor = const Color(0xFFEF4444);
  final Color surfaceColor = Colors.white;
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color titleColor = const Color(0xFF1E293B);
  final Color subtitleColor = const Color(0xFF64748B);
  final Color inputBgColor = const Color(0xFFF1F5F9);

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
    _dateInspectedCtrl.text = DateTime.now().toString().split(' ')[0];
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
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(pickedFile.path);
      final fileName = 'commercial_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

      await Supabase.instance.client.storage.from('hazard-photos').upload(fileName, file);
      final publicUrl = Supabase.instance.client.storage.from('hazard-photos').getPublicUrl(fileName);

      setState(() {
        _photoUrls.add(publicUrl);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _submitReport() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
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

    try {
      await Supabase.instance.client.from('inspections').insert({
        'inspector_id': userId,
        'checklist_type': 'commercial',
        'inspection_order_no': _model.ioNumber.isNotEmpty ? _model.ioNumber : 'IO-${DateTime.now().millisecondsSinceEpoch}',
        'date_issued': _model.dateIssued.isNotEmpty ? _model.dateIssued : DateTime.now().toIso8601String().split('T').first,
        'date_inspected': _model.dateInspected.isNotEmpty ? _model.dateInspected : DateTime.now().toIso8601String().split('T').first,
        'business_name': _model.businessName.isNotEmpty ? _model.businessName : (_model.buildingName.isNotEmpty ? _model.buildingName : 'Commercial Business'),
        'address': _model.address.isNotEmpty ? _model.address : 'No address provided',
        'overall_status': 'Completed',
        'compliance_status': _model.recommendationAction ?? 'Inspected',
        'recommendation': _model.recommendationAction ?? 'Notice to Comply',
        'risk_level': 'Medium',
        'score': 0,
        'rating': _model.recommendationAction ?? 'Inspected',
        'checklist_data': payloadData,
        'hazard_photo_urls': _photoUrls,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('BFP Commercial Fire Safety Checklist Submitted Successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e'), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSectionHeader('I. Reference & Inspection Nature'),
        _buildReferenceSection(),
        _buildSectionHeader('IV. General Information'),
        _buildGeneralInfoSection(),
        _buildSectionHeader('Building Specifications & Classification'),
        _buildBuildingSpecificationsSection(),
        _buildSectionHeader('V. Means of Egress'),
        _buildMeansOfEgressSection(),
        _buildSectionHeader('VI. Signs, Lighting & Exits Signage'),
        _buildSignsAndSignageSection(),
        _buildSectionHeader('VII. Hazard Identification'),
        _buildHazardSection(),
        _buildSectionHeader('VIII. Fire Protection Systems'),
        _buildFireProtectionSection(),
        _buildSectionHeader('IX. Defects, Recommendations & Signatures'),
        _buildDefectsAndRecommendationsSection(),
        _buildSectionHeader('Photo Documentation'),
        _buildPhotoDocumentationSection(),
        const SizedBox(height: 24),
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('Date Issued', controller: _dateIssuedCtrl, hint: 'YYYY-MM-DD')),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Date Inspected', controller: _dateInspectedCtrl, hint: 'YYYY-MM-DD')),
            ],
          ),
          const SizedBox(height: 16),
          Text('Nature of Inspection Conducted:', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          ...natures.map((n) {
            return RadioListTile<String>(
              title: Text(n, style: const TextStyle(fontSize: 13)),
              value: n,
              groupValue: _model.inspectionNature,
              activeColor: primaryColor,
              onChanged: (val) => setState(() => _model.inspectionNature = val),
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }),

          if (_model.inspectionNature == 'Verification Inspection for Compliance') ...[
            const SizedBox(height: 8),
            Text('Verification Sub-type:', style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: verificationTypes.map((vt) {
                final isSel = _model.verificationType == vt;
                return ChoiceChip(
                  label: Text(vt, style: const TextStyle(fontSize: 12)),
                  selected: isSel,
                  selectedColor: primaryColor,
                  labelStyle: TextStyle(color: isSel ? Colors.white : titleColor),
                  onSelected: (val) => setState(() => _model.verificationType = val ? vt : null),
                );
              }).toList(),
            ),
          ],

          if (_model.inspectionNature == 'Others') ...[
            const SizedBox(height: 8),
            _buildTextField('Specify Other Nature', controller: _natureOthersCtrl),
          ],

          const SizedBox(height: 16),
          Text('III. Requirements:', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          _buildYesNoToggleRow('FSCCR Report (Occupancy)', _model.fsccrRequired, (v) => setState(() => _model.fsccrRequired = v)),
          const SizedBox(height: 8),
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
          const SizedBox(height: 10),
          _buildTextField('Address', controller: _addressCtrl),
          const SizedBox(height: 10),
          _buildTextField('Business Name', controller: _businessNameCtrl),
          const SizedBox(height: 10),
          _buildTextField('Nature of Business', controller: _natureOfBusinessCtrl),
          const SizedBox(height: 10),
          _buildTextField('Name of Owner / Representative', controller: _ownerRepresentativeCtrl),
          const SizedBox(height: 10),
          _buildTextField('Contact No.', controller: _contactNoCtrl, isNum: true),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('FSIC for Occupancy Permits:', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('FSEC No.', controller: _fsecNoCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Date Issued', controller: _fsecDateCtrl)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('Building Permit No.', controller: _buildingPermitNoCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Date Issued', controller: _buildingPermitDateCtrl)),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('FSIC for Business Permit (New/Renewal):', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('FSIC No. (Latest)', controller: _fsicNoLatestCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Date Issued', controller: _fsicDateCtrl)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('Cert. of Fire Drill', controller: _fireDrillCertCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Date Issued', controller: _fireDrillDateCtrl)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('Business Permit No.', controller: _businessPermitNoCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Date Issued', controller: _businessPermitDateCtrl)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('Fire Insurance Policy', controller: _fireInsurancePolicyNoCtrl)),
              const SizedBox(width: 8),
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
          Text('Construction Type:', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          ...constructionTypes.map((ct) => RadioListTile<String>(
            title: Text(ct, style: const TextStyle(fontSize: 12)),
            value: ct,
            groupValue: _model.constructionType,
            activeColor: primaryColor,
            onChanged: (val) => setState(() => _model.constructionType = val),
            dense: true,
            contentPadding: EdgeInsets.zero,
          )),
          const SizedBox(height: 12),
          Text('Walls / Ceiling Interior Finish:', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: wallFinishes.map((wf) {
              final isSel = _model.interiorFinishWalls == wf;
              return ChoiceChip(
                label: Text(wf.split(':')[0], style: const TextStyle(fontSize: 11)),
                selected: isSel,
                selectedColor: primaryColor,
                labelStyle: TextStyle(color: isSel ? Colors.white : titleColor),
                onSelected: (val) => setState(() => _model.interiorFinishWalls = val ? wf : null),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text('Floor Interior Finish:', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: floorFinishes.map((ff) {
              final isSel = _model.interiorFinishFloor == ff;
              return ChoiceChip(
                label: Text(ff.split(':')[0], style: const TextStyle(fontSize: 11)),
                selected: isSel,
                selectedColor: primaryColor,
                labelStyle: TextStyle(color: isSel ? Colors.white : titleColor),
                onSelected: (val) => setState(() => _model.interiorFinishFloor = val ? ff : null),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('General Occupancy Classification:', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: occupancies.map((occ) {
              final isSel = _model.occupancyClassification == occ;
              return ChoiceChip(
                label: Text(occ, style: const TextStyle(fontSize: 11)),
                selected: isSel,
                selectedColor: primaryColor,
                labelStyle: TextStyle(color: isSel ? Colors.white : titleColor),
                onSelected: (val) => setState(() => _model.occupancyClassification = val ? occ : null),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Sectional Occupancy Usage:', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('Basement', controller: _basementCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Ground Floor', controller: _groundFloorCtrl)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _buildTextField('Second Floor', controller: _secondFloorCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Third Floor', controller: _thirdFloorCtrl)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _buildTextField('Fourth Floor', controller: _fourthFloorCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Nth Floor', controller: _nthFloorCtrl)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Other Building Information:', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('Max Occupant Load (P/Floor)', controller: _occupantLoadCtrl, isNum: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Number of Stories', controller: _numberOfStoriesCtrl, isNum: true)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('Building Height (m)', controller: _buildingHeightCtrl, isNum: true)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Highrise Building?', style: TextStyle(color: subtitleColor, fontSize: 11, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
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
            children: exitAccessComponents.map((comp) => _buildItemWithDimensionToggle(comp, _model.egressAccessStatus)).toList(),
          ),
          _buildAccordion(
            title: 'Exit Access Requirements',
            children: exitAccessRequirements.map((req) => _buildPassFailToggle(req, req, _model.egressRequirementsStatus)).toList(),
          ),
          _buildAccordion(
            title: 'B. Exits Components & Clear Width',
            children: exitComponents.map((comp) => _buildItemWithDimensionToggle(comp, _model.exitComponentsStatus)).toList(),
          ),
          _buildAccordion(
            title: 'Exits Requirements (Stairs & Doors)',
            children: exitRequirements.map((req) => _buildPassFailToggle(req, req, _model.egressRequirementsStatus)).toList(),
          ),
          _buildAccordion(
            title: 'C. Exits Discharge Requirements',
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
            children: egressMarkings.map((m) => _buildPassFailToggle(m, m, _model.exitSignageStatus)).toList(),
          ),
          _buildAccordion(
            title: 'B. Emergency Evacuation Plan',
            children: planChecklist.map((item) => _buildPassFailToggle(item, item, _model.exitSignageStatus)).toList(),
          ),
          _buildAccordion(
            title: 'C. Illumination of Means of Egress',
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
            children: flammableLiquids.map((item) => _buildPassFailToggle(item, item, _model.hazardStatus)).toList(),
          ),
          _buildAccordion(
            title: 'B. Miscellaneous Hazards (Equipment/Storage)',
            children: miscHazards.map((item) => _buildPassFailToggle(item, item, _model.hazardStatus)).toList(),
          ),
          _buildAccordion(
            title: 'C. Housekeeping & Waste Disposal',
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
            children: sprinklerItems.map((item) => _buildPassFailToggle(item, item, _model.fireProtectionStatus)).toList(),
          ),
          _buildAccordion(
            title: 'B. Wet Standpipe / Fire Hose Cabinet',
            children: hoseCabinetItems.map((item) => _buildPassFailToggle(item, item, _model.fireProtectionStatus)).toList(),
          ),
          _buildAccordion(
            title: 'C. Fire Pump Infrastructure',
            children: firePumpItems.map((item) => _buildPassFailToggle(item, item, _model.fireProtectionStatus)).toList(),
          ),
          _buildAccordion(
            title: 'D-K. Fire Alarms, Extinguishers, Kitchen & Fire Wall',
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
          const SizedBox(height: 16),
          Text('RECOMMENDATIONS:', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          ...recommendations.map((rec) {
            return RadioListTile<String>(
              title: Text(rec['label']!, style: const TextStyle(fontSize: 13)),
              value: rec['value']!,
              groupValue: _model.recommendationAction,
              activeColor: primaryColor,
              onChanged: (val) => setState(() => _model.recommendationAction = val),
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }),
          const SizedBox(height: 16),
          Text('Signatures & Approvals:', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          _buildTextField('Fire Safety Inspector/s', controller: _inspectorNameCtrl),
          const SizedBox(height: 8),
          _buildTextField('Team Leader', controller: _teamLeaderNameCtrl),
          const SizedBox(height: 8),
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
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: inputBgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  if (_isUploading)
                    CircularProgressIndicator(color: primaryColor)
                  else ...[
                    Icon(Icons.camera_alt_outlined, size: 32, color: subtitleColor),
                    const SizedBox(height: 6),
                    Text('Tap to capture commercial inspection photos', style: TextStyle(color: subtitleColor, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          if (_photoUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
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
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(_photoUrls[index]),
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
        height: 54,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('SUBMIT COMMERCIAL BFP CHECKLIST', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
        ),
      ),
    );
  }

  Widget _buildAccordion({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: _cardDecoration(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: children,
        ),
      ),
    );
  }

  Widget _buildItemWithDimensionToggle(String label, Map<String, String> statusMap) {
    final currentStatus = statusMap[label];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextFormField(
                  onChanged: (val) => _model.itemDimensions[label] = val,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Dim (m)',
                    hintStyle: TextStyle(color: subtitleColor.withOpacity(0.4), fontSize: 11),
                    filled: true,
                    fillColor: inputBgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: ['Passed', 'Failed', 'N/A'].map((opt) {
                    final isSel = currentStatus == opt;
                    Color c = subtitleColor;
                    if (opt == 'Passed') c = successColor;
                    if (opt == 'Failed') c = errorColor;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => statusMap[label] = opt),
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel ? c.withOpacity(0.15) : surfaceColor,
                            border: Border.all(color: isSel ? c : borderColor),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            opt,
                            style: TextStyle(color: isSel ? c : subtitleColor, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, fontSize: 11),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(
            children: ['Passed', 'Failed', 'N/A'].map((opt) {
              final isSel = current == opt;
              Color c = subtitleColor;
              if (opt == 'Passed') c = successColor;
              if (opt == 'Failed') c = errorColor;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => map[key] = opt),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? c.withOpacity(0.15) : surfaceColor,
                      border: Border.all(color: isSel ? c : borderColor),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      opt,
                      style: TextStyle(color: isSel ? c : subtitleColor, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, fontSize: 11),
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
          Expanded(child: Text(label, style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.w500))),
        Row(
          children: ['Yes', 'No', 'N/A'].map((opt) {
            final isSel = currentVal == opt;
            Color c = subtitleColor;
            if (opt == 'Yes') c = successColor;
            if (opt == 'No') c = errorColor;

            return GestureDetector(
              onTap: () => onChanged(opt),
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSel ? c.withOpacity(0.15) : surfaceColor,
                  border: Border.all(color: isSel ? c : borderColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  opt,
                  style: TextStyle(color: isSel ? c : subtitleColor, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, fontSize: 11),
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
        Text(label, style: TextStyle(color: subtitleColor, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNum ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint ?? 'Enter $label',
            hintStyle: TextStyle(color: subtitleColor.withOpacity(0.4), fontSize: 12),
            filled: true,
            fillColor: inputBgColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor, width: 1),
    );
  }
}
