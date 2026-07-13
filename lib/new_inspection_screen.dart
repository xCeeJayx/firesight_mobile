import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

class NewInspectionScreen extends StatefulWidget {
  const NewInspectionScreen({super.key});

  @override
  State<NewInspectionScreen> createState() => _NewInspectionScreenState();
}

class _NewInspectionScreenState extends State<NewInspectionScreen> {
  // Theme colors
  final Color primaryColor = const Color(0xFFF95921);
  final Color successColor = const Color(0xFF10B981);
  final Color errorColor = const Color(0xFFEF4444);
  final Color bgColor = const Color(0xFFF8F9FA);
  final Color surfaceColor = Colors.white;
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color titleColor = const Color(0xFF1E293B);
  final Color subtitleColor = const Color(0xFF64748B);
  final Color inputBgColor = const Color(0xFFF1F5F9);

  // Form State
  String complianceStatus = '';
  final Map<String, String> egressStatus = {};
  final Map<String, String> systemsStatus = {};
  final Map<String, bool> violations = {
    'No fire extinguisher': false,
    'Blocked exit': false,
    'Faulty wiring': false,
    'No fire alarm': false,
    'Expired permit': false,
  };

  final List<String> _photoUrls = [];
  bool _isUploading = false;
  bool _isSubmitting = false;
  
  // Controllers
  final TextEditingController _ioTrackingCtrl = TextEditingController();
  DateTime? _dateIssued;
  DateTime? _dateInspected;
  final TextEditingController _buildingNameCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _businessNameCtrl = TextEditingController();
  final TextEditingController _natureOfBusinessCtrl = TextEditingController();
  final TextEditingController _ownerNameCtrl = TextEditingController();
  final TextEditingController _contactNumberCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();

