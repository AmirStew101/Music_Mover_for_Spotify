import 'dart:io';

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/login/spot_login_view.dart';
import 'package:spotify_music_helper/src/settings/settings_view.dart';

class StartView extends StatelessWidget {
  const StartView({super.key});

  static const routeName = 'SpotHelper://callback';

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
      body: const Text(
        '''This app is to help organize your Spotify playlist faster. It allows you to select multiple 
        songs by your choice of Artist, Genre, Album, etc. in bulk and move them to another playlist or 
        playlists of your choice. You can also mass delete songs too.''',
        style: TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      ),
      bottomNavigationBar: bottom(context)
    );
  }

  Widget bottom(BuildContext context) {
    return BottomNavigationBar(
        backgroundColor: const Color.fromARGB(255, 6, 163, 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.login), 
            label: 'Spotify Login'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.close), 
            label: 'Close App',
          )
        ],
        onTap: (value) async{
          if (value == 0){
            Navigator.of(context).pushNamed(SpotViewContainer.routeName);
          }
          else{
            exit(0);
          }
        },
      );
  }
}
