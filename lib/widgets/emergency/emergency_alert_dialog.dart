import 'package:flutter/material.dart';
import '../../models/emergency_report_model.dart';
import '../../services/alarm/emergency_alarm_service.dart';
import 'emergency_details_bottom_sheet.dart';

class EmergencyAlertDialog extends StatefulWidget {
  final EmergencyReportModel report;
  final String? alertTitle;

  const EmergencyAlertDialog({
    super.key,
    required this.report,
    this.alertTitle,
  });

  /// Displays the High-Priority Emergency Pop-up Overlay Dialog with continuous siren & vibration
  static Future<void> show(
    BuildContext context,
    EmergencyReportModel report, {
    String? alertTitle,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      builder: (context) => EmergencyAlertDialog(
        report: report,
        alertTitle: alertTitle,
      ),
    );
  }

  @override
  State<EmergencyAlertDialog> createState() => _EmergencyAlertDialogState();
}

class _EmergencyAlertDialogState extends State<EmergencyAlertDialog> {
  @override
  void initState() {
    super.initState();
    // Start emergency alarm sound & vibration in background
    EmergencyAlarmService().startAlarm();
  }

  @override
  void dispose() {
    // Stop sound and vibration as soon as user closes dialog
    EmergencyAlarmService().stopAlarm();
    super.dispose();
  }

  void _closeAndNavigateDetails() {
    EmergencyAlarmService().stopAlarm();
    Navigator.of(context).pop();
    EmergencyDetailsBottomSheet.show(context, widget.report);
  }

  void _dismissDialog() {
    EmergencyAlarmService().stopAlarm();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const Color bfpRed = Color(0xFFDC2626);
    final String reporter = (widget.report.reporterName != null && widget.report.reporterName!.trim().isNotEmpty)
        ? widget.report.reporterName!.trim()
        : 'Anonymous Citizen';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 20,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Urgency Header (#DC2626 BFP Red)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: bfpRed,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HIGH-PRIORITY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white70,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.alertTitle ?? 'Incoming Emergency Report',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Alert Content Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Incident Type Chip + Timestamp
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.report.incidentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: widget.report.incidentColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.report.incidentIcon, size: 14, color: widget.report.incidentColor),
                          const SizedBox(width: 6),
                          Text(
                            widget.report.incidentType,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.report.incidentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      widget.report.formattedTimeAgo,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Details Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        icon: Icons.location_city_rounded,
                        label: 'Barangay',
                        value: 'Brgy. ${widget.report.barangay}',
                        isBold: true,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        icon: Icons.place_outlined,
                        label: 'Address / Landmark',
                        value: (widget.report.address != null && widget.report.address!.trim().isNotEmpty)
                            ? widget.report.address!
                            : 'Lingayen Area',
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Reported By',
                        value: reporter,
                      ),
                    ],
                  ),
                ),

                if (widget.report.description != null && widget.report.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.report.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action Controls: "View Full Details" and "Close"
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _dismissDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _closeAndNavigateDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bfpRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text(
                      'View Full Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
