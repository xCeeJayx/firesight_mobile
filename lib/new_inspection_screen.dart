import 'package:flutter/material.dart';
import 'widgets/commercial_checklist_widget.dart';

class NewInspectionScreen extends StatefulWidget {
  const NewInspectionScreen({super.key});

  @override
  State<NewInspectionScreen> createState() => _NewInspectionScreenState();
}

class _NewInspectionScreenState extends State<NewInspectionScreen> {
  // Theme colors
  final Color bgColor = const Color(0xFFF8F9FA);
  final Color surfaceColor = Colors.white;
  final Color titleColor = const Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Fire Safety Inspection',
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
        children: const [
          SizedBox(height: 12),
          CommercialChecklistWidget(),
        ],
      ),
    );
  }
}
