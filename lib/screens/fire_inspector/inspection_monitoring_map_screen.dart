import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../models/inspection_monitoring_model.dart';
import '../../services/inspection_monitoring_service.dart';

class InspectionMonitoringMapScreen extends StatefulWidget {
  const InspectionMonitoringMapScreen({super.key});

  @override
  State<InspectionMonitoringMapScreen> createState() => _InspectionMonitoringMapScreenState();
}

class _InspectionMonitoringMapScreenState extends State<InspectionMonitoringMapScreen> {
  final MapController _mapController = MapController();
  static const LatLng _lingayenCenter = LatLng(16.0120, 120.2250);

  LatLng? _myLocation;

  @override
  void initState() {
    super.initState();
    InspectionMonitoringService().fetchOnSiteInspectors();
    _detectMyLocation();
  }

  Future<void> _detectMyLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (mounted) {
        setState(() {
          _myLocation = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (_) {}
  }

  void _centerOnLingayen() {
    _mapController.move(_lingayenCenter, 13.5);
  }

  void _centerOnMyLocation() {
    if (_myLocation != null) {
      _mapController.move(_myLocation!, 15.5);
    } else {
      _detectMyLocation().then((_) {
        if (_myLocation != null) _mapController.move(_myLocation!, 15.5);
      });
    }
  }

  void _showInspectorDetailsSheet(InspectionMonitoringModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: item.visitTypeColor.withValues(alpha: 0.15),
                  child: Icon(item.visitTypeIcon, color: item.visitTypeColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.inspectorRank} ${item.inspectorName}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Badge: ${item.inspectorBadge ?? 'BFP Officer'}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.fiber_manual_record, color: Color(0xFF16A34A), size: 8),
                      SizedBox(width: 4),
                      Text('ON SITE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            _buildRow('Visit Type', item.visitType, valueColor: item.visitTypeColor, isBold: true),
            _buildRow('IO Reference No.', item.ioReferenceNo, isBold: true),
            if (item.relatedOrderNo != null)
              _buildRow('Related Order / Notice', item.relatedOrderNo!, valueColor: const Color(0xFFDC2626)),
            _buildRow('Barangay Location', 'Brgy. ${item.barangay}'),
            if (item.locationAddress != null && item.locationAddress!.isNotEmpty)
              _buildRow('Landmark / Address', item.locationAddress!),
            if (item.establishmentName != null && item.establishmentName!.isNotEmpty)
              _buildRow('Establishment', item.establishmentName!, isBold: true),
            _buildRow('Monitoring Start Time', item.formattedStartTime),
            _buildRow('Elapsed Time', item.elapsedDurationString, isBold: true),

            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Close Details', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Live Inspection Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh Map',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => InspectionMonitoringService().fetchOnSiteInspectors(),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<InspectionMonitoringModel>>(
        valueListenable: InspectionMonitoringService().onSiteInspectorsNotifier,
        builder: (context, onSiteInspectors, _) {
          final markers = onSiteInspectors.map((inspector) {
            final lat = inspector.currentLatitude ?? inspector.startLatitude ?? 16.0120;
            final lng = inspector.currentLongitude ?? inspector.startLongitude ?? 120.2250;

            return Marker(
              point: LatLng(lat, lng),
              width: 50,
              height: 50,
              child: GestureDetector(
                onTap: () => _showInspectorDetailsSheet(inspector),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulsing halo
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: inspector.visitTypeColor.withValues(alpha: 0.25),
                      ),
                    ),
                    // Inner badge
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: inspector.visitTypeColor,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            );
          }).toList();

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _lingayenCenter,
                  initialZoom: 13.5,
                  minZoom: 11.0,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.firesight.firesight_mobile',
                  ),
                  MarkerLayer(markers: markers),
                  if (_myLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _myLocation!,
                          width: 22,
                          height: 22,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF2563EB),
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // Top Status Badge
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.radar_rounded, color: Color(0xFFEA580C), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Live Field Monitoring Map',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              '${onSiteInspectors.length} Inspector(s) Currently ON SITE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: onSiteInspectors.isNotEmpty ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onSiteInspectors.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'LIVE',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Floating Controls (Right)
              Positioned(
                bottom: 24,
                right: 14,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'map_center_lingayen',
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F172A),
                      onPressed: _centerOnLingayen,
                      child: const Icon(Icons.home_rounded),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'map_center_me',
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0284C7),
                      onPressed: _centerOnMyLocation,
                      child: const Icon(Icons.my_location_rounded),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
