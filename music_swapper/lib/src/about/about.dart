import 'package:flutter/material.dart';
import 'package:spotify_music_helper/utils/universal_widgets.dart';

class AboutView extends StatelessWidget {
  const AboutView({required this.multiArgs, super.key});
  final Map<String, dynamic> multiArgs;

  static const routeName = '/About';

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> callback = multiArgs['callback'];
    Map<String, dynamic> user = multiArgs['user'];

    return Scaffold(
      appBar: AppBar(
        leading: OptionsMenu(callback: callback, user: user),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 6, 163, 11),
        title: const Text(
          'About Page',
          textAlign: TextAlign.center,
        ),
      ),
      body: const Text(
        '''This app is to help organize your Spotify playlist faster. It allows you to select multiple 
        songs by your choice of Artist, Genre, Album, etc. in bulk and move them to another playlist or 
        playlists of your choice. You can also mass delete songs too.''',
        style: TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      )
    );
  }
}

