import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  final VoidCallback? onOpenProvisioning;

  const UserManagementScreen({super.key, this.onOpenProvisioning});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedRoleFilter = 'All';
  late Future<List<Map<String, dynamic>>> _usersFuture;

  final List<String> _roleFilterTabs = ['All', 'Inspectors', 'Risk Officers', 'Admins'];

  @override
  void initState() {
    super.initState();
    _refreshUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshUsers() {
    setState(() {
      _usersFuture = AuthService().fetchPersonnelProfiles(
        searchQuery: _searchController.text,
        roleFilter: _selectedRoleFilter,
      );
    });
  }

  void _showEditUserModal(Map<String, dynamic> user) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user['full_name']?.toString() ?? '');
    final badgeController = TextEditingController(text: user['badge_number']?.toString() ?? '');
    
    UserRole selectedRole = UserRoleExtension.fromString(user['role']?.toString());
    if (selectedRole == UserRole.publicGuest) {
      selectedRole = UserRole.fireInspector;
    }
    
    bool isActive = user['is_active'] ?? true;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                                  color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.manage_accounts_outlined,
                                  color: Color(0xFFEA580C),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Edit Personnel Profile',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: badgeController,
                        decoration: const InputDecoration(
                          labelText: 'Badge / Service ID',
                          prefixIcon: Icon(Icons.shield_outlined, size: 20),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter badge number' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Assigned Staff Role',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<UserRole>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.badge_outlined, size: 20),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: UserRole.fireInspector,
                            child: Text('FSIC Fire Inspector'),
                          ),
                          DropdownMenuItem(
                            value: UserRole.communityRiskOfficer,
                            child: Text('OLP Community Risk Officer'),
                          ),
                          DropdownMenuItem(
                            value: UserRole.stationOfficer,
                            child: Text('Station Officer (Admin)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedRole = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isActive ? Icons.check_circle_outline : Icons.block_outlined,
                                  color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Account Status',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      isActive ? 'Active & Authorized' : 'Inactive (Access Restricted)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Switch(
                              value: isActive,
                              activeColor: const Color(0xFF16A34A),
                              onChanged: (val) {
                                setModalState(() => isActive = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() => isSubmitting = true);

                                  final res = await AuthService().updateUserProfile(
                                    userId: user['id']?.toString() ?? '',
                                    fullName: nameController.text.trim(),
                                    badgeNumber: badgeController.text.trim(),
                                    role: selectedRole,
                                    isActive: isActive,
                                  );

                                  if (mounted) {
                                    setModalState(() => isSubmitting = false);
                                    Navigator.of(context).pop();

                                    if (res['success'] == true) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: const [
                                              Icon(Icons.check_circle_outline, color: Colors.white),
                                              SizedBox(width: 10),
                                              Text('Personnel Profile Updated Successfully'),
                                            ],
                                          ),
                                          backgroundColor: const Color(0xFF16A34A),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      _refreshUsers();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res['error'] ?? 'Failed to update profile'),
                                          backgroundColor: const Color(0xFFDC2626),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                          ),
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined, size: 20),
                          label: Text(
                            isSubmitting ? 'Saving Changes...' : 'Save Profile Updates',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmToggleStatus(Map<String, dynamic> user) {
    final bool currentStatus = user['is_active'] ?? true;
    final bool newStatus = !currentStatus;
    final String userName = user['full_name']?.toString() ?? 'Personnel Account';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                newStatus ? Icons.check_circle_outline : Icons.block_outlined,
                color: newStatus ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                newStatus ? 'Activate User' : 'Deactivate User',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            newStatus
                ? 'Are you sure you want to reactivate $userName? This will restore access to BFP mobile modules.'
                : 'Are you sure you want to deactivate $userName? The officer will no longer be able to submit field data.',
            style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: newStatus ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                final res = await AuthService().toggleUserStatus(
                  userId: user['id']?.toString() ?? '',
                  isActive: newStatus,
                  targetName: userName,
                );

                if (mounted) {
                  if (res['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Account for $userName is now ${newStatus ? "Active" : "Inactive"}.'),
                        backgroundColor: newStatus ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    _refreshUsers();
                  }
                }
              },
              child: Text(newStatus ? 'Activate Account' : 'Deactivate Account'),
            ),
          ],
        );
      },
    );
  }

  void _showProvisioningModal() {
    if (widget.onOpenProvisioning != null) {
      widget.onOpenProvisioning!();
      return;
    }

    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final fullNameController = TextEditingController();
    final badgeController = TextEditingController();
    UserRole selectedRole = UserRole.fireInspector;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                                  color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.person_add_outlined,
                                  color: Color(0xFFEA580C),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Provision New Personnel',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter full name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: badgeController,
                        decoration: const InputDecoration(
                          labelText: 'Badge / Service ID (e.g. BFP-9531)',
                          prefixIcon: Icon(Icons.shield_outlined, size: 20),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter badge number' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                        validator: (val) => val == null || !val.contains('@') ? 'Please enter valid email' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Temporary Password',
                          prefixIcon: Icon(Icons.lock_outline, size: 20),
                        ),
                        validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Assigned Officer Role',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<UserRole>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.badge_outlined, size: 20),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: UserRole.fireInspector,
                            child: Text('FSIC Fire Inspector'),
                          ),
                          DropdownMenuItem(
                            value: UserRole.communityRiskOfficer,
                            child: Text('OLP Community Risk Officer'),
                          ),
                          DropdownMenuItem(
                            value: UserRole.stationOfficer,
                            child: Text('Station Officer (Admin)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedRole = val);
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (formKey.currentState?.validate() ?? false) {
                                    setModalState(() => isSubmitting = true);

                                    final res = await AuthService().createStaffAccount(
                                      email: emailController.text.trim(),
                                      password: passwordController.text,
                                      fullName: fullNameController.text.trim(),
                                      badgeNumber: badgeController.text.trim(),
                                      role: selectedRole,
                                    );

                                    if (!mounted) return;
                                    Navigator.of(context).pop();

                                    if (res['success'] == true) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.check_circle_outline, color: Colors.white),
                                              const SizedBox(width: 10),
                                              Text('Provisioned account for ${fullNameController.text.trim()}'),
                                            ],
                                          ),
                                          backgroundColor: const Color(0xFF16A34A),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      _refreshUsers();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res['error'] ?? 'Failed to provision personnel account'),
                                          backgroundColor: const Color(0xFFDC2626),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Provision Account',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed Top Search Header & Role Tabs (Sticky / Non-scrolling)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchHeader(),
                const SizedBox(height: 12),
                _buildRoleTabs(),
              ],
            ),
          ),

          // Scrollable Personnel Cards List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refreshUsers(),
              color: const Color(0xFFEA580C),
              child: _buildUserList(scrollable: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.people_outline, color: Color(0xFFEA580C), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Personnel Directory',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'View, manage, and provision station profiles',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showProvisioningModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add User', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (_) => _refreshUsers(),
            decoration: InputDecoration(
              hintText: 'Search by Full Name or Badge Number...',
              prefixIcon: const Icon(Icons.search_outlined, color: Color(0xFF64748B)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _refreshUsers();
                      },
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: _roleFilterTabs.map((tab) {
          final isSelected = _selectedRoleFilter == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(tab),
              selected: isSelected,
              selectedColor: const Color(0xFFEA580C).withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedRoleFilter = tab;
                    _refreshUsers();
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUserList({bool scrollable = false}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Color(0xFFEA580C)),
            ),
          );
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          final emptyWidget = Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.person_search_outlined, size: 48, color: Color(0xFF94A3B8)),
                SizedBox(height: 12),
                Text(
                  'No Personnel Records Found',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 4),
                Text(
                  'Try adjusting your search criteria or role filters.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
          itemCount: users.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildUserCard(user);
          },
        );
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final String name = user['full_name']?.toString() ?? 'BFP Officer';
    final String badge = user['badge_number']?.toString() ?? 'N/A';
    final String roleStr = user['role']?.toString() ?? 'fire_inspector';
    final UserRole role = UserRoleExtension.fromString(roleStr);
    final bool isActive = user['is_active'] ?? true;

    Color roleColor;
    IconData roleIcon;
    switch (role) {
      case UserRole.stationOfficer:
        roleColor = const Color(0xFFEA580C);
        roleIcon = Icons.admin_panel_settings_outlined;
        break;
      case UserRole.fireInspector:
        roleColor = const Color(0xFFD84315);
        roleIcon = Icons.assignment_turned_in_outlined;
        break;
      case UserRole.communityRiskOfficer:
        roleColor = const Color(0xFF0F172A);
        roleIcon = Icons.map_outlined;
        break;
      case UserRole.publicGuest:
        roleColor = const Color(0xFF64748B);
        roleIcon = Icons.person_outline;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: roleColor.withValues(alpha: 0.12),
              child: Icon(roleIcon, color: roleColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActive ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            role.displayName,
                            style: TextStyle(
                              color: roleColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.shield_outlined, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'edit') {
                  _showEditUserModal(user);
                } else if (val == 'toggle') {
                  _confirmToggleStatus(user);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: const [
                      Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0F172A)),
                      SizedBox(width: 10),
                      Text('Edit Profile'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        isActive ? Icons.block_outlined : Icons.check_circle_outline,
                        size: 18,
                        color: isActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isActive ? 'Deactivate User' : 'Activate User',
                        style: TextStyle(
                          color: isActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
