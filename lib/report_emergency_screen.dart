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

  // Safety photo bypass
  bool _isPhotoUnsafe = false;

  // Legal confirmation checkbox (RA 9514 Sec 8(i))
  bool _isLegalConfirmed = false;

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

        final inLingayen = SupabaseService.isInsideLingayen(
          position.latitude,
          position.longitude,
          barangay: _selectedBarangay,
        );

        if (!silent) {
          if (inLingayen) {
            _showSnackBar('GPS acquired: Lingayen Jurisdiction verified.');
          } else {
            _showSnackBar('GPS acquired: Location is outside Lingayen.');
          }
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

  /// Strictly uses the in-app camera for primary photo evidence.
  /// Citizen users cannot import gallery/stock photos to ensure authentic live reporting.
  Future<void> _captureLivePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
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
            _isPhotoUnsafe = false; // Reset unsafe flag if user takes photo
          });
        } else {
          setState(() {
            _pickedImageFile = File(image.path);
            _pickedImageName = image.name;
            _pickedImageBytes = null;
            _isPhotoUnsafe = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Live camera capture error: $e');
      _showSnackBar('Failed to access camera.');
    }
  }

  String? _validateContactNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Contact phone number is required.';
    }
    final clean = value.replaceAll(RegExp(r'[\s\-]'), '');
    final phMobileRegex = RegExp(r'^(09\d{9}|\+639\d{9}|9\d{9})$');
    if (!phMobileRegex.hasMatch(clean)) {
      return 'Enter a valid PH mobile number (e.g., 0917-123-4567).';
    }
    return null;
  }

  /// Handle report submission workflow (cooldown check, jurisdiction check, validation)
  Future<void> _onPreSubmitCheck() async {
    setState(() => _attemptedSubmit = true);

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please complete all required fields.');
      return;
    }

    // Photo evidence check: must either have taken camera photo or checked unsafe option
    final hasPhoto = _pickedImageFile != null || _pickedImageBytes != null;
    if (!hasPhoto && !_isPhotoUnsafe) {
      _showSnackBar('Please capture live photo evidence or check "Photo unsafe to capture".');
      return;
    }

    if (!_isLegalConfirmed) {
      _showSnackBar('Please read and confirm the Republic Act No. 9514 legal warning.');
      return;
    }

    // Spam / Flooding rate-limit check (2-minute cooldown)
    final remainingCooldown = await SupabaseService.getRemainingCooldownSeconds();
    if (remainingCooldown > 0) {
      if (mounted) {
        _showRateLimitDialog(remainingCooldown);
      }
      return;
    }

    // Jurisdiction Check: Based on incident location, NOT reporter residence
    final bool inLingayen = SupabaseService.isInsideLingayen(
      _latitude,
      _longitude,
      barangay: _selectedBarangay,
    );

    if (!inLingayen) {
      // Outside Lingayen: Show advisory prompt with Unified 911 button
      if (mounted) {
        _showOutOfJurisdictionDialog();
      }
      return;
    }

    // Inside Lingayen: Standard flow
    await _executeSubmission(isOutOfJurisdiction: false);
  }

  Future<void> _executeSubmission({required bool isOutOfJurisdiction}) async {
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
      photoUnsafe: _isPhotoUnsafe,
      isOutOfJurisdiction: isOutOfJurisdiction,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      final bool isMerged = result['isAutoMerged'] == true;
      final int supportingCount = (result['supportingReportsCount'] as num?)?.toInt() ?? 0;
      final Map<String, dynamic>? parent = result['parentIncident'];

      if (isMerged) {
        _showMergedIncidentSuccessModal(
          parentBarangay: parent?['barangay']?.toString() ?? _selectedBarangay,
          incidentType: _selectedIncidentType,
          supportingCount: supportingCount,
        );
      } else if (isOutOfJurisdiction) {
        _showOutOfJurisdictionSubmittedModal();
      } else {
        _showStandardSuccessModal();
      }
    } else {
      _showSnackBar('Failed to submit report: ${result['error']}');
    }
  }

  /// Dialog when rate-limiting cooldown is active
  void _showRateLimitDialog(int remainingSeconds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 24),
            SizedBox(width: 8),
            Text('Submission Cooldown', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A report from this device was submitted recently. To prevent accidental duplicates and system flooding, please wait $remainingSeconds seconds before submitting another report.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If life is currently in active danger, please call the BFP hotline immediately.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Wait', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              SupabaseService.callBfpHotline();
            },
            icon: const Icon(Icons.phone, size: 16),
            label: const Text('Call BFP Hotline'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Dialog when incident location is outside Lingayen jurisdiction
  void _showOutOfJurisdictionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Row(
          children: const [
            Icon(Icons.location_off_rounded, color: Color(0xFFEA580C), size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Outside Lingayen Jurisdiction',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: const Text(
                'The reported emergency appears to be outside Lingayen. For immediate assistance, please call Unified 911.\n\nYour report may also be reviewed for referral or coordination with the appropriate emergency response unit.',
                style: TextStyle(fontSize: 13, color: Color(0xFF9A3412), height: 1.45),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Recommended actions:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              SupabaseService.callUnified911();
            },
            icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 18),
            label: const Text('CALL UNIFIED 911 NOW', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _executeSubmission(isOutOfJurisdiction: true);
            },
            icon: const Icon(Icons.share_location_rounded, size: 18, color: Color(0xFFC2410C)),
            label: const Text(
              'Submit for Referral',
              style: TextStyle(color: Color(0xFFC2410C), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              backgroundColor: const Color(0xFFFFF7ED),
              side: const BorderSide(color: Color(0xFFF97316), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
            label: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              backgroundColor: const Color(0xFFF8FAFC),
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// Dialog when report was auto-merged into an active incident
  void _showMergedIncidentSuccessModal({
    required String parentBarangay,
    required String incidentType,
    required int supportingCount,
  }) {
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
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.merge_type_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 16),
            const Text(
              'REPORT MERGED',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                '${incidentType.toUpperCase()} – ${parentBarangay.toUpperCase()}  |  Supporting Reports: $supportingCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your report matches an ongoing active emergency at this location. It has been successfully linked as a supporting report so dispatchers have full visibility without duplicating emergency tickets.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => SupabaseService.callBfpHotline(),
              icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 18),
              label: const Text('CALL BFP HOTLINE (0917-186-1611)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _resetForm();
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog when report is submitted as Out-of-Jurisdiction
  void _showOutOfJurisdictionSubmittedModal() {
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
                color: Color(0xFFEA580C),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.share_location_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 16),
            const Text(
              'TRANSMITTED FOR REFERRAL',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your report has been tagged as Out-of-Jurisdiction and logged for BFP Lingayen referral coordination. For immediate local dispatch, call Unified 911.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => SupabaseService.callUnified911(),
              icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white),
              label: const Text('CALL UNIFIED 911 NOW', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _resetForm();
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showStandardSuccessModal() {
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
              'Your emergency report for Brgy. $_selectedBarangay has been received by BFP Lingayen for immediate response and dispatch.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => SupabaseService.callBfpHotline(),
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
      _isPhotoUnsafe = false;
      _isLegalConfirmed = false;
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
    final bool hasPhoto = _pickedImageFile != null || _pickedImageBytes != null;
    final bool isPhotoMissing = _attemptedSubmit && !hasPhoto && !_isPhotoUnsafe;
    final bool hasGps = _latitude != null && _longitude != null;
    final bool inLingayen = SupabaseService.isInsideLingayen(
      _latitude,
      _longitude,
      barangay: _selectedBarangay,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Citizen Emergency Report',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Call BFP Hotline',
            icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFDC2626)),
            onPressed: () => SupabaseService.callBfpHotline(),
          ),
        ],
      ),
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
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 28),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Direct Emergency Dispatch',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Direct line to BFP Lingayen Operations. For active life-threatening fires, dial the hotline immediately.',
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
                        'Report Fire or Incident',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Provide incident details to help BFP officers dispatch units quickly and safely.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),

                      // Section A1: Incident Type
                      const Text('Incident Type *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedIncidentType,
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

                      // Section A2: Contact Phone Number (Required & Validated)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Contact Phone Number *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                          Text('PH Mobile (09XX-XXX-XXXX)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _reporterContactController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration(Icons.phone_android_rounded, hintText: '0917-123-4567'),
                        validator: _validateContactNumber,
                      ),
                      const SizedBox(height: 16),

                      // Section A3: Incident Location (Barangay & Address & GPS)
                      const Text('Barangay Location *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedBarangay,
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

                      const Text('Landmark / Specific Address *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addressController,
                        decoration: _inputDecoration(Icons.pin_drop_rounded, hintText: 'e.g., Near Public Market, Avenida Rizal St.'),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter exact landmark or address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // GPS Location Card & Jurisdiction Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasGps
                                ? (inLingayen ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA))
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.my_location_rounded,
                                  color: hasGps
                                      ? (inLingayen ? const Color(0xFF16A34A) : const Color(0xFFEA580C))
                                      : const Color(0xFF0284C7),
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('GPS Incident Coordinates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
                                      Text(
                                        hasGps
                                            ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                                            : 'Not acquired yet',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: hasGps ? const Color(0xFF16A34A) : const Color(0xFF64748B),
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
                                  label: const Text('Update GPS', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                            if (hasGps && !inLingayen) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFDBA74)),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.info_outline_rounded, color: Color(0xFFEA580C), size: 16),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Outside Lingayen. You will be advised to call Unified 911 on submission.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF9A3412), fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section A4: Short Description
                      const Text('Short Description / Remarks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: _inputDecoration(
                          Icons.notes_rounded,
                          hintText: 'Describe smoke density, active flames, road blockages, or structures at risk...',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Optional Reporter Name
                      const Text('Reporter Name (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _reporterNameController,
                        decoration: _inputDecoration(Icons.person_outline_rounded, hintText: 'Leave blank to report anonymously'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 20),

                      // Section A5: Live Photo Evidence with In-App Camera Only & Safety Bypass
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isPhotoMissing ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                            width: isPhotoMissing ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.photo_camera_rounded, color: Color(0xFFDC2626), size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Live Photo Evidence',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                ),
                                const Spacer(),
                                if (_isPhotoUnsafe)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFCA5A5)),
                                    ),
                                    child: const Text(
                                      'Safety Bypass Active',
                                      style: TextStyle(fontSize: 10, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Use in-app camera for live proof. Gallery uploads are disabled to avoid old or fabricated images.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.35),
                            ),
                            const SizedBox(height: 12),

                            // Camera Capture or Preview
                            if (hasPhoto)
                              Container(
                                height: 140,
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
                                          ? Image.memory(_pickedImageBytes!, width: double.infinity, height: 140, fit: BoxFit.cover)
                                          : Image.file(_pickedImageFile!, width: double.infinity, height: 140, fit: BoxFit.cover),
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
                                          padding: const EdgeInsets.all(5),
                                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                              'Live Photo Captured',
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
                              ElevatedButton.icon(
                                onPressed: _captureLivePhoto,
                                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                                label: const Text('Capture Live Camera Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 46),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),

                            const SizedBox(height: 12),

                            // Safety Checkbox Rule: "Photo unsafe to capture"
                            Container(
                              decoration: BoxDecoration(
                                color: _isPhotoUnsafe ? const Color(0xFFFEF2F2) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _isPhotoUnsafe ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: CheckboxListTile(
                                value: _isPhotoUnsafe,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                controlAffinity: ListTileControlAffinity.leading,
                                activeColor: const Color(0xFFDC2626),
                                onChanged: (val) {
                                  setState(() {
                                    _isPhotoUnsafe = val ?? false;
                                    if (_isPhotoUnsafe) {
                                      _pickedImageFile = null;
                                      _pickedImageBytes = null;
                                      _pickedImageName = null;
                                    }
                                  });
                                },
                                title: const Text(
                                  'Photo unsafe to capture (Evacuating / in danger)',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                ),
                                subtitle: const Text(
                                  'Do not approach the incident or place yourself at risk solely to capture photo evidence. Life safety is paramount.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                                ),
                              ),
                            ),

                            if (isPhotoMissing) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Live photo evidence is required, or check "Photo unsafe to capture" if taking a photo would endanger you.',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section B: Mandatory Legal Warning (RA 9514 Sec 8(i))
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.gavel_rounded, color: Color(0xFFB45309), size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'FALSE EMERGENCY REPORT WARNING',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.5,
                                      color: Color(0xFF92400E),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'False or malicious fire alarms are prohibited under Section 8(i) of Republic Act No. 9514, the Revised Fire Code of the Philippines of 2008. Knowingly submitting false, prank, or malicious emergency information may result in penalties under applicable laws and ordinances and may be referred to the proper authorities.\n\nReport details such as submitted contact information, time, location, and supporting evidence may be used for verification and investigation, subject to applicable privacy rules.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.45),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isLegalConfirmed ? const Color(0xFF16A34A) : const Color(0xFFFCD34D),
                                ),
                              ),
                              child: CheckboxListTile(
                                value: _isLegalConfirmed,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                controlAffinity: ListTileControlAffinity.leading,
                                activeColor: const Color(0xFFDC2626),
                                onChanged: (val) {
                                  setState(() => _isLegalConfirmed = val ?? false);
                                },
                                title: const Text(
                                  'I confirm that this report is truthful and is being submitted for a legitimate emergency.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button: Remains strictly disabled until legal confirmation checkbox is checked
                      ElevatedButton(
                        onPressed: (!_isLegalConfirmed || _isSubmitting) ? null : _onPreSubmitCheck,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFCBD5E1),
                          disabledForegroundColor: const Color(0xFF94A3B8),
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: _isLegalConfirmed ? 3 : 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isLegalConfirmed ? Icons.send_rounded : Icons.lock_outline_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'SUBMIT EMERGENCY REPORT',
                                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                  ),
                                ],
                              ),
                      ),
                      if (!_isLegalConfirmed) ...[
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'Please check the truthfulness confirmation box above to enable submission.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
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
