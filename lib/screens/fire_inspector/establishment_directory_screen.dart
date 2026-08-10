import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../widgets/fsic_certificate_preview_modal.dart';
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
  static const Color colorWarning = Color(0xFFD97706);
  static const Color colorError = Color(0xFFDC2626);

  final TextEditingController _searchController = TextEditingController();
  String _selectedBarangay = 'All Barangays';
  String _selectedStatus = 'All Statuses';

  late Future<List<Map<String, dynamic>>> _establishmentsFuture;

  final List<String> _statusOptions = [
    'All Statuses',
    'FSIC Issued',
    'NTC Issued',
    'NTCV Issued',
    'Pending',
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

  Future<List<Map<String, dynamic>>> _fetchEstablishments() async {
    try {
      final client = Supabase.instance.client;
      List<Map<String, dynamic>> items = [];

      // Query public.establishments directly
      try {
        final estResponse = await client.from('establishments').select().order('created_at', ascending: false);
        items = List<Map<String, dynamic>>.from(estResponse);
      } catch (e) {
        debugPrint('Establishments table note: $e');
      }

      // If establishments is empty, fallback to querying unique commercial establishments from public.inspections
      if (items.isEmpty) {
        final insResponse = await client.from('inspections').select().order('created_at', ascending: false);
        final Map<String, Map<String, dynamic>> uniqueMap = {};
        for (var item in insResponse) {
          final bName = item['business_name']?.toString() ?? 'Commercial Establishment';
          if (!uniqueMap.containsKey(bName)) {
            uniqueMap[bName] = {
              'id': item['id'],
              'business_name': bName,
              'address': item['address'] ?? 'Lingayen, Pangasinan',
              'barangay': item['checklist_data']?['barangay'] ?? 'Poblacion',
              'occupancy_type': item['checklist_data']?['occupancy'] ?? 'Mercantile',
              'owner_name': item['checklist_data']?['owner_name'] ?? 'N/A',
              'contact_no': item['checklist_data']?['contact'] ?? 'N/A',
              'compliance_status': item['recommendation'] ?? item['compliance_status'] ?? 'FSIC Issued',
              'inspection_order_no': item['inspection_order_no'] ?? 'IO-2026',
              'last_inspection_date': item['date_inspected'] ?? item['created_at'],
            };
          }
        }
        items = uniqueMap.values.toList();
      }

      // Filter by Barangay
      if (_selectedBarangay != 'All Barangays') {
        items = items.where((e) {
          final brgy = (e['barangay'] ?? e['address'] ?? '').toString().toLowerCase();
          return brgy.contains(_selectedBarangay.toLowerCase());
        }).toList();
      }

      // Filter by Compliance Status
      if (_selectedStatus != 'All Statuses') {
        items = items.where((e) {
          final st = (e['compliance_status'] ?? e['status'] ?? '').toString().toLowerCase();
          final target = _selectedStatus.toLowerCase();
          if (target.contains('fsic')) return st.contains('fsic') || st.contains('pass') || st.contains('completed');
          if (target.contains('ntcv')) return st.contains('ntcv') || st.contains('violation');
          if (target.contains('ntc')) return st.contains('ntc') || st.contains('comply');
          return st.contains('pending');
        }).toList();
      }

      // Search Query Filter
      final q = _searchController.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        items = items.where((e) {
          final bName = (e['business_name'] ?? '').toString().toLowerCase();
          final owner = (e['owner_name'] ?? '').toString().toLowerCase();
          final addr = (e['address'] ?? '').toString().toLowerCase();
          final ioNo = (e['inspection_order_no'] ?? '').toString().toLowerCase();
          return bName.contains(q) || owner.contains(q) || addr.contains(q) || ioNo.contains(q);
        }).toList();
      }

      return items;
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
    showDialog(
      context: context,
      builder: (context) => ViewInspectionFormDialog(
        targetInspectionId: est['id']?.toString(),
        initialData: est,
      ),
    );
  }

  bool _isInspectionDone(String status) {
    final s = status.toLowerCase();
    return s.contains('fsic') || s.contains('pass') || s.contains('completed') || s.contains('compliant');
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
                  value: _selectedStatus,
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
            final bName = est['business_name'] ?? 'Commercial Business';
            final addr = est['address'] ?? 'Lingayen, Pangasinan';
            final owner = est['owner_name'] ?? 'N/A';
            final occupancy = est['occupancy_type'] ?? 'Mercantile';
            final status = est['compliance_status'] ?? est['status'] ?? 'FSIC Issued';
            final bool isDone = _isInspectionDone(status);

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
                    if (isDone) ...[
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
    final bName = est['business_name'] ?? 'Commercial Business';
    final addr = est['address'] ?? 'Lingayen, Pangasinan';
    final owner = est['owner_name'] ?? 'N/A';
    final contact = est['contact_no'] ?? 'N/A';
    final occupancy = est['occupancy_type'] ?? 'Mercantile';
    final status = est['compliance_status'] ?? est['status'] ?? 'FSIC Issued';
    final ioNo = est['inspection_order_no'] ?? 'N/A';
    final lastDate = est['last_inspection_date'] ?? 'Recent';
    final bool isDone = _isInspectionDone(status);

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
          if (isDone) ...[
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
    if (s.contains('fsic') || s.contains('pass') || s.contains('completed')) return const Color(0xFFDCFCE7);
    if (s.contains('ntcv') || s.contains('violation')) return const Color(0xFFFEE2E2);
    if (s.contains('ntc') || s.contains('comply')) return const Color(0xFFFEF3C7);
    return const Color(0xFFF1F5F9);
  }

  Color _getStatusTextColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('fsic') || s.contains('pass') || s.contains('completed')) return const Color(0xFF15803D);
    if (s.contains('ntcv') || s.contains('violation')) return const Color(0xFFB91C1C);
    if (s.contains('ntc') || s.contains('comply')) return const Color(0xFFB45309);
    return const Color(0xFF475569);
  }
}
