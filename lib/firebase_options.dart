// ARCHIVO GENERADO AUTOMÁTICAMENTE — NO EDITAR A MANO
// Ejecuta: flutterfire configure
// Este placeholder se reemplaza con las credenciales reales de Firebase.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web no soportado.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Plataforma no soportada: $defaultTargetPlatform. '
          'Ejecuta: flutterfire configure',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyACWMpSZGUzpT5a6bsqVRYcorXm5k3KMOs',
    appId: '1:378454359271:android:79fbd0fedc83eb6b197642',
    messagingSenderId: '378454359271',
    projectId: 'edutrack-family',
    storageBucket: 'edutrack-family.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyArzxjC6U2bEeveGliBWw4oeHamhhBhj-c',
    appId: '1:378454359271:ios:c12b3d92a0feda6c197642',
    messagingSenderId: '378454359271',
    projectId: 'edutrack-family',
    storageBucket: 'edutrack-family.firebasestorage.app',
    iosBundleId: 'com.example.edutrack',
  );

}