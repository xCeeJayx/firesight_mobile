import 'package:flutter/material.dart';
import 'widgets/commercial_checklist_widget.dart';
import 'widgets/community_urban_checklist_widget.dart';
import 'widgets/house_to_house_checklist_widget.dart';

class NewInspectionScreen extends StatefulWidget {
  const NewInspectionScreen({super.key});

  @override
  State<NewInspectionScreen> createState() => _NewInspectionScreenState();
}

class _NewInspectionScreenState extends State<NewInspectionScreen> {
  // Theme colors
  final Color primaryColor = const Color(0xFFF95921);
  final Color bgColor = const Color(0xFFF8F9FA);
  final Color surfaceColor = Colors.white;
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color titleColor = const Color(0xFF1E293B);
  final Color subtitleColor = const Color(0xFF64748B);
  final Color inputBgColor = const Color(0xFFF1F5F9);

  // Selected Checklist Index: 0 = Commercial, 1 = Community Risk (Urban), 2 = House to House
  int _selectedChecklistIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Inspection Checklists',
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: titleColor),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const SizedBox(height: 12),
          _buildChecklistSelectorBar(),
          const SizedBox(height: 12),
          if (_selectedChecklistIndex == 0) ...[
            const CommercialChecklistWidget(),
          ] else if (_selectedChecklistIndex == 1) ...[
            const CommunityUrbanChecklistWidget(),
          ] else ...[
            const HouseToHouseChecklistWidget(),
          ]
        ],
      ),
    );
  }

  Widget _buildChecklistSelectorBar() {
    final buttons = [
      {'label': 'Commercial', 'icon': Icons.business_outlined},
      {'label': 'Community Risk', 'icon': Icons.holiday_village_outlined},
      {'label': 'House to House', 'icon': Icons.home_outlined},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: inputBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: List.generate(buttons.length, (index) {
          final isSelected = _selectedChecklistIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedChecklistIndex = index;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Column(
                  children: [
                    Icon(
                      buttons[index]['icon'] as IconData,
                      size: 20,
                      color: isSelected ? Colors.white : subtitleColor,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      buttons[index]['label'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
