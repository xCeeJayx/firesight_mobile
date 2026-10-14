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
  bool _isSeparating = false;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
  }

  Future<void> _separateReport() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Separate Emergency Report?'),
        content: const Text(
          'This will detach this report from its parent incident and restore it as an independent emergency ticket.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Separate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSeparating = true);
    final success = await EmergencyService().separateReport(_report.id, _report.parentIncidentId);
    if (mounted) {
      setState(() {
        _isSeparating = false;
        if (success) {
          _report = _report.copyWith(parentIncidentId: null);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Report separated into an independent incident.' : 'Failed to separate report.',
          ),
          backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

  Future<void> _confirmAndChangeStatus(String newStatus) async {
    final isResolved = newStatus == 'Resolved';
    final isFalseAlarm = newStatus == 'False Alarm';

    if (isResolved || isFalseAlarm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isResolved
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isResolved ? Icons.check_circle_outline : Icons.cancel_outlined,
                  color: isResolved ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isResolved ? 'Mark as Resolved?' : 'Mark as False Alarm?',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          content: Text(
            isResolved
                ? 'This will conclude operational response for this incident and archive it from active maps and feeds.'
                : 'Are you sure this report is a false or prank alarm? It will be dismissed from active operations and hidden from maps.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isResolved ? const Color(0xFF0F172A) : const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                isResolved ? 'Confirm & Resolve' : 'Confirm False Alarm',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    if (!mounted) return;
    setState(() => _isUpdatingStatus = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final success = await EmergencyService().updateReportStatus(_report.id, newStatus);

    if (!mounted) return;
    setState(() => _isUpdatingStatus = false);

    if (success) {
      if (isResolved || isFalseAlarm) {
        nav.pop(); // Close the modal sheet upon resolution or false alarm
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isResolved ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  isResolved ? 'Incident marked as Resolved.' : 'Report marked as False Alarm.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: isResolved ? const Color(0xFF16A34A) : const Color(0xFF64748B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // If Verified or Responding: update the local report model so UI reflects the next lifecycle state
      setState(() {
        _report = _report.copyWith(status: newStatus);
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                newStatus == 'Verified'
                    ? 'Incident Verified by BFP. Public alert broadcast.'
                    : 'Response Dispatched. BFP units responding.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: newStatus == 'Verified' ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Failed to update report status. Please check connection.'),
            ],
          ),
          backgroundColor: Color(0xFFDC2626),
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

                  // Grouping & Jurisdiction Status Indicators
                  if (_report.hasSupportingReports) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.merge_type_rounded, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Parent Incident | ${_report.supportingReportsCount} Supporting Report(s) linked',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_report.isSupportingReport) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.link_rounded, color: Color(0xFF475569), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Supporting Report (Grouped)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'This report was auto-merged under an active parent incident.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                          if (isStaff) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _isSeparating ? null : _separateReport,
                              icon: _isSeparating
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.call_split_rounded, size: 16),
                              label: const Text('Separate Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFF87171)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  if (_report.isOutDistrict) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.location_off_rounded, color: Color(0xFFEA580C), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Outside Lingayen Jurisdiction: Transmitted for referral and coordination with Unified 911 / external units.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFC2410C),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_report.isFlaggedSuspicious) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Flagged for Verification: High report frequency detected from this device/account.',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

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

                  if (!hasPhoto && _report.photoUnsafe) ...[
                    const SizedBox(height: 16),
                    _buildSectionTitle('Incident Evidence Status'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.health_and_safety_rounded, color: Color(0xFFDC2626), size: 24),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Safety Bypass Active: Reporter stated capturing live photo evidence would place them in immediate danger or evacuation.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF991B1B),
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
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
                      _buildOperationalActions(),
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

  Widget _buildOperationalActions() {
    final status = _report.status.toLowerCase();

    // 1. Resolved State -> Read-only Case Closed Banner
    if (status == 'resolved') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Incident Resolved',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'This incident is closed. Operational response is concluded.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 2. False Alarm State -> Read-only Closed Banner
    if (status == 'false alarm' || status == 'false_alarm') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marked as False Alarm',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Dismissed as invalid or prank report. No action needed.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 3. Out-of-Jurisdiction State
    if (status == 'out-of-jurisdiction' || _report.isOutOfJurisdiction) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDD5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.near_me_outlined, color: Color(0xFFC2410C), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Out of Jurisdiction',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFC2410C)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Coordinates are outside Lingayen. Replaced with referral protocol.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 4. Sequential Active Lifecycle:
    // - Unverified: [Verify Incident], [False Alarm]
    // - Verified: [Dispatch Response], [Mark Resolved]
    // - Responding / Dispatched: [Mark Resolved]
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (status == 'unverified') ...[
          ElevatedButton.icon(
            onPressed: () => _confirmAndChangeStatus('Verified'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.verified_outlined, size: 16),
            label: const Text('Verify Incident', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          OutlinedButton.icon(
            onPressed: () => _confirmAndChangeStatus('False Alarm'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFFECACA)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: const Text('False Alarm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ] else if (status == 'verified') ...[
          ElevatedButton.icon(
            onPressed: () => _confirmAndChangeStatus('Responding'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.local_shipping_outlined, size: 16),
            label: const Text('Dispatch Response', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () => _confirmAndChangeStatus('Resolved'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Mark Resolved', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ] else if (status == 'responding' || status == 'dispatched') ...[
          ElevatedButton.icon(
            onPressed: () => _confirmAndChangeStatus('Resolved'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Mark Resolved', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
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
