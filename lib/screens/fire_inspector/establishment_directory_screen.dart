import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import 'view_inspection_form_dialog.dart';

class EstablishmentDirectoryScreen extends StatefulWidget {
  const EstablishmentDirectoryScreen({super.key});

  @override
  State<EstablishmentDirectoryScreen> createState() => _EstablishmentDirectoryScreenState();
}

class _EstablishmentDirectoryScreenState extends State<EstablishmentDirectoryScreen> {
  // Design Tokens
  static const Color colorCanvas = Color(0xFFF8FAFC);
  static const Color colorSurface = Color(0xFFFFFFFF);
  static const Color colorTextPrimary = Color(0xFF0F172A);
  static const Color colorTextSecondary = Color(0xFF475569);
  static const Color colorAccent = Color(0xFFEA580C);
  static const Color colorBorder = Color(0xFFE2E8F0);
  static const Color colorSuccess = Color(0xFF16A34A);

  final TextEditingController _searchController = TextEditingController();
  String _selectedBarangay = 'All Barangays';
  String _selectedStatus = 'All Statuses';

  late Future<List<Map<String, dynamic>>> _establishmentsFuture;

  final List<String> _statusOptions = [
    'All Statuses',
    'FSIC Issued',
    'NTC Issued',
    'NTCV Issued',
    'NOD Issued',
    'Pending Inspection',
  ];

