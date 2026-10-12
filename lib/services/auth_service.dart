import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';
import 'emergency_service.dart';
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

  static const String supabaseUrl = 'https://lapfwiawufudxervauzc.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_6M90oMjDOdT5oXqzKpbZug_JJOO4U2k';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  UserRole _currentRole = UserRole.publicGuest;
  Map<String, dynamic>? _userProfile;
  bool _initialized = false;

  UserRole get currentRole => _currentRole;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isAuthenticated => _currentRole != UserRole.publicGuest;

  /// Checks if current authenticated account must change temporary password on first login
  bool get mustChangePassword {
    if (_currentRole == UserRole.publicGuest) return false;

    // Station Officer main administrator account is exempt unless explicitly flagged
    final email = _client?.auth.currentUser?.email?.toLowerCase() ?? '';
    if (email == 'admin@bfp.gov.ph') {
      return _userProfile?['must_change_password'] == true;
    }

    if (_userProfile != null) {
      final val = _userProfile!['must_change_password'];
      if (val == true) return true;
      if (val == false) return false;
      // If null/absent on an officer account, default to requiring password change
      return true;
    }

    final meta = _client?.auth.currentUser?.userMetadata;
    if (meta != null) {
      if (meta['must_change_password'] == true) return true;
      if (meta['must_change_password'] == false) return false;
    }

    // Default to true for any newly created officer account
    return true;
  }

  void setEffectiveRoleForSession(UserRole role) {
    if (role != UserRole.publicGuest) {
      _currentRole = role;
      notifyListeners();
    }
  }

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
        EmergencyService().resubscribeRealtime();
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

      // 2. If not found by ID, query profile by email
      if (profileData == null && email.isNotEmpty) {
        profileData = await client
            .from('profiles')
            .select()
            .eq('email', email)
            .maybeSingle();
      }

      if (profileData != null) {
        _userProfile = Map<String, dynamic>.from(profileData);
        _currentRole = UserRoleExtension.fromString(profileData['role']?.toString());

        // Update profile ID and email in Supabase to match active auth user ID
        if (profileData['id'] != user.id || profileData['email'] != user.email) {
          try {
            await client.from('profiles').update({
              'id': user.id,
              'email': user.email,
            }).eq('id', profileData['id']);
            _userProfile!['id'] = user.id;
            _userProfile!['email'] = user.email;
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
          'email': user.email,
          'role': inferredRole.toDbString(),
          'full_name': metaName.isNotEmpty ? metaName : inferredRole.displayName,
          'badge_number': metaBadge.isNotEmpty ? metaBadge : 'BFP-PENDING',
          'must_change_password': true,
        };

        // Provision profile record in Supabase profiles table
        try {
          await client.from('profiles').upsert({
            'id': user.id,
            'email': user.email,
            'role': inferredRole.toDbString(),
            'full_name': _userProfile!['full_name'],
            'badge_number': _userProfile!['badge_number'],
            'must_change_password': true,
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

    // Synchronize FCM device push token to Supabase safely without blocking auth
    try {
      unawaited(PushNotificationService().syncTokenToSupabase());
      if (role != UserRole.publicGuest) {
        unawaited(PushNotificationService().updateOfficerTopicSubscription(isOfficer: true));
      }
    } catch (e) {
      debugPrint('Post sign-in push notification setup note: $e');
    }

    return role;
  }

  /// Continue as public citizen guest
  void setGuestMode() {
    _currentRole = UserRole.publicGuest;
    _userProfile = null;
    try {
      PushNotificationService().updateOfficerTopicSubscription(isOfficer: false);
    } catch (e) {
      debugPrint('Guest mode topic subscription note: $e');
    }
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

  /// Completes mandatory first-login password change for the current authenticated officer.
  /// Updates password in Supabase Auth, updates must_change_password to false in
  /// user metadata & database profiles table, writes an audit record, and updates cached session.
  Future<Map<String, dynamic>> completeFirstLoginPasswordChange({
    required String newPassword,
  }) async {
    final client = _client;
    if (client == null) {
      return {'success': false, 'error': 'Database client not connected.'};
    }
    final user = client.auth.currentUser;
    if (user == null) {
      return {'success': false, 'error': 'No active session found.'};
    }

    try {
      // 1. Update password and user_metadata via Supabase Auth
      final response = await client.auth.updateUser(
        UserAttributes(
          password: newPassword,
          data: {'must_change_password': false},
        ),
      );

      if (response.user == null) {
        return {'success': false, 'error': 'Failed to update user credentials.'};
      }

      // 2. Update profiles table in Supabase
      try {
        await client.from('profiles').update({
          'must_change_password': false,
        }).eq('id', user.id);
      } catch (dbErr) {
        debugPrint('Warning: Could not update profiles table must_change_password: $dbErr');
      }

      // 3. Update in-memory user profile & cached storage
      if (_userProfile != null) {
        _userProfile!['must_change_password'] = false;
        await _saveCachedSession(_currentRole, _userProfile!);
      }

      // 4. Audit trail
      final name = _userProfile?['full_name'] ?? user.email ?? 'Officer';
      await logAuditAction(
        actionType: 'FIRST_LOGIN_PASSWORD_SET',
        targetEntity: 'User: $name (${user.id})',
        details: 'Officer completed mandatory first login password reset and secured account credentials.',
      );

      notifyListeners();
      return {'success': true};
    } catch (e) {
      debugPrint('Error updating password on first login: $e');
      return {'success': false, 'error': e.toString()};
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
      // Use an isolated SupabaseClient instance without session persistence
      // so the Station Officer's active login session is preserved on the admin device.
      final isolatedClient = SupabaseClient(
        supabaseUrl,
        supabaseAnonKey,
        authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      );

      final response = await isolatedClient.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'badge_number': badgeNumber,
          'role': role.toDbString(),
          'must_change_password': true,
        },
      );

      final newUser = response.user;
      if (newUser != null) {
        // Upsert into profiles table with must_change_password: true
        await client.from('profiles').upsert({
          'id': newUser.id,
          'role': role.toDbString(),
          'full_name': fullName,
          'badge_number': badgeNumber,
          'is_active': true,
          'must_change_password': true,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Audit action
        await logAuditAction(
          actionType: 'USER_PROVISIONED',
          targetEntity: 'User: $fullName ($badgeNumber)',
          details: 'Provisioned new ${role.displayName} account ($email) with temporary password. First login password reset flag set to TRUE.',
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
    bool? mustChangePassword,
  }) async {
    final client = _client;
    if (client == null) {
      return {'success': false, 'error': 'Database client not connected.'};
    }
    if (_currentRole != UserRole.stationOfficer) {
      return {'success': false, 'error': 'Unauthorized: Only Station Officers can edit personnel profiles.'};
    }

    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (badgeNumber != null) updates['badge_number'] = badgeNumber;
      if (role != null) updates['role'] = role.toDbString();
      if (isActive != null) updates['is_active'] = isActive;
      if (mustChangePassword != null) updates['must_change_password'] = mustChangePassword;

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

  /// Station Officer Admin function: Toggle require password change on next login
  Future<Map<String, dynamic>> toggleMustChangePassword({
    required String userId,
    required bool mustChange,
    required String targetName,
  }) async {
    final client = _client;
    if (client == null) {
      return {'success': false, 'error': 'Database client not connected.'};
    }
    if (_currentRole != UserRole.stationOfficer) {
      return {'success': false, 'error': 'Unauthorized: Only Station Officers can modify password requirements.'};
    }

    try {
      await client.from('profiles').update({
        'must_change_password': mustChange,
      }).eq('id', userId);

      await logAuditAction(
        actionType: 'PASSWORD_RESET_FLAG_UPDATED',
        targetEntity: 'User: $targetName',
        details: mustChange
            ? 'Station Officer required password reset on next login'
            : 'Station Officer waived password reset on next login',
      );

      return {'success': true};
    } catch (e) {
      debugPrint('Error toggling must_change_password: $e');
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
