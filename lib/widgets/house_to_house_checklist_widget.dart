import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/house_to_house_checklist_model.dart';

class HouseToHouseChecklistWidget extends StatefulWidget {
  const HouseToHouseChecklistWidget({super.key});

  @override
  State<HouseToHouseChecklistWidget> createState() => _HouseToHouseChecklistWidgetState();
}

class _HouseToHouseChecklistWidgetState extends State<HouseToHouseChecklistWidget> {
  final _model = HouseToHouseChecklistModel();

  // Color theme
  final Color primaryColor = const Color(0xFFF95921);
  final Color successColor = const Color(0xFF10B981);
  final Color warningColor = const Color(0xFFF59E0B);
  final Color errorColor = const Color(0xFFEF4444);
  final Color surfaceColor = Colors.white;
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color titleColor = const Color(0xFF1E293B);
  final Color subtitleColor = const Color(0xFF64748B);
  final Color inputBgColor = const Color(0xFFF1F5F9);

  final List<String> _photoUrls = [];
  bool _isUploading = false;
  bool _isSubmitting = false;

  final _occupantNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _suggestionsCtrl = TextEditingController();
  final _acknowledgedByCtrl = TextEditingController();

  @override
  void dispose() {
    _occupantNameCtrl.dispose();
    _addressCtrl.dispose();
    _suggestionsCtrl.dispose();
    _acknowledgedByCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(pickedFile.path);
      final fileName = 'h2h_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

      await Supabase.instance.client.storage.from('hazard-photos').upload(fileName, file);
      final publicUrl = Supabase.instance.client.storage.from('hazard-photos').getPublicUrl(fileName);

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

  Future<void> _submitReport() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSubmitting = true);

    _model.occupantName = _occupantNameCtrl.text;
    _model.address = _addressCtrl.text;
    _model.suggestions = _suggestionsCtrl.text;
    _model.acknowledgedBy = _acknowledgedByCtrl.text;

    final payloadData = _model.toJson();
    payloadData['checklist_type'] = 'house_to_house';

    try {
      await Supabase.instance.client.from('inspections').insert({
        'inspector_id': userId,
        'checklist_type': 'house_to_house',
        'inspection_order_no': 'H2H-${DateTime.now().millisecondsSinceEpoch}',
        'date_issued': DateTime.now().toIso8601String().split('T').first,
        'date_inspected': DateTime.now().toIso8601String().split('T').first,
        'business_name': _model.occupantName.isNotEmpty ? 'House of ${_model.occupantName}' : 'House Inspection',
        'address': _model.address.isNotEmpty ? _model.address : 'No address provided',
        'overall_status': 'Completed',
        'compliance_status': _model.safetyInterpretation,
        'recommendation': _model.suggestions.isNotEmpty ? _model.suggestions : _model.safetyInterpretation,
        'risk_level': _model.totalYesPoints < 12 ? 'High' : (_model.totalYesPoints < 24 ? 'Medium' : 'Low'),
        'score': _model.totalYesPoints,
        'rating': _model.safetyInterpretation,
        'checklist_data': payloadData,
        'hazard_photo_urls': _photoUrls,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('House to House Checklist Submitted!'), backgroundColor: Color(0xFF10B981)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e'), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSafetySummaryCard(),
        _buildSectionHeader('General Info'),
        _buildGeneralInfoSection(),
        _buildSectionHeader('Checklist Items'),
        _buildSectionAccordion('A. KAAYUSAN SA BAHAY', 1, 9),
        _buildSectionAccordion('B. KAAYUSAN NG ELECTRICAL', 10, 21),
        _buildSectionAccordion('C. KAAYUSAN SA KUSINA', 22, 29),
        _buildSectionAccordion('D. DAANAN O LABASAN SA BAHAY', 30, 35),
        _buildSectionHeader('Building Materials Matrix'),
        _buildMaterialsSection(),
        _buildSectionHeader('Suggestions & Recommendations'),
        _buildSuggestionsSection(),
        _buildSectionHeader('Photo Documentation'),
        _buildPhotoDocumentationSection(),
        const SizedBox(height: 24),
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildSafetySummaryCard() {
    final yesPoints = _model.totalYesPoints;
    final interpretation = _model.safetyInterpretation;

    Color badgeColor = successColor;
    if (yesPoints < 12) {
      badgeColor = errorColor;
    } else if (yesPoints < 24) {
      badgeColor = warningColor;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL YES POINTS',
                  style: TextStyle(color: subtitleColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$yesPoints / 35 Points',
                    style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              interpretation,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
      ),
    );
  }

  Widget _buildGeneralInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildTextField('Name of Household Head / Occupant', controller: _occupantNameCtrl, hint: 'e.g. Jennifer A. Simbajon'),
          const SizedBox(height: 12),
          _buildTextField('Address', controller: _addressCtrl, hint: 'e.g. Alvear St. Brgy. Poblacion, Lingayen, Pangasinan'),
        ],
      ),
    );
  }

  Widget _buildSectionAccordion(String title, int startIdx, int endIdx) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: _cardDecoration(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (int i = startIdx; i <= endIdx; i++)
              _buildCheckitemToggle(i, HouseToHouseChecklistModel.checklistItems[i] ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckitemToggle(int itemNo, String label) {
    final currentStatus = _model.itemStatuses[itemNo];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#$itemNo. $label',
            style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Row(
            children: ['YES', 'NO', 'N/A'].map((opt) {
              final isSel = currentStatus == opt;
              Color activeColor = subtitleColor;
              if (opt == 'YES') activeColor = successColor;
              if (opt == 'NO') activeColor = errorColor;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _model.itemStatuses[itemNo] = opt),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? activeColor.withOpacity(0.15) : surfaceColor,
                      border: Border.all(color: isSel ? activeColor : borderColor),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      opt,
                      style: TextStyle(
                        color: isSel ? activeColor : subtitleColor,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: HouseToHouseChecklistModel.buildingElements.map((element) {
          final selectedMaterial = _model.buildingMaterials[element];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(element, style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: HouseToHouseChecklistModel.materialOptions.map((mat) {
                    final isSel = selectedMaterial == mat;
                    return ChoiceChip(
                      label: Text(mat, style: const TextStyle(fontSize: 11)),
                      selected: isSel,
                      selectedColor: primaryColor,
                      labelStyle: TextStyle(color: isSel ? Colors.white : titleColor),
                      onSelected: (val) => setState(() => _model.buildingMaterials[element] = val ? mat : ''),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildTextField('Suggestions / Recommendations', controller: _suggestionsCtrl, maxLines: 3, hint: 'Enter safety recommendations for the household'),
          const SizedBox(height: 12),
          _buildTextField('Acknowledged By (Occupant Signature/Name)', controller: _acknowledgedByCtrl, hint: 'Enter name of acknowledging occupant'),
        ],
      ),
    );
  }

  Widget _buildPhotoDocumentationSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          InkWell(
            onTap: _isUploading ? null : _pickAndUploadImage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: inputBgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  if (_isUploading)
                    CircularProgressIndicator(color: primaryColor)
                  else ...[
                    Icon(Icons.camera_alt_outlined, size: 32, color: subtitleColor),
                    const SizedBox(height: 6),
                    Text('Tap to capture photos of house inspection', style: TextStyle(color: subtitleColor, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          if (_photoUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
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
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('SUBMIT HOUSE CHECKLIST', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, {required TextEditingController controller, String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: subtitleColor, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint ?? 'Enter $label',
            hintStyle: TextStyle(color: subtitleColor.withOpacity(0.4), fontSize: 12),
            filled: true,
            fillColor: inputBgColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor, width: 1),
    );
  }
}
