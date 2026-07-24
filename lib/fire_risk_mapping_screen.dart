import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/community_urban_checklist_widget.dart';
import 'widgets/house_to_house_checklist_widget.dart';

class FireRiskMappingScreen extends StatefulWidget {
  const FireRiskMappingScreen({super.key});

  @override
  State<FireRiskMappingScreen> createState() => _FireRiskMappingScreenState();
}

class _FireRiskMappingScreenState extends State<FireRiskMappingScreen> {
  int _selectedTabIndex = 0; // 0 = Interactive Map, 1 = Urban Risk, 2 = House Check

  @override
  Widget build(BuildContext context) {
    final buttons = [
      {'label': 'GIS Risk Map', 'icon': Icons.map_rounded},
      {'label': 'Urban Risk', 'icon': Icons.holiday_village_outlined},
      {'label': 'House Check', 'icon': Icons.home_outlined},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Selector header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: List.generate(buttons.length, (index) {
                  final isSelected = _selectedTabIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFD84315) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              buttons[index]['icon'] as IconData,
                              size: 16,
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              buttons[index]['label'] as String,
                              style: TextStyle(
                                fontSize: 11,
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

          // Active view body
          Expanded(
            child: _selectedTabIndex == 0
                ? const InteractiveRiskMapWidget()
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      if (_selectedTabIndex == 1)
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

class InteractiveRiskMapWidget extends StatefulWidget {
  const InteractiveRiskMapWidget({super.key});

  @override
  State<InteractiveRiskMapWidget> createState() => _InteractiveRiskMapWidgetState();
}

class _InteractiveRiskMapWidgetState extends State<InteractiveRiskMapWidget> {
  bool _isLoading = true;
  bool _showSitioMarkers = true;
  bool _showHydrantMarkers = true;
  bool _showEvacuationMarkers = true;

  List<Map<String, dynamic>> _sitioSurveys = [];
  List<Map<String, dynamic>> _hydrants = [];
  List<Map<String, dynamic>> _evacuationCenters = [];

  // Default map center: Lingayen, Pangasinan
  static const LatLng _lingayenCenter = LatLng(16.0242, 120.2300);

  @override
  void initState() {
    super.initState();
    _fetchGisData();
  }

  Future<void> _fetchGisData() async {
    try {
      final client = Supabase.instance.client;

      // 1. Fetch fire risk surveys
      try {
        final surveyRes = await client.from('fire_risk_surveys').select();
        _sitioSurveys = List<Map<String, dynamic>>.from(surveyRes);
      } catch (e) {
        debugPrint('fire_risk_surveys fetch error: $e');
      }

      // 2. Fetch hydrants
      try {
        final hydrantRes = await client.from('hydrants').select();
        _hydrants = List<Map<String, dynamic>>.from(hydrantRes);
      } catch (e) {
        debugPrint('hydrants fetch error: $e');
      }

      // 3. Fetch evacuation centers
      try {
        final evacRes = await client.from('evacuation_centers').select();
        _evacuationCenters = List<Map<String, dynamic>>.from(evacRes);
      } catch (e) {
        debugPrint('evacuation_centers fetch error: $e');
      }

      // If empty in Supabase, add fallback Lingayen data points for demonstration
      if (_sitioSurveys.isEmpty) {
        _sitioSurveys = [
          {'purok_name': 'Purok 1, Poblacion', 'latitude': 16.0245, 'longitude': 120.2310, 'rating': 3, 'score': 14},
          {'purok_name': 'Sitio Libtone, Baay', 'latitude': 16.0290, 'longitude': 120.2250, 'rating': 4, 'score': 32},
          {'purok_name': 'Purok 4, Maniboc (Riverbank)', 'latitude': 16.0180, 'longitude': 120.2360, 'rating': 5, 'score': 48},
        ];
      }

      if (_hydrants.isEmpty) {
        _hydrants = [
          {'location': 'Town Plaza Primewater Outlet', 'barangay': 'Poblacion', 'status': 'Operational', 'latitude': 16.0240, 'longitude': 120.2315},
          {'location': 'Maniboc Elementary Hydrant', 'barangay': 'Maniboc', 'status': 'Operational', 'latitude': 16.0195, 'longitude': 120.2340},
          {'location': 'Baay Crossing Hydrant', 'barangay': 'Baay', 'status': 'Defective', 'latitude': 16.0280, 'longitude': 120.2230},
        ];
      }

      if (_evacuationCenters.isEmpty) {
        _evacuationCenters = [
          {'name': 'Lingayen Civic Center', 'barangay': 'Poblacion', 'capacity': 500, 'latitude': 16.0255, 'longitude': 120.2305},
          {'name': 'Pangasinan National High Gym', 'barangay': 'Artacho', 'capacity': 800, 'latitude': 16.0210, 'longitude': 120.2280},
        ];
      }
    } catch (e) {
      debugPrint('GIS fetch overall error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDetailsDialog(String title, String subtitle, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: Text(subtitle, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildSitioMarkers() {
    return _sitioSurveys.map((item) {
      final lat = (item['latitude'] as num?)?.toDouble() ?? 16.0242;
      final lng = (item['longitude'] as num?)?.toDouble() ?? 120.2300;
      final name = item['purok_name']?.toString() ?? 'Sitio Fire Risk';
      final score = item['score'] ?? item['total_score'] ?? 0;
      final rating = item['rating'] ?? item['vulnerability_rating'] ?? 3;

      Color color = const Color(0xFF2ECC71); // Green - Rating 3
      String statusLabel = 'Rating 3: Mildly Vulnerable';
      if (rating >= 5 || score >= 40) {
        color = const Color(0xFFE74C3C); // Red - Rating 5
        statusLabel = 'Rating 5: Highly Vulnerable';
      } else if (rating >= 4 || score >= 20) {
        color = const Color(0xFFF1C40F); // Yellow - Rating 4
        statusLabel = 'Rating 4: Moderately Vulnerable';
      }

      return Marker(
        point: LatLng(lat, lng),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _showDetailsDialog(name, 'Vulnerability: $statusLabel\nTotal YES Score: $score', Icons.warning_amber_rounded, color),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildHydrantMarkers() {
    return _hydrants.map((item) {
      final lat = (item['latitude'] as num?)?.toDouble() ?? 16.0242;
      final lng = (item['longitude'] as num?)?.toDouble() ?? 120.2300;
      final loc = item['location']?.toString() ?? 'Primewater Hydrant';
      final barangay = item['barangay']?.toString() ?? '';
      final status = item['status']?.toString() ?? 'Operational';
      final isOperational = status.toLowerCase() == 'operational';

      final color = isOperational ? const Color(0xFF0284C7) : const Color(0xFFDC2626);

      return Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showDetailsDialog('💧 $loc', 'Barangay: $barangay\nStatus: $status', Icons.water_drop_rounded, color),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 20),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildEvacuationMarkers() {
    return _evacuationCenters.map((item) {
      final lat = (item['latitude'] as num?)?.toDouble() ?? 16.0242;
      final lng = (item['longitude'] as num?)?.toDouble() ?? 120.2300;
      final name = item['name']?.toString() ?? 'Evacuation Center';
      final barangay = item['barangay']?.toString() ?? '';
      final cap = item['capacity']?.toString() ?? 'N/A';

      const color = Color(0xFF7C3AED);

      return Marker(
        point: LatLng(lat, lng),
        width: 42,
        height: 42,
        child: GestureDetector(
          onTap: () => _showDetailsDialog('🏫 $name', 'Barangay: $barangay\nDesignated Capacity: $cap Persons', Icons.night_shelter_rounded, color),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.night_shelter_rounded, color: Colors.white, size: 22),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD84315)));
    }

    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(
            initialCenter: _lingayenCenter,
            initialZoom: 14.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bfp.firesight_mobile',
            ),
            if (_showSitioMarkers) MarkerLayer(markers: _buildSitioMarkers()),
            if (_showHydrantMarkers) MarkerLayer(markers: _buildHydrantMarkers()),
            if (_showEvacuationMarkers) MarkerLayer(markers: _buildEvacuationMarkers()),
          ],
        ),

        // Layer Filter Toggle Chips Bar
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    selected: _showSitioMarkers,
                    label: const Text('🔴/🟡/🟢 Sitios', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    selectedColor: const Color(0xFFFEE2E2),
                    checkmarkColor: const Color(0xFFDC2626),
                    onSelected: (val) => setState(() => _showSitioMarkers = val),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    selected: _showHydrantMarkers,
                    label: const Text('💧 Hydrants', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    selectedColor: const Color(0xFFE0F2FE),
                    checkmarkColor: const Color(0xFF0284C7),
                    onSelected: (val) => setState(() => _showHydrantMarkers = val),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    selected: _showEvacuationMarkers,
                    label: const Text('🏫 Shelters', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    selectedColor: const Color(0xFFF3E8FF),
                    checkmarkColor: const Color(0xFF7C3AED),
                    onSelected: (val) => setState(() => _showEvacuationMarkers = val),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
