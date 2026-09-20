import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/emergency_report_model.dart';
import 'services/emergency_service.dart';
import 'services/gis_data_service.dart';
import 'services/supabase_service.dart';
import 'widgets/community_urban_checklist_widget.dart';
import 'widgets/emergency/emergency_details_bottom_sheet.dart';
import 'widgets/emergency/pulsing_emergency_marker.dart';
import 'widgets/house_to_house_checklist_widget.dart';

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
  final MapController _mapController = MapController();
  bool _isLoading = true;

  // Layer Visibility Toggles
  bool _showBarangayPolygons = true;
  bool _showEstablishmentMarkers = false;
  bool _showEmergencyMarkers = true;
  bool _showHydrantMarkers = false;
  bool _showEvacuationMarkers = false;

  // Emergency Filter
  String _selectedStatusFilter = 'All';

  // Data Collections
  List<BarangayRiskPolygon> _barangayPolygons = [];
  List<CommercialEstablishmentPin> _establishmentPins = [];
  List<Map<String, dynamic>> _hydrants = [];
  List<Map<String, dynamic>> _evacuationCenters = [];

  // GPS User Location
  LatLng? _currentUserLocation;

  @override
  void initState() {
    super.initState();
    _loadGisData();
    // Pre-fetch latest reports from EmergencyService
    EmergencyService().fetchReports();
  }

  Future<void> _loadGisData() async {
    try {
      final gisService = GisDataService();
      final polygons = await gisService.fetchBarangayRiskPolygons();
      final establishments = widget.isPublicUser
          ? <CommercialEstablishmentPin>[]
          : await gisService.fetchEstablishments();

      final client = Supabase.instance.client;
      List<Map<String, dynamic>> hydrants = [];
      List<Map<String, dynamic>> evacs = [];

      try {
        final hRes = await client.from('hydrants').select();
        hydrants = List<Map<String, dynamic>>.from(hRes);
      } catch (e) {
        debugPrint('Hydrants fetch note: $e');
      }

      try {
        final eRes = await client.from('evacuation_centers').select();
        evacs = List<Map<String, dynamic>>.from(eRes);
      } catch (e) {
        debugPrint('Evacuation centers fetch note: $e');
      }

      if (mounted) {
        setState(() {
          _barangayPolygons = polygons;
          _establishmentPins = establishments;
          _hydrants = hydrants;
          _evacuationCenters = evacs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading GIS data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _centerMap(double lat, double lng, {double zoom = 15.5}) {
    _mapController.move(LatLng(lat, lng), zoom);
  }

  void _resetToLingayenView() {
    _mapController.move(GisDataService.lingayenCenter, GisDataService.defaultZoom);
  }

  Future<void> _locateUser() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        final userLatLng = LatLng(pos.latitude, pos.longitude);
        setState(() => _currentUserLocation = userLatLng);
        _centerMap(pos.latitude, pos.longitude, zoom: 15.0);
      }
    } catch (e) {
      debugPrint('Locate user error: $e');
    }
  }

  // --- Map Layer Builders ---

  List<Polygon> _buildBarangayPolygons() {
    return _barangayPolygons.map<Polygon>((bgy) {
      return Polygon(
        points: bgy.polygonPoints,
        color: bgy.riskFillColor,
        borderColor: bgy.riskBorderColor,
        borderStrokeWidth: 1.8,
      );
    }).toList();
  }

  List<Marker> _buildBarangayCentroidMarkers() {
    return _barangayPolygons.map((bgy) {
      return Marker(
        point: bgy.centroid,
        width: 100,
        height: 34,
        child: GestureDetector(
          onTap: () => _showBarangayDetailsSheet(bgy),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: bgy.riskColor, width: 1.3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bgy.riskColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        bgy.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildEstablishmentMarkers() {
    return _establishmentPins.map((est) {
      return Marker(
        point: est.position,
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () => _showEstablishmentDetailsSheet(est),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              shape: BoxShape.circle,
              border: Border.all(color: est.statusColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildEmergencyMarkers(List<EmergencyReportModel> reports) {
    // 1. Filter reports with valid coordinates
    var filtered = reports.where((r) => r.latitude != null && r.longitude != null).toList();

    // 2. Role-based visibility controls:
    // If public user, show ONLY verified emergencies (Verified, Responding, Dispatched)
    if (widget.isPublicUser) {
      filtered = filtered.where((r) => r.isVerified).toList();
    }

    // 3. Status filter selection
    if (_selectedStatusFilter != 'All') {
      filtered = filtered.where((r) {
        return r.status.toLowerCase() == _selectedStatusFilter.toLowerCase();
      }).toList();
    }

    return filtered.map((report) {
      return Marker(
        point: LatLng(report.latitude!, report.longitude!),
        width: 54,
        height: 54,
        child: PulsingEmergencyMarker(
          report: report,
          onTap: () => EmergencyDetailsBottomSheet.show(
            context,
            report,
            isPublicUser: widget.isPublicUser,
            onCenterMap: () => _centerMap(report.latitude!, report.longitude!),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildHydrantMarkers() {
    return _hydrants.map((item) {
      final lat = (item['latitude'] as num?)?.toDouble() ?? 16.0267;
      final lng = (item['longitude'] as num?)?.toDouble() ?? 120.2298;
      final status = (item['status'] ?? 'Operational').toString();
      final isOperational = status.toLowerCase() == 'operational';
      final color = isOperational ? const Color(0xFF0284C7) : const Color(0xFFDC2626);

      return Marker(
        point: LatLng(lat, lng),
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () => _showHydrantDetailsSheet(item),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 16),
          ),
        ),
      );
    }).toList();
  }

  void _showHydrantDetailsSheet(Map<String, dynamic> item) {
    final hydrantNo = item['hydrant_no']?.toString() ?? '#N/A';
    final location = item['location']?.toString() ?? 'Lingayen, Pangasinan';
    final barangay = item['barangay']?.toString() ?? 'Poblacion';
    final status = item['status']?.toString() ?? 'Operational';
    final colorName = item['color']?.toString() ?? 'Yellow';
    final remarks = item['remarks']?.toString() ?? 'Coupling Compatible';
    final lat = (item['latitude'] as num?)?.toDouble() ?? 16.0267;
    final lng = (item['longitude'] as num?)?.toDouble() ?? 120.2298;

    final isOperational = status.toLowerCase() == 'operational';
    final statusColor = isOperational ? const Color(0xFF0284C7) : const Color(0xFFDC2626);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.water_drop_rounded, color: statusColor, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hydrant $hydrantNo',
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Brgy. $barangay',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'FIRE HYDRANT SPECIFICATIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Physical Location', location, Icons.pin_drop_outlined),
              _buildDetailRow('Color Marking', colorName, Icons.color_lens_outlined),
              _buildDetailRow('Technical Remarks', remarks, Icons.build_circle_outlined),
              _buildDetailRow('GPS Coordinates', '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}', Icons.my_location_outlined),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _centerMap(lat, lng, zoom: 17.0);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                  label: const Text('Center on Hydrant', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Marker> _buildEvacuationMarkers() {
    return _evacuationCenters.map((item) {
      final lat = (item['latitude'] as num?)?.toDouble() ?? 16.0267;
      final lng = (item['longitude'] as num?)?.toDouble() ?? 120.2298;
      final centerName = item['center_name']?.toString() ?? item['name']?.toString() ?? 'Evacuation Center';
      final barangay = item['barangay']?.toString() ?? '';
      const color = Color(0xFF7C3AED);

      return Marker(
        point: LatLng(lat, lng),
        width: 46,
        height: 46,
        child: GestureDetector(
          onTap: () => _showEvacuationCenterDetailsSheet(item),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.night_shelter_rounded, color: Colors.white, size: 14),
              ),
              if (barangay.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C1D95),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 0.5),
                  ),
                  child: Text(
                    barangay,
                    style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _showEvacuationCenterDetailsSheet(Map<String, dynamic> item) {
    final centerName = item['center_name']?.toString() ?? item['name']?.toString() ?? 'Evacuation Center';
    final barangay = item['barangay']?.toString() ?? 'Lingayen';
    final address = item['address']?.toString() ?? 'Lingayen, Pangasinan';
    final capacity = (item['capacity'] as num?)?.toInt() ?? 0;
    final lat = (item['latitude'] as num?)?.toDouble() ?? 16.0267;
    final lng = (item['longitude'] as num?)?.toDouble() ?? 120.2298;
    const color = Color(0xFF7C3AED);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.night_shelter_rounded, color: color, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          centerName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Brgy. $barangay',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color),
                    ),
                    child: Text(
                      capacity > 0 ? '$capacity CAP' : 'ACTIVE SHELTER',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'EVACUATION FACILITY DETAILS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Physical Address', address, Icons.pin_drop_outlined),
              _buildDetailRow('Designated Barangay', 'Brgy. $barangay', Icons.holiday_village_outlined),
              _buildDetailRow(
                'Shelter Capacity',
                capacity > 0 ? '$capacity Persons / Family Evacuees' : 'Standard Community Capacity',
                Icons.people_outline_rounded,
              ),
              _buildDetailRow('GPS Coordinates', '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}', Icons.my_location_outlined),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _centerMap(lat, lng, zoom: 17.0);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                  label: const Text('Center on Evacuation Center', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Marker _buildUserLocationMarker() {
    return Marker(
      point: _currentUserLocation!,
      width: 24,
      height: 24,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 3,
            ),
          ],
        ),
      ),
    );
  }

  // --- Detail Sheets & Dialogs ---

  void _showBarangayDetailsSheet(BarangayRiskPolygon bgy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: bgy.riskColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.holiday_village_rounded, color: bgy.riskColor, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Brgy. ${bgy.name}',
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PSGC Code: ${bgy.legalCode}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bgy.riskColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: bgy.riskColor),
                    ),
                    child: Text(
                      bgy.riskBadgeLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: bgy.riskColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // CFPP Status Pill & Score Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: bgy.cfppStatusColor),
                        const SizedBox(width: 6),
                        Text(
                          'CFPP Plan: ${bgy.cfppStatus}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: bgy.cfppStatusColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      bgy.calculatedScore > 0
                          ? 'Score: ${bgy.calculatedScore.toStringAsFixed(1)} / 100.0'
                          : 'Score: Unassessed',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'COMMUNITY FIRE RISK PROFILE (CFPP)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Demographics & Housing',
                bgy.totalHouseholds > 0
                    ? '${bgy.population} residents • ${bgy.totalHouseholds} households'
                    : '${bgy.population} residents (Census)',
                Icons.people_outline_rounded,
              ),
              _buildDetailRow(
                'Predominant Hazard',
                bgy.predominantHazard,
                Icons.warning_amber_rounded,
              ),
              _buildDetailRow(
                'Water & Hydrants',
                bgy.hydrantsCount > 0
                    ? '${bgy.waterSupplyStatus} (${bgy.hydrantsCount} Hydrant${bgy.hydrantsCount == 1 ? '' : 's'})'
                    : '${bgy.waterSupplyStatus} (No Hydrants Recorded)',
                Icons.water_drop_outlined,
              ),
              _buildDetailRow(
                'Fire Truck Accessibility',
                bgy.roadAccessibility,
                Icons.alt_route_rounded,
              ),
              _buildDetailRow(
                'Designated Evacuation Shelter',
                bgy.evacuationCenter,
                Icons.night_shelter_outlined,
              ),
              _buildDetailRow(
                'Last Assessment Date',
                bgy.lastAssessed,
                Icons.event_available_outlined,
              ),

              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              // HOUSE-TO-HOUSE (H2H) SAFETY SECTION
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'HOUSE-TO-HOUSE (H2H) SAFETY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  if (bgy.totalH2HInspected > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${bgy.totalH2HInspected} Inspected',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (bgy.totalH2HInspected == 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No household safety checks conducted yet in this barangay.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.analytics_outlined, size: 16, color: Color(0xFF0F172A)),
                          const SizedBox(width: 6),
                          Text(
                            bgy.totalHouseholds > 0
                                ? 'Coverage: ${bgy.totalH2HInspected} of ${bgy.totalHouseholds} Households'
                                : '${bgy.totalH2HInspected} Household Checks Recorded',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      if (bgy.h2hSummaryInterpretation != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text(
                              'Overall Status: ',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            Text(
                              bgy.h2hSummaryInterpretation!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: bgy.h2hHighRiskCount > bgy.h2hSafeCount
                                    ? const Color(0xFFDC2626)
                                    : (bgy.h2hModerateCount > bgy.h2hSafeCount
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF16A34A)),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildH2HPill(
                              label: 'Ligtas',
                              count: bgy.h2hSafeCount,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildH2HPill(
                              label: 'May Pangamba',
                              count: bgy.h2hModerateCount,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildH2HPill(
                              label: 'Mapanganib',
                              count: bgy.h2hHighRiskCount,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _centerMap(bgy.centroid.latitude, bgy.centroid.longitude, zoom: 15.0);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                  label: const Text('Center on Barangay', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEstablishmentDetailsSheet(CommercialEstablishmentPin est) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Color(0xFF0F172A), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        est.businessName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${est.barangay}, Lingayen',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            _buildDetailRow('Nature of Business', est.occupancyType, Icons.category_outlined),
            _buildDetailRow('Compliance Status', est.complianceStatus, Icons.verified_outlined, valueColor: est.statusColor),
            _buildDetailRow('Inspection Order Ref', est.inspectionOrderNo, Icons.assignment_outlined),
            _buildDetailRow('Risk Classification', '${est.riskLevel} Hazard Zone', Icons.shield_outlined),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _centerMap(est.position.latitude, est.position.longitude, zoom: 16.5);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                label: const Text('Center on Establishment', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: valueColor ?? const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildH2HPill({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showGenericDialog({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD84315)));
    }

    return Stack(
      children: [
        // --- 1. Map Canvas Layer Stack (In strict rendering z-order) ---
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: GisDataService.lingayenCenter,
            initialZoom: GisDataService.defaultZoom,
            minZoom: 10.0,
            maxZoom: 18.5,
          ),
          children: [
            // Layer 1: Base OpenStreetMap Tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bfp.firesight_mobile',
            ),

            // Layer 2: Barangay Risk Boundary Polygons
            if (_showBarangayPolygons)
              PolygonLayer(
                polygons: _buildBarangayPolygons(),
              ),
            if (_showBarangayPolygons)
              MarkerLayer(
                markers: _buildBarangayCentroidMarkers(),
              ),

            // Layer 3: Commercial Establishment Pins (Officers / Inspectors Only)
            if (_showEstablishmentMarkers && !widget.isPublicUser)
              MarkerLayer(
                markers: _buildEstablishmentMarkers(),
              ),

            // Auxiliary GIS Markers (Hydrants & Shelters)
            if (_showHydrantMarkers)
              MarkerLayer(
                markers: _buildHydrantMarkers(),
              ),
            if (_showEvacuationMarkers)
              MarkerLayer(
                markers: _buildEvacuationMarkers(),
              ),

            // Current User GPS Marker (if located)
            if (_currentUserLocation != null)
              MarkerLayer(
                markers: [_buildUserLocationMarker()],
              ),

            // Layer 4: Live Real-Time Emergency Report Incident Markers
            if (_showEmergencyMarkers)
              ValueListenableBuilder<List<EmergencyReportModel>>(
                valueListenable: EmergencyService().reportsNotifier,
                builder: (context, reports, _) {
                  return MarkerLayer(
                    markers: _buildEmergencyMarkers(reports),
                  );
                },
              ),
          ],
        ),

        // --- 2. Floating Layer Control Overlay & Status Filter Header ---
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Glassmorphic Control Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Status Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Live Radar Status Pill
                        ValueListenableBuilder<List<EmergencyReportModel>>(
                          valueListenable: EmergencyService().reportsNotifier,
                          builder: (context, reports, _) {
                            final activeCount = reports.where((r) {
                              if (widget.isPublicUser) {
                                return r.isVerified;
                              }
                              final s = r.status.toLowerCase();
                              return s != 'resolved' && s != 'false alarm';
                            }).length;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'LIVE RADAR • $activeCount ACTIVE',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFDC2626),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Subtitle
                        Text(
                          widget.isPublicUser ? 'Public Safety Map' : 'BFP GIS Command',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Layer Toggle Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            selected: _showEmergencyMarkers,
                            showCheckmark: false,
                            avatar: Icon(
                              Icons.local_fire_department_rounded,
                              size: 15,
                              color: _showEmergencyMarkers ? Colors.white : const Color(0xFFDC2626),
                            ),
                            label: const Text('Emergencies', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            selectedColor: const Color(0xFFDC2626),
                            labelStyle: TextStyle(
                              color: _showEmergencyMarkers ? Colors.white : const Color(0xFF0F172A),
                            ),
                            onSelected: (val) => setState(() => _showEmergencyMarkers = val),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            selected: _showBarangayPolygons,
                            showCheckmark: false,
                            avatar: Icon(
                              Icons.holiday_village_outlined,
                              size: 15,
                              color: _showBarangayPolygons ? Colors.white : const Color(0xFF0F172A),
                            ),
                            label: const Text('Barangay Risk', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            selectedColor: const Color(0xFF0F172A),
                            labelStyle: TextStyle(
                              color: _showBarangayPolygons ? Colors.white : const Color(0xFF0F172A),
                            ),
                            onSelected: (val) => setState(() => _showBarangayPolygons = val),
                          ),
                          if (!widget.isPublicUser) ...[
                            const SizedBox(width: 6),
                            FilterChip(
                              selected: _showEstablishmentMarkers,
                              showCheckmark: false,
                              avatar: Icon(
                                Icons.storefront_rounded,
                                size: 15,
                                color: _showEstablishmentMarkers ? Colors.white : const Color(0xFF2563EB),
                              ),
                              label: const Text('Establishments', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                              selectedColor: const Color(0xFF2563EB),
                              labelStyle: TextStyle(
                                color: _showEstablishmentMarkers ? Colors.white : const Color(0xFF0F172A),
                              ),
                              onSelected: (val) => setState(() => _showEstablishmentMarkers = val),
                            ),
                          ],
                          const SizedBox(width: 6),
                          FilterChip(
                            selected: _showHydrantMarkers,
                            showCheckmark: false,
                            avatar: Icon(
                              Icons.water_drop_rounded,
                              size: 15,
                              color: _showHydrantMarkers ? Colors.white : const Color(0xFF0284C7),
                            ),
                            label: const Text('Hydrants', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            selectedColor: const Color(0xFF0284C7),
                            labelStyle: TextStyle(
                              color: _showHydrantMarkers ? Colors.white : const Color(0xFF0F172A),
                            ),
                            onSelected: (val) => setState(() => _showHydrantMarkers = val),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            selected: _showEvacuationMarkers,
                            showCheckmark: false,
                            avatar: Icon(
                              Icons.night_shelter_rounded,
                              size: 15,
                              color: _showEvacuationMarkers ? Colors.white : const Color(0xFF7C3AED),
                            ),
                            label: const Text('Shelters', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            selectedColor: const Color(0xFF7C3AED),
                            labelStyle: TextStyle(
                              color: _showEvacuationMarkers ? Colors.white : const Color(0xFF0F172A),
                            ),
                            onSelected: (val) => setState(() => _showEvacuationMarkers = val),
                          ),
                        ],
                      ),
                    ),

                    // Sub-filter for Emergency Statuses (when emergency layer active)
                    if (_showEmergencyMarkers && !widget.isPublicUser) ...[
                      const SizedBox(height: 6),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text('Filter: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            ...['All', 'Unverified', 'Verified', 'Responding', 'Resolved'].map((st) {
                              final isSel = _selectedStatusFilter == st;
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: InkWell(
                                  onTap: () => setState(() => _selectedStatusFilter = st),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSel ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isSel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      st,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                        color: isSel ? Colors.white : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- 3. Floating Map Navigation & Zoom Controls (Right Side) ---
        Positioned(
          bottom: widget.isPublicUser ? 80 : 24,
          right: 14,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom In
              _buildFloatingActionBtn(
                icon: Icons.add_rounded,
                tooltip: 'Zoom In',
                onPressed: () {
                  final zoom = _mapController.camera.zoom + 1;
                  _mapController.move(_mapController.camera.center, zoom);
                },
              ),
              const SizedBox(height: 6),

              // Zoom Out
              _buildFloatingActionBtn(
                icon: Icons.remove_rounded,
                tooltip: 'Zoom Out',
                onPressed: () {
                  final zoom = _mapController.camera.zoom - 1;
                  _mapController.move(_mapController.camera.center, zoom);
                },
              ),
              const SizedBox(height: 6),

              // Reset Lingayen View
              _buildFloatingActionBtn(
                icon: Icons.home_rounded,
                tooltip: 'Reset to Lingayen Center',
                onPressed: _resetToLingayenView,
              ),
              const SizedBox(height: 6),

              // My Location
              _buildFloatingActionBtn(
                icon: Icons.my_location_rounded,
                tooltip: 'Locate Me',
                highlight: _currentUserLocation != null,
                onPressed: _locateUser,
              ),
            ],
          ),
        ),

        // --- 4. Risk Rating Legend (Bottom Left) ---
        if (_showBarangayPolygons)
          Positioned(
            bottom: widget.isPublicUser ? 80 : 24,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendItem(const Color(0xFFDC2626), 'High'),
                  const SizedBox(width: 8),
                  _buildLegendItem(const Color(0xFFD97706), 'Med'),
                  const SizedBox(width: 8),
                  _buildLegendItem(const Color(0xFF16A34A), 'Low'),
                  const SizedBox(width: 8),
                  _buildLegendItem(const Color(0xFF94A3B8), 'Unassessed'),
                ],
              ),
            ),
          ),

        // --- 5. Persistent Floating BFP Hotline Call Button (Public Citizen Mode Only) ---
        if (widget.isPublicUser)
          Positioned(
            bottom: 16,
            left: 16,
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Call BFP Lingayen Hotline (Emergency)',
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

  Widget _buildFloatingActionBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool highlight = false,
  }) {
    return Material(
      color: highlight ? const Color(0xFF2563EB) : Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: highlight ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
        ),
      ],
    );
  }
}
