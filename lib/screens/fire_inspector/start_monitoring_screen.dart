import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/inspection_monitoring_model.dart';
import '../../services/inspection_monitoring_service.dart';
import '../../services/supabase_service.dart';

class StartMonitoringScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;

  const StartMonitoringScreen({super.key, this.onNavigateTab});

  @override
  State<StartMonitoringScreen> createState() => _StartMonitoringScreenState();
}

class _StartMonitoringScreenState extends State<StartMonitoringScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedVisitType = 'Regular / Initial Inspection';
  String _selectedBarangay = 'Poblacion';

  final TextEditingController _ioRefController = TextEditingController();
  final TextEditingController _relatedOrderController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _establishmentController = TextEditingController();

  String? _selectedEstablishmentId;

  bool _isDetectingLocation = false;
  bool _isStarting = false;

  double? _latitude;
  double? _longitude;

  bool get _isReinspection => _selectedVisitType != 'Regular / Initial Inspection';

  @override
  void initState() {
    super.initState();
    _detectLocation(silent: true);
    InspectionMonitoringService().fetchActiveSession();
  }

  @override
  void dispose() {
    _ioRefController.dispose();
    _relatedOrderController.dispose();
    _addressController.dispose();
    _establishmentController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation({bool silent = false}) async {
    if (!silent) {
      setState(() => _isDetectingLocation = true);
    }
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) _showSnackBar('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!silent && mounted) _showSnackBar('Location permission denied.');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
        if (!silent) _showSnackBar('GPS Coordinates acquired.');
      }
    } catch (e) {
      debugPrint('Location detection error: $e');
      if (!silent && mounted) _showSnackBar('Could not acquire GPS position.');
    } finally {
      if (mounted && !silent) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  Future<void> _openEstablishmentPicker() async {
    try {
      final res = await Supabase.instance.client
          .from('establishments')
          .select('id, name, trade_name, address, barangay')
          .order('name', ascending: true)
          .limit(50);

      final establishments = List<Map<String, dynamic>>.from(res);

      if (!mounted) return;

      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (ctx, scrollController) => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded, color: Color(0xFFEA580C)),
                    const SizedBox(width: 8),
                    const Text('Select Registered Establishment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: establishments.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = establishments[i];
                    final name = item['name']?.toString() ?? item['trade_name']?.toString() ?? 'Unnamed';
                    final bgy = item['barangay']?.toString() ?? '';
                    final addr = item['address']?.toString() ?? '';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        'Brgy. $bgy${addr.isNotEmpty ? ' • $addr' : ''}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      onTap: () => Navigator.pop(ctx, item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

      if (selected != null && mounted) {
        setState(() {
          _selectedEstablishmentId = selected['id']?.toString();
          _establishmentController.text = selected['name']?.toString() ?? selected['trade_name']?.toString() ?? '';
          if (selected['address'] != null && selected['address'].toString().isNotEmpty) {
            _addressController.text = selected['address'].toString();
          }
          final matchedBgy = selected['barangay']?.toString();
          if (matchedBgy != null && SupabaseService.lingayenBarangays.contains(matchedBgy)) {
            _selectedBarangay = matchedBgy;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching establishments: $e');
    }
  }

  Future<void> _submitStartMonitoring() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please complete all required fields.');
      return;
    }

    setState(() => _isStarting = true);

    final result = await InspectionMonitoringService().startFieldMonitoring(
      visitType: _selectedVisitType,
      ioReferenceNo: _ioRefController.text.trim(),
      relatedOrderNo: _isReinspection ? _relatedOrderController.text.trim() : null,
      barangay: _selectedBarangay,
      locationAddress: _addressController.text.trim(),
      establishmentName: _establishmentController.text.trim(),
      establishmentId: _selectedEstablishmentId,
      latitude: _latitude,
      longitude: _longitude,
    );

    if (!mounted) return;
    setState(() => _isStarting = false);

    if (result['success'] == true) {
      _showSnackBar('Field Monitoring Started: Status ON SITE');
      // Navigate to Active Monitoring Tab
      widget.onNavigateTab?.call(1);
    } else {
      _showSnackBar(result['error']?.toString() ?? 'Failed to start field monitoring.');
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InspectionMonitoringModel?>(
      valueListenable: InspectionMonitoringService().activeSessionNotifier,
      builder: (context, activeSession, _) {
        final bool hasActiveSession = activeSession != null;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Inspection Monitor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            elevation: 0,
            centerTitle: false,
            actions: [
              if (hasActiveSession)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.fiber_manual_record, color: Color(0xFF16A34A), size: 10),
                      SizedBox(width: 4),
                      Text('ON SITE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    ],
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // If currently active: Show On-Site card with direct redirect
                if (hasActiveSession) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDBA74), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEA580C),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Field Monitoring in Progress',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF9A3412)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'IO Reference: ${activeSession.ioReferenceNo}\nVisit Type: ${activeSession.visitType}\nBarangay: Brgy. ${activeSession.barangay}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF7C2D12), height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => widget.onNavigateTab?.call(1),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text('GO TO ACTIVE SESSION & END MONITORING', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // Start Monitoring Form
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start Field Monitoring',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Lightweight on-site monitoring logger. Official checklists and e-AIR processing are managed in the official BFP system.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                          ),
                          const SizedBox(height: 20),

                          // Visit Type Selection
                          const Text('Visit Type *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedVisitType,
                            decoration: _inputDecoration(Icons.category_outlined),
                            items: InspectionMonitoringService.visitTypes
                                .map((vt) => DropdownMenuItem(
                                      value: vt,
                                      child: Text(vt, style: const TextStyle(fontSize: 13.5)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedVisitType = val);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Official BFP-FSIS / e-Inspection Order Ref Number
                          const Text(
                            'Official BFP-FSIS / e-Inspection Order Ref No. *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _ioRefController,
                            decoration: _inputDecoration(Icons.assignment_outlined, hintText: 'e.g., IO-2026-0428-R1'),
                            textCapitalization: TextCapitalization.characters,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Inspection Order Reference Number is required.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Related Order Ref No (for Reinspections / Orders)
                          if (_isReinspection) ...[
                            const Text(
                              'Related NTC / NTCV / Order Reference No. *',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _relatedOrderController,
                              decoration: _inputDecoration(Icons.fact_check_outlined, hintText: 'e.g., NTC-2026-0184 / NTCV-0042'),
                              textCapitalization: TextCapitalization.characters,
                              validator: (val) {
                                if (_isReinspection && (val == null || val.trim().isEmpty)) {
                                  return 'Related Order / Notice Reference is required for reinspections.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Barangay Location
                          const Text('Barangay Location *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedBarangay,
                            decoration: _inputDecoration(Icons.location_city_rounded),
                            items: SupabaseService.lingayenBarangays
                                .map((bgy) => DropdownMenuItem(
                                      value: bgy,
                                      child: Text('Brgy. $bgy', style: const TextStyle(fontSize: 13.5)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedBarangay = val);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Specific Landmark / Address
                          const Text('Specific Landmark / Address (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _addressController,
                            decoration: _inputDecoration(Icons.pin_drop_outlined, hintText: 'e.g., Near Poblacion Market, Rizal St.'),
                          ),
                          const SizedBox(height: 16),

                          // Establishment / Business Name (Optional)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Establishment / Building Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                              TextButton.icon(
                                onPressed: _openEstablishmentPicker,
                                icon: const Icon(Icons.search_rounded, size: 16),
                                label: const Text('Pick Registered', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _establishmentController,
                            decoration: _inputDecoration(Icons.storefront_outlined, hintText: 'e.g., Lingayen Commercial Center'),
                          ),
                          const SizedBox(height: 16),

                          // On-Site GPS Fix Status Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _latitude != null ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.my_location_rounded,
                                  color: _latitude != null ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('On-Site GPS Fix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
                                      Text(
                                        _latitude != null
                                            ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                                            : 'Detecting location...',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: _latitude != null ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _isDetectingLocation ? null : () => _detectLocation(),
                                  icon: _isDetectingLocation
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Update GPS', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Start Monitoring Button
                          ElevatedButton.icon(
                            onPressed: _isStarting ? null : _submitStartMonitoring,
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: _isStarting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('START FIELD MONITORING (ON SITE)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA580C),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(IconData icon, {String? hintText}) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5)),
    );
  }
}
