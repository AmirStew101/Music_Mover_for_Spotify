import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/home/home_view.dart';
import 'package:spotify_music_helper/src/settings/settings_view.dart';

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
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu), 
            onPressed: ()  {
              debugPrint('Sending to Drawer - User: $user Callback: $callback');
              Scaffold.of(context).openDrawer();
            },
          )
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 6, 163, 11),
        title: const Text(
          'About Page',
          textAlign: TextAlign.center,
        ),
      ),
      drawer: aboutOptionsMenu(callback, user, context),

      body: const Text(
        '''This app is to help organize your Spotify playlist faster. It allows you to select multiple 
        songs by your choice of Artist, Genre, Album, etc. in bulk and move them to another playlist or 
        playlists of your choice. You can also mass delete songs too.
        
        1. If you have over 500 tracks first time syncing from Spotify might take a minute
        2. If a playlist is not showing you will need to go to the playlist click the playlist settings icon and click 'add to other playlist' and create a new playlist and the app should be able to find it now
        ''',
        style: TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      )
    );
  }

    Drawer aboutOptionsMenu(Map<String, dynamic> callback, Map<String, dynamic> user, context){
    return Drawer(
      elevation: 16,
      width: 200,
      child: Container(
        alignment: Alignment.bottomLeft,
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color.fromARGB(255, 6, 163, 11)),
              child: Text(
                'Sidebar',
                style: TextStyle(fontSize: 18),
              )
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Playlists'),
              onTap: () {
                Map<String, dynamic> multiArgs = {
                'callback': callback,
                'user': user,
                };

                Navigator.restorablePushNamed(context, HomeView.routeName, arguments: multiArgs);
              },
            ),
            ListTile(
              leading: const Icon(Icons.question_mark),
              title: const Text('About'),
              onTap: () {
                Map<String, dynamic> multiArgs = {
                'callback': callback,
                'user': user,
                };
                
                Navigator.restorablePushNamed(context, AboutView.routeName, arguments: multiArgs);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.restorablePushNamed(context, SettingsView.routeName);
              },
            ),
            ListTile(
              title: const Text('Sign Out'),
              onTap: () {
                debugPrint('Sign Out Selected');
              },
            ),
          ],
        ),
      )
    );
  }
}

