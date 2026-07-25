import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/commercial_checklist_widget.dart';

class ActiveInspectionScreen extends StatefulWidget {
  final String assignmentId;

  const ActiveInspectionScreen({
    super.key,
    required this.assignmentId,
  });

  @override
  State<ActiveInspectionScreen> createState() => _ActiveInspectionScreenState();
}

class _ActiveInspectionScreenState extends State<ActiveInspectionScreen> {
  bool _isLoading = true;
  String _ioNumber = '';
  String _businessName = '';
  String _address = '';
  String _riskLevel = 'Medium';

  // IO Consent & NTC status
  String _ownerConsentStatus = 'pending';
  String? _refusalReason;

  @override
  void initState() {
    super.initState();
    _fetchScheduledData();
  }

  Future<void> _fetchScheduledData() async {
    try {
      final response = await Supabase.instance.client
          .from('inspections')
          .select('inspection_order_no, business_name, address, risk_level, owner_consent_status, refusal_reason')
          .eq('id', widget.assignmentId)
          .maybeSingle();

      if (response != null) {
        _ioNumber = response['inspection_order_no']?.toString() ?? '';
        _businessName = response['business_name']?.toString() ?? '';
        _address = response['address']?.toString() ?? '';
        _riskLevel = response['risk_level']?.toString() ?? 'Medium';
        _ownerConsentStatus = response['owner_consent_status']?.toString() ?? 'pending';
        _refusalReason = response['refusal_reason']?.toString();
      }
    } catch (e) {
      debugPrint('Error fetching scheduled inspection: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGrantConsent() async {
    setState(() {
      _ownerConsentStatus = 'granted';
    });
    try {
      await Supabase.instance.client.from('inspections').update({
        'owner_consent_status': 'granted',
      }).eq('id', widget.assignmentId);
      _showToast('Owner consent granted!', isError: false);
    } catch (e) {
      debugPrint('Failed to update consent status: $e');
    }
  }

  Future<void> _handleRefusal() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Owner Refusal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Owner refused entry for inspection. Enter a mandatory reason to flag for FSES Head escalation.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter reason for refusal (e.g. Owner absent, Entry denied, Premises locked)...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('LOG REFUSAL', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      setState(() {
        _ownerConsentStatus = 'refused';
        _refusalReason = reason;
      });

      try {
        await Supabase.instance.client.from('inspections').update({
          'owner_consent_status': 'refused',
          'overall_status': 'refused',
          'approval_stage': 'flagged_for_fses_head',
          'refusal_reason': reason,
        }).eq('id', widget.assignmentId);

        _showToast('Inspection marked Refused & Flagged for FSES Head', isError: true);
      } catch (e) {
        _showToast('Failed to record refusal: $e', isError: true);
      }
    }
  }

  void _showToast(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildOwnerConsentCard() {
    if (_ownerConsentStatus == 'refused') {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF87171)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 20),
                SizedBox(width: 8),
                Text(
                  'ENTRY REFUSED BY OWNER',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Reason: ${_refusalReason ?? "Owner denied entry."}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF7F1D1D)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Status: Flagged for FSES Head Review',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
            ),
          ],
        ),
      );
    }

    if (_ownerConsentStatus == 'granted') {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Owner Consent Granted — Entry Authorized',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534), fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _handleRefusal,
              child: const Text('Change to Refused', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_ind_outlined, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 8),
              Text(
                'Owner Entry Consent Checklist',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Confirm owner consent prior to physical inspection assessment.',
            style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleRefusal,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('REFUSE ENTRY'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _handleGrantConsent,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('GRANT ENTRY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _businessName.isNotEmpty ? _businessName : 'Field Inspection Audit',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'IO: ${_ioNumber.isNotEmpty ? _ioNumber : widget.assignmentId}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD84315)))
          : ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                _buildOwnerConsentCard(),
                const SizedBox(height: 12),
                CommercialChecklistWidget(
                  assignmentId: widget.assignmentId,
                  initialIoNumber: _ioNumber,
                  initialBusinessName: _businessName,
                  initialAddress: _address,
                ),
              ],
            ),
    );
  }
}
