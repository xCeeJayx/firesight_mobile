import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  UserRole _currentRole = UserRole.publicGuest;
  Map<String, dynamic>? _userProfile;
  bool _initialized = false;

  UserRole get currentRole => _currentRole;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isAuthenticated => _client.auth.currentUser != null && _currentRole != UserRole.publicGuest;

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    _client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        if (_client.auth.currentUser == null) {
          _currentRole = UserRole.publicGuest;
          _userProfile = null;
          notifyListeners();
        }
      } else if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed || event == AuthChangeEvent.initialSession) {
        await refreshUserProfile();
      }
    });
  }

  /// Refreshes current user's profile and active role from Supabase 'profiles'
  Future<UserRole> refreshUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _currentRole = UserRole.publicGuest;
      _userProfile = null;
      notifyListeners();
      return _currentRole;
    }

    final email = user.email?.toLowerCase() ?? '';
    final userRoleMeta = user.userMetadata?['role']?.toString();
    UserRole inferredRole = UserRole.fireInspector;

    if (userRoleMeta != null && userRoleMeta.isNotEmpty) {
      inferredRole = UserRoleExtension.fromString(userRoleMeta);
    } else if (email.contains('admin') || email.contains('station') || email.contains('officer')) {
      inferredRole = UserRole.stationOfficer;
    } else if (email.contains('cro') || email.contains('risk')) {
      inferredRole = UserRole.communityRiskOfficer;
    } else if (email.contains('inspector') || email.contains('fire')) {
      inferredRole = UserRole.fireInspector;
    }

    try {
      // 1. Try querying profile by exact auth user ID
      var profileData = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // 2. If not found by ID, query profile by role from Supabase profiles table
      if (profileData == null) {
        profileData = await _client
            .from('profiles')
            .select()
            .eq('role', inferredRole.toDbString())
            .maybeSingle();
      }

      if (profileData != null) {
        _userProfile = Map<String, dynamic>.from(profileData);
        _currentRole = UserRoleExtension.fromString(profileData['role']?.toString());

        // Update profile ID in Supabase to match active auth user ID
        if (profileData['id'] != user.id) {
          try {
            await _client.from('profiles').update({'id': user.id}).eq('role', inferredRole.toDbString());
            _userProfile!['id'] = user.id;
          } catch (e) {
            debugPrint('Note linking profile ID: $e');
          }
        }
      } else {
        // 3. Read metadata if present
        final String metaName = user.userMetadata?['full_name']?.toString() ?? '';
        final String metaBadge = user.userMetadata?['badge_number']?.toString() ?? '';

        _currentRole = inferredRole;
        _userProfile = {
          'id': user.id,
          'role': inferredRole.toDbString(),
          'full_name': metaName.isNotEmpty ? metaName : inferredRole.displayName,
          'badge_number': metaBadge.isNotEmpty ? metaBadge : 'BFP-PENDING',
        };

        // Provision profile record in Supabase profiles table
        try {
          await _client.from('profiles').upsert({
            'id': user.id,
            'role': inferredRole.toDbString(),
            'full_name': _userProfile!['full_name'],
            'badge_number': _userProfile!['badge_number'],
          });
        } catch (upsertError) {
          debugPrint('Profile auto-creation note: $upsertError');
        }
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      _currentRole = inferredRole;
      _userProfile = {
        'id': user.id,
        'role': inferredRole.toDbString(),
        'full_name': inferredRole == UserRole.stationOfficer
            ? 'Station Officer'
            : inferredRole == UserRole.fireInspector
                ? 'Fire Inspector'
                : 'Community Risk Officer',
        'badge_number': inferredRole == UserRole.stationOfficer
            ? 'BFP-2188'
            : inferredRole == UserRole.fireInspector
                ? 'BFP-9531'
                : 'BFP-5153',
      };
    }

    notifyListeners();
    return _currentRole;
  }

  /// Sign in with email and password
  Future<UserRole> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw const AuthException('Failed to sign in. User account not found.');
    }

    return await refreshUserProfile();
  }

  /// Continue as public citizen guest
  void setGuestMode() {
    _currentRole = UserRole.publicGuest;
    _userProfile = null;
    notifyListeners();
  }

  /// Sign out current user
  Future<void> signOut() async {
    if (_client.auth.currentUser != null) {
      await _client.auth.signOut();
    }
    _currentRole = UserRole.publicGuest;
    _userProfile = null;
    notifyListeners();
  }

  /// Station Officer Admin function: Create internal staff account (fire_inspector or community_risk_officer)
  Future<Map<String, dynamic>> createStaffAccount({
    required String email,
    required String password,
    required String fullName,
    required String badgeNumber,
    required UserRole role,
  }) async {
    if (_currentRole != UserRole.stationOfficer) {
      return {'success': false, 'error': 'Only Station Officers can create internal personnel accounts.'};
    }

    if (role == UserRole.publicGuest) {
      return {'success': false, 'error': 'Cannot create a guest account.'};
    }

    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'badge_number': badgeNumber,
          'role': role.toDbString(),
        },
      );

      final newUser = response.user;
      if (newUser != null) {
        // Upsert into profiles table
        await _client.from('profiles').upsert({
          'id': newUser.id,
          'role': role.toDbString(),
          'full_name': fullName,
          'badge_number': badgeNumber,
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Audit action
        await logAuditAction(
          actionType: 'USER_PROVISIONED',
          targetEntity: 'User: $fullName ($badgeNumber)',
          details: 'Provisioned new ${role.displayName} account with email $email',
        );

        return {'success': true, 'userId': newUser.id};
      } else {
        return {'success': false, 'error': 'Failed to create user record.'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Station Officer Admin function: Update user profile
  Future<Map<String, dynamic>> updateUserProfile({
    required String userId,
    String? fullName,
    String? badgeNumber,
    UserRole? role,
    bool? isActive,
  }) async {
    if (_currentRole != UserRole.stationOfficer) {
      return {'success': false, 'error': 'Unauthorized: Only Station Officers can edit personnel profiles.'};
    }

    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (fullName != null) updates['full_name'] = fullName;
      if (badgeNumber != null) updates['badge_number'] = badgeNumber;
      if (role != null) updates['role'] = role.toDbString();
      if (isActive != null) updates['is_active'] = isActive;

      await _client.from('profiles').update(updates).eq('id', userId);

      await logAuditAction(
        actionType: 'USER_ROLE_UPDATED',
        targetEntity: 'User ID: $userId',
        details: 'Updated profile details: ${updates.toString()}',
      );

      return {'success': true};
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Station Officer Admin function: Toggle user account active status
  Future<Map<String, dynamic>> toggleUserStatus({
    required String userId,
    required bool isActive,
    required String targetName,
  }) async {
    if (_currentRole != UserRole.stationOfficer) {
      return {'success': false, 'error': 'Unauthorized: Only Station Officers can toggle account status.'};
    }

    try {
      await _client.from('profiles').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      await logAuditAction(
        actionType: 'USER_STATUS_TOGGLED',
        targetEntity: 'User: $targetName',
        details: 'Account status set to ${isActive ? "Active" : "Inactive"}',
      );

      return {'success': true};
    } catch (e) {
      debugPrint('Error toggling user status: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetch personnel profiles from Supabase with optional search and role filter
  Future<List<Map<String, dynamic>>> fetchPersonnelProfiles({
    String? searchQuery,
    String? roleFilter,
  }) async {
    try {
      final response = await _client.from('profiles').select().order('created_at', ascending: false);
      List<Map<String, dynamic>> profiles = List<Map<String, dynamic>>.from(response);

      if (roleFilter != null && roleFilter != 'All' && roleFilter.isNotEmpty) {
        final dbRole = UserRoleExtension.fromString(roleFilter).toDbString();
        profiles = profiles.where((p) => p['role'] == dbRole).toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        profiles = profiles.where((p) {
          final name = (p['full_name'] ?? '').toString().toLowerCase();
          final badge = (p['badge_number'] ?? '').toString().toLowerCase();
          return name.contains(q) || badge.contains(q);
        }).toList();
      }

      return profiles;
    } catch (e) {
      debugPrint('Error fetching personnel profiles from Supabase: $e');
      return [];
    }
  }

  /// Write entry to Supabase audit_logs table
  Future<void> logAuditAction({
    required String actionType,
    required String targetEntity,
    String? details,
  }) async {
    final user = _client.auth.currentUser;
    final performerName = _userProfile?['full_name'] ?? user?.email ?? 'System Officer';
    final performerRole = _currentRole.toDbString();

    final logData = {
      'created_at': DateTime.now().toIso8601String(),
      'actor_id': user?.id,
      'performer_name': performerName,
      'performer_role': performerRole,
      'action_type': actionType,
      'target_entity': targetEntity,
      'details': details ?? '',
    };

    try {
      await _client.from('audit_logs').insert(logData);
    } catch (e) {
      debugPrint('Audit logging note: $e');
    }
  }

  /// Fetch audit logs from Supabase with search and action type filter
  Future<List<Map<String, dynamic>>> fetchAuditLogs({
    String? searchQuery,
    String? actionFilter,
  }) async {
    try {
      final response = await _client
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      List<Map<String, dynamic>> logs = List<Map<String, dynamic>>.from(response);

      if (actionFilter != null && actionFilter != 'All' && actionFilter.isNotEmpty) {
        logs = logs.where((l) => (l['action_type'] ?? '').toString().toUpperCase() == actionFilter.toUpperCase()).toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        logs = logs.where((l) {
          final performer = (l['performer_name'] ?? '').toString().toLowerCase();
          final action = (l['action_type'] ?? '').toString().toLowerCase();
          final target = (l['target_entity'] ?? '').toString().toLowerCase();
          final details = (l['details'] ?? '').toString().toLowerCase();
          return performer.contains(q) || action.contains(q) || target.contains(q) || details.contains(q);
        }).toList();
      }

      return logs;
    } catch (e) {
      debugPrint('Note fetching audit logs from Supabase: $e');
      return [];
    }
  }
}


