import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/community_urban_checklist_model.dart';

class CommunityUrbanChecklistWidget extends StatefulWidget {
  const CommunityUrbanChecklistWidget({super.key});

  @override
  State<CommunityUrbanChecklistWidget> createState() => _CommunityUrbanChecklistWidgetState();
}

class _CommunityUrbanChecklistWidgetState extends State<CommunityUrbanChecklistWidget> {
  final _model = CommunityUrbanChecklistModel();

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

  // Controllers
  final _barangayCtrl = TextEditingController();
  final _purokCtrl = TextEditingController();
  final _householdsCtrl = TextEditingController();
  final _familiesCtrl = TextEditingController();
  final _individualsCtrl = TextEditingController();
  final _landAreaCtrl = TextEditingController();

  // Geography % controllers
  final _thickForestCtrl = TextEditingController();
  final _grassyFieldsCtrl = TextEditingController();
  final _mountainsCtrl = TextEditingController();
  final _riverPlainsCtrl = TextEditingController();
  final _developedLandsCtrl = TextEditingController();
  final _geoOthersCtrl = TextEditingController();

  final _residentialZonesCtrl = TextEditingController();
  final _commercialComplexCtrl = TextEditingController();
  final _educationalCompoundsCtrl = TextEditingController();
  final _industrialParkCtrl = TextEditingController();
  final _parksOpenSpacesCtrl = TextEditingController();
  final _devOthersCtrl = TextEditingController();

  // Sub-fields controllers
  final _primaryRouteCtrl = TextEditingController();
  final _primaryDistCtrl = TextEditingController();
  final _primaryEstTimeCtrl = TextEditingController();
  final _primaryActualTimeCtrl = TextEditingController();

  final _secondaryRouteCtrl = TextEditingController();
  final _secondaryDistCtrl = TextEditingController();
  final _secondaryEstTimeCtrl = TextEditingController();
  final _secondaryActualTimeCtrl = TextEditingController();

  final _entryRespondingTrucksCtrl = TextEditingController();
  final _entryRefillingTrucksCtrl = TextEditingController();
  final _roadWidthCtrl = TextEditingController();
  final _roadPavementCtrl = TextEditingController();
  final _narrowAlleysWidthCtrl = TextEditingController();
  final _narrowAlleysPavementCtrl = TextEditingController();
  final _accessPassableCtrl = TextEditingController();
  final _additionalAlleysCtrl = TextEditingController();
  final _hosesNeededCtrl = TextEditingController();

  final _waterLocationCtrl = TextEditingController();
  final _waterDistCtrl = TextEditingController();
  final _waterDischargeCtrl = TextEditingController();
  final _waterStatusCtrl = TextEditingController();

