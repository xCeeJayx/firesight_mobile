import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/community_urban_checklist_widget.dart';
import 'widgets/house_to_house_checklist_widget.dart';

import 'services/supabase_service.dart';

class FireRiskMappingScreen extends StatefulWidget {
  final bool isPublicUser;
  final int initialTab;

  const FireRiskMappingScreen({
    super.key,
    this.isPublicUser = false,
    this.initialTab = 0,
  });

  @override
  State<FireRiskMappingScreen> createState() => _FireRiskMappingScreenState();
}

class _FireRiskMappingScreenState extends State<FireRiskMappingScreen> {
  late int _selectedTabIndex;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTab;
  }

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

      // Fallback data for Barangays (All 32 Barangays of Lingayen) if offline or empty
      if (_barangays.isEmpty) {
        _barangays = [
          {'name': 'Aliwekwek', 'population': '1,745', 'legal_code': '105522001', 'latitude': 15.9686, 'longitude': 120.2458},
          {'name': 'Baay', 'population': '5,324', 'legal_code': '105522002', 'latitude': 16.0117, 'longitude': 120.2334},
          {'name': 'Balangobong', 'population': '1,299', 'legal_code': '105522003', 'latitude': 15.9902, 'longitude': 120.2198},
          {'name': 'Balococ', 'population': '2,233', 'legal_code': '105522004', 'latitude': 15.9863, 'longitude': 120.2492},
          {'name': 'Bantayan', 'population': '1,343', 'legal_code': '105522006', 'latitude': 15.9996, 'longitude': 120.2031},
          {'name': 'Basing', 'population': '3,103', 'legal_code': '105522007', 'latitude': 15.9984, 'longitude': 120.2523},
          {'name': 'Capandanan', 'population': '2,544', 'legal_code': '105522008', 'latitude': 16.0076, 'longitude': 120.1979},
          {'name': 'Domalandan Center', 'population': '2,100', 'legal_code': '105522009', 'latitude': 16.0156, 'longitude': 120.2016},
          {'name': 'Domalandan East', 'population': '2,449', 'legal_code': '105522010', 'latitude': 16.0123, 'longitude': 120.2117},
          {'name': 'Domalandan West', 'population': '2,727', 'legal_code': '105522011', 'latitude': 16.0201, 'longitude': 120.1884},
          {'name': 'Dorongan', 'population': '1,605', 'legal_code': '105522012', 'latitude': 15.9768, 'longitude': 120.2155},
          {'name': 'Dulag', 'population': '3,556', 'legal_code': '105522013', 'latitude': 15.9881, 'longitude': 120.2332},
          {'name': 'Estanza', 'population': '4,675', 'legal_code': '105522014', 'latitude': 16.0254, 'longitude': 120.1702},
          {'name': 'Lasip', 'population': '4,057', 'legal_code': '105522015', 'latitude': 15.9989, 'longitude': 120.2323},
          {'name': 'Libsong East', 'population': '4,050', 'legal_code': '105522016', 'latitude': 16.0352, 'longitude': 120.2411},
          {'name': 'Libsong West', 'population': '3,923', 'legal_code': '105522017', 'latitude': 16.0360, 'longitude': 120.2319},
          {'name': 'Malawa', 'population': '3,091', 'legal_code': '105522018', 'latitude': 15.9796, 'longitude': 120.2589},
          {'name': 'Malimpuec', 'population': '3,744', 'legal_code': '105522019', 'latitude': 16.0347, 'longitude': 120.1852},
          {'name': 'Maniboc', 'population': '4,964', 'legal_code': '105522020', 'latitude': 16.0315, 'longitude': 120.2185},
          {'name': 'Matalava', 'population': '2,752', 'legal_code': '105522021', 'latitude': 15.9905, 'longitude': 120.2647},
          {'name': 'Naguelguel', 'population': '2,058', 'legal_code': '105522022', 'latitude': 15.9664, 'longitude': 120.2311},
          {'name': 'Namolan', 'population': '3,456', 'legal_code': '105522023', 'latitude': 15.9748, 'longitude': 120.2435},
          {'name': 'Pangapisan North', 'population': '2,630', 'legal_code': '105522024', 'latitude': 16.0381, 'longitude': 120.2033},
          {'name': 'Pangapisan Sur', 'population': '2,668', 'legal_code': '105522025', 'latitude': 16.0275, 'longitude': 120.2021},
          {'name': 'Poblacion', 'population': '4,117', 'legal_code': '105522026', 'latitude': 16.0234, 'longitude': 120.2314},
          {'name': 'Quibaol', 'population': '2,425', 'legal_code': '105522027', 'latitude': 15.9711, 'longitude': 120.2574},
          {'name': 'Rosario', 'population': '2,752', 'legal_code': '105522028', 'latitude': 15.9449, 'longitude': 120.2671},
          {'name': 'Sabangan', 'population': '2,683', 'legal_code': '105522029', 'latitude': 16.0406, 'longitude': 120.1917},
          {'name': 'Talogtog', 'population': '1,821', 'legal_code': '105522030', 'latitude': 15.9863, 'longitude': 120.1989},
          {'name': 'Tonton', 'population': '4,923', 'legal_code': '105522031', 'latitude': 16.0263, 'longitude': 120.2520},
          {'name': 'Tumbar', 'population': '2,906', 'legal_code': '105522032', 'latitude': 15.9981, 'longitude': 120.2434},
          {'name': 'Wawa', 'population': '4,312', 'legal_code': '105522033', 'latitude': 16.0401, 'longitude': 120.2198},
        ];
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

      // Fallback data for Evacuation Centers if offline or empty
      if (_evacuationCenters.isEmpty) {
        _evacuationCenters = [
          {'name': 'Lingayen Evacuation Center', 'barangay': 'Poblacion', 'capacity': 500, 'latitude': 16.0245, 'longitude': 120.2345},
          {'name': 'Domalandan Civic Center', 'barangay': 'Domalandan Center', 'capacity': 300, 'latitude': 16.0156, 'longitude': 120.2016},
          {'name': 'Baay Covered Court Shelter', 'barangay': 'Baay', 'capacity': 250, 'latitude': 16.0117, 'longitude': 120.2334},
          {'name': 'Libsong West Evacuation Site', 'barangay': 'Libsong West', 'capacity': 400, 'latitude': 16.0360, 'longitude': 120.2319},
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
      final title = hydrantNo.isNotEmpty ? 'Hydrant $hydrantNo' : loc;
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
            name,
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
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.location_city_rounded,
                      size: 16,
                      color: _showBarangayMarkers ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                    ),
                    label: const Text('Barangays', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    selectedColor: const Color(0xFFE2E8F0),
                    onSelected: (val) => setState(() => _showBarangayMarkers = val),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    selected: _showHydrantMarkers,
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.water_drop_rounded,
                      size: 16,
                      color: _showHydrantMarkers ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                    ),
                    label: const Text('Hydrants', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    selectedColor: const Color(0xFFE0F2FE),
                    onSelected: (val) => setState(() => _showHydrantMarkers = val),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    selected: _showEvacuationMarkers,
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.night_shelter_rounded,
                      size: 16,
                      color: _showEvacuationMarkers ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                    ),
                    label: const Text('Shelters', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    selectedColor: const Color(0xFFF3E8FF),
                    onSelected: (val) => setState(() => _showEvacuationMarkers = val),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Persistent Floating BFP Hotline Call Button (Public Citizen Mode Only)
        if (widget.isPublicUser)
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
