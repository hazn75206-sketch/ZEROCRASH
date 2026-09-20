// File generated for Firebase - Zero DarkVerse (Android only)
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDcy_u9LOn1OMsSmhtKFUO1sJ2yXHFBPDw',
    appId: '1:895687496893:android:8625b7c17cf20c793c53d4',
    messagingSenderId: '895687496893',
    projectId: 'apkbugnexus-367cf',
    storageBucket: 'apkbugnexus-367cf.firebasestorage.app',
    databaseURL: 'https://apkbugnexus-367cf-default-rtdb.firebaseio.com',
  );
}