  @override
  void initState() {
    super.initState();
    _refreshDirectory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshDirectory() {
    setState(() {
      _establishmentsFuture = _fetchEstablishments();
    });
  }

  String _extractBarangay(String? address) {
    if (address == null || address.trim().isEmpty) return 'Poblacion';
    final lowerAddr = address.toLowerCase();
    for (var b in SupabaseService.lingayenBarangays) {
      if (lowerAddr.contains(b.toLowerCase())) {
        return b;
      }
    }
    return 'Poblacion';
  }

  String _normalizeComplianceStatus(String? recommendation, String? complianceStatus) {
    final rec = (recommendation ?? '').toUpperCase().trim();
    final comp = (complianceStatus ?? '').toUpperCase().trim();
    final combined = '$rec $comp';

    if (combined.contains('FSIC') || combined.contains('ISSUANCE') || combined.contains('PASS') || combined.contains('COMPLIANT')) {
      return 'FSIC Issued';
    }
    if (combined.contains('NTCV') || combined.contains('VIOLATION')) {
      return 'NTCV Issued';
    }
    if (combined.contains('NTC') || combined.contains('COMPLY') || combined.contains('NOTICE TO COMPLY') || combined.contains('NOTICETOCOMPLY')) {
      return 'NTC Issued';
    }
    if (combined.contains('NOD') || combined.contains('DISAPPROVAL')) {
      return 'NOD Issued';
    }
    return 'Pending Inspection';
  }

  Future<List<Map<String, dynamic>>> _fetchEstablishments() async {
    try {
      final client = Supabase.instance.client;

      // 1. Fetch registered establishments from public.establishments
      List<Map<String, dynamic>> rawEstablishments = [];
      try {
        final estResponse = await client.from('establishments').select().order('created_at', ascending: false);
        rawEstablishments = List<Map<String, dynamic>>.from(estResponse);
      } catch (e) {
        debugPrint('Establishments table note: $e');
      }

      // 2. Fetch all inspections from public.inspections
      List<Map<String, dynamic>> rawInspections = [];
      try {
        final insResponse = await client.from('inspections').select().order('created_at', ascending: false);
        rawInspections = List<Map<String, dynamic>>.from(insResponse);
      } catch (e) {
        debugPrint('Inspections table note: $e');
      }

      // 3. Build lookup maps for latest inspections
      final Map<String, Map<String, dynamic>> latestInspByEstId = {};
      final Map<String, Map<String, dynamic>> latestInspByNameAndBrgy = {};
      final Map<String, Map<String, dynamic>> latestInspByName = {};

      for (var ins in rawInspections) {
        final estId = ins['establishment_id']?.toString().trim();
        final bName = ins['business_name']?.toString().trim() ?? '';
        final bNameKey = bName.toLowerCase();

        final chk = ins['checklist_data'] is Map<String, dynamic> ? ins['checklist_data'] as Map<String, dynamic> : {};
        final genInfo = chk['generalInfo'] is Map<String, dynamic> ? chk['generalInfo'] as Map<String, dynamic> : {};
        final bldgSpecs = chk['buildingSpecifications'] is Map<String, dynamic> ? chk['buildingSpecifications'] as Map<String, dynamic> : {};

        final address = ins['address']?.toString() ?? genInfo['address']?.toString() ?? 'Lingayen, Pangasinan';
        final brgy = chk['barangay']?.toString() ?? _extractBarangay(address);
        final nameAndBrgyKey = '$bNameKey|${brgy.toLowerCase()}';

        final owner = genInfo['ownerRepresentative']?.toString().trim() ??
            chk['owner_name']?.toString().trim() ??
            ins['owner_name']?.toString().trim() ??
            'N/A';
        final contact = genInfo['contactNo']?.toString().trim() ??
            chk['contact']?.toString().trim() ??
            ins['contact_no']?.toString().trim() ??
            'N/A';
        final occupancy = bldgSpecs['occupancyClassification']?.toString() ??
            genInfo['natureOfBusiness']?.toString() ??
            chk['occupancy']?.toString() ??
            'Commercial';

        final status = _normalizeComplianceStatus(
          ins['recommendation']?.toString(),
          ins['compliance_status']?.toString(),
        );

        final processedInsp = {
          'inspection_id': ins['id'],
          'business_name': bName.isNotEmpty ? bName : 'Commercial Business',
          'address': address,
          'barangay': brgy,
          'occupancy_type': occupancy,
          'owner_name': owner.isNotEmpty ? owner : 'N/A',
          'contact_no': contact.isNotEmpty ? contact : 'N/A',
          'compliance_status': status,
          'inspection_order_no': ins['inspection_order_no'] ?? genInfo['fsecNo'] ?? chk['ioNumber'] ?? 'IO-2026',
          'last_inspection_date': ins['date_inspected'] ?? ins['created_at'],
        };

        if (estId != null && estId.isNotEmpty && !latestInspByEstId.containsKey(estId)) {
          latestInspByEstId[estId] = processedInsp;
        }
        if (bNameKey.isNotEmpty && !latestInspByNameAndBrgy.containsKey(nameAndBrgyKey)) {
          latestInspByNameAndBrgy[nameAndBrgyKey] = processedInsp;
        }
        if (bNameKey.isNotEmpty && !latestInspByName.containsKey(bNameKey)) {
          latestInspByName[bNameKey] = processedInsp;
        }
      }

      final List<Map<String, dynamic>> items = [];
      final Set<String> matchedInspectionIds = {};

      // 4. Process all establishments from public.establishments
      for (var est in rawEstablishments) {
        final estId = est['id']?.toString() ?? '';
        final name = (est['name'] ?? est['business_name'] ?? '').toString().trim();
        final addr = est['address']?.toString() ?? 'Lingayen, Pangasinan';
        final brgy = est['barangay']?.toString() ?? _extractBarangay(addr);
        final occ = est['nature_of_business'] ?? est['occupancy_classification'] ?? 'Commercial';

        Map<String, dynamic>? matchedInsp;
        if (estId.isNotEmpty && latestInspByEstId.containsKey(estId)) {
          matchedInsp = latestInspByEstId[estId];
        } else {
          final nameAndBrgyKey = '${name.toLowerCase()}|${brgy.toLowerCase()}';
          if (latestInspByNameAndBrgy.containsKey(nameAndBrgyKey)) {
            matchedInsp = latestInspByNameAndBrgy[nameAndBrgyKey];
          } else if (latestInspByName.containsKey(name.toLowerCase())) {
            matchedInsp = latestInspByName[name.toLowerCase()];
          }
        }

        if (matchedInsp != null) {
          matchedInspectionIds.add(matchedInsp['inspection_id']?.toString() ?? '');
          items.add({
            'id': estId.isNotEmpty ? estId : matchedInsp['inspection_id'],
            'establishment_id': estId,
            'inspection_id': matchedInsp['inspection_id'],
            'has_inspection': true,
            'business_name': name.isNotEmpty ? name : matchedInsp['business_name'],
            'address': addr.isNotEmpty ? addr : matchedInsp['address'],
            'barangay': brgy.isNotEmpty ? brgy : matchedInsp['barangay'],
            'occupancy_type': occ.toString().isNotEmpty ? occ : matchedInsp['occupancy_type'],
            'owner_name': matchedInsp['owner_name'],
            'contact_no': matchedInsp['contact_no'],
            'compliance_status': matchedInsp['compliance_status'],
            'inspection_order_no': matchedInsp['inspection_order_no'],
            'last_inspection_date': matchedInsp['last_inspection_date'],
          });
        } else {
          items.add({
            'id': estId,
            'establishment_id': estId,
            'inspection_id': null,
            'has_inspection': false,
            'business_name': name.isNotEmpty ? name : 'Commercial Establishment',
            'address': addr,
            'barangay': brgy,
            'occupancy_type': occ,
            'owner_name': 'N/A',
            'contact_no': 'N/A',
            'compliance_status': 'Pending Inspection',
            'inspection_order_no': 'N/A',
            'last_inspection_date': est['created_at'],
          });
        }
      }

      // 5. Add unique commercial establishments from inspections that were not in establishments table
      final Map<String, Map<String, dynamic>> extraBusinesses = {};
      for (var insp in rawInspections) {
        final inspId = insp['id']?.toString() ?? '';
        if (matchedInspectionIds.contains(inspId)) continue;

        final bName = insp['business_name']?.toString().trim() ?? '';
        if (bName.isEmpty) continue;

        final chk = insp['checklist_data'] is Map<String, dynamic> ? insp['checklist_data'] as Map<String, dynamic> : {};
        final genInfo = chk['generalInfo'] is Map<String, dynamic> ? chk['generalInfo'] as Map<String, dynamic> : {};
        final bldgSpecs = chk['buildingSpecifications'] is Map<String, dynamic> ? chk['buildingSpecifications'] as Map<String, dynamic> : {};
        final addr = insp['address']?.toString() ?? genInfo['address']?.toString() ?? 'Lingayen, Pangasinan';
        final brgy = chk['barangay']?.toString() ?? _extractBarangay(addr);
        final uniqueKey = '${bName.toLowerCase()}|${brgy.toLowerCase()}';

        if (!extraBusinesses.containsKey(uniqueKey)) {
          final owner = genInfo['ownerRepresentative']?.toString().trim() ??
              chk['owner_name']?.toString().trim() ??
              insp['owner_name']?.toString().trim() ??
              'N/A';
          final contact = genInfo['contactNo']?.toString().trim() ??
              chk['contact']?.toString().trim() ??
              insp['contact_no']?.toString().trim() ??
              'N/A';
          final occupancy = bldgSpecs['occupancyClassification']?.toString() ??
              genInfo['natureOfBusiness']?.toString() ??
              chk['occupancy']?.toString() ??
              'Mercantile';

          final status = _normalizeComplianceStatus(
            insp['recommendation']?.toString(),
            insp['compliance_status']?.toString(),
          );

          extraBusinesses[uniqueKey] = {
            'id': inspId,
            'establishment_id': null,
            'inspection_id': inspId,
            'has_inspection': true,
            'business_name': bName,
            'address': addr,
            'barangay': brgy,
            'occupancy_type': occupancy,
            'owner_name': owner.isNotEmpty ? owner : 'N/A',
            'contact_no': contact.isNotEmpty ? contact : 'N/A',
            'compliance_status': status,
            'inspection_order_no': insp['inspection_order_no'] ?? genInfo['fsecNo'] ?? chk['ioNumber'] ?? 'IO-2026',
            'last_inspection_date': insp['date_inspected'] ?? insp['created_at'],
          };
        }
      }

      items.addAll(extraBusinesses.values);

      // Sort by last inspection date or created_at descending
      items.sort((a, b) {
        final dateA = (a['last_inspection_date'] ?? '').toString();
        final dateB = (b['last_inspection_date'] ?? '').toString();
        return dateB.compareTo(dateA);
      });

      // Filter by Barangay
      List<Map<String, dynamic>> filteredItems = items;
      if (_selectedBarangay != 'All Barangays') {
        filteredItems = filteredItems.where((e) {
          final brgy = (e['barangay'] ?? e['address'] ?? '').toString().toLowerCase();
          return brgy.contains(_selectedBarangay.toLowerCase());
        }).toList();
      }

      // Filter by Compliance Status
      if (_selectedStatus != 'All Statuses') {
        filteredItems = filteredItems.where((e) {
          final st = (e['compliance_status'] ?? '').toString().toLowerCase();
          final target = _selectedStatus.toLowerCase();
          if (target.contains('fsic')) return st.contains('fsic');
          if (target.contains('ntcv')) return st.contains('ntcv');
          if (target.contains('ntc')) return st == 'ntc issued' || (st.contains('ntc') && !st.contains('ntcv'));
          if (target.contains('nod')) return st.contains('nod');
          if (target.contains('pending')) return st.contains('pending');
          return st == target;
        }).toList();
      }

      // Search Query Filter
      final q = _searchController.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        filteredItems = filteredItems.where((e) {
          final bName = (e['business_name'] ?? e['name'] ?? '').toString().toLowerCase();
          final owner = (e['owner_name'] ?? '').toString().toLowerCase();
          final addr = (e['address'] ?? '').toString().toLowerCase();
          final brgy = (e['barangay'] ?? '').toString().toLowerCase();
          final ioNo = (e['inspection_order_no'] ?? '').toString().toLowerCase();
          final occ = (e['occupancy_type'] ?? '').toString().toLowerCase();
          final st = (e['compliance_status'] ?? '').toString().toLowerCase();
          return bName.contains(q) ||
              owner.contains(q) ||
              addr.contains(q) ||
              brgy.contains(q) ||
              ioNo.contains(q) ||
              occ.contains(q) ||
              st.contains(q);
        }).toList();
      }

      return filteredItems;
    } catch (e) {
      debugPrint('Error fetching establishment directory: $e');
      return [];
    }
  }

