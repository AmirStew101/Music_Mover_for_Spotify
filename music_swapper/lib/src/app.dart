import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:spotify_music_helper/src/about/about.dart';
import 'package:spotify_music_helper/src/home/home_view.dart';
import 'package:spotify_music_helper/src/login/spot_login_view.dart';
import 'package:spotify_music_helper/src/select_playlists/select_playlists_view.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/src/login/login_Screen.dart';

import 'settings/settings_controller.dart';
import 'settings/settings_view.dart';

/// The Widget that configures your application.
class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.settingsController,
  });

  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    // Glue the SettingsController to the MaterialApp.
    //
    // The ListenableBuilder Widget listens to the SettingsController for changes.
    // Whenever the user updates their settings, the MaterialApp is rebuilt.
    return ListenableBuilder(
      listenable: settingsController,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          // Providing a restorationScopeId allows the Navigator built by the
          // MaterialApp to restore the navigation stack when a user leaves and
          // returns to the app after it has been killed while running in the
          // background.
          restorationScopeId: 'app',

          // Provide the generated AppLocalizations to the MaterialApp. This
          // allows descendant Widgets to display the correct translations
          // depending on the user's locale.
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
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

          // Define a function to handle named routes in order to support
          // Flutter web url navigation and deep linking.
          onGenerateRoute: (RouteSettings routeSettings) {
            return MaterialPageRoute<void>(
              settings: routeSettings,
              builder: (BuildContext context) {
                switch (routeSettings.name) {

                  //User is not signed in goes to Start page
                  case StartView.routeName:
                    bool reLogin = routeSettings.arguments as bool;
                    return StartView(reLogin: reLogin);

                  case SettingsView.routeName:
                    return SettingsView(controller: settingsController);

                  //Login to Spotify
                  case SpotLoginWidget.routeName:
                    bool reLogin = routeSettings.arguments as bool;
                    return SpotLoginWidget(reLogin: reLogin);

                  //View the users tracks
                  case TracksView.routeName:
                    final currentPlaylist = routeSettings.arguments as Map<String, dynamic>;
                    return TracksView(currentPLaylist: currentPlaylist);

                  //The Apps details page
                  case AboutViewWidget.routeName:
                    return const AboutViewWidget();

                  //Select playlists to move/add tracks to
                  case SelectPlaylistsViewWidget.routeName:
                    final multiArgs = routeSettings.arguments as Map<String, dynamic>;
                    return SelectPlaylistsViewWidget(multiArgs: multiArgs);

                  //View the users playlist
                  default:
                    return const HomeView();
                    
                }
              },
            );
          },
        );
      },
    );
  }
}
