import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDRXWaaPPnOe79TAGycOQP5GpwrEoWASUU',
    appId: '1:1016968248373:web:2ef812c60a81b5550d857c',
    messagingSenderId: '1016968248373',
    projectId: 'todoapp-177c5',
    authDomain: 'todoapp-177c5.firebaseapp.com',
    storageBucket: 'todoapp-177c5.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDRXWaaPPnOe79TAGycOQP5GpwrEoWASUU',
    appId: '1:1016968248373:android:2ef812c60a81b5550d857c',
    messagingSenderId: '1016968248373',
    projectId: 'todoapp-177c5',
    storageBucket: 'todoapp-177c5.firebasestorage.app',
  );
} 