import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/info/info_page.dart';
import 'package:spotify_music_helper/src/home/home_view.dart';
import 'package:spotify_music_helper/src/login/spot_login_view.dart';
import 'package:spotify_music_helper/src/select_playlists/select_view.dart';
import 'package:spotify_music_helper/src/settings/settings_controller.dart';
import 'package:spotify_music_helper/src/settings/settings_service.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/database_classes.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/spotify_requests.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/storage.dart';
import 'package:spotify_music_helper/src/utils/class%20models/callback_model.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';
import 'package:spotify_music_helper/src/utils/dev_global.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';

import 'src/settings/settings_view.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spotify_music_helper/firebase_options.dart';

bool shouldUseFirestoreEmulator = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //Firebase initialization
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  AndroidProvider androidProvider = AndroidProvider.playIntegrity;
  if(kDebugMode || kProfileMode){
    androidProvider = AndroidProvider.debug;
  }

  AppleProvider appleProvider = AppleProvider.appAttestWithDeviceCheckFallback;
  if(kDebugMode || kProfileMode){
    appleProvider = AppleProvider.debug;
  }

  await FirebaseAppCheck.instance.activate(
    androidProvider: androidProvider,
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

  /// Get if the App is initialized.
  bool get isInitialized => _isInitialized;

  /// Get an instance of MusicMover
  static MusicMover get instance {
    try{
      return Get.find();
    }
    catch (e){
      return Get.put(MusicMover());
    }
  }

  Future<void> initializeApp() async{
    UserModel? user = await SecureStorage.instance.getUser();
    CallbackModel? callback = await SecureStorage.instance.getTokens();

    if(user != null && user.isNotEmpty && callback != null && callback.isNotEmpty){
      await DatabaseStorage.instance.initializeDatabase(user);
      final databaseInit = DatabaseStorage.instance.isInitialized; 
      if(!databaseInit) return;

      user = DatabaseStorage.instance.user;

      final requestsInit = await SpotifyRequests.instance.initializeRequests(callback: callback, savedUser: user);
      if(!requestsInit) return;

      await SecureStorage.instance.saveUser(SpotifyRequests.instance.user);

      _isInitialized = true;
    }
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
            GetPage(name: '/info', page: () => const InfoView()),
          ],
        );
      },
    );
  }
}
