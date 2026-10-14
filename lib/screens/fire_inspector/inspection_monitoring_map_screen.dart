import 'package:flutter/material.dart';
import '../../fire_risk_mapping_screen.dart';

/// Unified Map screen for Fire Inspectors.
/// Merges GIS Fire Risk, Hydrants, Shelters, Commercial Establishments,
/// Live On-Site Fire Inspectors, and Active Emergency Incidents
/// into a single seamless map interface without inner tabs.
class InspectionMonitoringMapScreen extends StatelessWidget {
  const InspectionMonitoringMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InteractiveRiskMapWidget(isPublicUser: false);
  }
}
