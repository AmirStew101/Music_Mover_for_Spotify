import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/login/spot_login_view.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';

class StartViewWidget extends StatefulWidget{
  const StartViewWidget({super.key});

  @override
  State<StatefulWidget> createState() => StartViewState();
}

class StartViewState extends State<StartViewWidget> {
  bool reLogin = Get.arguments;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: spotHelperGreen,
        title: const Text(
          'About Spotify Helper',
          textAlign: TextAlign.center,
        ),
      ),
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Image.asset(
              SpotifyLogos().greenRGB,
              fit: BoxFit.scaleDown,
              scale: 0.1,
            ),
            const Text(
              'Login to start modifing your playlists faster. Move or Add multiple Tracks to multiple Playlists at once.',
              textScaler: TextScaler.linear(1.6),
              textAlign: TextAlign.center,
            ),

            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: <Widget>[

                //Login to Spotify.
                TextButton.icon(
                  icon: Icon(
                    color: spotHelperGreen,
                    Icons.login,
                  ),
                  label: Text(
                    style: TextStyle(color: spotHelperGreen),
                    'Spotify Login',
                    textScaler: const TextScaler.linear(1.5),
                  ),
                  onPressed: () => Get.to(const SpotLoginWidget(), arguments: reLogin),
                ),

                //Close the App.
                TextButton.icon(
                  icon: Icon(
                    Icons.close,
                    color: errorMessageRed,
                  ), 
                  label: Text(
                    style: TextStyle(color: errorMessageRed),
                    'Close App',
                    textScaler: const TextScaler.linear(1.5),
                  ),
                  onPressed: () {
                    exit(0);
                  }, 
                )
              ],
            )
          ],
        ),
      );
  }
}
