import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/ads.dart';
import 'package:spotify_music_helper/src/utils/analytics.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';
import 'package:spotify_music_helper/src/utils/global_classes/options_menu.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';

///App info an turtorials.
class InfoView extends StatelessWidget {
  const InfoView({super.key});
  
  @override
  Widget build(BuildContext context) {
    AppAnalytics().trackHelpMenu();
    
    final Rx<UserModel> user = UserModel(subscribe: true).obs;
    user.update((val) => val!.subscribed = Get.arguments.subscribed ?? false);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (BuildContext context) => IconButton(
            icon: const Icon(Icons.menu), 
            onPressed: ()  {
              Scaffold.of(context).openDrawer();
            },
          )
        ),
        centerTitle: true,
        backgroundColor: spotHelperGreen,
        title: const Text(
          'Help Page',
          textAlign: TextAlign.center,
        ),
      ),
      drawer: optionsMenu(context, user.value),

      body: Stack(
        children: <Widget>[
          ListView(
            children: <Widget>[ 
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  'This app is to help organize your Spotify playlists faster. It allows you to select multiple songs by Title or Artist, and move them to another playlist or playlists of your choice. You can also delete multiple songs from a playlist of your choice.',
                  style: TextStyle(fontSize: 16, color: spotHelperGreen,),
                  textAlign: TextAlign.start,
                )
              ),
              const Divider(color: Colors.grey),

              const ListTile(
                title: Text(
                  'If a playlist is not showing in the app follow these steps:',
                  textAlign: TextAlign.start,
                ),
                subtitle: Text(
                  '''1) Open Spotify and go to the missing playlist.\n2) Click the playlist settings icon and click 'add to other playlist'.\n3) Create a new playlist.\n4) Reopen Spot Helper and click the Refresh button on the Playlists page''',
                ),
              ),
            ],
          ),
        ],
      ),

      bottomNavigationBar: Obx(() => BottomAppBar(
          height: user.value.subscribed
          ? 0
          : 70,
          child: user.value.subscribed
          ? Container()
          : Ads().setupAds(context, user.value, home: true),
        )),
          
          
    );
      
    
  }
  
}