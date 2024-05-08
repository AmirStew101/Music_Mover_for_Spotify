import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:music_mover/src/info/info_page.dart';
import 'package:music_mover/src/home/home_view.dart';
import 'package:music_mover/src/login/spot_login_view.dart';
import 'package:music_mover/src/select_playlists/select_view.dart';
import 'package:music_mover/src/settings/settings_controller.dart';
import 'package:music_mover/src/settings/settings_service.dart';
import 'package:music_mover/src/tracks/tracks_view.dart';
import 'package:music_mover/src/login/start_screen.dart';
import 'package:music_mover/src/utils/auth.dart';
import 'package:music_mover/src/utils/backend_calls/database_classes.dart';
import 'package:music_mover/src/utils/backend_calls/spotify_requests.dart';
import 'package:music_mover/src/utils/backend_calls/storage.dart';
import 'package:music_mover/src/utils/dev_global.dart';
import 'package:music_mover/src/utils/exceptions.dart';

import 'src/settings/settings_view.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:music_mover/firebase_options.dart';

bool shouldUseFirestoreEmulator = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //Firebase initialization
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

  AppleProvider appleProvider = AppleProvider.appAttestWithDeviceCheckFallback;
  if(kDebugMode || kProfileMode){
    appleProvider = AppleProvider.debug;
  }
  
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: appleProvider
  );

  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = (FlutterErrorDetails errorDetails) async{
    await FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if(error is CustomException){
      FirebaseCrashlytics.instance.recordError(error.error, error.stack, fatal: error.fatal);
    }
    else{
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  
  if (shouldUseFirestoreEmulator){
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  }
  
  //Google AdMob initialization
  await MobileAds.instance.initialize();
  
  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.
  settingsController = SettingsController(SettingsService());

  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();

  await MusicMover.instance.initializeApp();

  // Run the app and pass in the SettingsController. The app listens to the
  // SettingsController for changes, then passes it further down to the
  // SettingsView.
  runApp(const MyApp());
}

class MusicMover extends GetxController{

  bool _isInitialized = false;
  final Rx<bool> _loading = false.obs;

  /// Get if the App is initialized.
  bool get isInitialized => _isInitialized;

  bool get loading{
    return _loading.value;
  }

  final DatabaseStorage _databaseStorage = DatabaseStorage.instance;
  final SpotifyRequests _spotifyRequests = SpotifyRequests.instance;
  final SecureStorage _secureStorage = SecureStorage.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Get an instance of MusicMover
  static MusicMover get instance {
    try{
      return Get.find();
    }
    catch (e){
      return Get.put(MusicMover());
    }
  }

  /// Signs out the user and removes all cached Data.
  Future<void> signOut() async{
    _loading.value = true;
    await clearCache();
    await UserAuth().signOutUser();
    _loading.value = false;
    _isInitialized = false;
  }

  // Future<void> loadingWait() async{
  //   int count = 0;
  //   await Future.doWhile(() async{
  //     count++;
  //     await Future.delayed(const Duration(seconds: 1));
  //     if(_loading.value || count >= 15){
  //       return false;
  //     }
  //     return false;
  //   });
  // }

  /// Initializes the Music Mover app by Connecting to the Database and Spotify with the current User.
  Future<bool> initializeApp() async{
    await Future.doWhile(() => _loading.value);
    
    _loading.value = true;

    try{
      await _secureStorage.getTokens();

      if(_secureStorage.secureCallback != null && _secureStorage.secureCallback!.isNotEmpty){
        // Check if the Requests are already initialized.
        final requestsInit = await _spotifyRequests.initializeRequests(callback: _secureStorage.secureCallback!);
        if(!requestsInit) return _isInitialized;

        await UserAuth().signInUser(_spotifyRequests.user.spotifyId);

        await _databaseStorage.initializeDatabase(_spotifyRequests.user);
        final databaseInit = _databaseStorage.isInitialized; 
        if(!databaseInit) return _isInitialized;
        
        _spotifyRequests.user = _databaseStorage.user;

        _isInitialized = true;
        _loading.value = false;
        return _isInitialized;
      }
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Error while trying to Initialize Music Mover');
    }

    _isInitialized = false;
    _loading.value = false;
    return _isInitialized;
  }

}

/// The Widget that configures the application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Glue the SettingsController to the MaterialApp.
    //
    // The ListenableBuilder Widget listens to the SettingsController for changes.
    // Whenever the user updates their settings, the MaterialApp is rebuilt.
    return ListenableBuilder(
      listenable: settingsController,
      builder: (BuildContext context, Widget? child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,

          // Provide the generated AppLocalizations to the MaterialApp. This
          // allows descendant Widgets to display the correct translations
          // depending on the user's locale.
          localizationsDelegates: const <LocalizationsDelegate>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[
            Locale('en', ''), // English, no country code
          ],

          // Use AppLocalizations to configure the correct application title
          // depending on the user's locale.
          //
          // The appTitle is defined in .arb files found in the localization
          // directory.
          onGenerateTitle: (BuildContext context) =>
              AppLocalizations.of(context)!.appTitle,

          // Define a light and dark color theme. Then, read the user's
          // preferred ThemeMode (light, dark, or system default) from the
          // SettingsController to display the correct theme.
          theme: ThemeData(),
          darkTheme: ThemeData.dark(),
          themeMode: settingsController.themeMode,

          initialRoute: MusicMover.instance.isInitialized ? '/' : 'start',

          // Define a function to handle named routes
          getPages: <GetPage>[
            GetPage(name: '/', page: () => const HomeView()),
            GetPage(name: '/start', page: () => const StartViewWidget()),
            GetPage(name: '/login', page: () => const SpotLoginWidget()),
            GetPage(name: '/settings', page: () => const SettingsViewWidget()),
            GetPage(name: '/playlists', page: () => const SelectPlaylistsViewWidget()),
            GetPage(name: '/tracks', page: () => const TracksView()),
            GetPage(name: '/info', page: () => const InfoView())
          ],
        );
      },
    );
  }
}
