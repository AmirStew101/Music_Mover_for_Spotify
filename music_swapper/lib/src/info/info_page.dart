import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:spotify_music_helper/src/utils/universal_widgets.dart';

class InfoView extends StatelessWidget {
  const InfoView({super.key});
  static const routeName = '/Info';


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu), 
            onPressed: ()  {
              Scaffold.of(context).openDrawer();
            },
          )
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 6, 163, 11),
        title: const Text(
          'Info Page',
          textAlign: TextAlign.center,
        ),
      ),
      drawer: optionsMenu(context),

      body: ListView(
        children: const [ 
          ListTile(
            title: Text(
              'This app is to help organize your Spotify playlists faster. \nIt allows you to select multiple songs by Title or Artist, and move them to another playlist or playlists of your choice. \nYou can also delete multiple songs from a playlist of your choice.',
              style: TextStyle(fontSize: 16, color: Color.fromARGB(255, 18, 202, 24)),
              textAlign: TextAlign.center,
            ),
          ),
          Divider(color: Colors.grey),

          ListTile(
            title: Text(
                'If you have over 500 tracks first time syncing and Deep Syncs from Spotify might take a minute.',
                style: TextStyle(fontSize: 16, color: Color.fromARGB(255, 219, 19, 5)),
                textAlign: TextAlign.start,
              ),
          ),
          Divider(color: Colors.grey),

          ListTile(
            title: Text(
              'If a playlist is not showing in the app follow these steps:',
              style: TextStyle(fontSize: 16, color: Colors.yellow),
              textAlign: TextAlign.start,
            ),
            subtitle: Text(
              '''1) Open Spotify and go to the missing playlist.\n2) Click the playlist settings icon and click 'add to other playlist'.\n3) Create a new playlist.\n4) Reopen Spot Helper and click the Refresh button on the Playlists page''',
              style: TextStyle(fontSize: 15, color: Colors.white),
            ),
          ),
        ],
      )
          
          
    );
      
    
  }
  
}