  @override
  void dispose() {
    _ioTrackingCtrl.dispose();
    _buildingNameCtrl.dispose();
    _addressCtrl.dispose();
    _businessNameCtrl.dispose();
    _natureOfBusinessCtrl.dispose();
    _ownerNameCtrl.dispose();
    _contactNumberCtrl.dispose();
    _notesCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() {
      _locationCtrl.text = "Detecting location...";
    });

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationCtrl.text = "Location services disabled";
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationCtrl.text = "Location permissions denied";
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationCtrl.text = "Permissions permanently denied";
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      setState(() {
        _locationCtrl.text = "${position.latitude.toStringAsFixed(4)}° N, ${position.longitude.toStringAsFixed(4)}° E";
      });
    } catch (e) {
      setState(() {
        _locationCtrl.text = "Error getting location";
      });
    }
  }

  Future<void> _pickDateIssued(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _dateIssued) {
      setState(() => _dateIssued = picked);
    }
  }

  Future<void> _pickDateInspected(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _dateInspected) {
      setState(() => _dateInspected = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'New Inspection',
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: titleColor),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          _buildSectionHeader('General Information'),
          _buildGeneralInfoSection(),
          
          _buildSectionHeader('Means of Egress'),
          _buildMeansOfEgressSection(),

          _buildSectionHeader('Fire Protection Systems'),
          _buildFireProtectionSection(),

          _buildSectionHeader('Compliance & Violations'),
          _buildComplianceSection(),

          _buildSectionHeader('Photo Documentation'),
          _buildPhotoDocumentationSection(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FloatingActionButton.extended(
            onPressed: () async {
              final userId = Supabase.instance.client.auth.currentUser?.id;
              if (userId == null) return;

              setState(() => _isSubmitting = true);

              try {
                // 1. Compile the checklist JSON data
                final checklistData = {
                  'general_info': {
                    'building_name': _buildingNameCtrl.text,
                    'nature_of_business': _natureOfBusinessCtrl.text,
                    'owner_name': _ownerNameCtrl.text,
                    'contact_number': _contactNumberCtrl.text,
                  },
                  'means_of_egress': egressStatus,
                  'fire_protection_systems': systemsStatus,
                  'violations': violations,
                  'notes': _notesCtrl.text, 
                };

                // 2. Insert into Supabase
                await Supabase.instance.client.from('inspections').insert({
                  'inspector_id': userId,
                  'inspection_order_no': _ioTrackingCtrl.text,
                  'date_issued': _dateIssued?.toIso8601String(),
                  'date_inspected': _dateInspected?.toIso8601String(),
                  'business_name': _businessNameCtrl.text,
                  'address': _addressCtrl.text,
                  'overall_status': 'Completed',
                  'compliance_status': complianceStatus,
                  'checklist_data': checklistData,
                  'hazard_photo_urls': _photoUrls,
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report Submitted!'), backgroundColor: Color(0xFF10B981)),
                  );
                  Navigator.pop(context); // Go back to the dashboard
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
                  );
                }
              }
            },
            backgroundColor: primaryColor,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            label: const Text(
              'SUBMIT REPORT',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: subtitleColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGeneralInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _cardDecoration(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text('Section A', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _buildTextField('Inspection Order No.', controller: _ioTrackingCtrl),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Date Issued', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _pickDateIssued(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFFF95921)),
                        const SizedBox(width: 12),
                        Text(
                          _dateIssued == null ? 'Select Date' : '${_dateIssued!.toLocal()}'.split(' ')[0],
                          style: const TextStyle(color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Date Inspected', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _pickDateInspected(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFFF95921)),
                        const SizedBox(width: 12),
                        Text(
                          _dateInspected == null ? 'Select Date' : '${_dateInspected!.toLocal()}'.split(' ')[0],
                          style: const TextStyle(color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _buildTextField('Name of Building', controller: _buildingNameCtrl),
            const SizedBox(height: 12),
            _buildTextField('Address', controller: _addressCtrl),
            const SizedBox(height: 12),
            _buildTextField('Business Name', hintText: 'Enter name', controller: _businessNameCtrl),
            const SizedBox(height: 12),
            _buildTextField('Nature of Business', controller: _natureOfBusinessCtrl),
            const SizedBox(height: 12),
            _buildTextField('Name of Owner', controller: _ownerNameCtrl),
            const SizedBox(height: 12),
            _buildTextField('Contact Number', controller: _contactNumberCtrl),
            const SizedBox(height: 12),
            _buildTextField(
              'Location (GPS Auto-detect)',
              controller: _locationCtrl,
              readOnly: true,
              prefixIcon: Icon(Icons.location_on_outlined, color: primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeansOfEgressSection() {
    final items = [
      'Exit Doors Width',
      'Corridors Clearance',
      'Stairway Clearance',
      'Door Swing Direction',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _cardDecoration(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text('Section B', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: items.map((item) => _buildToggles(item, egressStatus)).toList(),
        ),
      ),
    );
  }

  Widget _buildFireProtectionSection() {
    final items = [
      'Automatic Fire Suppression (Sprinkler)',
      'Wet Standpipe/Hose',
      'Fire Pump',
      'Fire Detection System',
      'Fire Extinguishers',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _cardDecoration(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text('Section C', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: items.map((item) => _buildToggles(item, systemsStatus)).toList(),
        ),
      ),
    );
  }

  Widget _buildComplianceSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _cardDecoration(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text('Section D', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => complianceStatus = 'Compliant'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: complianceStatus == 'Compliant' ? const Color(0xFFD1FAE5) : surfaceColor,
                        border: Border.all(
                          color: complianceStatus == 'Compliant' ? successColor : borderColor,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, 
                              color: complianceStatus == 'Compliant' ? successColor : subtitleColor),
                          const SizedBox(width: 8),
                          Text(
                            'Compliant',
                            style: TextStyle(
                              color: complianceStatus == 'Compliant' ? successColor : subtitleColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => complianceStatus = 'Non-Compliant'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: complianceStatus == 'Non-Compliant' ? const Color(0xFFFEE2E2) : surfaceColor,
                        border: Border.all(
                          color: complianceStatus == 'Non-Compliant' ? errorColor : borderColor,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, 
                              color: complianceStatus == 'Non-Compliant' ? errorColor : subtitleColor),
                          const SizedBox(width: 8),
                          Text(
                            'Non-Compliant',
                            style: TextStyle(
                              color: complianceStatus == 'Non-Compliant' ? errorColor : subtitleColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Violations',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...violations.keys.map((key) {
              return Theme(
                data: ThemeData(
                  unselectedWidgetColor: borderColor,
                ),
                child: CheckboxListTile(
                  title: Text(
                    key,
                    style: TextStyle(color: titleColor, fontSize: 14),
                  ),
                  value: violations[key],
                  onChanged: (bool? value) {
                    setState(() {
                      violations[key] = value ?? false;
                    });
                  },
                  activeColor: primaryColor,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            _buildTextField('Notes', maxLines: 3, controller: _notesCtrl),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;
    
    setState(() => _isUploading = true);
    
    try {
      final file = File(pickedFile.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
      
      await Supabase.instance.client.storage
          .from('hazard-photos')
          .upload(fileName, file);
          
      final publicUrl = Supabase.instance.client.storage
          .from('hazard-photos')
          .getPublicUrl(fileName);
          
      setState(() {
        _photoUrls.add(publicUrl);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _buildPhotoDocumentationSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _cardDecoration(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text('Section E', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            InkWell(
              onTap: _isUploading ? null : _pickAndUploadImage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: inputBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    if (_isUploading)
                      CircularProgressIndicator(color: primaryColor)
                    else ...[
                      Icon(Icons.camera_alt_outlined, size: 32, color: subtitleColor),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to open camera',
                        style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_photoUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _photoUrls.length,
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(_photoUrls[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, {String? initialValue, String? hintText, bool readOnly = false, Widget? prefixIcon, int maxLines = 1, TextEditingController? controller}) {
    final displayHint = hintText ?? (label.toLowerCase().contains('notes') ? 'Add notes here' : 'Enter ${label.toLowerCase()}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: subtitleColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          readOnly: readOnly,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: displayHint,
            hintStyle: TextStyle(color: subtitleColor.withOpacity(0.5)),
            filled: true,
            fillColor: inputBgColor,
            prefixIcon: prefixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryColor, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggles(String label, Map<String, String> statusMap) {
    final status = statusMap[label];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSegmentButton('Pass', status, (val) => setState(() => statusMap[label] = val)),
              const SizedBox(width: 8),
              _buildSegmentButton('Fail', status, (val) => setState(() => statusMap[label] = val)),
              const SizedBox(width: 8),
              _buildSegmentButton('N/A', status, (val) => setState(() => statusMap[label] = val)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String text, String? currentStatus, Function(String) onTap) {
    final isSelected = currentStatus == text;
    Color activeColor;
    if (text == 'Pass') {
      activeColor = successColor;
    } else if (text == 'Fail') {
      activeColor = errorColor;
    } else {
      activeColor = subtitleColor;
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(text),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.1) : surfaceColor,
            border: Border.all(
              color: isSelected ? activeColor : borderColor,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? activeColor : subtitleColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
