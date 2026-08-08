import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/supabase_service.dart';

class BarangayRiskSurveyScreen extends StatefulWidget {
  final String? initialBarangay;
  final Function(int)? onNavigateTab;

  const BarangayRiskSurveyScreen({
    super.key,
    this.initialBarangay,
    this.onNavigateTab,
  });

  @override
  State<BarangayRiskSurveyScreen> createState() => _BarangayRiskSurveyScreenState();
}

class _BarangayRiskSurveyScreenState extends State<BarangayRiskSurveyScreen> {
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 0; // 0 to 4 (5 Steps)

  // Header & Community Profile (ALL BLANK BY DEFAULT)
  String _selectedBarangay = 'Poblacion';
  final TextEditingController _purokCtrl = TextEditingController();
  late final TextEditingController _surveyDateCtrl;

  int _householdsCount = 0;
  int _familiesCount = 0;
  int _individualsCount = 0;
  final TextEditingController _householdsCtrl = TextEditingController();
  final TextEditingController _familiesCtrl = TextEditingController();
  final TextEditingController _individualsCtrl = TextEditingController();
  final TextEditingController _landAreaCtrl = TextEditingController();

  // Section I: Type of Community
  String _communityType = 'Rural Community';
  String _metroSubtype = 'Slums/Informal Settlements';
  String _ruralSubtype = 'Common Rural Community';

  // Section II: Geography & Developed Lands Percentages
  String _geographyType = '100% Developed Lands';
  int _pctResidential = 0;
  int _pctCommercial = 0;
  int _pctEducational = 0;
  int _pctIndustrial = 0;
  int _pctParks = 0;
  int _pctOthers = 0;

  // Section III: Vulnerability Parameters YES / NO / N/A (ALL DEFAULT 'NO')
  final Map<String, String> _landStatuses = {
    '1a': 'NO',
    '1b': 'NO',
    '1c': 'NO',
    '1d': 'NO',
    '1e': 'NO',
    '1f': 'NO',
    '1g': 'NO',
    '1h': 'NO',
  };

  String _clusteringDistance = '4-8 meters';
  final TextEditingController _primaryRouteCtrl = TextEditingController();
  final TextEditingController _primaryDistanceCtrl = TextEditingController();
  final TextEditingController _primaryEstTimeCtrl = TextEditingController();
  final TextEditingController _primaryActTimeCtrl = TextEditingController();

  final TextEditingController _secondaryRouteCtrl = TextEditingController();
  final TextEditingController _secondaryDistanceCtrl = TextEditingController();
  final TextEditingController _secondaryEstTimeCtrl = TextEditingController();
  final TextEditingController _secondaryActTimeCtrl = TextEditingController();

  final TextEditingController _entryRespondingTrucksCtrl = TextEditingController();
  final TextEditingController _entryRefillingTrucksCtrl = TextEditingController();

  final TextEditingController _roadWidthCtrl = TextEditingController();
  final TextEditingController _roadPavementCtrl = TextEditingController();
  final TextEditingController _narrowAlleysWidthCtrl = TextEditingController();
  final TextEditingController _narrowAlleysPavementCtrl = TextEditingController();
  final TextEditingController _accessPassableForCtrl = TextEditingController();
  final TextEditingController _additionalEntryAlleysCtrl = TextEditingController();
  int _hosesNeededFarthestArea = 0;
  final TextEditingController _hosesNeededCtrl = TextEditingController();

  final TextEditingController _hydrantLocationCtrl = TextEditingController();
  final TextEditingController _hydrantDistanceCtrl = TextEditingController();
  final TextEditingController _hydrantDischargeCtrl = TextEditingController();
  final TextEditingController _hydrantStatusCtrl = TextEditingController();

  final Map<String, String> _urbanStatuses = {
    '2a': 'NO',
    '2b': 'NO',
    '2c': 'NO',
    '2d': 'NO',
    '2e': 'NO',
    '2f': 'NO',
    '2g': 'NO',
    '2h': 'NO',
    '2i': 'NO',
  };

  final Map<String, String> _sociologyStatuses = {
    '3a': 'NO',
    '3b': 'NO',
    '3c': 'NO',
    '3d': 'NO',
    '3e': 'NO',
    '3f': 'NO',
  };

  final Map<String, String> _structureStatuses = {
    '4a': 'NO',
    '4b': 'NO',
    '4c': 'NO',
    '4d': 'NO',
    '4e': 'NO',
  };

