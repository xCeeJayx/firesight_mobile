import 'package:flutter/material.dart';
import 'widgets/community_urban_checklist_widget.dart';
import 'widgets/house_to_house_checklist_widget.dart';

class FireRiskMappingScreen extends StatefulWidget {
  const FireRiskMappingScreen({super.key});

  @override
  State<FireRiskMappingScreen> createState() => _FireRiskMappingScreenState();
}

class _FireRiskMappingScreenState extends State<FireRiskMappingScreen> {
  int _selectedChecklistIndex = 0; // 0 = Community Risk, 1 = House to House

  @override
  Widget build(BuildContext context) {
    final buttons = [
      {'label': 'Community Risk (Urban)', 'icon': Icons.holiday_village_outlined},
      {'label': 'House to House', 'icon': Icons.home_outlined},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Checklist selector header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: List.generate(buttons.length, (index) {
                  final isSelected = _selectedChecklistIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedChecklistIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFD84315) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              buttons[index]['icon'] as IconData,
                              size: 18,
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              buttons[index]['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Active checklist widget body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                if (_selectedChecklistIndex == 0)
                  const CommunityUrbanChecklistWidget()
                else
                  const HouseToHouseChecklistWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