  void _showEstablishmentDetails(Map<String, dynamic> est) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDetailModal(est),
    );
  }

  void _showInspectionForm(Map<String, dynamic> est) {
    final inspectionId = est['inspection_id']?.toString() ?? est['id']?.toString();
    showDialog(
      context: context,
      builder: (context) => ViewInspectionFormDialog(
        targetInspectionId: inspectionId,
        initialData: est,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final List<String> barangayOptions = ['All Barangays', ...SupabaseService.lingayenBarangays];

    return Scaffold(
      backgroundColor: colorCanvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed Top Header & Search Filters (Sticky / Non-scrolling)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _buildHeaderAndSearchCard(barangayOptions),
          ),

          // Scrollable Establishment Directory List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refreshDirectory(),
              color: colorAccent,
              child: _buildEstablishmentList(scrollable: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAndSearchCard(List<String> barangayOptions) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.storefront_outlined, color: colorAccent, size: 22),
              SizedBox(width: 8),
              Text(
                'Lingayen Establishment Directory',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: colorTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Search registered commercial establishments, compliance status, and structural safety records.',
            style: TextStyle(fontSize: 12, color: colorTextSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (_) => _refreshDirectory(),
            style: const TextStyle(fontSize: 13, color: colorTextPrimary),
            decoration: InputDecoration(
              hintText: 'Search business name, owner, address...',
              hintStyle: const TextStyle(color: colorTextSecondary, fontSize: 12),
              prefixIcon: const Icon(Icons.search_outlined, size: 20, color: colorTextSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_outlined, size: 18, color: colorTextSecondary),
                      onPressed: () {
                        _searchController.clear();
                        _refreshDirectory();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: colorBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: colorBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: colorAccent, width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedBarangay,
                  items: barangayOptions.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedBarangay = val);
                      _refreshDirectory();
                    }
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusOptions.contains(_selectedStatus) ? _selectedStatus : _statusOptions.first,
                  items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedStatus = val);
                      _refreshDirectory();
                    }
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstablishmentList({bool scrollable = false}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _establishmentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(color: colorAccent),
            ),
          );
        }

        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          final emptyWidget = Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: colorSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.storefront_outlined, size: 40, color: colorTextSecondary),
                SizedBox(height: 10),
                Text(
                  'No establishments found.',
                  style: TextStyle(color: colorTextPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'Try searching for another commercial business or changing filters.',
                  style: TextStyle(color: colorTextSecondary, fontSize: 12),
                ),
              ],
            ),
          );

          if (scrollable) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: emptyWidget,
            );
          }
          return emptyWidget;
        }

        return ListView.separated(
          shrinkWrap: !scrollable,
          physics: scrollable ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
          padding: scrollable ? const EdgeInsets.fromLTRB(16, 0, 16, 24) : EdgeInsets.zero,
          itemCount: list.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final est = list[index];
            final bName = (est['business_name'] ?? est['name'] ?? 'Commercial Business').toString().trim();
            final addr = (est['address'] ?? 'Lingayen, Pangasinan').toString().trim();
            final owner = (est['owner_name'] ?? 'N/A').toString().trim();
            final occupancy = (est['occupancy_type'] ?? est['nature_of_business'] ?? est['occupancy_classification'] ?? 'Commercial').toString().trim();
            final status = (est['compliance_status'] ?? 'Pending Inspection').toString().trim();
            final bool hasForm = est['has_inspection'] == true && est['inspection_id'] != null;

            return InkWell(
              onTap: () => _showEstablishmentDetails(est),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            occupancy.toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorAccent),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusBgColor(status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusTextColor(status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorTextPrimary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: colorTextSecondary),
                        const SizedBox(width: 4),
                        Text('Owner: $owner', style: const TextStyle(fontSize: 12, color: colorTextSecondary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: colorTextSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            addr,
                            style: const TextStyle(fontSize: 12, color: colorTextSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (hasForm) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: colorBorder),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showInspectionForm(est),
                            icon: const Icon(
                              Icons.description_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'View Form',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorSuccess,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailModal(Map<String, dynamic> est) {
    final bName = (est['business_name'] ?? est['name'] ?? 'Commercial Business').toString().trim();
    final addr = (est['address'] ?? 'Lingayen, Pangasinan').toString().trim();
    final owner = (est['owner_name'] ?? 'N/A').toString().trim();
    final contact = (est['contact_no'] ?? 'N/A').toString().trim();
    final occupancy = (est['occupancy_type'] ?? est['nature_of_business'] ?? est['occupancy_classification'] ?? 'Commercial').toString().trim();
    final status = (est['compliance_status'] ?? 'Pending Inspection').toString().trim();
    final ioNo = est['inspection_order_no'] ?? 'N/A';
    final lastDate = est['last_inspection_date'] ?? 'Recent';
    final bool hasForm = est['has_inspection'] == true && est['inspection_id'] != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: colorSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: colorBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  bName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorTextPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusBgColor(status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getStatusTextColor(status)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDetailRow(Icons.business_outlined, 'Occupancy Type', occupancy),
          _buildDetailRow(Icons.person_outline, 'Owner / Representative', owner),
          _buildDetailRow(Icons.phone_outlined, 'Contact Number', contact),
          _buildDetailRow(Icons.location_on_outlined, 'Address / Barangay', addr),
          _buildDetailRow(Icons.confirmation_number_outlined, 'Latest IO #', ioNo),
          _buildDetailRow(Icons.event_outlined, 'Last Inspected', lastDate.toString().split('T').first),
          if (hasForm) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showInspectionForm(est);
                },
                icon: const Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: Colors.white,
                ),
                label: const Text(
                  'View Inspection Form',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorSuccess,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorBorder),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, size: 18, color: colorTextSecondary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No completed inspection checklist recorded yet for this establishment.',
                      style: TextStyle(fontSize: 12, color: colorTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorTextSecondary),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorTextPrimary)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: colorTextSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Color _getStatusBgColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('fsic') || s.contains('pass') || s.contains('compliant')) return const Color(0xFFDCFCE7);
    if (s.contains('ntcv') || s.contains('violation')) return const Color(0xFFFEE2E2);
    if (s.contains('ntc') || s.contains('comply')) return const Color(0xFFFEF3C7);
    if (s.contains('nod') || s.contains('disapproval')) return const Color(0xFFFFEDD5);
    return const Color(0xFFF1F5F9);
  }

  Color _getStatusTextColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('fsic') || s.contains('pass') || s.contains('compliant')) return const Color(0xFF15803D);
    if (s.contains('ntcv') || s.contains('violation')) return const Color(0xFFB91C1C);
    if (s.contains('ntc') || s.contains('comply')) return const Color(0xFFB45309);
    if (s.contains('nod') || s.contains('disapproval')) return const Color(0xFFC2410C);
    return const Color(0xFF64748B);
  }
}
