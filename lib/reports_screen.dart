import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'report_detail_screen.dart';
import 'widgets/common/status_badge.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<List<Map<String, dynamic>>> _reports;
  String _searchQuery = '';
  String _selectedFilter = 'All'; // All, Commercial, Community, Residential

  @override
  void initState() {
    super.initState();
    _reports = _fetchReports();
  }

  Future<List<Map<String, dynamic>>> _fetchReports() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      List<Map<String, dynamic>> inspectionsList = [];
      try {
        dynamic response;
        if (userId != null) {
          response = await Supabase.instance.client
              .from('inspections')
              .select()
              .eq('inspector_id', userId)
              .order('created_at', ascending: false);
        } else {
          response = await Supabase.instance.client
              .from('inspections')
              .select()
              .order('created_at', ascending: false);
        }
        inspectionsList = List<Map<String, dynamic>>.from(response);
      } catch (_) {}

      List<Map<String, dynamic>> surveysList = [];
      try {
        dynamic response;
        if (userId != null) {
          response = await Supabase.instance.client
              .from('fire_risk_surveys')
              .select()
              .eq('inspector_id', userId)
              .order('created_at', ascending: false);
        } else {
          response = await Supabase.instance.client
              .from('fire_risk_surveys')
              .select()
              .order('created_at', ascending: false);
        }
        surveysList = List<Map<String, dynamic>>.from(response);
      } catch (_) {}

      final knownBarangays = [
        'Aliwekwek', 'Baay', 'Balangobong', 'Balococ', 'Bantayan', 'Basing',
        'Capandanan', 'Domalandan Center', 'Domalandan East', 'Domalandan West',
        'Dorongan', 'Dulag', 'Estanza', 'Lasip', 'Libsong East', 'Libsong West',
        'Malawa', 'Malimpuec', 'Maniboc', 'Matalava', 'Naguelguel', 'Namolan',
        'Pangapisan North', 'Pangapisan Sur', 'Poblacion', 'Quibaol', 'Rosario',
        'Sabangan', 'Talogtog', 'Tonton', 'Tumbar', 'Wawa'
      ];

      // Normalize survey records into report format
      final normalizedSurveys = surveysList.map((item) {
        final String surveyType = item['survey_type'] ?? 'community_urban';
        String bgy = item['barangay_name'] ?? 'Poblacion';
        final Map<String, dynamic> sData = item['survey_data'] as Map<String, dynamic>? ?? {};

        final String userAddr = sData['address']?.toString() ?? sData['address_text']?.toString() ?? item['address']?.toString() ?? '';
        
        if (userAddr.isNotEmpty) {
          final addrLower = userAddr.toLowerCase();
          for (final b in knownBarangays) {
            if (addrLower.contains(b.toLowerCase())) {
              bgy = b;
              break;
            }
          }
        }

        final String displayAddress = userAddr.isNotEmpty
            ? userAddr
            : '$bgy, Lingayen, Pangasinan';

        final String occupant = sData['occupantName']?.toString() ?? sData['occupant_name']?.toString() ?? '';
        final String displayTitle = surveyType == 'house_to_house'
            ? (occupant.isNotEmpty ? 'House of $occupant (Brgy. $bgy)' : 'House Survey - Brgy. $bgy')
            : 'Barangay $bgy Fire Risk Audit';

        return <String, dynamic>{
          'id': item['id'],
          'inspector_id': item['inspector_id'],
          'checklist_type': surveyType,
          'inspection_order_no': surveyType == 'community_urban' ? 'CFPP-SURVEY' : 'H2H-SURVEY',
          'business_name': displayTitle,
          'address': displayAddress,
          'overall_status': 'Completed',
          'compliance_status': item['risk_level'] ?? 'Medium Risk',
          'recommendation': item['risk_level'] ?? 'Medium Risk',
          'risk_level': (item['risk_level'] ?? 'Medium').toString().replaceAll(' Risk', ''),
          'score': item['calculated_score'] ?? 0,
          'rating': item['risk_level'] ?? 'Completed',
          'checklist_data': sData,
          'hazard_photo_urls': item['photo_urls'] ?? [],
          'created_at': item['created_at'],
          'date_inspected': item['created_at'] != null ? item['created_at'].toString().split('T').first : 'Today',
        };
      }).toList();

      final combined = [...inspectionsList, ...normalizedSurveys];
      combined.sort((a, b) {
        final aDate = (a['created_at'] ?? '').toString();
        final bDate = (b['created_at'] ?? '').toString();
        return bDate.compareTo(aDate);
      });

      return combined;
    } catch (e) {
      return [];
    }
  }

  void _exportReportsPdf() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Generating BFP Official Audit Log PDF Report...'),
          ],
        ),
        backgroundColor: const Color(0xFFD84315),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Filter & Search Header Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search audits by name, address, or IO...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _exportReportsPdf,
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: const Text('PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD84315),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      {'label': 'All Audits', 'type': 'All'},
                      {'label': 'Commercial FSIC', 'type': 'Commercial'},
                      {'label': 'OLP Community', 'type': 'Community'},
                      {'label': 'H2H Residential', 'type': 'Residential'},
                    ].map((filter) {
                      final isSelected = _selectedFilter == filter['type'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter['label']!),
                          selected: isSelected,
                          onSelected: (val) => setState(() => _selectedFilter = filter['type']!),
                          selectedColor: const Color(0xFFD84315),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 12,
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Reports List Body
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _reports,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFD84315)));
                }

                final allReports = snapshot.data ?? [];
                final filtered = allReports.where((r) {
                  final name = (r['business_name'] ?? '').toString().toLowerCase();
                  final address = (r['address'] ?? '').toString().toLowerCase();
                  final ioNo = (r['inspection_order_no'] ?? '').toString().toLowerCase();
                  final type = (r['checklist_data']?['checklist_type'] ?? r['checklist_type'] ?? '').toString().toLowerCase();

                  final matchesSearch = name.contains(_searchQuery) || address.contains(_searchQuery) || ioNo.contains(_searchQuery);
                  bool matchesFilter = true;

                  if (_selectedFilter == 'Commercial') matchesFilter = type.contains('commercial');
                  if (_selectedFilter == 'Community') matchesFilter = type.contains('community');
                  if (_selectedFilter == 'Residential') matchesFilter = type.contains('house');

                  return matchesSearch && matchesFilter;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.folder_open_rounded, size: 48, color: Color(0xFF94A3B8)),
                        SizedBox(height: 12),
                        Text(
                          'No Inspection Reports Found',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Submitted audits and risk surveys will appear here.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _reports = _fetchReports();
                    });
                  },
                  color: const Color(0xFFD84315),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _buildReportCard(filtered[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final checklistData = report['checklist_data'] as Map<String, dynamic>? ?? {};
    final String type = checklistData['checklist_type'] ?? report['checklist_type'] ?? 'commercial';

    String typeLabel = 'Commercial FSIC';
    IconData typeIcon = Icons.business_rounded;
    Color borderAccent = const Color(0xFFD84315);
    Color iconBg = const Color(0xFFFFF7ED);

    if (type == 'community_urban') {
      typeLabel = 'OLP Community Risk';
      typeIcon = Icons.holiday_village_rounded;
      borderAccent = const Color(0xFF0284C7);
      iconBg = const Color(0xFFF0F9FF);
    } else if (type == 'house_to_house') {
      typeLabel = 'House to House Survey';
      typeIcon = Icons.home_rounded;
      borderAccent = const Color(0xFF16A34A);
      iconBg = const Color(0xFFF0FDF4);
    }

    final String title = report['business_name'] ?? 'Inspection Report';
    final String address = report['address'] ?? 'Lingayen, Pangasinan';
    final String statusStr = report['compliance_status'] ?? report['recommendation'] ?? report['rating'] ?? 'Completed';
    final String dateStr = report['date_inspected'] != null
        ? report['date_inspected'].toString().split('T').first
        : (report['created_at'] != null ? report['created_at'].toString().split('T').first : 'Today');

    Widget metricWidget = const SizedBox.shrink();
    if (type == 'house_to_house') {
      final int totalPoints = checklistData['totalYesPoints'] ?? report['score'] ?? 0;
      metricWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Text(
          '$totalPoints / 35 YES',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: borderAccent,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(typeIcon, color: borderAccent, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: borderAccent,
                          ),
                        ),
                      ],
                    ),
                    StatusBadge(status: statusStr),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Inspected: $dateStr',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    metricWidget,
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ReportDetailScreen(report: report),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                      label: const Text('View Details'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFD84315),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}