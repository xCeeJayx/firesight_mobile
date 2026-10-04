import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';
import 'offline_sync_service.dart';
import 'push_notification_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  UserRole _currentRole = UserRole.publicGuest;
  Map<String, dynamic>? _userProfile;
  bool _initialized = false;

  UserRole get currentRole => _currentRole;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isAuthenticated => _currentRole != UserRole.publicGuest;

  /// Keys for secure local storage caching
  static const String _keyCachedRole = 'firesight_cached_role';
  static const String _keyCachedProfile = 'firesight_cached_profile';
  static const String _keyCachedUserId = 'firesight_cached_user_id';

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Attempt restoring cached session & role for offline startup
    await _restoreCachedSession();

    // 2. Listen to Supabase auth state changes
    _client?.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        if (_client?.auth.currentUser == null) {
          _currentRole = UserRole.publicGuest;
          _userProfile = null;
          await PushNotificationService().clearTokenOnLogout();
          await PushNotificationService().updateOfficerTopicSubscription(isOfficer: false);
          await _clearCachedSession();
          notifyListeners();
        }
      } else if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.initialSession) {
        await refreshUserProfile();
        await PushNotificationService().syncTokenToSupabase();
        await PushNotificationService().updateOfficerTopicSubscription(
          isOfficer: _currentRole != UserRole.publicGuest,
        );
      }
    });
  }

  /// Restore cached session and role from FlutterSecureStorage during offline startup
  Future<void> _restoreCachedSession() async {
    try {
      final savedRoleStr = await _storage.read(key: _keyCachedRole);
      final savedProfileStr = await _storage.read(key: _keyCachedProfile);

      if (savedRoleStr != null && savedRoleStr.isNotEmpty) {
        _currentRole = UserRoleExtension.fromString(savedRoleStr);
      }

      if (savedProfileStr != null && savedProfileStr.isNotEmpty) {
        _userProfile = jsonDecode(savedProfileStr);
      }

      // If current Supabase user exists or cached session exists, retain role
      if (_client?.auth.currentUser != null) {
        await refreshUserProfile();
      } else if (_currentRole != UserRole.publicGuest) {
        PushNotificationService().updateOfficerTopicSubscription(isOfficer: true);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error restoring cached offline session: $e');
    }
  }

  Future<void> _saveCachedSession(UserRole role, Map<String, dynamic> profile) async {
    try {
      await _storage.write(key: _keyCachedRole, value: role.toDbString());
      await _storage.write(key: _keyCachedProfile, value: jsonEncode(profile));
      if (profile['id'] != null) {
        await _storage.write(key: _keyCachedUserId, value: profile['id'].toString());
      }
    } catch (e) {
      debugPrint('Error saving cached session: $e');
    }
  }

  Future<void> _clearCachedSession() async {
    try {
      await _storage.delete(key: _keyCachedRole);
      await _storage.delete(key: _keyCachedProfile);
      await _storage.delete(key: _keyCachedUserId);
    } catch (e) {
      debugPrint('Error clearing cached session: $e');
    }
  }

  /// Refreshes current user's profile and active role from Supabase 'profiles'
  Future<UserRole> refreshUserProfile() async {
    final client = _client;
    if (client == null) {
      if (_userProfile != null && _currentRole != UserRole.publicGuest) {
        return _currentRole;
      }
      return _currentRole;
    }

    final user = client.auth.currentUser;
    if (user == null) {
      // If offline but we have cached profile, retain cached profile
      if (_userProfile != null && _currentRole != UserRole.publicGuest) {
        return _currentRole;
      }
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
      var profileData = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // 2. If not found by ID, query profile by role from Supabase profiles table
      if (profileData == null) {
        profileData = await client
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
            await client.from('profiles').update({'id': user.id}).eq('role', inferredRole.toDbString());
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
          await client.from('profiles').upsert({
            'id': user.id,
            'role': inferredRole.toDbString(),
            'full_name': _userProfile!['full_name'],
            'badge_number': _userProfile!['badge_number'],
          });
        } catch (upsertError) {
          debugPrint('Profile auto-creation note: $upsertError');
        }
      }

      // Cache the refreshed profile locally for offline startup
      if (_userProfile != null) {
        await _saveCachedSession(_currentRole, _userProfile!);
      }
    } catch (e) {
      debugPrint('Network error fetching profile (Offline Fallback): $e');
      // If we already have a cached profile, use it
      if (_userProfile == null) {
        _currentRole = inferredRole;
        _userProfile = {
          'id': user.id,
          'role': inferredRole.toDbString(),
          'full_name': user.email ?? inferredRole.displayName,
          'badge_number': 'BFP-OFFLINE',
        };
      }
    }

    notifyListeners();
    return _currentRole;
  }

  /// Sign in with email and password
  Future<UserRole> signIn({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AuthException('Network service unavailable');
    }
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw const AuthException('Failed to sign in. User account not found.');
    }

    final role = await refreshUserProfile();

    // Synchronize FCM device push token to Supabase immediately upon sign in
    unawaited(PushNotificationService().syncTokenToSupabase());
    if (role != UserRole.publicGuest) {
      unawaited(PushNotificationService().updateOfficerTopicSubscription(isOfficer: true));
    }

    return role;
  }

  /// Continue as public citizen guest
  void setGuestMode() {
    _currentRole = UserRole.publicGuest;
    _userProfile = null;
    PushNotificationService().updateOfficerTopicSubscription(isOfficer: false);
    _clearCachedSession();
    notifyListeners();
  }

  /// Sign out current user
  Future<void> signOut() async {
    // 1. Immediately reset in-memory role & profile to avoid lingering state
    _currentRole = UserRole.publicGuest;
    _userProfile = null;
    notifyListeners();

    // 2. Clear cached persistent session
    try {
      await _clearCachedSession();
    } catch (e) {
      debugPrint('Clear cached session note: $e');
    }

    // 3. Unsubscribe from officer FCM topics & clear FCM token in profiles table
    try {
      await PushNotificationService().clearTokenOnLogout().timeout(const Duration(seconds: 2));
      await PushNotificationService().updateOfficerTopicSubscription(isOfficer: false).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Push notification cleanup note on signout: $e');
    }

    // 4. Remote Supabase session revocation
    final client = _client;
    if (client?.auth.currentUser != null) {
      try {
        await client?.auth.signOut().timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('Supabase sign out note: $e');
      }
    }
  }

  /// Station Officer Admin function: Create internal staff account (fire_inspector or community_risk_officer)
  Future<Map<String, dynamic>> createStaffAccount({
    required String email,
    required String password,
    required String fullName,
    required String badgeNumber,
    required UserRole role,
  }) async {
    final client = _client;
    if (client == null) {
      return {'success': false, 'error': 'Database client not connected.'};
    }
    if (_currentRole != UserRole.stationOfficer) {
      return {'success': false, 'error': 'Only Station Officers can create internal personnel accounts.'};
    }

    if (role == UserRole.publicGuest) {
      return {'success': false, 'error': 'Cannot create a guest account.'};
    }

    try {
      final response = await client.auth.signUp(
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
        await client.from('profiles').upsert({
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
    final client = _client;
    if (client == null) {
      return {'success': false, 'error': 'Database client not connected.'};
    }
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

      await client.from('profiles').update(updates).eq('id', userId);

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
    final client = _client;
    if (client == null) {
      return {'success': false, 'error': 'Database client not connected.'};
    }
    if (_currentRole != UserRole.stationOfficer) {
      return {'success': false, 'error': 'Unauthorized: Only Station Officers can toggle account status.'};
    }

    try {
      await client.from('profiles').update({
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
    final client = _client;
    if (client == null) return [];
    try {
      final response = await client.from('profiles').select().order('created_at', ascending: false);
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

  /// Write entry to Supabase audit_logs table (or local queue when offline)
  Future<void> logAuditAction({
    required String actionType,
    required String targetEntity,
    String? details,
  }) async {
    final client = _client;
    final user = client?.auth.currentUser;
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
      if (client == null) throw Exception('Client offline');
      await client.from('audit_logs').insert(logData);
    } catch (e) {
      debugPrint('Audit logging online note (Queueing locally for sync): $e');
      // Queue offline
      try {
        await OfflineSyncService().queueForSync(targetTable: 'audit_logs', payload: logData);
      } catch (queueErr) {
        debugPrint('Audit offline queueing note: $queueErr');
      }
    }
  }

  /// Fetch audit logs from Supabase with search and action type filter
  Future<List<Map<String, dynamic>>> fetchAuditLogs({
    String? searchQuery,
    String? actionFilter,
  }) async {
    final client = _client;
    if (client == null) return [];
    try {
      final response = await client
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
