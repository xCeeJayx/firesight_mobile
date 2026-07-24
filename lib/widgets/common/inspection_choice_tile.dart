import 'package:flutter/material.dart';

enum InspectionChoice { pass, fail, notApplicable }

class InspectionChoiceTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final InspectionChoice? selectedValue;
  final ValueChanged<InspectionChoice?> onChanged;
  final VoidCallback? onAddPhoto;
  final String? photoUrl;
  final String? noteText;
  final ValueChanged<String>? onNoteChanged;

  const InspectionChoiceTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.selectedValue,
    required this.onChanged,
    this.onAddPhoto,
    this.photoUrl,
    this.noteText,
    this.onNoteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedValue == InspectionChoice.pass
              ? const Color(0xFF16A34A).withOpacity(0.4)
              : (selectedValue == InspectionChoice.fail
                  ? const Color(0xFFDC2626).withOpacity(0.4)
                  : const Color(0xFFE2E8F0)),
          width: selectedValue != null ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _buildButton(
                context,
                choice: InspectionChoice.pass,
                label: 'PASS',
                icon: Icons.check_circle_rounded,
                activeColor: const Color(0xFF16A34A),
                activeBgColor: const Color(0xFFDCFCE7),
              ),
              const SizedBox(width: 8),
              _buildButton(
                context,
                choice: InspectionChoice.fail,
                label: 'FAIL',
                icon: Icons.cancel_rounded,
                activeColor: const Color(0xFFDC2626),
                activeBgColor: const Color(0xFFFEE2E2),
              ),
              const SizedBox(width: 8),
              _buildButton(
                context,
                choice: InspectionChoice.notApplicable,
                label: 'N/A',
                icon: Icons.remove_circle_rounded,
                activeColor: const Color(0xFF64748B),
                activeBgColor: const Color(0xFFF1F5F9),
              ),
            ],
          ),
          if (onAddPhoto != null || photoUrl != null || onNoteChanged != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9), height: 16),
            Row(
              children: [
                if (onAddPhoto != null)
                  InkWell(
                    onTap: onAddPhoto,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.camera_alt_outlined, size: 16, color: Color(0xFFD84315)),
                          SizedBox(width: 4),
                          Text(
                            'Attach Photo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD84315),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (photoUrl != null && photoUrl!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      photoUrl!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required InspectionChoice choice,
    required String label,
    required IconData icon,
    required Color activeColor,
    required Color activeBgColor,
  }) {
    final bool isSelected = selectedValue == choice;

    return Expanded(
      child: Material(
        color: isSelected ? activeBgColor : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => onChanged(isSelected ? null : choice),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? activeColor : const Color(0xFFE2E8F0),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? activeColor : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? activeColor : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
