import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spotify_music_helper/firebase_options.dart';
import 'package:spotify_music_helper/src/utils/dev_global.dart';

import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';

bool shouldUseFirestoreEmulator = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //Firebase initialization
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = (FlutterErrorDetails errorDetails){
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  

  FirebaseAppCheck.instance.activate();

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  
  if (shouldUseFirestoreEmulator){
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  }
  
  //Google AdMob initialization
  await MobileAds.instance.initialize();
  
  FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.debug
  );

  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.
  settingsController = SettingsController(SettingsService());

  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();

  // Run the app and pass in the SettingsController. The app listens to the
  // SettingsController for changes, then passes it further down to the
  // SettingsView.
  runApp(const MyApp());
}