import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'active_inspection_screen.dart';
import 'widgets/common/status_badge.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late Future<List<Map<String, dynamic>>> _schedules;
  DateTime _selectedDate = DateTime.now();
  String _activeTab = 'All'; // All, Commercial, OLP Barangay
  String _dateFilter = 'Today'; // Today, Upcoming, All

  @override
  void initState() {
    super.initState();
    _schedules = _fetchSchedules();
  }

  Future<List<Map<String, dynamic>>> _fetchSchedules() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await Supabase.instance.client
          .from('inspections')
          .select()
          .eq('inspector_id', userId)
          .order('date_inspected', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  void _addNewScheduleDialog() {
    final businessCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final ioCtrl = TextEditingController(text: 'IO-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    String selectedRisk = 'Medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
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
                  const Text(
                    'Schedule New Inspection Order',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Inspection Order (IO) Number',
                      prefixIcon: Icon(Icons.confirmation_number_outlined, color: Color(0xFFD84315)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: businessCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Business / Establishment Name',
                      prefixIcon: Icon(Icons.business_rounded, color: Color(0xFFD84315)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address (Barangay, Street)',
                      prefixIcon: Icon(Icons.location_on_outlined, color: Color(0xFFD84315)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Risk Level: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: selectedRisk,
                        items: ['Low', 'Medium', 'High'].map((val) {
                          return DropdownMenuItem(value: val, child: Text('$val Risk'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedRisk = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final userId = Supabase.instance.client.auth.currentUser?.id;
                        if (userId == null) return;

                        final dateStr = DateTime.now().toIso8601String().split('T').first;

                        try {
                          await Supabase.instance.client.from('inspections').insert({
                            'inspector_id': userId,
                            'checklist_type': 'commercial',
                            'inspection_order_no': ioCtrl.text.isNotEmpty ? ioCtrl.text : 'IO-${DateTime.now().millisecondsSinceEpoch}',
                            'date_issued': dateStr,
                            'date_inspected': dateStr,
                            'business_name': businessCtrl.text.isNotEmpty ? businessCtrl.text : 'Establishment Inspection',
                            'address': addressCtrl.text.isNotEmpty ? addressCtrl.text : 'Lingayen, Pangasinan',
                            'overall_status': 'Pending',
                            'compliance_status': 'Pending',
                            'recommendation': 'For Inspection',
                            'risk_level': selectedRisk,
                            'score': 0,
                            'rating': 'Pending',
                          });

                          if (mounted) {
                            Navigator.pop(context);
                            setState(() {
                              _schedules = _fetchSchedules();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('New Inspection Order Scheduled!'), backgroundColor: Color(0xFF16A34A)),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error scheduling inspection: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.add_task_rounded),
                      label: const Text('CONFIRM SCHEDULE ORDER'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD84315),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewScheduleDialog,
        backgroundColor: const Color(0xFFD84315),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Schedule Audit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Header Date Strip & Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Inspection Schedule',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'BFP Fire Safety Dispatch Orders',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFFD84315)),
                      onPressed: () {
                        setState(() {
                          _schedules = _fetchSchedules();
                        });
                      },
                      tooltip: 'Refresh Schedule',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildDateStrip(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildFilterChip('Today'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Upcoming'),
                    const SizedBox(width: 8),
                    _buildFilterChip('All'),
                  ],
                ),
              ],
            ),
          ),

          // Schedule Items List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _schedules,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFD84315)));
                }

                final rawSchedules = snapshot.data ?? [];
                final nowStr = DateTime.now().toIso8601String().split('T').first;

                final filtered = rawSchedules.where((item) {
                  final status = (item['overall_status'] ?? '').toString().toLowerCase();
                  final date = (item['date_inspected'] ?? item['created_at'] ?? '').toString().split('T').first;

                  bool matchesDate = true;
                  if (_dateFilter == 'Today') {
                    matchesDate = date == nowStr || status == 'pending';
                  } else if (_dateFilter == 'Upcoming') {
                    matchesDate = date.compareTo(nowStr) >= 0;
                  }

                  return matchesDate;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.calendar_month_outlined, size: 48, color: Color(0xFF94A3B8)),
                        SizedBox(height: 12),
                        Text(
                          'No Inspections Scheduled',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap "+ Schedule Audit" to dispatch a new inspection.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _schedules = _fetchSchedules();
                    });
                  },
                  color: const Color(0xFFD84315),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _buildScheduleCard(filtered[index]);
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

  Widget _buildFilterChip(String label) {
    final isSelected = _dateFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _dateFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD84315) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDateStrip() {
    final now = DateTime.now();
    final weekDays = List.generate(7, (idx) => now.add(Duration(days: idx - 2)));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: weekDays.map((date) {
          final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;
          final isToday = date.day == now.day && date.month == now.month;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedDate = date),
              child: Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0F172A) : (isToday ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0F172A) : (isToday ? const Color(0xFFD84315) : const Color(0xFFE2E8F0)),
                    width: isToday ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      days[date.weekday % 7],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : (isToday ? const Color(0xFFD84315) : const Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final String id = schedule['id']?.toString() ?? '';
    final String businessName = schedule['business_name'] ?? 'Commercial Establishment';
    final String address = schedule['address'] ?? 'Lingayen, Pangasinan';
    final String ioNo = schedule['inspection_order_no'] ?? 'IO-${schedule['id']}';
    final String riskLevel = schedule['risk_level'] ?? 'Medium';
    final String status = schedule['overall_status'] ?? 'Pending';
    final String dateStr = schedule['date_inspected'] != null
        ? schedule['date_inspected'].toString().split('T').first
        : (schedule['created_at'] != null ? schedule['created_at'].toString().split('T').first : 'Today');

    Color riskColor = const Color(0xFFEA580C);
    if (riskLevel.toLowerCase().contains('high')) {
      riskColor = const Color(0xFFDC2626);
    } else if (riskLevel.toLowerCase().contains('low')) {
      riskColor = const Color(0xFF16A34A);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: riskColor,
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ioNo,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    StatusBadge(status: status == 'Completed' ? 'Completed' : '$riskLevel Risk'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  businessName,
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFFD84315)),
                    const SizedBox(width: 4),
                    Text(
                      'Scheduled Date: $dateStr',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFD84315), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ActiveInspectionScreen(assignmentId: id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('BEGIN FIELD AUDIT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD84315),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}