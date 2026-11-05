// From google-services.json; `flutterfire configure` can regenerate this.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return null; // Uses android/app/google-services.json.
      default:
        throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform. '
          'Run flutterfire configure.',
        );
    }
  }

  // Web reuses the Android app id; fine for Auth and Firestore.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBm1P-5FR7wiqyD-8vox0zi65jbCuuy_TM',
    appId: '1:141996700470:android:3a56e9618cb461d5597997',
    messagingSenderId: '141996700470',
    projectId: 'my-week-a229c',
    authDomain: 'my-week-a229c.firebaseapp.com',
    storageBucket: 'my-week-a229c.firebasestorage.app',
  );
}
