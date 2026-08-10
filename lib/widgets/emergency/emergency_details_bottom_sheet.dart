import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/emergency_report_model.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/emergency_service.dart';

class EmergencyDetailsBottomSheet extends StatefulWidget {
  final EmergencyReportModel report;
  final bool isPublicUser;
  final VoidCallback? onCenterMap;

  const EmergencyDetailsBottomSheet({
    super.key,
    required this.report,
    this.isPublicUser = false,
    this.onCenterMap,
  });

  /// Static helper to display the sheet
  static Future<void> show(
    BuildContext context,
    EmergencyReportModel report, {
    bool isPublicUser = false,
    VoidCallback? onCenterMap,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EmergencyDetailsBottomSheet(
        report: report,
        isPublicUser: isPublicUser,
        onCenterMap: onCenterMap,
      ),
    );
  }

  @override
  State<EmergencyDetailsBottomSheet> createState() => _EmergencyDetailsBottomSheetState();
}

class _EmergencyDetailsBottomSheetState extends State<EmergencyDetailsBottomSheet> {
  late EmergencyReportModel _report;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
  }

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final clean = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;

    final Uri telUri = Uri(scheme: 'tel', path: clean);
    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else {
        await launchUrl(telUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(telUri, mode: LaunchMode.platformDefault);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open phone dialer: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  Future<void> _launchMaps(double lat, double lng, String label) async {
    // 1. Google Maps Navigation intent / directions
    final Uri googleMapsDirUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    // 2. Standard Universal Geo intent
    final Uri geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(label)})');
    // 3. Fallback search URL
    final Uri googleMapsSearchUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      bool launched = false;
      // Try opening native map app first (Google Maps / Apple Maps / Waze)
      if (await canLaunchUrl(geoUri)) {
        launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      }
      if (!launched && await canLaunchUrl(googleMapsDirUri)) {
        launched = await launchUrl(googleMapsDirUri, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        launched = await launchUrl(googleMapsDirUri, mode: LaunchMode.platformDefault);
      }
      if (!launched) {
        await launchUrl(googleMapsSearchUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(googleMapsDirUri, mode: LaunchMode.platformDefault);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open map navigation: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdatingStatus = true);
    final success = await EmergencyService().updateReportStatus(_report.id, newStatus);
    if (mounted) {
      setState(() {
        _isUpdatingStatus = false;
        if (success) {
          _report = _report.copyWith(status: newStatus);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                success
                    ? 'Status updated to "$newStatus"'
                    : 'Failed to update report status',
              ),
            ],
          ),
          backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = !widget.isPublicUser && (AuthService().currentRole != UserRole.publicGuest);
    final hasGps = _report.latitude != null && _report.longitude != null;
    final hasContact = _report.reporterContact != null &&
        _report.reporterContact!.trim().isNotEmpty &&
        _report.reporterContact!.trim().toLowerCase() != 'n/a';
    final hasPhoto = _report.photoUrl != null && _report.photoUrl!.trim().isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _report.incidentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _report.incidentIcon,
                        color: _report.incidentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Emergency Report Details',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _report.formattedDateTime,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Incident Type & Status Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _report.incidentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _report.incidentType.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _report.incidentColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _report.statusBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _report.statusTextColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                _report.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _report.statusTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.location_city_rounded, size: 16, color: Color(0xFF0F172A)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Brgy. ${_report.barangay}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_report.address != null && _report.address!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.pin_drop_outlined, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _report.address!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Description
                  _buildSectionTitle('Incident Description & Notes'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      (_report.description != null && _report.description!.trim().isNotEmpty)
                          ? _report.description!
                          : 'No additional incident description provided.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        height: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // GPS Coordinates & Map Launcher Actions
                  _buildSectionTitle('GPS Coordinates & Dispatch Location'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.my_location_rounded, color: Color(0xFF0F172A), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hasGps
                                        ? '${_report.latitude!.toStringAsFixed(6)}, ${_report.longitude!.toStringAsFixed(6)}'
                                        : 'GPS Coordinates Unavailable',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: hasGps ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasGps ? 'Geolocated coordinate fix' : 'Reported with address only',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (hasGps) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (widget.onCenterMap != null) ...[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      widget.onCenterMap!();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.center_focus_strong_rounded, size: 16),
                                    label: const Text(
                                      'Center on Map',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _launchMaps(
                                    _report.latitude!,
                                    _report.longitude!,
                                    _report.incidentType,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD84315),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.navigation_rounded, size: 16),
                                  label: const Text(
                                    'Launch Navigation',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Reporter Details (Restricted: Staff Only if isPublicUser == false)
                  if (isStaff) ...[
                    const SizedBox(height: 16),
                    _buildSectionTitle('Reporter Information (Internal Personnel View)'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_outline_rounded, color: Color(0xFFEA580C), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (_report.reporterName != null && _report.reporterName!.trim().isNotEmpty)
                                      ? _report.reporterName!
                                      : 'Anonymous Citizen',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasContact ? _report.reporterContact! : 'No phone number provided',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          if (hasContact)
                            ElevatedButton.icon(
                              onPressed: () => _launchPhoneCall(_report.reporterContact!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                              label: const Text('Call', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Photo Evidence
                  if (hasPhoto) ...[
                    const SizedBox(height: 16),
                    _buildSectionTitle('Incident Evidence Photo'),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 260),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Image.network(
                          _report.photoUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(color: Color(0xFFEA580C)),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(30),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.broken_image_outlined, color: Colors.white54, size: 36),
                                    SizedBox(height: 6),
                                    Text('Unable to load photo evidence', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  // BFP Operational Controls (if staff)
                  if (isStaff) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle('Operational Response Actions'),
                    const SizedBox(height: 10),
                    if (_isUpdatingStatus)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(color: Color(0xFFEA580C)),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_report.status.toLowerCase() != 'verified')
                            ElevatedButton.icon(
                              onPressed: () => _updateStatus('Verified'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.verified_outlined, size: 16),
                              label: const Text('Verify Incident', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          if (_report.status.toLowerCase() != 'responding' && _report.status.toLowerCase() != 'dispatched')
                            ElevatedButton.icon(
                              onPressed: () => _updateStatus('Responding'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEA580C),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.local_shipping_outlined, size: 16),
                              label: const Text('Dispatch Response', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          if (_report.status.toLowerCase() != 'resolved')
                            ElevatedButton.icon(
                              onPressed: () => _updateStatus('Resolved'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check_circle_outline, size: 16),
                              label: const Text('Mark Resolved', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          if (_report.status.toLowerCase() != 'false alarm')
                            OutlinedButton.icon(
                              onPressed: () => _updateStatus('False Alarm'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFFECACA)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.cancel_outlined, size: 16),
                              label: const Text('False Alarm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Color(0xFF334155),
        letterSpacing: 0.2,
      ),
    );
  }
}
