import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/ads.dart';
import 'package:spotify_music_helper/src/utils/global_classes/options_menu.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';

///App info an turtorials.
class InfoView extends StatelessWidget {
  const InfoView({required this.user, super.key});
  final Map<String, dynamic> user;
  
  static const routeName = '/Info';

  @override
  Widget build(BuildContext context) {
    UserModel userModel = UserModel().toModel(user);

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
        backgroundColor: spotHelperGreen,
        title: const Text(
          'Info Page',
          textAlign: TextAlign.center,
        ),
      ),
      drawer: optionsMenu(context),

      body: Stack(
        children: [
          ListView(
            children: [ 
              ListTile(
                title: Text(
                  'This app is to help organize your Spotify playlists faster. \nIt allows you to select multiple songs by Title or Artist, and move them to another playlist or playlists of your choice. \nYou can also delete multiple songs from a playlist of your choice.',
                  style: TextStyle(fontSize: 16, color: spotHelperGreen,),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(color: Colors.grey),

              ListTile(
                title: Text(
                    'If you have over 500 tracks first time syncing and Deep Syncs from Spotify might take a minute.',
                    style: TextStyle(fontSize: 16, color: failedRed),
                    textAlign: TextAlign.start,
                  ),
              ),
              const Divider(color: Colors.grey),

              const ListTile(
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
          ),
          if (!userModel.subscribed)
            Ads().setupAds(context, userModel)
        ],
      )
          
          
    );
      
    
  }
  
}