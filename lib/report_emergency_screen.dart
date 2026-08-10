import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'services/supabase_service.dart';

class ReportEmergencyScreen extends StatefulWidget {
  const ReportEmergencyScreen({super.key});

  @override
  State<ReportEmergencyScreen> createState() => _ReportEmergencyScreenState();
}

class _ReportEmergencyScreenState extends State<ReportEmergencyScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedIncidentType = 'Structural Fire';
  String _selectedBarangay = 'Poblacion';

  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _reporterNameController = TextEditingController();
  final TextEditingController _reporterContactController = TextEditingController();

  bool _isDetectingLocation = false;
  bool _isSubmitting = false;
  bool _attemptedSubmit = false;

  double? _latitude;
  double? _longitude;

  File? _pickedImageFile;
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;

  final List<String> _incidentTypes = [
    'Structural Fire',
    'Grass / Garbage Fire',
    'Electrical Spaghetti Hazard',
    'Obstructed / Defective Hydrant',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _detectGpsLocation(silent: true);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _descriptionController.dispose();
    _reporterNameController.dispose();
    _reporterContactController.dispose();
    super.dispose();
  }

  Future<void> _detectGpsLocation({bool silent = false}) async {
    if (!silent) {
      setState(() => _isDetectingLocation = true);
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
          _showSnackBar('Location services are disabled. Please enable GPS.');
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!silent && mounted) {
            _showSnackBar('Location permissions are denied.');
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          _showSnackBar('Location permissions are permanently denied.');
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
        if (!silent) {
          _showSnackBar('GPS location updated: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}');
        }
      }
    } catch (e) {
      debugPrint('GPS Detection Error: $e');
      if (!silent && mounted) {
        _showSnackBar('Could not acquire GPS location.');
      }
    } finally {
      if (mounted && !silent) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _pickedImageBytes = bytes;
            _pickedImageName = image.name;
            _pickedImageFile = null;
          });
        } else {
          setState(() {
            _pickedImageFile = File(image.path);
            _pickedImageName = image.name;
            _pickedImageBytes = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
      _showSnackBar('Failed to select image.');
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Attach Hazard Photo Proof',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFEDD5),
                child: Icon(Icons.camera_alt_rounded, color: Color(0xFFEA580C)),
              ),
              title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE0F2FE),
                child: Icon(Icons.photo_library_rounded, color: Color(0xFF0284C7)),
              ),
              title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    setState(() => _attemptedSubmit = true);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_pickedImageFile == null && _pickedImageBytes == null) {
      _showSnackBar('Photo evidence is required. Please capture or attach a photo of the incident.');
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await SupabaseService.submitEmergencyReport(
      reporterName: _reporterNameController.text.trim(),
      reporterContact: _reporterContactController.text.trim(),
      incidentType: _selectedIncidentType,
      barangay: _selectedBarangay,
      address: _addressController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      description: _descriptionController.text.trim(),
      photoFile: _pickedImageFile,
      photoBytes: _pickedImageBytes,
      photoName: _pickedImageName,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      _showSuccessConfirmationModal();
    } else {
      _showSnackBar('Failed to submit report: ${result['error']}');
    }
  }

  void _showSuccessConfirmationModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'ALERT TRANSMITTED!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your emergency report for Brgy. $_selectedBarangay has been safely received by the BFP Command Portal for immediate dispatch.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                SupabaseService.callBfpHotline();
              },
              icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white),
              label: const Text(
                'CALL BFP HOTLINE NOW',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _resetForm();
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Home', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _addressController.clear();
    _descriptionController.clear();
    _reporterNameController.clear();
    _reporterContactController.clear();
    setState(() {
      _selectedIncidentType = 'Structural Fire';
      _selectedBarangay = 'Poblacion';
      _attemptedSubmit = false;
      _pickedImageFile = null;
      _pickedImageBytes = null;
      _pickedImageName = null;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPhotoMissing = _attemptedSubmit && _pickedImageFile == null && _pickedImageBytes == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Emergency Header Banner
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.3),
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
                      const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 28),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Direct Emergency Dispatch',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Submitting this form alerts BFP Lingayen Station immediately. For active life-threatening fires, tap the hotline button below.',
                    style: TextStyle(color: Color(0xFFFEE2E2), fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => SupabaseService.callBfpHotline(),
                    icon: const Icon(Icons.phone_forwarded_rounded, size: 18),
                    label: const Text('CALL HOTLINE: 0917-186-1611', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFDC2626),
                      minimumSize: const Size(double.infinity, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Form Section
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report Fire or Safety Hazard',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Provide incident details to help BFP officers respond effectively. All fields marked (*) are required.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),

                      // Incident Type Dropdown
                      const Text('Incident / Hazard Type *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedIncidentType,
                        decoration: _inputDecoration(Icons.fireplace_rounded),
                        items: _incidentTypes
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type, style: const TextStyle(fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedIncidentType = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Barangay Dropdown
                      const Text('Barangay Location *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedBarangay,
                        decoration: _inputDecoration(Icons.location_city_rounded),
                        items: SupabaseService.lingayenBarangays
                            .map((bgy) => DropdownMenuItem(
                                  value: bgy,
                                  child: Text('Brgy. $bgy', style: const TextStyle(fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedBarangay = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Address / Landmark
                      const Text('Landmark / Specific Address *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addressController,
                        decoration: _inputDecoration(Icons.pin_drop_rounded, hintText: 'e.g., Near Petron Station, Avenida Rizal St.'),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter exact landmark or address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Reporter Full Name (Required)
                      const Text('Reporter Full Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _reporterNameController,
                        decoration: _inputDecoration(Icons.person_outline_rounded, hintText: 'e.g., Juan Dela Cruz'),
                        textCapitalization: TextCapitalization.words,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter your full name.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Contact Phone Number (Required)
                      const Text('Contact Phone Number *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _reporterContactController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration(Icons.phone_outlined, hintText: 'e.g., 0917-123-4567'),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter your contact phone number.';
                          }
                          if (val.trim().length < 7) {
                            return 'Please enter a valid contact phone number.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // GPS Location Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.my_location_rounded, color: Color(0xFF0284C7), size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('GPS Coordinates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
                                  Text(
                                    _latitude != null && _longitude != null
                                        ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                                        : 'Not detected yet',
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
                              onPressed: _isDetectingLocation ? null : () => _detectGpsLocation(),
                              icon: _isDetectingLocation
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Detect', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      const Text('Description / Remarks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: _inputDecoration(Icons.notes_rounded, hintText: 'Describe smoke density, visible flames, or road obstructions...'),
                      ),
                      const SizedBox(height: 16),

                      // Photo Evidence (Required)
                      Row(
                        children: const [
                          Text(
                            'Photo Evidence *',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
                          ),
                          SizedBox(width: 6),
                          Text(
                            '(Required for verification)',
                            style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_pickedImageFile != null || _pickedImageBytes != null)
                        Container(
                          height: 130,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: _pickedImageBytes != null
                                    ? Image.memory(_pickedImageBytes!, width: double.infinity, height: 130, fit: BoxFit.cover)
                                    : Image.file(_pickedImageFile!, width: double.infinity, height: 130, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _pickedImageFile = null;
                                      _pickedImageBytes = null;
                                      _pickedImageName = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Photo Attached',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _showImageSourceOptions,
                              icon: Icon(
                                Icons.add_a_photo_rounded,
                                size: 20,
                                color: isPhotoMissing ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                              ),
                              label: Text(
                                'Capture / Attach Photo Evidence *',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isPhotoMissing ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                                side: BorderSide(
                                  color: isPhotoMissing ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
                                  width: isPhotoMissing ? 1.5 : 1.0,
                                ),
                                backgroundColor: isPhotoMissing ? const Color(0xFFFEF2F2) : Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            if (isPhotoMissing) ...[
                              const SizedBox(height: 6),
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Text(
                                  'Photo evidence is required to submit an emergency incident.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'SUBMIT EMERGENCY ALERT',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(IconData prefixIcon, {String? hintText}) {
    return InputDecoration(
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF64748B), size: 20),
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }
}
