import 'dart:io';

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/login/spot_login_view.dart';
import 'package:spotify_music_helper/src/settings/settings_view.dart';

class StartView extends StatelessWidget {
  const StartView({super.key});

  static const routeName = 'Login_Screen';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 6, 163, 11),
        title: const Text(
          'About Spotify Helper',
          textAlign: TextAlign.center,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to the settings page. If the user leaves and returns
              // to the app after it has been killed while running in the
              // background, the navigation stack is restored.
              Navigator.restorablePushNamed(context, SettingsView.routeName);
            },
          ),
        ],
      ),
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '''Login to Spotify to start modifing your playlists faster.
              ''',
              textScaler: TextScaler.linear(2),
              textAlign: TextAlign.center,
            ),
            const Padding(padding: EdgeInsets.all(20)),

            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: [
                //Login to Spotify
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(SpotViewContainer.routeName);
                  },
                  icon: const Icon(Icons.login),
                  label: const Text(
                    'Spotify Login',
                    textScaler: TextScaler.linear(1.5),
                  )
                ),
                //Close the App
                TextButton.icon(
                  onPressed: () {
                    exit(0);
                  }, 
                  icon: const Icon(Icons.close), 
                  label: const Text(
                    'Close App',
                    textScaler: TextScaler.linear(1.5),
                  )
                )
              ],
            )
          ],
        ),
      );
  }
}
