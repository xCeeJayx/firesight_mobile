import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/supabase_service.dart';
import '../../models/house_to_house_checklist_model.dart';

class HouseToHouseChecklistScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const HouseToHouseChecklistScreen({
    super.key,
    this.onNavigateTab,
  });

  @override
  State<HouseToHouseChecklistScreen> createState() => _HouseToHouseChecklistScreenState();
}

class _HouseToHouseChecklistScreenState extends State<HouseToHouseChecklistScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0; // 0 to 3 (4 Steps)

  // Header & Occupant Info (ALL BLANK BY DEFAULT)
  final TextEditingController _occupantNameCtrl = TextEditingController();
  final TextEditingController _purokCtrl = TextEditingController();
  String _selectedBarangay = 'Poblacion';
  final TextEditingController _acknowledgedByCtrl = TextEditingController();
  final TextEditingController _suggestionsCtrl = TextEditingController();

  // 35 item statuses (1..35) -> 'YES', 'NO', 'N/A' (DEFAULT ALL 'NO')
  final Map<int, String> _itemStatuses = {};

  // Building materials matrix (DEFAULT ALL UNSELECTED / EMPTY STRING)
  final Map<String, String> _buildingMaterials = {};

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Default all 35 items to 'NO' for 100% empty initial score
    for (int i = 1; i <= 35; i++) {
      _itemStatuses[i] = 'NO';
    }
    // Default all building materials to empty/unselected
    for (var element in HouseToHouseChecklistModel.buildingElements) {
      _buildingMaterials[element] = '';
    }
  }

  @override
  void dispose() {
    _occupantNameCtrl.dispose();
    _purokCtrl.dispose();
    _acknowledgedByCtrl.dispose();
    _suggestionsCtrl.dispose();
    super.dispose();
  }

  int get _totalYesPoints {
    return _itemStatuses.values.where((v) => v == 'YES').length;
  }

  String get _safetyInterpretation {
    final pts = _totalYesPoints;
    if (pts >= 24) {
      return 'Ligtas ang inyong tahanan';
    } else if (pts >= 12) {
      return 'Mayroong dapat ipangamba';
    } else {
      return 'Labis na mapanganib';
    }
  }

  String get _riskLevel {
    final pts = _totalYesPoints;
    if (pts >= 24) {
      return 'Low Risk';
    } else if (pts >= 12) {
      return 'Medium Risk';
    } else {
      return 'High Risk';
    }
  }

  Color get _interpretationColor {
    final pts = _totalYesPoints;
    if (pts >= 24) {
      return const Color(0xFF16A34A);
    } else if (pts >= 12) {
      return const Color(0xFFD97706);
    } else {
      return const Color(0xFFDC2626);
    }
  }

  Future<void> _submitH2HChecklist() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final profile = AuthService().userProfile;
    final surveyorName = profile?['full_name']?.toString() ?? user?.email ?? 'Community Risk Officer';

    final occupantName = _occupantNameCtrl.text.trim();
    final purok = _purokCtrl.text.trim();
    final address = '${purok.isNotEmpty ? "$purok, " : ""}Brgy. $_selectedBarangay, Lingayen, Pangasinan';

    final Map<String, String> itemStatusesJson = {};
    _itemStatuses.forEach((k, v) {
      itemStatusesJson[k.toString()] = v;
    });

    final surveyData = {
      'occupantName': occupantName,
      'purokName': purok,
      'barangayName': _selectedBarangay,
      'municipality': 'Lingayen',
      'fullAddress': address,
      'itemStatuses': itemStatusesJson,
      'buildingMaterials': _buildingMaterials,
      'totalYesPoints': _totalYesPoints,
      'safetyInterpretation': _safetyInterpretation,
      'riskLevel': _riskLevel,
      'suggestions': _suggestionsCtrl.text.trim(),
      'acknowledgedBy': _acknowledgedByCtrl.text.trim(),
      'surveyorName': surveyorName,
    };

    final isOnline = await ConnectivityService().hasInternetConnection();

    final payload = {
      'inspector_id': user?.id ?? profile?['id'],
      'survey_type': 'house_to_house',
      'barangay_name': _selectedBarangay,
      'purok_name': purok,
      'municipality': 'Lingayen',
      'province': 'Pangasinan',
      'calculated_score': _totalYesPoints.toDouble(),
      'risk_level': _riskLevel,
      'acknowledged_by': _acknowledgedByCtrl.text.trim(),
      'survey_data': surveyData,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (!isOnline) {
      // 1. Save locally with status = 'Pending Sync'
      final offlinePayload = Map<String, dynamic>.from(payload);
      offlinePayload['status'] = 'Pending Sync';
      await OfflineSyncService().queueForSync(
        targetTable: 'fire_risk_surveys',
        payload: offlinePayload,
      );

      await AuthService().logAuditAction(
        actionType: 'H2H_SURVEY_QUEUED_OFFLINE',
        targetEntity: '$occupantName ($_selectedBarangay)',
        details: 'H2H Household Fire Safety Inspection queued locally for sync. Score: $_totalYesPoints/35 ($_safetyInterpretation).',
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
      await client.from('fire_risk_surveys').insert(payload);

      await AuthService().logAuditAction(
        actionType: 'H2H_SURVEY_SUBMITTED',
        targetEntity: '$occupantName ($_selectedBarangay)',
        details: 'H2H Household Fire Safety Inspection submitted. Score: $_totalYesPoints/35 ($_safetyInterpretation).',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Household Inspection for $occupantName saved successfully!'),
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
      debugPrint('Online submission failed, saving locally to sync queue: $e');
      final offlinePayload = Map<String, dynamic>.from(payload);
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
    'Household & Structure',
    'General & Electrical (1-12)',
    'Electrical & Kusina (13-24)',
    'Labasan & Signatures (25-35)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'House-to-House Fire Safety Inspection',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 16,
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
            // Sticky Header & Progress Bar
            _buildStickyHeaderBar(),

            // Step Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStepView(),
              ),
            ),

            // Step Navigation Wizard Bar
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STEP ${_currentStep + 1} OF 4',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEA580C), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _stepTitles[_currentStep],
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _interpretationColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _interpretationColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_totalYesPoints / 35 PTS',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _interpretationColor),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: _interpretationColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _safetyInterpretation,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _interpretationColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 4,
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
        return _buildStep1HouseholdAndStructure();
      case 1:
        return _buildStep2ChecklistPart1();
      case 2:
        return _buildStep3ChecklistPart2();
      case 3:
        return _buildStep4ChecklistPart3AndSignatures();
      default:
        return _buildStep1HouseholdAndStructure();
    }
  }

  // STEP 1: Household Profile & Building Materials Matrix
  Widget _buildStep1HouseholdAndStructure() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Taong Nirerespondehan (Household Profile)',
          icon: Icons.person_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _occupantNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pangalan ng Nakatira (Occupant Name) *',
                  hintText: 'e.g. Juan Dela Cruz',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter occupant name' : null,
              ),
              const SizedBox(height: 14),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PUROK / SITIO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _purokCtrl,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Purok 1',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionCard(
          title: 'Building Materials Matrix',
          icon: Icons.foundation_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pumili ng materyales na ginamit sa bawat bahagi ng bahay:',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              ...HouseToHouseChecklistModel.buildingElements.map((element) {
                final currentMaterial = _buildingMaterials[element] ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        element,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: HouseToHouseChecklistModel.materialOptions.map((mat) {
                          final isSelected = currentMaterial == mat;
                          return ChoiceChip(
                            label: Text(mat),
                            selected: isSelected,
                            selectedColor: const Color(0xFFEA580C),
                            labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF0F172A), fontSize: 11),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            onSelected: (val) {
                              setState(() {
                                _buildingMaterials[element] = val ? mat : '';
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 2: General & Electrical Safety (Items 1 to 12)
  Widget _buildStep2ChecklistPart1() {
    return Column(
      children: [
        _buildSectionCard(
          title: 'A. KAAYUSAN SA BAHAY (Items 1 - 9)',
          icon: Icons.cleaning_services_outlined,
          child: Column(
            children: List.generate(9, (index) {
              final itemNo = index + 1;
              return _buildChecklistItemTile(itemNo);
            }),
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionCard(
          title: 'B. KAAYUSAN NG ELECTRICAL (Items 10 - 12)',
          icon: Icons.power_outlined,
          child: Column(
            children: List.generate(3, (index) {
              final itemNo = index + 10;
              return _buildChecklistItemTile(itemNo);
            }),
          ),
        ),
      ],
    );
  }

  // STEP 3: Electrical & Kusina Safety (Items 13 to 24)
  Widget _buildStep3ChecklistPart2() {
    return Column(
      children: [
        _buildSectionCard(
          title: 'B. KAAYUSAN NG ELECTRICAL (Items 13 - 21)',
          icon: Icons.electrical_services_outlined,
          child: Column(
            children: List.generate(9, (index) {
              final itemNo = index + 13;
              return _buildChecklistItemTile(itemNo);
            }),
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionCard(
          title: 'C. KAAYUSAN SA KUSINA (Items 22 - 24)',
          icon: Icons.soup_kitchen_outlined,
          child: Column(
            children: List.generate(3, (index) {
              final itemNo = index + 22;
              return _buildChecklistItemTile(itemNo);
            }),
          ),
        ),
      ],
    );
  }

  // STEP 4: Kusina Continuation, Daanan/Labasan & Signatures (Items 25 to 35)
  Widget _buildStep4ChecklistPart3AndSignatures() {
    return Column(
      children: [
        _buildSectionCard(
          title: 'C. KAAYUSAN SA KUSINA (Items 25 - 29)',
          icon: Icons.kitchen_outlined,
          child: Column(
            children: List.generate(5, (index) {
              final itemNo = index + 25;
              return _buildChecklistItemTile(itemNo);
            }),
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionCard(
          title: 'D. DAANAN O LABASAN SA BAHAY (Items 30 - 35)',
          icon: Icons.sensor_door_outlined,
          child: Column(
            children: List.generate(6, (index) {
              final itemNo = index + 30;
              return _buildChecklistItemTile(itemNo);
            }),
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionCard(
          title: 'Rekomendasyon at Pagkilala (Officer & Suggestions)',
          icon: Icons.rate_review_outlined,
          child: Column(
            children: [
              TextFormField(
                controller: _suggestionsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mga Payo at Rekomendasyon ng Bumbero',
                  hintText: 'Isulat dito ang mga komento o paalala...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _acknowledgedByCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pumirma / Tumanggap na May-ari (Acknowledged By)',
                  hintText: 'Pangalan ng tumanggap ng inspeksyon',
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

  Widget _buildChecklistItemTile(int itemNo) {
    final itemText = HouseToHouseChecklistModel.checklistItems[itemNo] ?? 'Item $itemNo';
    final currentStatus = _itemStatuses[itemNo] ?? 'NO';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$itemNo',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              itemText,
              style: const TextStyle(fontSize: 12, height: 1.3, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(width: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'YES', label: Text('YES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              ButtonSegment(value: 'NO', label: Text('NO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              ButtonSegment(value: 'N/A', label: Text('N/A', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            ],
            selected: {currentStatus},
            onSelectionChanged: (Set<String> newSel) {
              setState(() {
                _itemStatuses[itemNo] = newSel.first;
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

  Widget _buildBottomWizardBar() {
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == 3;

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
                  if (!_isSubmitting) _submitH2HChecklist();
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
                    ? 'Submitting H2H Checklist...'
                    : isLastStep
                        ? 'Submit Household Inspection'
                        : 'Next: ${_stepTitles[_currentStep + 1]}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
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
