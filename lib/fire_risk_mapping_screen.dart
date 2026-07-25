import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/community_urban_checklist_widget.dart';
import 'widgets/house_to_house_checklist_widget.dart';

import 'services/supabase_service.dart';

class FireRiskMappingScreen extends StatefulWidget {
  final bool isPublicUser;

  const FireRiskMappingScreen({
    super.key,
    this.isPublicUser = false,
  });

  @override
  State<FireRiskMappingScreen> createState() => _FireRiskMappingScreenState();
}

class _FireRiskMappingScreenState extends State<FireRiskMappingScreen> {
  int _selectedTabIndex = 0; // 0 = Interactive Map, 1 = Urban Risk, 2 = House Check

  @override
  Widget build(BuildContext context) {
    if (widget.isPublicUser) {
      return const InteractiveRiskMapWidget(isPublicUser: true);
    }

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
                ? const InteractiveRiskMapWidget(isPublicUser: false)
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
  final bool isPublicUser;

  const InteractiveRiskMapWidget({
    super.key,
    this.isPublicUser = false,
  });

  @override
  State<InteractiveRiskMapWidget> createState() => _InteractiveRiskMapWidgetState();
}

class _InteractiveRiskMapWidgetState extends State<InteractiveRiskMapWidget> {
  bool _isLoading = true;
  bool _showBarangayMarkers = true;
  bool _showHydrantMarkers = true;
  bool _showEvacuationMarkers = true;

  List<Map<String, dynamic>> _barangays = [];
  List<Map<String, dynamic>> _hydrants = [];
  List<Map<String, dynamic>> _evacuationCenters = [];

  // Configured Viewport for full Municipality of Lingayen, Pangasinan
  static const LatLng _lingayenCenter = LatLng(15.9950, 120.2250);
  static const double _initialZoomLevel = 12.8;

  @override
  void initState() {
    super.initState();
    _fetchGisData();
  }