  final Map<String, String> _envStatuses = {
    '5a': 'NO',
    '5b': 'NO',
    '5c': 'NO',
    '5d': 'NO',
    '5e': 'NO',
    '5f': 'NO',
  };

  // Signatures / Officers (ALL BLANK BY DEFAULT)
  final TextEditingController _designatedBumberoCtrl = TextEditingController();
  final TextEditingController _workshopLeaderCtrl = TextEditingController();
  final TextEditingController _barangayCaptainCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _surveyDateCtrl = TextEditingController(
      text: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );

    if (widget.initialBarangay != null && widget.initialBarangay!.isNotEmpty) {
      if (SupabaseService.lingayenBarangays.contains(widget.initialBarangay)) {
        _selectedBarangay = widget.initialBarangay!;
      }
    }
  }

  @override
  void dispose() {
    _purokCtrl.dispose();
    _surveyDateCtrl.dispose();
    _householdsCtrl.dispose();
    _familiesCtrl.dispose();
    _individualsCtrl.dispose();
    _landAreaCtrl.dispose();
    _primaryRouteCtrl.dispose();
    _primaryDistanceCtrl.dispose();
    _primaryEstTimeCtrl.dispose();
    _primaryActTimeCtrl.dispose();
    _secondaryRouteCtrl.dispose();
    _secondaryDistanceCtrl.dispose();
    _secondaryEstTimeCtrl.dispose();
    _secondaryActTimeCtrl.dispose();
    _entryRespondingTrucksCtrl.dispose();
    _entryRefillingTrucksCtrl.dispose();
    _roadWidthCtrl.dispose();
    _roadPavementCtrl.dispose();
    _narrowAlleysWidthCtrl.dispose();
    _narrowAlleysPavementCtrl.dispose();
    _accessPassableForCtrl.dispose();
    _additionalEntryAlleysCtrl.dispose();
    _hosesNeededCtrl.dispose();
    _hydrantLocationCtrl.dispose();
    _hydrantDistanceCtrl.dispose();
    _hydrantDischargeCtrl.dispose();
    _hydrantStatusCtrl.dispose();
    _designatedBumberoCtrl.dispose();
    _workshopLeaderCtrl.dispose();
    _barangayCaptainCtrl.dispose();
    super.dispose();
  }

  int get _calculatedScore {
    int score = 0;
    _landStatuses.forEach((_, val) {
      if (val == 'YES') score += 3;
    });
    _urbanStatuses.forEach((_, val) {
      if (val == 'YES') score += 2;
    });
    _sociologyStatuses.forEach((_, val) {
      if (val == 'YES') score += 2;
    });
    _structureStatuses.forEach((_, val) {
      if (val == 'YES') score += 2;
    });
    _envStatuses.forEach((_, val) {
      if (val == 'YES') score += 1;
    });
    return score;
  }

  int get _vulnerabilityRating {
    final s = _calculatedScore;
    if (s >= 40) {
      return 5;
    } else if (s >= 20) {
      return 4;
    } else {
      return 3;
    }
  }

  String get _vulnerabilityRemarks {
    final rating = _vulnerabilityRating;
    if (rating == 5) {
      return 'Highly Vulnerable';
    } else if (rating == 4) {
      return 'Moderately Vulnerable';
    } else {
      return 'Mildly Vulnerable';
    }
  }

  String get _riskLevel {
    final rating = _vulnerabilityRating;
    if (rating == 5) {
      return 'High Risk';
    } else if (rating == 4) {
      return 'Medium Risk';
    } else {
      return 'Low Risk';
    }
  }

  Color get _ratingColor {
    final rating = _vulnerabilityRating;
    if (rating == 5) {
      return const Color(0xFFDC2626);
    } else if (rating == 4) {
      return const Color(0xFFD97706);
    } else {
      return const Color(0xFF16A34A);
    }
  }

  Future<void> _submitSurvey() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final profile = AuthService().userProfile;
    final surveyorName = profile?['full_name']?.toString() ?? user?.email ?? 'Community Risk Officer';

    final purok = _purokCtrl.text.trim();
    final address = '${purok.isNotEmpty ? "$purok, " : ""}Brgy. $_selectedBarangay, Lingayen, Pangasinan';

    final surveyData = {
      'barangayName': _selectedBarangay,
      'purokName': purok,
      'address': address,
      'surveyorName': surveyorName,
      'date': _surveyDateCtrl.text.trim(),
      'householdsCount': _householdsCount,
      'familiesCount': _familiesCount,
      'individualsCount': _individualsCount,
      'estimatedLandArea': _landAreaCtrl.text.trim(),
      'communityType': _communityType,
      'metroSubtype': _metroSubtype,
      'ruralSubtype': _ruralSubtype,
      'geographyType': _geographyType,
      'developedLandPercentages': {
        'residential': _pctResidential,
        'commercial': _pctCommercial,
        'educational': _pctEducational,
        'industrial': _pctIndustrial,
        'parks': _pctParks,
        'others': _pctOthers,
      },
      'landStatuses': _landStatuses,
      'urbanStatuses': _urbanStatuses,
      'sociologyStatuses': _sociologyStatuses,
      'structureStatuses': _structureStatuses,
      'envStatuses': _envStatuses,
      'totalScore': _calculatedScore,
      'vulnerabilityRating': _vulnerabilityRating,
      'vulnerabilityRemarks': _vulnerabilityRemarks,
      'officers': {
        'designatedBumbero': _designatedBumberoCtrl.text.trim(),
        'workshopLeader': _workshopLeaderCtrl.text.trim(),
        'barangayCaptain': _barangayCaptainCtrl.text.trim(),
      },
    };

    final isOnline = await ConnectivityService().hasInternetConnection();

    final surveyPayload = {
      'inspector_id': user?.id ?? profile?['id'],
      'survey_type': 'community_urban',
      'barangay_name': _selectedBarangay,
      'purok_name': purok,
      'municipality': 'Lingayen',
      'province': 'Pangasinan',
      'total_houses': _householdsCount,
      'households_count': _householdsCount,
      'families_count': _familiesCount,
      'individuals_count': _individualsCount,
      'population_density': _landStatuses['1a'] == 'YES' ? 'High' : 'Medium',
      'water_source_availability': _landStatuses['1g'] == 'YES' ? 'Inadequate' : 'Adequate',
      'calculated_score': _calculatedScore.toDouble(),
      'risk_level': _riskLevel,
      'survey_data': surveyData,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (!isOnline) {
      // 1. Save locally with status = 'Pending Sync'
      final offlinePayload = Map<String, dynamic>.from(surveyPayload);
      offlinePayload['status'] = 'Pending Sync';
      await OfflineSyncService().queueForSync(
        targetTable: 'fire_risk_surveys',
        payload: offlinePayload,
      );

      await AuthService().logAuditAction(
        actionType: 'BARANGAY_RISK_QUEUED_OFFLINE',
        targetEntity: '$_selectedBarangay${purok.isNotEmpty ? " ($purok)" : ""}',
        details: 'Barangay CFPP Urban Risk Checklist queued locally for sync. Score: $_calculatedScore (Rating $_vulnerabilityRating).',
      );

      // 2. Display success feedback to inspector
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally (Offline). Will automatically sync when connected.'),
            backgroundColor: Colors.amber,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(0);
        } else {
          Navigator.pop(context);
        }
      }
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    try {
      final onlinePayload = Map<String, dynamic>.from(surveyPayload);
      onlinePayload.remove('status');
      await client.from('fire_risk_surveys').insert(onlinePayload);

      await AuthService().logAuditAction(
        actionType: 'BARANGAY_RISK_PROFILED',
        targetEntity: '$_selectedBarangay${purok.isNotEmpty ? " ($purok)" : ""}',
        details: 'Barangay CFPP Urban Risk Checklist submitted. Total Score: $_calculatedScore (Rating $_vulnerabilityRating - $_vulnerabilityRemarks).',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Barangay CFPP Assessment for $_selectedBarangay saved successfully!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (widget.onNavigateTab != null) {
        widget.onNavigateTab!(0);
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Online submission error, queueing offline: $e');
      final offlinePayload = Map<String, dynamic>.from(surveyPayload);
      offlinePayload['status'] = 'Pending Sync';

      await OfflineSyncService().queueForSync(
        targetTable: 'fire_risk_surveys',
        payload: offlinePayload,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved locally (Offline). Will automatically sync when connected.'),
          backgroundColor: Colors.amber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (widget.onNavigateTab != null) {
        widget.onNavigateTab!(0);
      } else {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  final List<String> _stepTitles = const [
    'General Profile',
    'Land Considerations',
    'Urbanized Factors',
    'Sociology & Structure',
    'Environment & Signatures',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Barangay CFPP Risk Survey',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE2E8F0), height: 1.0),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Sticky Live Score & Step Indicator Bar
            _buildStickyHeaderBar(),

            // Step Content Body with generous 20px padding
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStepView(),
              ),
            ),

            // Step Wizard Navigation Bottom Controls
            _buildBottomWizardBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEP ${_currentStep + 1} OF 5',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEA580C), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _stepTitles[_currentStep],
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _ratingColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _ratingColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Text(
                      '$_calculatedScore PTS',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _ratingColor),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: _ratingColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Rating $_vulnerabilityRating',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _ratingColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 5,
              backgroundColor: const Color(0xFFF1F5F9),
              color: const Color(0xFFEA580C),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildStep1GeneralProfile();
      case 1:
        return _buildStep2LandConsiderations();
      case 2:
        return _buildStep3UrbanFactors();
      case 3:
        return _buildStep4SociologyAndStructure();
      case 4:
        return _buildStep5EnvironmentAndSignatures();
      default:
        return _buildStep1GeneralProfile();
    }
  }

  // STEP 1: General Community Profile & Geography
  Widget _buildStep1GeneralProfile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'General Community Profile',
          icon: Icons.assignment_outlined,
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
                        const Text('BARANGAY *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedBarangay,
                              isExpanded: true,
                              items: SupabaseService.lingayenBarangays.map((bgy) {
                                return DropdownMenuItem<String>(
                                  value: bgy,
                                  child: Text(bgy, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedBarangay = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _surveyDateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'SURVEY DATE',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _purokCtrl,
                decoration: const InputDecoration(
                  labelText: 'PUROK / SITIO *',
                  hintText: 'e.g. Alvear Street West',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter Purok/Sitio name' : null,
              ),
              const SizedBox(height: 18),

              // Demographics Counter Grid replaced with Direct Numeric Input Fields
              const Text('COMMUNITY DEMOGRAPHICS COUNTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildNumberInputField('Households', _householdsCtrl, (v) => setState(() => _householdsCount = v)),
                  const SizedBox(width: 10),
                  _buildNumberInputField('Families', _familiesCtrl, (v) => setState(() => _familiesCount = v)),
                  const SizedBox(width: 10),
                  _buildNumberInputField('Individuals', _individualsCtrl, (v) => setState(() => _individualsCount = v)),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _landAreaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Estimated Land Area',
                  hintText: 'e.g. 2.5 Hectares',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionCard(
          title: 'I. TYPE OF COMMUNITY',
          icon: Icons.holiday_village_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Metropolitan/City Center', 'Town Center', 'Exclusive Village', 'Rural Community', 'Suburban Subdivision'].map((type) {
                  final isSelected = _communityType == type;
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0F172A),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    onSelected: (val) {
                      if (val) setState(() => _communityType = type);
                    },
                  );
                }).toList(),
              ),
              if (_communityType == 'Metropolitan/City Center') ...[
                const SizedBox(height: 14),
                const Text('*For Metropolitan/City Centers identify whether:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Condominium Complexes', 'Urban Centers/Business District', 'Slums/Informal Settlements'].map((sub) {
                    final isSel = _metroSubtype == sub;
                    return ChoiceChip(
                      label: Text(sub),
                      selected: isSel,
                      selectedColor: const Color(0xFFEA580C),
                      labelStyle: TextStyle(color: isSel ? Colors.white : const Color(0xFF0F172A), fontSize: 11),
                      onSelected: (val) {
                        if (val) setState(() => _metroSubtype = sub);
                      },
                    );
                  }).toList(),
                ),
              ],
              if (_communityType == 'Rural Community') ...[
                const SizedBox(height: 14),
                const Text('*For Rural Communities identify whether:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Common Rural Community', 'Island Barangay', 'Geographically Isolated and Disadvantaged Areas (GIDA)'].map((sub) {
                    final isSel = _ruralSubtype == sub;
                    return ChoiceChip(
                      label: Text(sub),
                      selected: isSel,
                      selectedColor: const Color(0xFFEA580C),
                      labelStyle: TextStyle(color: isSel ? Colors.white : const Color(0xFF0F172A), fontSize: 11),
                      onSelected: (val) {
                        if (val) setState(() => _ruralSubtype = sub);
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionCard(
          title: 'II. GEOGRAPHY & DEVELOPED LANDS',
          icon: Icons.map_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['100% Developed Lands', 'Thick Forest', 'Grassy fields/ Rice Fields', 'River Flood Plains', 'Mountains and Hills', 'Others'].map((geo) {
                  final isSel = _geographyType == geo;
                  return ChoiceChip(
                    label: Text(geo),
                    selected: isSel,
                    selectedColor: const Color(0xFF0F172A),
                    labelStyle: TextStyle(color: isSel ? Colors.white : const Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
                    onSelected: (val) {
                      if (val) setState(() => _geographyType = geo);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('*For Developed Lands [Indicate percentage]:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildPctSlider('Residential Zones', _pctResidential, (v) => setState(() => _pctResidential = v)),
                  const SizedBox(width: 12),
                  _buildPctSlider('Commercial Complex', _pctCommercial, (v) => setState(() => _pctCommercial = v)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPctSlider('Educational Compounds', _pctEducational, (v) => setState(() => _pctEducational = v)),
                  const SizedBox(width: 12),
                  _buildPctSlider('Industrial Park/Factories', _pctIndustrial, (v) => setState(() => _pctIndustrial = v)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 2: Land & Surface Considerations (3 PTS EACH)
  Widget _buildStep2LandConsiderations() {
    return _buildSectionCard(
      title: '1. LAND & SURFACE CONSIDERATIONS [3 PTS EACH]',
      icon: Icons.landscape_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildYesNoTile('1a', 'a. Purok/sitio highly dense in terms of buildings (Slums, Row housing)', _landStatuses),
          _buildYesNoTile('1b', 'b. Buildings closely clustered to each other? (0 - 8 meters)', _landStatuses),
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 4, bottom: 12),
            child: Wrap(
              spacing: 8,
              children: ['9 meters +', '4-8 meters', '0-3 meters'].map((dist) {
                final isSel = _clusteringDistance == dist;
                return ChoiceChip(
                  label: Text(dist),
                  selected: isSel,
                  selectedColor: const Color(0xFFEA580C),
                  labelStyle: TextStyle(color: isSel ? Colors.white : const Color(0xFF0F172A), fontSize: 11),
                  onSelected: (v) {
                    if (v) setState(() => _clusteringDistance = dist);
                  },
                );
              }).toList(),
            ),
          ),

          _buildYesNoTile('1c', 'c. Limited accessibility to rescue vehicles?', _landStatuses),
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(left: 12, top: 6, bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Primary Route During Operation:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                TextFormField(controller: _primaryRouteCtrl, decoration: const InputDecoration(hintText: 'Route Name (e.g. Maramba Street)', isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _primaryDistanceCtrl, decoration: const InputDecoration(labelText: 'Distance (km)', isDense: true, border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _primaryEstTimeCtrl, decoration: const InputDecoration(labelText: 'Est. Time', isDense: true, border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _primaryActTimeCtrl, decoration: const InputDecoration(labelText: 'Actual Time', isDense: true, border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Secondary Route During Operation:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                TextFormField(controller: _secondaryRouteCtrl, decoration: const InputDecoration(hintText: 'Route Name (e.g. Artucho Street)', isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _secondaryDistanceCtrl, decoration: const InputDecoration(labelText: 'Distance (km)', isDense: true, border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _secondaryEstTimeCtrl, decoration: const InputDecoration(labelText: 'Est. Time', isDense: true, border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _secondaryActTimeCtrl, decoration: const InputDecoration(labelText: 'Actual Time', isDense: true, border: OutlineInputBorder()))),
                  ],
                ),
              ],
            ),
          ),

          _buildYesNoTile('1d', 'd. Limited access to remote areas of the community', _landStatuses),
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(left: 12, top: 6, bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                TextFormField(controller: _entryRespondingTrucksCtrl, decoration: const InputDecoration(labelText: 'Entry Point for Responding Trucks', isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextFormField(controller: _entryRefillingTrucksCtrl, decoration: const InputDecoration(labelText: 'Entry Point for Refilling Trucks', isDense: true, border: OutlineInputBorder())),
              ],
            ),
          ),

          _buildYesNoTile('1e', 'e. Access areas are obstructed or not easily navigable', _landStatuses),
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(left: 12, top: 6, bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _roadWidthCtrl, decoration: const InputDecoration(labelText: 'Road Width', isDense: true, border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _roadPavementCtrl, decoration: const InputDecoration(labelText: 'Road Pavement', isDense: true, border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _narrowAlleysWidthCtrl, decoration: const InputDecoration(labelText: 'Alleys Width', isDense: true, border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _narrowAlleysPavementCtrl, decoration: const InputDecoration(labelText: 'Alleys Pavement', isDense: true, border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _accessPassableForCtrl,
                  decoration: const InputDecoration(labelText: 'Access Passable For (e.g. Kubota P/T)', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _additionalEntryAlleysCtrl,
                  decoration: const InputDecoration(labelText: 'Additional Entry Alleys', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _hosesNeededCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Hoses Needed for Farthest Area (Count)',
                    hintText: 'e.g. 3',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _hosesNeededFarthestArea = int.tryParse(val.trim()) ?? 0;
                    });
                  },
                ),
              ],
            ),
          ),

          _buildYesNoTile('1f', 'f. Limited proper markings or way-finding (street names/markers)', _landStatuses),
          _buildYesNoTile('1g', 'g. Limited accessible/operational fire hydrants & water sources?', _landStatuses),
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(left: 12, top: 6, bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Operational Hydrant Details:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _hydrantLocationCtrl, decoration: const InputDecoration(labelText: 'Location', isDense: true, border: OutlineInputBorder()))),
                    const SizedBox(width: 6),
                    Expanded(child: TextFormField(controller: _hydrantDistanceCtrl, decoration: const InputDecoration(labelText: 'Distance', isDense: true, border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _hydrantDischargeCtrl, decoration: const InputDecoration(labelText: 'Discharge', isDense: true, border: OutlineInputBorder()))),
                    const SizedBox(width: 6),
                    Expanded(child: TextFormField(controller: _hydrantStatusCtrl, decoration: const InputDecoration(labelText: 'Status', isDense: true, border: OutlineInputBorder()))),
                  ],
                ),
              ],
            ),
          ),

          _buildYesNoTile('1h', 'h. Limited evacuation areas or safe areas of refuge', _landStatuses),
        ],
      ),
    );
  }

  // STEP 3: Highly-Urbanized Area Factors (2 PTS EACH)
  Widget _buildStep3UrbanFactors() {
    return _buildSectionCard(
      title: '2. HIGHLY-URBANIZED AREA FACTORS [2 PTS EACH]',
      icon: Icons.location_city_outlined,
      child: Column(
        children: [
          _buildYesNoTile('2a', 'a. Residential areas tightly integrated with mercantile establishments', _urbanStatuses),
          _buildYesNoTile('2b', 'b. Mercantile Establishments in the area deals with open-flames (Karenderia, BBQ)', _urbanStatuses),
          _buildYesNoTile('2c', 'c. Mercantile occupancies issued Notice to Comply for Fire Code violations', _urbanStatuses),
          _buildYesNoTile('2d', 'd. Interior roadways frequently blocked by vehicles/deliveries', _urbanStatuses),
          _buildYesNoTile('2e', 'e. Residential areas in close proximity to industrial facilities / warehouses', _urbanStatuses),
          _buildYesNoTile('2f', 'f. Proximal facilities storing/processing Hazardous Materials (LPG, gas)', _urbanStatuses),
          _buildYesNoTile('2g', 'g. Industrial waste (rags, paper, fuel byproducts) improperly managed', _urbanStatuses),
          _buildYesNoTile('2h', 'h. Large quantities of combustible dust posing dust explosion risk', _urbanStatuses),
          _buildYesNoTile('2i', 'i. Nearest available water source located outside industrial facility boundary', _urbanStatuses),
        ],
      ),
    );
  }

  // STEP 4: Population, Sociology & Structure Set-up (2 PTS EACH)
  Widget _buildStep4SociologyAndStructure() {
    return Column(
      children: [
        _buildSectionCard(
          title: '3. POPULATION & SOCIOLOGY [2 PTS EACH]',
          icon: Icons.groups_outlined,
          child: Column(
            children: [
              _buildYesNoTile('3a', 'a. Highly dense population for land area (Squatters Area)', _sociologyStatuses),
              _buildYesNoTile('3b', 'b. Poor housekeeping practice in general sense', _sociologyStatuses),
              _buildYesNoTile('3c', 'c. Improper disposal of flammable domestic waste', _sociologyStatuses),
              _buildYesNoTile('3d', 'd. Poor housing conditions', _sociologyStatuses),
              _buildYesNoTile('3e', 'e. Improper electrification practice (Illegal jumpers/DIY connections)', _sociologyStatuses),
              _buildYesNoTile('3f', 'f. Uncooperative populace and indifference to warnings', _sociologyStatuses),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionCard(
          title: '4. STRUCTURE & MATERIAL COMPOSITION [2 PTS EACH]',
          icon: Icons.other_houses_outlined,
          child: Column(
            children: [
              _buildYesNoTile('4a', 'a. Majority of buildings made of light & easily combustible materials', _structureStatuses),
              _buildYesNoTile('4b', 'b. Buildings built poorly without regard to construction standards', _structureStatuses),
              _buildYesNoTile('4c', 'c. Improper building separation (No firewalls for row houses)', _structureStatuses),
              _buildYesNoTile('4d', 'd. Alleyways and residence access too narrow for evacuation', _structureStatuses),
              _buildYesNoTile('4e', 'e. Deep interior pockets requiring more than 5 fire hose lines', _structureStatuses),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 5: Environmental Factors & Signatures (1 PT EACH)
  Widget _buildStep5EnvironmentAndSignatures() {
    return Column(
      children: [
        _buildSectionCard(
          title: '5. ENVIRONMENTAL FACTORS [1 PT EACH]',
          icon: Icons.thermostat_outlined,
          child: Column(
            children: [
              _buildYesNoTile('5a', 'a. Dominant winds in direction of greater part of residences', _envStatuses),
              _buildYesNoTile('5b', 'b. Historically high fire incident recorded during summer months', _envStatuses),
              _buildYesNoTile('5c', 'c. Limited natural bodies of water close to area', _envStatuses),
              _buildYesNoTile('5d', 'd. Relatively high heat index during summer/dry months', _envStatuses),
              _buildYesNoTile('5e', 'e. Area prone to or listed with Urban Heat Island Effect', _envStatuses),
              _buildYesNoTile('5f', 'f. Proximity to grasslands prone to grass fires', _envStatuses),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionCard(
          title: 'Official Station Officers & Signatures',
          icon: Icons.badge_outlined,
          child: Column(
            children: [
              TextFormField(
                controller: _designatedBumberoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Designated Bumbero sa Barangay',
                  hintText: 'e.g. FO1 Roger A. Toledo Jr.',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _workshopLeaderCtrl,
                decoration: const InputDecoration(
                  labelText: 'CFPP Workshop Team Leader',
                  hintText: 'e.g. FO1 Hortaniel S. Rebollas',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _barangayCaptainCtrl,
                decoration: const InputDecoration(
                  labelText: 'Punong Barangay / Barangay Captain',
                  hintText: 'e.g. HON. HIRAM G. HIDALGO',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomWizardBar() {
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == 4;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isFirstStep)
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _currentStep--;
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
            ),
          if (!isFirstStep) const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                if (isLastStep) {
                  if (!_isSubmitting) _submitSurvey();
                } else {
                  if (_currentStep == 0) {
                    if (!_formKey.currentState!.validate()) return;
                  }
                  setState(() {
                    _currentStep++;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastStep ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(isLastStep ? Icons.send_outlined : Icons.arrow_forward_outlined, size: 18),
              label: Text(
                _isSubmitting
                    ? 'Submitting CFPP Checklist...'
                    : isLastStep
                        ? 'Submit Barangay CFPP Profile'
                        : 'Next: ${_stepTitles[_currentStep + 1]}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYesNoTile(String itemKey, String titleText, Map<String, String> statusMap) {
    final currentStatus = statusMap[itemKey] ?? 'NO';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              titleText,
              style: const TextStyle(fontSize: 12, height: 1.3, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(width: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'YES', label: Text('YES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              ButtonSegment(value: 'NO', label: Text('NO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              ButtonSegment(value: 'N/A', label: Text('N/A', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            ],
            selected: {currentStatus},
            onSelectionChanged: (Set<String> newSel) {
              setState(() {
                statusMap[itemKey] = newSel.first;
              });
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInputField(String label, TextEditingController controller, ValueChanged<int> onChanged) {
    return Expanded(
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: '0',
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        onChanged: (val) {
          final parsed = int.tryParse(val.trim()) ?? 0;
          onChanged(parsed);
        },
      ),
    );
  }

  Widget _buildPctSlider(String label, int val, ValueChanged<int> onChanged) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('$val%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 4),
            SliderTheme(
              data: const SliderThemeData(
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: val.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: const Color(0xFFEA580C),
                onChanged: (v) => onChanged(v.toInt()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFFEA580C)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
