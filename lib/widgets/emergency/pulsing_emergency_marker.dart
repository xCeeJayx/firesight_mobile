import 'package:flutter/material.dart';
import '../../models/emergency_report_model.dart';

/// Animated pulsing marker for real-time emergency incidents on the GIS map canvas
class PulsingEmergencyMarker extends StatefulWidget {
  final EmergencyReportModel report;
  final VoidCallback onTap;
  final bool isSelected;

  const PulsingEmergencyMarker({
    super.key,
    required this.report,
    required this.onTap,
    this.isSelected = false,
  });

  /// Map exact incident_type to specification styling color
  static Color getIncidentColor(String incidentType) {
    final type = incidentType.toLowerCase();
    if (type.contains('structural') || type.contains('building')) {
      return const Color(0xFFDC2626); // Pulsing Red
    } else if (type.contains('grass') || type.contains('garbage')) {
      return const Color(0xFFEA580C); // Orange-Red
    } else if (type.contains('electrical') || type.contains('spaghetti')) {
      return const Color(0xFFD97706); // Amber
    } else if (type.contains('hydrant') || type.contains('defective') || type.contains('water')) {
      return const Color(0xFF0284C7); // Cyan / Blue
    } else {
      return const Color(0xFF475569); // Slate / Dark
    }
  }

  /// Map exact incident_type to specification outline icon
  static IconData getIncidentIcon(String incidentType) {
    final type = incidentType.toLowerCase();
    if (type.contains('structural') || type.contains('building')) {
      return Icons.local_fire_department_outlined;
    } else if (type.contains('grass') || type.contains('garbage')) {
      return Icons.whatshot_outlined;
    } else if (type.contains('electrical') || type.contains('spaghetti')) {
      return Icons.flash_on_outlined;
    } else if (type.contains('hydrant') || type.contains('defective') || type.contains('water')) {
      return Icons.water_drop_outlined;
    } else {
      return Icons.warning_amber_outlined;
    }
  }

  @override
  State<PulsingEmergencyMarker> createState() => _PulsingEmergencyMarkerState();
}

class _PulsingEmergencyMarkerState extends State<PulsingEmergencyMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    // Only pulse actively for active/unresolved reports
    final status = widget.report.status.toLowerCase();
    if (status != 'resolved' && status != 'false alarm') {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PulsingEmergencyMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final status = widget.report.status.toLowerCase();
    if (status == 'resolved' || status == 'false alarm') {
      if (_pulseController.isAnimating) _pulseController.stop();
    } else {
      if (!_pulseController.isAnimating) _pulseController.repeat();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = PulsingEmergencyMarker.getIncidentColor(widget.report.incidentType);
    final icon = PulsingEmergencyMarker.getIncidentIcon(widget.report.incidentType);
    final status = widget.report.status;
    final isResolved = status.toLowerCase() == 'resolved' || status.toLowerCase() == 'false alarm';

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Radar Pulse Effect (for Active Emergency Incidents)
          if (!isResolved)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: _opacityAnimation.value),
                    ),
                  ),
                );
              },
            ),

          // Outer Ring / Glow
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: isResolved ? 0.2 : 0.3),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isResolved ? 0.2 : 0.45),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

          // Central Marker Pin
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          // Status Badge Pill Indicator
          Positioned(
            bottom: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                  color: isResolved ? const Color(0xFF94A3B8) : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
