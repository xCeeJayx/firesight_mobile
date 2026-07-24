import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    final lower = status.trim().toLowerCase();

    // Critical / Fail / High Hazard / No
    if (lower == 'no' ||
        lower.contains('fail') ||
        lower.contains('critical') ||
        lower.contains('high') ||
        lower.contains('non-compliant') ||
        lower.contains('hazard')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      icon = Icons.cancel_outlined;
    }
    // Moderate / Warning / Medium Risk / Notice
    else if (lower.contains('medium') ||
        lower.contains('progress') ||
        lower.contains('warning') ||
        lower.contains('notice') ||
        lower.contains('moderate')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      icon = Icons.warning_amber_rounded;
    }
    // Pass / Compliant / Completed / Low Risk / Yes
    else if (lower == 'yes' ||
        lower.contains('pass') ||
        lower.contains('completed') ||
        lower.contains('compliant') ||
        lower.contains('synced') ||
        lower.contains('issued') ||
        lower.contains('low') ||
        lower.contains('good') ||
        lower.contains('safe')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
      icon = Icons.check_circle_outline;
    }
    // Pending / Waiting
    else if (lower.contains('pending') || lower.contains('waiting')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      icon = Icons.hourglass_empty_rounded;
    }
    // N/A or Neutral Info (Inspected, N/A, Not Applicable, etc.)
    else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
      icon = lower.contains('n/a') ? Icons.remove_circle_outline : Icons.info_outline;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 3, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              status.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
