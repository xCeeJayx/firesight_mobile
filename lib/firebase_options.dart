// File generated from android/app/google-services.json
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBpeG4PASpsnFNu5cEiv1QygaikvKNpKOM',
    appId: '1:897866731754:android:0f0213f9d2e3f10c82c793',
    messagingSenderId: '897866731754',
    projectId: 'firesight-pushnotif',
    storageBucket: 'firesight-pushnotif.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBpeG4PASpsnFNu5cEiv1QygaikvKNpKOM',
    appId: '1:897866731754:web:0f0213f9d2e3f10c82c793',
    messagingSenderId: '897866731754',
    projectId: 'firesight-pushnotif',
    storageBucket: 'firesight-pushnotif.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBpeG4PASpsnFNu5cEiv1QygaikvKNpKOM',
    appId: '1:897866731754:ios:0f0213f9d2e3f10c82c793',
    messagingSenderId: '897866731754',
    projectId: 'firesight-pushnotif',
    storageBucket: 'firesight-pushnotif.firebasestorage.app',
  );
}
