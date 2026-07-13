import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'models/bfp_checklist_model.dart';

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
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  
  late BfpChecklistModel _checklistData;
  List<String> _hazardPhotoUrls = [];

  // Controllers for General Information
  final _businessNameController = TextEditingController();
  final _ownersNameController = TextEditingController();
  final _ioTrackingController = TextEditingController();
  final _contactNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownersNameController.dispose();
    _ioTrackingController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final response = await Supabase.instance.client
          .from('inspections')
          .select('checklist_data, hazard_photo_urls')
          .eq('id', widget.assignmentId)
          .maybeSingle();

      if (response != null) {
        if (response['checklist_data'] != null) {
          _checklistData = BfpChecklistModel.fromJson(response['checklist_data']);
        } else {
          _checklistData = BfpChecklistModel();
        }

        if (response['hazard_photo_urls'] != null) {
          _hazardPhotoUrls = List<String>.from(response['hazard_photo_urls']);
        }
      } else {
        _checklistData = BfpChecklistModel();
      }

      // Initialize controllers with fetched data
      _businessNameController.text = _checklistData.generalInfo.businessName ?? '';
      _ownersNameController.text = _checklistData.generalInfo.ownersName ?? '';
      _ioTrackingController.text = _checklistData.generalInfo.ioTrackingNumber ?? '';
      _contactNumberController.text = _checklistData.generalInfo.contactNumber ?? '';

    } catch (e) {
      _showToast('Failed to load inspection data: $e', isError: true);
      _checklistData = BfpChecklistModel();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveChecklistData() async {
    setState(() {
      _isSaving = true;
    });

    // Update model with text fields before saving
    _checklistData.generalInfo.businessName = _businessNameController.text;
    _checklistData.generalInfo.ownersName = _ownersNameController.text;
    _checklistData.generalInfo.ioTrackingNumber = _ioTrackingController.text;
    _checklistData.generalInfo.contactNumber = _contactNumberController.text;

    try {
      await Supabase.instance.client
          .from('inspections')
          .update({'checklist_data': _checklistData.toJson()})
          .eq('id', widget.assignmentId);

      _showToast('Checklist saved successfully!', isError: false);
    } catch (e) {
      _showToast('Failed to save checklist: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _captureAndUploadPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile == null) return;

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final file = File(pickedFile.path);
      final fileName = '${widget.assignmentId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Upload to Supabase Storage bucket named 'hazard-photos'
      await Supabase.instance.client.storage
          .from('hazard-photos')
          .upload(fileName, file);

      // Get the public URL
      final publicUrl = Supabase.instance.client.storage
          .from('hazard-photos')
          .getPublicUrl(fileName);

      // Append to our local state list
      setState(() {
        _hazardPhotoUrls.add(publicUrl);
      });

      // Update the text array column in the inspections table
      await Supabase.instance.client
          .from('inspections')
          .update({'hazard_photo_urls': _hazardPhotoUrls})
          .eq('id', widget.assignmentId);

      _showToast('Photo uploaded successfully!', isError: false);
    } catch (e) {
      _showToast('Failed to upload photo: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  void _showToast(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('BFP Inspection Checklist', style: TextStyle(fontSize: 18)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : ListView(
              padding: const EdgeInsets.only(bottom: 100), // Padding for FAB
              children: [
                _buildGeneralInformationSection(),
                _buildMeansOfEgressSection(),
                _buildFireProtectionSystemsSection(),
                _buildPhotoDocumentationSection(),
              ],
            ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _isSaving ? null : _saveChecklistData,
              backgroundColor: const Color(0xFFEF4444),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isSaving ? 'SAVING...' : 'SAVE CHECKLIST',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
    );
  }

  Widget _buildGeneralInformationSection() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        iconColor: const Color(0xFF10B981),
        collapsedIconColor: Colors.white70,
        title: const Text(
          'General Information',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildTextField(label: 'Business Name', controller: _businessNameController, icon: Icons.business),
          const SizedBox(height: 16),
          _buildTextField(label: 'Owners Name', controller: _ownersNameController, icon: Icons.person),
          const SizedBox(height: 16),
          _buildTextField(label: 'IO Tracking Number', controller: _ioTrackingController, icon: Icons.assignment),
          const SizedBox(height: 16),
          _buildTextField(label: 'Contact Number', controller: _contactNumberController, icon: Icons.phone, isPhone: true),
        ],
      ),
    );
  }

  Widget _buildMeansOfEgressSection() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        iconColor: const Color(0xFF10B981),
        collapsedIconColor: Colors.white70,
        title: const Text(
          'Means of Egress',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildStatusToggle(
            title: 'Exit Doors Width (Compliance)',
            currentValue: _checklistData.meansOfEgress.exitDoorsWidth,
            onChanged: (val) => setState(() => _checklistData.meansOfEgress.exitDoorsWidth = val),
          ),
          _buildStatusToggle(
            title: 'Corridors Clearance',
            currentValue: _checklistData.meansOfEgress.corridorsClearance,
            onChanged: (val) => setState(() => _checklistData.meansOfEgress.corridorsClearance = val),
          ),
          _buildStatusToggle(
            title: 'Stairway Clearance',
            currentValue: _checklistData.meansOfEgress.stairwayClearance,
            onChanged: (val) => setState(() => _checklistData.meansOfEgress.stairwayClearance = val),
          ),
        ],
      ),
    );
  }

  Widget _buildFireProtectionSystemsSection() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        iconColor: const Color(0xFF10B981),
        collapsedIconColor: Colors.white70,
        title: const Text(
          'Fire Protection Systems',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildStatusToggle(
            title: 'Fire Alarms & Detection',
            currentValue: _checklistData.fireProtectionSystems.fireAlarms,
            onChanged: (val) => setState(() => _checklistData.fireProtectionSystems.fireAlarms = val),
          ),
          _buildStatusToggle(
            title: 'Extinguisher Pressure Logs',
            currentValue: _checklistData.fireProtectionSystems.extinguisherPressureLogs,
            onChanged: (val) => setState(() => _checklistData.fireProtectionSystems.extinguisherPressureLogs = val),
          ),
          _buildStatusToggle(
            title: 'Sprinkler Infrastructure',
            currentValue: _checklistData.fireProtectionSystems.sprinklerInfrastructure,
            onChanged: (val) => setState(() => _checklistData.fireProtectionSystems.sprinklerInfrastructure = val),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoDocumentationSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Photo Documentation of Fire Hazards',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          // Grid of photos
          if (_hazardPhotoUrls.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _hazardPhotoUrls.length,
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF334155)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.network(
                      _hazardPhotoUrls[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFF10B981)),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.broken_image, color: Colors.white54),
                        );
                      },
                    ),
                  ),
                );
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Center(
                child: Text(
                  'No hazard photos captured yet.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ),
            ),
          const SizedBox(height: 24),
          // Capture button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUploadingPhoto ? null : _captureAndUploadPhoto,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.5)),
                ),
                elevation: 4,
              ),
              icon: _isUploadingPhoto
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2))
                  : const Icon(Icons.camera_alt, size: 24),
              label: Text(
                _isUploadingPhoto ? 'UPLOADING...' : 'CAPTURE PHOTO',
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool isPhone = false,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: const Color(0xFF10B981).withOpacity(0.8)),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildStatusToggle({
    required String title,
    required CheckStatus? currentValue,
    required Function(CheckStatus?) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          SegmentedButton<CheckStatus>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: CheckStatus.pass,
                label: Text('Pass', style: TextStyle(fontSize: 13)),
                icon: Icon(Icons.check, size: 18),
              ),
              ButtonSegment(
                value: CheckStatus.fail,
                label: Text('Fail', style: TextStyle(fontSize: 13)),
                icon: Icon(Icons.close, size: 18),
              ),
              ButtonSegment(
                value: CheckStatus.notApplicable,
                label: Text('N/A', style: TextStyle(fontSize: 13)),
                icon: Icon(Icons.remove, size: 18),
              ),
            ],
            selected: currentValue != null ? {currentValue} : {},
            onSelectionChanged: (Set<CheckStatus> selection) {
              if (selection.isEmpty) {
                onChanged(null);
              } else {
                onChanged(selection.first);
              }
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                if (states.contains(MaterialState.selected)) {
                  if (currentValue == CheckStatus.pass) return const Color(0xFF10B981).withOpacity(0.3);
                  if (currentValue == CheckStatus.fail) return const Color(0xFFEF4444).withOpacity(0.3);
                  return Colors.white.withOpacity(0.2); // N/A state
                }
                return const Color(0xFF0F172A); // Unselected background
              }),
              foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                if (states.contains(MaterialState.selected)) {
                  if (currentValue == CheckStatus.pass) return const Color(0xFF10B981);
                  if (currentValue == CheckStatus.fail) return const Color(0xFFEF4444);
                  return Colors.white;
                }
                return Colors.white54;
              }),
              side: MaterialStateProperty.all(BorderSide(color: Colors.white.withOpacity(0.1))),
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
