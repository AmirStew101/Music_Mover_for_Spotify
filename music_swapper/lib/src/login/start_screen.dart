import 'dart:io';

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/login/spot_login_view.dart';

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
        backgroundColor: const Color.fromARGB(255, 6, 163, 11),
        title: const Text(
          'About Spotify Helper',
          textAlign: TextAlign.center,
        ),
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
                  icon: const Icon(Icons.login),
                  label: const Text(
                    'Spotify Login',
                    textScaler: TextScaler.linear(1.5),
                  ),
                  onPressed: () {
                    debugPrint('Start View Relogin value $reLogin');
                    Navigator.of(context).pushNamed(SpotLoginWidget.routeName, arguments: reLogin);
                  },
                ),
                //Close the App
                TextButton.icon(
                  icon: const Icon(Icons.close), 
                  label: const Text(
                    'Close App',
                    textScaler: TextScaler.linear(1.5),
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
