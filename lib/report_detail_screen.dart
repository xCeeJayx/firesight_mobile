import 'package:flutter/material.dart';
import 'widgets/common/status_badge.dart';

class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> report;

  const ReportDetailScreen({super.key, required this.report});

  void _exportPdf(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Exporting Audit Report PDF...'),
          ],
        ),
        backgroundColor: const Color(0xFFD84315),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checklistData = report['checklist_data'] as Map<String, dynamic>? ?? {};
    final String type = checklistData['checklist_type'] ?? report['checklist_type'] ?? 'commercial';

    String typeTitle = 'Commercial Fire Safety Inspection';
    Color themeColor = const Color(0xFFD84315);
    IconData typeIcon = Icons.business_rounded;

    if (type == 'community_urban') {
      typeTitle = 'CFPP Community Risk (Urban)';
      themeColor = const Color(0xFF0284C7);
      typeIcon = Icons.holiday_village_rounded;
    } else if (type == 'house_to_house') {
      typeTitle = 'House to House Fire Safety';
      themeColor = const Color(0xFF16A34A);
      typeIcon = Icons.home_rounded;
    }

    final String title = report['business_name'] ?? 'Inspection Report';
    final String address = report['address'] ?? 'No address provided';
    final String status = report['compliance_status'] ?? report['recommendation'] ?? report['rating'] ?? 'Completed';
    final String riskLevel = report['risk_level'] ?? 'Medium';
    final String dateStr = report['date_inspected'] != null
        ? report['date_inspected'].toString().split('T').first
        : (report['created_at'] != null ? report['created_at'].toString().split('T').first : 'N/A');
    final String ioNo = report['inspection_order_no'] ?? report['inspection_order_number'] ?? 'N/A';

    final List<dynamic> rawPhotos = report['hazard_photo_urls'] is List ? report['hazard_photo_urls'] : [];
    final List<String> photoUrls = rawPhotos.map((e) => e.toString()).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(typeTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF0F172A)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing Inspection Summary...')),
              );
            },
            tooltip: 'Share Report',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFD84315)),
            onPressed: () => _exportPdf(context),
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(typeIcon, size: 22, color: themeColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(address, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFFE2E8F0)),
                Row(
                  children: [
                    Expanded(child: _buildInfoBadge('DATE INSPECTED', dateStr)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInfoBadge('IO TRACKING', ioNo)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('RISK LEVEL', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          StatusBadge(status: riskLevel),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('STATUS', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          StatusBadge(status: status),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Detailed Breakdown Payload Viewer
          if (type == 'community_urban')
            _buildCommunityUrbanDetails(context, checklistData, themeColor)
          else if (type == 'house_to_house')
            _buildHouseToHouseDetails(context, checklistData, themeColor)
          else
            _buildCommercialDetails(context, checklistData, themeColor),

          const SizedBox(height: 20),

          // Photo Documentation Gallery
          if (photoUrls.isNotEmpty) ...[
            _buildSectionTitle('HAZARD PHOTO EVIDENCE'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _cardDecoration(),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: photoUrls.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _openImagePreview(context, photoUrls[index]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        photoUrls[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // COMMERCIAL CHECKLIST DETAILS
  Widget _buildCommercialDetails(BuildContext context, Map<String, dynamic> data, Color themeColor) {
    final genInfo = data['generalInfo'] as Map<String, dynamic>? ?? {};
    final specs = data['buildingSpecifications'] as Map<String, dynamic>? ?? {};
    final secOcc = specs['sectionalOccupancy'] as Map<String, dynamic>? ?? {};
    final sig = data['signatories'] as Map<String, dynamic>? ?? {};
    final egressAccess = Map<String, String>.from(data['egressAccessStatus'] ?? {});
    final fireProtection = Map<String, String>.from(data['fireProtectionStatus'] ?? {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('GENERAL INFORMATION'),
        _buildDetailCard([
          _buildDetailRow('Building Name', genInfo['buildingName']),
          _buildDetailRow('Business Name', genInfo['businessName']),
          _buildDetailRow('Nature of Business', genInfo['natureOfBusiness']),
          _buildDetailRow('Owner / Representative', genInfo['ownerRepresentative']),
          _buildDetailRow('Contact No.', genInfo['contactNo']),
          _buildDetailRow('FSEC No.', genInfo['fsecNo']),
          _buildDetailRow('Building Permit No.', genInfo['buildingPermitNo']),
          _buildDetailRow('FSIC No. (Latest)', genInfo['fsicNoLatest']),
          _buildDetailRow('Business Permit No.', genInfo['businessPermitNo']),
          _buildDetailRow('Fire Insurance Policy', genInfo['fireInsurancePolicyNo']),
        ]),
        const SizedBox(height: 16),
        _buildSectionTitle('BUILDING SPECIFICATIONS'),
        _buildDetailCard([
          _buildDetailRow('Construction Type', specs['constructionType']),
          _buildDetailRow('Walls Interior Finish', specs['interiorFinishWalls']),
          _buildDetailRow('Floor Interior Finish', specs['interiorFinishFloor']),
          _buildDetailRow('Occupancy Classification', specs['occupancyClassification']),
          _buildDetailRow('Occupant Load (P/Floor)', specs['occupantLoad']),
          _buildDetailRow('Number of Stories', specs['numberOfStories']?.toString()),
          _buildDetailRow('Building Height', specs['buildingHeight'] != null ? '${specs['buildingHeight']} m' : null),
          _buildDetailRow('Highrise Building', specs['isHighrise']?.toString()),
          if (secOcc.isNotEmpty) ...[
            const Divider(height: 16),
            _buildDetailRow('Basement Usage', secOcc['basement']),
            _buildDetailRow('Ground Floor Usage', secOcc['groundFloor']),
            _buildDetailRow('Second Floor Usage', secOcc['secondFloor']),
            _buildDetailRow('Third Floor Usage', secOcc['thirdFloor']),
          ],
        ]),
        if (egressAccess.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('MEANS OF EGRESS STATUS'),
          _buildStatusGridCard(egressAccess),
        ],
        if (fireProtection.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('FIRE PROTECTION SYSTEMS STATUS'),
          _buildStatusGridCard(fireProtection),
        ],
        if (data['defectsSummary'] != null && data['defectsSummary'].toString().isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('DEFECTS & RECOMMENDATIONS'),
          _buildDetailCard([
            _buildDetailRow('Defects Summary', data['defectsSummary']),
            _buildDetailRow('Recommendation Action', data['recommendationAction']),
          ]),
        ],
        if (sig.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('SIGNATORIES'),
          _buildDetailCard([
            _buildDetailRow('Inspector', sig['inspectorName']),
            _buildDetailRow('Team Leader', sig['teamLeaderName']),
            _buildDetailRow('Fire Marshal', sig['fireMarshalName']),
          ]),
        ],
      ],
    );
  }

  // COMMUNITY RISK URBAN DETAILS
  Widget _buildCommunityUrbanDetails(BuildContext context, Map<String, dynamic> data, Color themeColor) {
    final sub = data['subFields'] as Map<String, dynamic>? ?? {};
    final sig = data['signatories'] as Map<String, dynamic>? ?? {};
    final sec1 = Map<String, String>.from(data['sec1Params'] ?? {});
    final sec2 = Map<String, String>.from(data['sec2Params'] ?? {});
    final sec3 = Map<String, String>.from(data['sec3Params'] ?? {});
    final sec4 = Map<String, String>.from(data['sec4Params'] ?? {});
    final sec5 = Map<String, String>.from(data['sec5Params'] ?? {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('COMMUNITY PROFILE'),
        _buildDetailCard([
          _buildDetailRow('Barangay', data['barangay']),
          _buildDetailRow('Purok / Sitio', data['purokSitio']),
          _buildDetailRow('No. of Households', data['householdCount']?.toString()),
          _buildDetailRow('No. of Families', data['familyCount']?.toString()),
          _buildDetailRow('No. of Individuals', data['individualCount']?.toString()),
          _buildDetailRow('Land Area', data['landArea']),
          _buildDetailRow('Category', data['communityType']),
          if (data['metroSubtype'] != null) _buildDetailRow('Metro Type', data['metroSubtype']),
          if (data['ruralSubtype'] != null) _buildDetailRow('Rural Type', data['ruralSubtype']),
        ]),
        const SizedBox(height: 16),
        _buildSectionTitle('VULNERABILITY SCORE SUMMARY'),
        _buildDetailCard([
          _buildDetailRow('Total YES Count', data['totalYesCount']?.toString()),
          _buildDetailRow('Vulnerability Score', data['totalScore']?.toString()),
          _buildDetailRow('Vulnerability Rating', data['vulnerabilityRating']),
        ]),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('ACCESSIBILITY & WATER SOURCES'),
          _buildDetailCard([
            _buildDetailRow('Clustered Distance', sub['buildingClusteredDistance']),
            _buildDetailRow('Primary Route', sub['primaryRouteName']),
            _buildDetailRow('Primary Route Est Time', sub['primaryRouteEstTime']),
            _buildDetailRow('Responding Trucks Entry', sub['entryRespondingTrucks']),
            _buildDetailRow('Refilling Trucks Entry', sub['entryRefillingTrucks']),
            _buildDetailRow('Road Width & Pavement', sub['roadWidth'] != null ? '${sub['roadWidth']}m (${sub['roadPavement']})' : null),
            _buildDetailRow('Alley Width & Pavement', sub['narrowAlleysWidth'] != null ? '${sub['narrowAlleysWidth']}m (${sub['narrowAlleysPavement']})' : null),
            _buildDetailRow('Passable For', sub['accessPassableFor']),
            _buildDetailRow('Water Source Location', sub['waterSourceLocation']),
            _buildDetailRow('Water Discharge Rate', sub['rateOfDischarge']),
          ]),
        ],
        if (sec1.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('1. LAND & SURFACE CONSIDERATIONS'),
          _buildStatusGridCard(sec1),
        ],
        if (sec2.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('2. HIGHLY-URBANIZED PARAMETERS'),
          _buildStatusGridCard(sec2),
        ],
        if (sec3.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('3. POPULATION & SOCIOLOGY'),
          _buildStatusGridCard(sec3),
        ],
        if (sec4.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('4. SET-UP OF STRUCTURES'),
          _buildStatusGridCard(sec4),
        ],
        if (sec5.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('5. ENVIRONMENTAL FACTORS'),
          _buildStatusGridCard(sec5),
        ],
        if (sig.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('SIGNATORIES'),
          _buildDetailCard([
            _buildDetailRow('Designated Bumbero', sig['designatedBumbero']),
            _buildDetailRow('Workshop Team Leader', sig['workshopTeamLeader']),
            _buildDetailRow('Barangay Captain', sig['barangayCaptain']),
            _buildDetailRow('Fire Marshal', sig['fireMarshal']),
          ]),
        ],
      ],
    );
  }

  // HOUSE TO HOUSE DETAILS
  Widget _buildHouseToHouseDetails(BuildContext context, Map<String, dynamic> data, Color themeColor) {
    final rawItems = data['itemStatuses'] as Map<String, dynamic>? ?? {};
    final materials = Map<String, String>.from(data['buildingMaterials'] ?? {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('HOUSEHOLD SUMMARY'),
        _buildDetailCard([
          _buildDetailRow('Occupant / Head of Household', data['occupantName']),
          _buildDetailRow('Address', data['address']),
          _buildDetailRow('Total YES Points', '${data['totalYesPoints'] ?? 0} / 35 Points'),
          _buildDetailRow('Safety Interpretation', data['safetyInterpretation']),
          if (data['suggestions'] != null && data['suggestions'].toString().isNotEmpty)
            _buildDetailRow('Suggestions / Recommendations', data['suggestions']),
          if (data['acknowledgedBy'] != null && data['acknowledgedBy'].toString().isNotEmpty)
            _buildDetailRow('Acknowledged By', data['acknowledgedBy']),
        ]),
        if (materials.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('BUILDING MATERIALS MATRIX'),
          _buildDetailCard(materials.entries.map((e) => _buildDetailRow(e.key, e.value)).toList()),
        ],
        if (rawItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('CHECKLIST ITEMS (35 ITEMS)'),
          _buildStatusGridCard(rawItems.map((k, v) => MapEntry('Item #$k', v.toString()))),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildDetailCard(List<Widget> children) {
    final validChildren = children.where((w) => w is! SizedBox).toList();
    if (validChildren.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(children: children),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusGridCard(Map<String, String> statusMap) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        children: statusMap.entries.map((entry) {
          final val = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(entry.key, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500)),
                ),
                StatusBadge(status: val),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _openImagePreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(url, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    );
  }
}
