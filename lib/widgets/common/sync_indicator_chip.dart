import 'package:flutter/material.dart';

class SyncIndicatorChip extends StatefulWidget {
  final bool isOnline;
  final int pendingDrafts;

  const SyncIndicatorChip({
    super.key,
    this.isOnline = true,
    this.pendingDrafts = 0,
  });

  @override
  State<SyncIndicatorChip> createState() => _SyncIndicatorChipState();
}

class _SyncIndicatorChipState extends State<SyncIndicatorChip> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPending = widget.pendingDrafts > 0;
    final Color dotColor = hasPending ? const Color(0xFFEA580C) : const Color(0xFF16A34A);
    final Color bgColor = hasPending ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4);
    final Color borderColor = hasPending ? const Color(0xFFFED7AA) : const Color(0xFFBBF7D0);
    final String label = hasPending ? '${widget.pendingDrafts} Pending Sync' : 'Online & Synced';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _pulseAnimation,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: hasPending ? const Color(0xFFC2410C) : const Color(0xFF15803D),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
