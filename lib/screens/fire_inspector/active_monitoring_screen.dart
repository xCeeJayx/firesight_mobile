import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/inspection_monitoring_model.dart';
import '../../services/inspection_monitoring_service.dart';

class ActiveMonitoringScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;

  const ActiveMonitoringScreen({super.key, this.onNavigateTab});

  @override
  State<ActiveMonitoringScreen> createState() => _ActiveMonitoringScreenState();
}

class _ActiveMonitoringScreenState extends State<ActiveMonitoringScreen> {
  Timer? _stopwatchTimer;
  Duration _elapsed = Duration.zero;

  bool _isEndingSession = false;
  bool _isRefreshingGps = false;

  @override
  void initState() {
    super.initState();
    _startStopwatch();
  }

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  void _startStopwatch() {
    _stopwatchTimer?.cancel();
    _updateElapsed();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateElapsed();
    });
  }

  void _updateElapsed() {
    final active = InspectionMonitoringService().activeSessionNotifier.value;
    if (active != null) {
      final now = DateTime.now();
      final diff = now.difference(active.startTime);
      setState(() {
        _elapsed = diff.isNegative ? Duration.zero : diff;
      });
    }
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00:00';
    final hours = d.inHours.toString().padLeft(2, '0');
    final mins = (d.inMinutes.remainder(60)).abs().toString().padLeft(2, '0');
    final secs = (d.inSeconds.remainder(60)).abs().toString().padLeft(2, '0');
    return '$hours:$mins:$secs';
  }

  Future<void> _refreshCurrentGps() async {
    final active = InspectionMonitoringService().activeSessionNotifier.value;
    if (active == null) return;

    setState(() => _isRefreshingGps = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final updated = active.copyWith(
        currentLatitude: pos.latitude,
        currentLongitude: pos.longitude,
        lastLocationUpdate: DateTime.now(),
      );

      InspectionMonitoringService().activeSessionNotifier.value = updated;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('On-Site GPS position updated.')),
        );
      }
    } catch (e) {
      debugPrint('Error updating GPS: $e');
    } finally {
      if (mounted) setState(() => _isRefreshingGps = false);
    }
  }

  Future<void> _promptEndMonitoring(InspectionMonitoringModel session) async {
    final remarksController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Row(
          children: const [
            Icon(Icons.stop_circle_outlined, color: Color(0xFFDC2626), size: 26),
            SizedBox(width: 8),
            Text('End Field Monitoring', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will mark your monitoring status as COMPLETED, record your final on-site GPS location, calculate total duration, and remove your live marker from the Web Admin map.',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: remarksController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Field Remarks / Notes (Optional)',
                hintText: 'e.g., Verification completed, returned to station',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm End Session', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isEndingSession = true);

    double? endLat;
    double? endLng;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 6)),
      );
      endLat = pos.latitude;
      endLng = pos.longitude;
    } catch (_) {}

    final res = await InspectionMonitoringService().endFieldMonitoring(
      session.id,
      endLatitude: endLat,
      endLongitude: endLng,
      remarks: remarksController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isEndingSession = false);

    if (res['success'] == true) {
      final completed = res['data'] as InspectionMonitoringModel;
      _showCompletionSuccessDialog(completed);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end monitoring: ${res['error']}')),
      );
    }
  }

  void _showCompletionSuccessDialog(InspectionMonitoringModel session) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 44),
            ),
            const SizedBox(height: 16),
            const Text(
              'SESSION COMPLETED',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Total Duration: ${session.formattedDuration}\nStatus updated to COMPLETED and logged in Monitoring History.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onNavigateTab?.call(2); // Go to history
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('View Monitoring History', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InspectionMonitoringModel?>(
      valueListenable: InspectionMonitoringService().activeSessionNotifier,
      builder: (context, activeSession, _) {
        if (activeSession == null) {
          // Empty State
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: const Text('Active Field Monitoring', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.timer_off_outlined, size: 48, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Active Monitoring Session',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You are currently off-site. When arriving at a field inspection, tap below to start a live monitoring session.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => widget.onNavigateTab?.call(0),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Field Monitoring', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(220, 46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Active On-Site View
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Active Field Monitoring', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Refresh Location',
                icon: _isRefreshingGps
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded, color: Color(0xFF0284C7)),
                onPressed: _isRefreshingGps ? null : _refreshCurrentGps,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Stopwatch Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF22C55E)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.fiber_manual_record, color: Color(0xFF22C55E), size: 10),
                                SizedBox(width: 5),
                                Text(
                                  'ON SITE MONITORING',
                                  style: TextStyle(color: Color(0xFF86EFAC), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            activeSession.formattedStartTime,
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _formatDuration(_elapsed),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                          fontFeatures: [],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'ELAPSED DURATION',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Session Details Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: activeSession.visitTypeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(activeSession.visitTypeIcon, size: 14, color: activeSession.visitTypeColor),
                                const SizedBox(width: 6),
                                Text(
                                  activeSession.visitType,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: activeSession.visitTypeColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      _buildDetailRow(
                        icon: Icons.assignment_outlined,
                        label: 'IO Reference No.',
                        value: activeSession.ioReferenceNo,
                        isBold: true,
                      ),

                      if (activeSession.relatedOrderNo != null) ...[
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          icon: Icons.fact_check_outlined,
                          label: 'Related Order / Notice',
                          value: activeSession.relatedOrderNo!,
                          valueColor: const Color(0xFFDC2626),
                          isBold: true,
                        ),
                      ],

                      if (activeSession.establishmentName != null && activeSession.establishmentName!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          icon: Icons.storefront_rounded,
                          label: 'Establishment / Building',
                          value: activeSession.establishmentName!,
                          isBold: true,
                        ),
                      ],

                      const SizedBox(height: 10),
                      _buildDetailRow(
                        icon: Icons.location_city_rounded,
                        label: 'Barangay Location',
                        value: 'Brgy. ${activeSession.barangay}',
                      ),

                      if (activeSession.locationAddress != null && activeSession.locationAddress!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          icon: Icons.pin_drop_outlined,
                          label: 'Specific Landmark',
                          value: activeSession.locationAddress!,
                        ),
                      ],

                      const SizedBox(height: 10),
                      _buildDetailRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Field Inspector',
                        value: '${activeSession.inspectorRank} ${activeSession.inspectorName}',
                      ),

                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),

                      // GPS Details
                      Row(
                        children: [
                          const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF0284C7)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              activeSession.currentLatitude != null
                                  ? 'Current GPS: ${activeSession.currentLatitude!.toStringAsFixed(5)}, ${activeSession.currentLongitude!.toStringAsFixed(5)}'
                                  : 'Initial GPS recorded',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Web Admin Live Sync Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.share_location_rounded, color: Color(0xFF2563EB), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Active Live Marker: You are visible on the Web Admin Map. Ending this session will remove the live pin.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // End Monitoring Action Button
                ElevatedButton.icon(
                  onPressed: _isEndingSession ? null : () => _promptEndMonitoring(activeSession),
                  icon: const Icon(Icons.stop_circle_rounded, size: 22),
                  label: _isEndingSession
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('END FIELD MONITORING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