  Future<void> _fetchGisData() async {
    try {
      final client = Supabase.instance.client;

      // 1. Query barangays (All 32 Barangays)
      try {
        final barangayRes = await client.from('barangays').select();
        _barangays = List<Map<String, dynamic>>.from(barangayRes);
      } catch (e) {
        debugPrint('barangays fetch error: $e');
      }

      // 2. Query hydrants
      try {
        final hydrantRes = await client.from('hydrants').select('id, hydrant_no, location, barangay, latitude, longitude, status, color, remarks');
        _hydrants = List<Map<String, dynamic>>.from(hydrantRes);
      } catch (e) {
        debugPrint('hydrants fetch error: $e');
      }

      // 3. Query evacuation_centers (STRICTLY live Supabase data, no mock fallbacks)
      try {
        final evacRes = await client.from('evacuation_centers').select();
        _evacuationCenters = List<Map<String, dynamic>>.from(evacRes);
      } catch (e) {
        debugPrint('evacuation_centers fetch error: $e');
        _evacuationCenters = [];
      }

      // Fallback data for Hydrants if offline or empty
      if (_hydrants.isEmpty) {
        _hydrants = [
          {'hydrant_no': '#117', 'location': 'Tonton West (Pump Station No. 3)', 'barangay': 'Tonton West', 'latitude': 16.0267751, 'longitude': 120.2498305, 'status': 'Operational', 'remarks': 'Coupling Compatible'},
          {'hydrant_no': '#44', 'location': 'Avenida Rizal St. East (Infront of Petron)', 'barangay': 'Poblacion', 'latitude': 16.0232040, 'longitude': 120.2384332, 'status': 'Operational', 'remarks': 'Coupling Compatible'},
          {'hydrant_no': '#20', 'location': 'Artacho St. (Corner Ramos St. West)', 'barangay': 'Poblacion', 'latitude': 16.0233771, 'longitude': 120.2344507, 'status': 'Operational', 'remarks': 'Coupling Compatible'},
          {'hydrant_no': '#91', 'location': 'Alvear St. West (Corner Artacho St.)', 'barangay': 'Poblacion', 'latitude': 16.0255989, 'longitude': 120.2285535, 'status': 'Operational', 'remarks': 'Coupling Compatible'},
          {'hydrant_no': '#14', 'location': 'Sto. Niño St. West & Iron Works', 'barangay': 'Baay', 'latitude': 16.0103560, 'longitude': 120.2284970, 'status': 'Operational', 'remarks': 'Coupling Compatible'},
          {'hydrant_no': '#48', 'location': 'Solis St. Poblacion (Below footbridge)', 'barangay': 'Poblacion', 'latitude': 16.0202090, 'longitude': 120.2313050, 'status': 'Operational', 'remarks': 'Coupling Compatible'},
          {'hydrant_no': '#111', 'location': '#23 Maramba Blvd. (Sto. Cruz St.)', 'barangay': 'Poblacion', 'latitude': 16.0284010, 'longitude': 120.2335210, 'status': 'Operational', 'remarks': 'Coupling Compatible'},
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD84315))),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildBarangayMarkers() {
    return _barangays.map((item) {
      final lat = (item['latitude'] as num?)?.toDouble() ?? 15.9950;
      final lng = (item['longitude'] as num?)?.toDouble() ?? 120.2250;
      final rawName = item['name']?.toString() ?? 'Barangay';
      final displayName = rawName.toLowerCase().startsWith('brgy') ? rawName : 'Brgy. $rawName';
      final pop = item['population'] != null ? '${item['population']} residents' : 'N/A';
      final legalCode = item['legal_code'] ?? item['code'] ?? item['psgc_code'] ?? 'N/A';

      const color = Color(0xFF1E293B);

      return Marker(
        point: LatLng(lat, lng),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _showDetailsDialog(
            displayName,
            'Population (2024): $pop\nLegal Code: $legalCode\nCoordinates: $lat, $lng',
            Icons.location_city_rounded,
            color,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.location_city_rounded, color: Colors.white, size: 22),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildHydrantMarkers() {
    return _hydrants.map((item) {
      final lat = (item['latitude'] as num?)?.toDouble() ?? 15.9950;
      final lng = (item['longitude'] as num?)?.toDouble() ?? 120.2250;
      final hydrantNo = item['hydrant_no']?.toString() ?? '';
      final loc = item['location']?.toString() ?? 'Primewater Hydrant';
      final barangay = item['barangay']?.toString() ?? 'Lingayen';
      final status = item['status']?.toString() ?? 'Operational';
      final remarks = item['remarks']?.toString() ?? 'Coupling Compatible';
      final isOperational = status.toLowerCase() == 'operational';

      final color = isOperational ? const Color(0xFF0284C7) : const Color(0xFFDC2626);
      final title = hydrantNo.isNotEmpty ? '💧 Hydrant $hydrantNo' : '💧 $loc';
      final details = 'Location: $loc\nBarangay: $barangay\nStatus: $status\nRemarks: $remarks';

      return Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showDetailsDialog(title, details, Icons.water_drop_rounded, color),
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
      final lat = (item['latitude'] as num?)?.toDouble() ?? 15.9950;
      final lng = (item['longitude'] as num?)?.toDouble() ?? 120.2250;
      final name = item['name']?.toString() ?? 'Evacuation Center';
      final barangay = item['barangay']?.toString() ?? '';
      final cap = item['capacity']?.toString() ?? 'N/A';

      const color = Color(0xFF7C3AED);

      return Marker(
        point: LatLng(lat, lng),
        width: 42,
        height: 42,
        child: GestureDetector(
          onTap: () => _showDetailsDialog(
            '🏫 $name',
            'Barangay: $barangay\nDesignated Capacity: $cap Persons',
            Icons.night_shelter_rounded,
            color,
          ),
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
            initialZoom: _initialZoomLevel,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bfp.firesight_mobile',
            ),
            if (_showBarangayMarkers) MarkerLayer(markers: _buildBarangayMarkers()),
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
                    selected: _showBarangayMarkers,
                    label: const Text('🏛️ Barangays', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    selectedColor: const Color(0xFFE2E8F0),
                    checkmarkColor: const Color(0xFF1E293B),
                    onSelected: (val) => setState(() => _showBarangayMarkers = val),
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

        // Persistent Floating BFP Hotline Call Button
        Positioned(
          bottom: 20,
          right: 16,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(30),
            color: const Color(0xFFDC2626),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => SupabaseService.callBfpHotline(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Call BFP Lingayen Hotline',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
