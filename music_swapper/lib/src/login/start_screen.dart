import 'dart:io';

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/login/spot_login_view.dart';
import 'package:spotify_music_helper/src/utils/global_classes/sync_services.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';

class StartViewWidget extends StatefulWidget{
  const StartViewWidget({
    super.key, 
    required this.reLogin}
  );

  final bool reLogin;

  static const routeName = '/Start_Screen';

  @override
  State<StatefulWidget> createState() => StartViewState();
}

class StartViewState extends State<StartViewWidget> {
  bool reLogin = false;

  @override
  void initState(){
    super.initState();
    reLogin = widget.reLogin;
  }

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
          children: [
            Image.asset(
              SpotifyLogos().greenRGB,
              fit: BoxFit.scaleDown,
              scale: 0.1,
            ),
            const Text(
              'Login to start modifing your playlists faster. Move, Add, Remove multiple Tracks to multiple Playlists at once.',
              textScaler: TextScaler.linear(1.6),
              textAlign: TextAlign.center,
            ),

            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: [
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
                  onPressed: () {
                    Navigator.of(context).pushNamed(SpotLoginWidget.routeName, arguments: reLogin);
                  },
                ),
                //Close the App
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
