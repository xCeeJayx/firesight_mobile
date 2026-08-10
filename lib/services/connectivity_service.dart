import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'offline_sync_service.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);

  /// Global messenger key to display top synchronization toasts across the app
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Initialize real-time connectivity listener
  void initialize() {
    _checkInitialConnectivity();

    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = _isResultOnline(results);
      isOnlineNotifier.value = _isOnline;
      if (_isOnline) {
        // Run queue check on startup if online
        OfflineSyncService().processSyncQueue();
      }
    } catch (e) {
      debugPrint('Error checking initial connectivity: $e');
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = _isResultOnline(results);
    isOnlineNotifier.value = _isOnline;

    debugPrint('Connectivity changed: results=$results, isOnline=$_isOnline, wasOnline=$wasOnline');

    // When transitioning from offline to online (none -> mobile or wifi)
    if (!wasOnline && _isOnline) {
      debugPrint('Reconnected to internet. Triggering auto-sync queue...');
      OfflineSyncService().processSyncQueue();
    }
  }

  bool _isResultOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Check whether active internet connection is available right now
  Future<bool> hasInternetConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final isBasicOnline = _isResultOnline(results);
      if (!isBasicOnline) {
        _isOnline = false;
        isOnlineNotifier.value = false;
        return false;
      }

      // Check real internet reachability with quick DNS lookup (non-web only)
      if (!kIsWeb) {
        try {
          final lookup = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
          if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
            _isOnline = true;
            isOnlineNotifier.value = true;
            return true;
          }
        } catch (_) {
          // Fallback: If lookup timed out, trust basic connection state
        }
      }

      _isOnline = isBasicOnline;
      isOnlineNotifier.value = _isOnline;
      return _isOnline;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return true; // Fallback to allow sync attempt
    }
  }

  /// Display a subtle top Toast/SnackBar for synchronization feedback
  void showSyncToast({String message = 'Offline data synchronized successfully.'}) {
    final state = scaffoldMessengerKey.currentState;
    if (state == null) {
      debugPrint('ScaffoldMessenger not attached for sync toast');
      return;
    }

    state.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A), // Forest success green
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 20),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void dispose() {
    _subscription?.cancel();
  }
}