  final _bumberoCtrl = TextEditingController();
  final _teamLeaderCtrl = TextEditingController();
  final _captainCtrl = TextEditingController();
  final _marshalCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _model.date = DateTime.now().toString().split(' ')[0];
  }

  @override
  void dispose() {
    _barangayCtrl.dispose();
    _purokCtrl.dispose();
    _householdsCtrl.dispose();
    _familiesCtrl.dispose();
    _individualsCtrl.dispose();
    _landAreaCtrl.dispose();
    _thickForestCtrl.dispose();
    _grassyFieldsCtrl.dispose();
    _mountainsCtrl.dispose();
    _riverPlainsCtrl.dispose();
    _developedLandsCtrl.dispose();
    _geoOthersCtrl.dispose();
    _residentialZonesCtrl.dispose();
    _commercialComplexCtrl.dispose();
    _educationalCompoundsCtrl.dispose();
    _industrialParkCtrl.dispose();
    _parksOpenSpacesCtrl.dispose();
    _devOthersCtrl.dispose();
    _primaryRouteCtrl.dispose();
    _primaryDistCtrl.dispose();
    _primaryEstTimeCtrl.dispose();
    _primaryActualTimeCtrl.dispose();
    _secondaryRouteCtrl.dispose();
    _secondaryDistCtrl.dispose();
    _secondaryEstTimeCtrl.dispose();
    _secondaryActualTimeCtrl.dispose();
    _entryRespondingTrucksCtrl.dispose();
    _entryRefillingTrucksCtrl.dispose();
    _roadWidthCtrl.dispose();
    _roadPavementCtrl.dispose();
    _narrowAlleysWidthCtrl.dispose();
    _narrowAlleysPavementCtrl.dispose();
    _accessPassableCtrl.dispose();
    _additionalAlleysCtrl.dispose();
    _hosesNeededCtrl.dispose();
    _waterLocationCtrl.dispose();
    _waterDistCtrl.dispose();
    _waterDischargeCtrl.dispose();
    _waterStatusCtrl.dispose();
    _bumberoCtrl.dispose();
    _teamLeaderCtrl.dispose();
    _captainCtrl.dispose();
    _marshalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(pickedFile.path);
      final fileName = 'cfpp_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

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
    _model.barangay = _barangayCtrl.text;
    _model.purokSitio = _purokCtrl.text;
    _model.householdCount = int.tryParse(_householdsCtrl.text);
    _model.familyCount = int.tryParse(_familiesCtrl.text);
    _model.individualCount = int.tryParse(_individualsCtrl.text);
    _model.landArea = _landAreaCtrl.text;

    _model.thickForestPct = _thickForestCtrl.text;
    _model.grassyFieldsPct = _grassyFieldsCtrl.text;
    _model.mountainsHillsPct = _mountainsCtrl.text;
    _model.riverFloodPlainsPct = _riverPlainsCtrl.text;
    _model.developedLandsPct = _developedLandsCtrl.text;
    _model.geoOthersPct = _geoOthersCtrl.text;

    _model.residentialZonesPct = _residentialZonesCtrl.text;
    _model.commercialComplexPct = _commercialComplexCtrl.text;
    _model.educationalCompoundsPct = _educationalCompoundsCtrl.text;
    _model.industrialParkPct = _industrialParkCtrl.text;
    _model.parksOpenSpacesPct = _parksOpenSpacesCtrl.text;
    _model.devOthersPct = _devOthersCtrl.text;

    _model.primaryRouteName = _primaryRouteCtrl.text;
    _model.primaryRouteDist = _primaryDistCtrl.text;
    _model.primaryRouteEstTime = _primaryEstTimeCtrl.text;
    _model.primaryRouteActualTime = _primaryActualTimeCtrl.text;
    _model.secondaryRouteName = _secondaryRouteCtrl.text;
    _model.secondaryRouteDist = _secondaryDistCtrl.text;
    _model.secondaryRouteEstTime = _secondaryEstTimeCtrl.text;
    _model.secondaryRouteActualTime = _secondaryActualTimeCtrl.text;

    _model.entryRespondingTrucks = _entryRespondingTrucksCtrl.text;
    _model.entryRefillingTrucks = _entryRefillingTrucksCtrl.text;
    _model.roadWidth = _roadWidthCtrl.text;
    _model.roadPavement = _roadPavementCtrl.text;
    _model.narrowAlleysWidth = _narrowAlleysWidthCtrl.text;
    _model.narrowAlleysPavement = _narrowAlleysPavementCtrl.text;
    _model.accessPassableFor = _accessPassableCtrl.text;
    _model.additionalEntryAlleys = _additionalAlleysCtrl.text;
    _model.hosesNeeded = _hosesNeededCtrl.text;

    _model.waterSourceLocation = _waterLocationCtrl.text;
    _model.waterSourceDistance = _waterDistCtrl.text;
    _model.rateOfDischarge = _waterDischargeCtrl.text;
    _model.waterSourceStatus = _waterStatusCtrl.text;

    _model.designatedBumbero = _bumberoCtrl.text;
    _model.workshopTeamLeader = _teamLeaderCtrl.text;
    _model.barangayCaptain = _captainCtrl.text;
    _model.fireMarshal = _marshalCtrl.text;

    final payloadData = _model.toJson();
    payloadData['checklist_type'] = 'community_urban';

    final barangayText = _model.barangay.isNotEmpty ? _model.barangay : 'Poblacion';
    final sitioText = _model.purokSitio.isNotEmpty ? _model.purokSitio : 'Sitio';

    try {
      final surveyPayload = {
        'inspector_id': userId,
        'survey_type': 'community_urban',
        'barangay_name': barangayText,
        'municipality': 'Lingayen',
        'province': 'Pangasinan',
        'total_houses': _model.householdCount ?? 0,
        'population_density': _model.totalYesCount >= 40 ? 'High' : 'Medium',
        'structure_type': _model.communityType ?? 'Urban / Rural Community',
        'road_accessibility': (_model.accessPassableFor != null && _model.accessPassableFor!.isNotEmpty) ? _model.accessPassableFor! : 'Passable',
        'water_source_availability': (_model.waterSourceStatus != null && _model.waterSourceStatus!.isNotEmpty) ? _model.waterSourceStatus! : 'Available',
        'electrical_hazards': 'Evaluated in survey',
        'previous_fire_incidents': 0,
        'calculated_score': _model.calculateTotalScore,
        'risk_level': _model.totalYesCount >= 40 ? 'High Risk' : (_model.totalYesCount >= 20 ? 'Medium Risk' : 'Low Risk'),
        'survey_data': payloadData,
        'photo_urls': _photoUrls,
      };

      try {
        await Supabase.instance.client.from('fire_risk_surveys').insert(surveyPayload);
      } catch (_) {
        // Fallback to inspections table if fire_risk_surveys table does not exist yet in Supabase
        await Supabase.instance.client.from('inspections').insert({
          'inspector_id': userId,
          'checklist_type': 'community_urban',
          'inspection_order_no': 'CFPP-${DateTime.now().millisecondsSinceEpoch}',
          'date_issued': DateTime.now().toIso8601String().split('T').first,
          'date_inspected': DateTime.now().toIso8601String().split('T').first,
          'business_name': 'Barangay $barangayText - $sitioText',
          'address': '$sitioText, Barangay $barangayText, Lingayen, Pangasinan',
          'overall_status': 'Completed',
          'compliance_status': _model.vulnerabilityLabel,
          'recommendation': _model.vulnerabilityLabel,
          'risk_level': _model.totalYesCount >= 40 ? 'High' : (_model.totalYesCount >= 20 ? 'Medium' : 'Low'),
          'score': _model.calculateTotalScore,
          'rating': _model.vulnerabilityRating.toString(),
          'checklist_data': payloadData,
          'hazard_photo_urls': _photoUrls,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CFPP Risk & Vulnerability Checklist Submitted Successfully!'),
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
        _buildScoreSummaryBanner(),
        _buildSectionHeader('General Community Profile'),
        _buildGeneralProfileSection(),
        _buildSectionHeader('I. Type of Community'),
        _buildCommunityTypeSection(),
        _buildSectionHeader('II. Geography (% Land Use)'),
        _buildGeographySection(),
        _buildSectionHeader('III. Vulnerability Parameters'),
        _buildSection1LandSurface(),
        _buildSection2Urbanized(),
        _buildSection3Population(),
        _buildSection4Structures(),
        _buildSection5Environmental(),
        _buildSectionHeader('Signatures & Prepared By'),
        _buildSignaturesSection(),
        _buildSectionHeader('Photo Documentation'),
        _buildPhotoDocumentationSection(),
        const SizedBox(height: 24),
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildScoreSummaryBanner() {
    final score = _model.calculateTotalScore;
    final yesCount = _model.totalYesCount;
    final ratingLabel = _model.vulnerabilityLabel;

    Color badgeColor = successColor;
    if (yesCount >= 40) {
      badgeColor = errorColor;
    } else if (yesCount >= 20) {
      badgeColor = warningColor;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VULNERABILITY SCORE',
                  style: TextStyle(color: subtitleColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$yesCount YES Answers (Score: $score)',
                    style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              ratingLabel,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
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

  Widget _buildGeneralProfileSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildTextField('Barangay', controller: _barangayCtrl, hint: 'e.g. Poblacion'),
          const SizedBox(height: 12),
          _buildTextField('Purok / Sitio', controller: _purokCtrl, hint: 'e.g. Alvear Street West'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('No. of Households', controller: _householdsCtrl, isNum: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('No. of Families', controller: _familiesCtrl, isNum: true)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('No. of Individuals', controller: _individualsCtrl, isNum: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Estimated Land Area', controller: _landAreaCtrl, hint: 'e.g. 5.2 sq km')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityTypeSection() {
    final types = ['Metropolitan/City Center', 'Exclusive Village', 'Suburban Subdivision', 'Town Center', 'Rural Community'];
    final metroSubtypes = ['Condominium Complexes', 'Urban Centers/Business District', 'Slums/Informal Settlements'];
    final ruralSubtypes = ['Common Rural Community', 'Island Barangay', 'Geographically Isolated and Disadvantaged Areas (GIDA)'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Community Category', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: types.map((t) {
              final selected = _model.communityType == t;
              return ChoiceChip(
                label: Text(t),
                selected: selected,
                selectedColor: primaryColor,
                labelStyle: TextStyle(color: selected ? Colors.white : titleColor),
                onSelected: (val) => setState(() => _model.communityType = val ? t : null),
              );
            }).toList(),
          ),

          if (_model.communityType == 'Metropolitan/City Center') ...[
            const SizedBox(height: 16),
            Text('Identify Metropolitan Type:', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            ...metroSubtypes.map((st) => RadioListTile<String>(
              title: Text(st, style: const TextStyle(fontSize: 13)),
              value: st,
              groupValue: _model.metroSubtype,
              activeColor: primaryColor,
              onChanged: (val) => setState(() => _model.metroSubtype = val),
              dense: true,
              contentPadding: EdgeInsets.zero,
            )),
          ],

          if (_model.communityType == 'Rural Community') ...[
            const SizedBox(height: 16),
            Text('Identify Rural Type:', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            ...ruralSubtypes.map((st) => RadioListTile<String>(
              title: Text(st, style: const TextStyle(fontSize: 13)),
              value: st,
              groupValue: _model.ruralSubtype,
              activeColor: primaryColor,
              onChanged: (val) => setState(() => _model.ruralSubtype = val),
              dense: true,
              contentPadding: EdgeInsets.zero,
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildGeographySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Indicate Percentage (%) for each variable:', style: TextStyle(color: subtitleColor, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('Thick Forest %', controller: _thickForestCtrl, isNum: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Grassy/Rice Fields %', controller: _grassyFieldsCtrl, isNum: true)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('Mountains & Hills %', controller: _mountainsCtrl, isNum: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('River Flood Plains %', controller: _riverPlainsCtrl, isNum: true)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('100% Developed Lands %', controller: _developedLandsCtrl, isNum: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Others %', controller: _geoOthersCtrl, isNum: true)),
            ],
          ),
          const SizedBox(height: 16),
          Text('For Developed Lands Breakdown (%):', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('Residential %', controller: _residentialZonesCtrl, isNum: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Commercial %', controller: _commercialComplexCtrl, isNum: true)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('Educational %', controller: _educationalCompoundsCtrl, isNum: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Industrial %', controller: _industrialParkCtrl, isNum: true)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('Parks & Open Spaces %', controller: _parksOpenSpacesCtrl, isNum: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Dev Others %', controller: _devOthersCtrl, isNum: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection1LandSurface() {
    return _buildAccordion(
      title: '1. Land & Surface Considerations (3 Points / Check)',
      children: [
        _buildYesNoToggle('1a. Purok/sitio highly dense in terms of buildings (eg. Slums, Row housing)', '1a', _model.sec1Params),
        _buildYesNoToggle('1b. Buildings closely clustered to each other? (0-8 meters Check YES)', '1b', _model.sec1Params),
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 12),
          child: Row(
            children: ['9 meters +', '4-8 meters', '0-3 meters'].map((dist) {
              final sel = _model.buildingClusteredDistance == dist;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(dist, style: const TextStyle(fontSize: 11)),
                  selected: sel,
                  selectedColor: primaryColor,
                  labelStyle: TextStyle(color: sel ? Colors.white : titleColor),
                  onSelected: (val) => setState(() => _model.buildingClusteredDistance = val ? dist : null),
                ),
              );
            }).toList(),
          ),
        ),
        _buildYesNoToggle('1c. Limited accessibility to rescue vehicles?', '1c', _model.sec1Params),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Primary Route Details:', style: TextStyle(color: subtitleColor, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: _buildTextField('Route Name', controller: _primaryRouteCtrl)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildTextField('Distance (km)', controller: _primaryDistCtrl)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: _buildTextField('Est Time (mins)', controller: _primaryEstTimeCtrl)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildTextField('Actual Time (mins)', controller: _primaryActualTimeCtrl)),
                ],
              ),
            ],
          ),
        ),
        _buildYesNoToggle('1d. Limited access to remote areas of the community', '1d', _model.sec1Params),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(child: _buildTextField('Entry for Responding Trucks', controller: _entryRespondingTrucksCtrl)),
              const SizedBox(width: 6),
              Expanded(child: _buildTextField('Entry for Refilling Trucks', controller: _entryRefillingTrucksCtrl)),
            ],
          ),
        ),
        _buildYesNoToggle('1e. Access areas are obstructed or not easily navigable.', '1e', _model.sec1Params),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildTextField('Road Width (m)', controller: _roadWidthCtrl)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildTextField('Road Pavement', controller: _roadPavementCtrl)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: _buildTextField('Alley Width (m)', controller: _narrowAlleysWidthCtrl)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildTextField('Alley Pavement', controller: _narrowAlleysPavementCtrl)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: _buildTextField('Passable For', controller: _accessPassableCtrl)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildTextField('Hoses Needed', controller: _hosesNeededCtrl)),
                ],
              ),
            ],
          ),
        ),
        _buildYesNoToggle('1f. Limited proper markings or way-finding (eg. Street names, markers)', '1f', _model.sec1Params),
        _buildYesNoToggle('1g. Limited accessible/operational fire hydrants & water sources?', '1g', _model.sec1Params),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(child: _buildTextField('Hydrant Location', controller: _waterLocationCtrl)),
              const SizedBox(width: 6),
              Expanded(child: _buildTextField('Distance', controller: _waterDistCtrl)),
            ],
          ),
        ),
        _buildYesNoToggle('1h. Limited evacuation areas or safe areas of refuge', '1h', _model.sec1Params),
      ],
    );
  }

  Widget _buildSection2Urbanized() {
    return _buildAccordion(
      title: '2. Highly-Urbanized Areas (2 Points / Check)',
      children: [
        _buildYesNoToggle('2a. Residential areas tightly integrated with mercantile establishments', '2a', _model.sec2Params),
        _buildYesNoToggle('2b. Mercantile establishments dealing with open-flames (Karenderia, BBQ)', '2b', _model.sec2Params),
        _buildYesNoToggle('2c. Mercantile occupancies issued Notice to Comply for violations', '2c', _model.sec2Params),
        _buildYesNoToggle('2d. Interior roadways frequently blocked by vehicles/deliveries', '2d', _model.sec2Params),
        _buildYesNoToggle('2e. Residential areas close to industrial facilities/warehouses', '2e', _model.sec2Params),
        _buildYesNoToggle('2f. Proximal facilities storing/processing Hazardous Materials (HAZMAT)', '2f', _model.sec2Params),
        _buildYesNoToggle('2g. Industrial waste improperly managed or disposed', '2g', _model.sec2Params),
        _buildYesNoToggle('2h. Large quantities of combustible dust generated/accumulated', '2h', _model.sec2Params),
        _buildYesNoToggle('2i. Water source for fire tenders located outside industrial boundary', '2i', _model.sec2Params),
      ],
    );
  }

  Widget _buildSection3Population() {
    return _buildAccordion(
      title: '3. Population and Sociology (2 Points / Check)',
      children: [
        _buildYesNoToggle('3a. Highly dense population for the land area (eg. Squatters Area)', '3a', _model.sec3Params),
        _buildYesNoToggle('3b. Poor housekeeping practice in general sense', '3b', _model.sec3Params),
        _buildYesNoToggle('3c. Improper disposal of flammable domestic waste', '3c', _model.sec3Params),
        _buildYesNoToggle('3d. Poor housing conditions', '3d', _model.sec3Params),
        _buildYesNoToggle('3e. Improper electrification practice (jumpers, DIY electrical connections)', '3e', _model.sec3Params),
        _buildYesNoToggle('3f. Uncooperative populace and indifference to warnings', '3f', _model.sec3Params),
      ],
    );
  }

  Widget _buildSection4Structures() {
    return _buildAccordion(
      title: '4. Set-up of Structures (2 Points / Check)',
      children: [
        _buildYesNoToggle('4a. Majority of structures made of light/combustible materials', '4a', _model.sec4Params),
        _buildYesNoToggle('4b. Buildings built poorly without regard to construction standards', '4b', _model.sec4Params),
        _buildYesNoToggle('4c. Improper structural separation (No Firewalls for row houses)', '4c', _model.sec4Params),
        _buildYesNoToggle('4d. Alleyways too narrow for fast evacuation / emergency response', '4d', _model.sec4Params),
        _buildYesNoToggle('4e. Pockets of packed residences deep in interior requiring >5 hose lines', '4e', _model.sec4Params),
      ],
    );
  }

  Widget _buildSection5Environmental() {
    return _buildAccordion(
      title: '5. Environmental Factors (1 Point / Check)',
      children: [
        _buildYesNoToggle('5a. Dominant winds in direction of greater part of residences', '5a', _model.sec5Params),
        _buildYesNoToggle('5b. High fire incident history during summer months', '5b', _model.sec5Params),
        _buildYesNoToggle('5c. Limited natural bodies of water close to the area', '5c', _model.sec5Params),
        _buildYesNoToggle('5d. Relatively high heat index during summer/dry months', '5d', _model.sec5Params),
        _buildYesNoToggle('5e. Area prone to or listed with history of Urban Heat Island (UHI) Effect', '5e', _model.sec5Params),
        _buildYesNoToggle('5f. Proximity to grasslands prone or with history of grass fires', '5f', _model.sec5Params),
      ],
    );
  }

  Widget _buildSignaturesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildTextField('Designated Bumbero sa Barangay', controller: _bumberoCtrl),
          const SizedBox(height: 10),
          _buildTextField('CFPP Workshop Team Leader', controller: _teamLeaderCtrl),
          const SizedBox(height: 10),
          _buildTextField('Punong Barangay / Barangay Captain', controller: _captainCtrl),
          const SizedBox(height: 10),
          _buildTextField('Fire Marshal', controller: _marshalCtrl),
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
                    Text('Tap to capture photos of Sitio / Purok', style: TextStyle(color: subtitleColor, fontSize: 13)),
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
              : const Text('SUBMIT COMMUNITY CHECKLIST', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
        ),
      ),
    );
  }

  Widget _buildAccordion({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: _cardDecoration(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: children,
        ),
      ),
    );
  }

  Widget _buildYesNoToggle(String label, String key, Map<String, String> map) {
    final current = map[key];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(
            children: ['YES', 'NO', 'N/A'].map((opt) {
              final isSel = current == opt;
              Color c = subtitleColor;
              if (opt == 'YES') c = errorColor;
              if (opt == 'NO') c = successColor;

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
                      style: TextStyle(color: isSel ? c : subtitleColor, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, fontSize: 12),
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

  Widget _buildTextField(String label, {required TextEditingController controller, String? hint, bool isNum = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: subtitleColor, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
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
