import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'active_inspection_screen.dart';

class TaskDashboard extends StatefulWidget {
  const TaskDashboard({super.key});

  @override
  State<TaskDashboard> createState() => _TaskDashboardState();
}

class _TaskDashboardState extends State<TaskDashboard> {
  late Future<List<Map<String, dynamic>>> _pendingInspections;

  @override
  void initState() {
    super.initState();
    _pendingInspections = _fetchPendingInspections();
  }

  Future<List<Map<String, dynamic>>> _fetchPendingInspections() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User is not authenticated');
    }

    final response = await Supabase.instance.client
        .from('inspections')
        .select()
        .eq('inspector_id', userId)
        .eq('overall_status', 'Pending')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _refreshInspections() async {
    setState(() {
      _pendingInspections = _fetchPendingInspections();
    });
  }

  void _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Pending Tasks',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF10B981),
        backgroundColor: const Color(0xFF1E293B),
        onRefresh: _refreshInspections,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _pendingInspections,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF10B981)),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load tasks.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshInspections,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final inspections = snapshot.data ?? [];

            if (inspections.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, color: const Color(0xFF10B981).withOpacity(0.5), size: 80),
                    const SizedBox(height: 24),
                    const Text(
                      'All caught up!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No pending inspections assigned to you.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              itemCount: inspections.length,
              itemBuilder: (context, index) {
                final inspection = inspections[index];
                return _buildInspectionCard(context, inspection);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildInspectionCard(BuildContext context, Map<String, dynamic> inspection) {
    final String id = inspection['id']?.toString() ?? '';
    final String businessName = inspection['business_name'] ?? 'Unknown Business';
    final String address = inspection['address'] ?? 'No Address Provided';
    final String ioNumber = inspection['inspection_order_number'] ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ActiveInspectionScreen(assignmentId: id),
              ),
            );
          },
          highlightColor: const Color(0xFF10B981).withOpacity(0.1),
          splashColor: const Color(0xFF10B981).withOpacity(0.2),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B), // Dark container frame
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF334155), // Subtle outline
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4), // Deep ambient shadow
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.05), // Very faint emerald glow
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        'IO: $ioNumber',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFF475569),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  businessName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF94A3B8),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
