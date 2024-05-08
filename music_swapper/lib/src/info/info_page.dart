import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:music_mover/src/utils/ads.dart';
import 'package:music_mover/src/utils/analytics.dart';
import 'package:music_mover/src/utils/class%20models/user_model.dart';
import 'package:music_mover/src/utils/global_classes/global_objects.dart';
import 'package:music_mover/src/utils/global_classes/options_menu.dart';
import 'package:music_mover/src/utils/globals.dart';

///App info an turtorials.
class InfoView extends StatelessWidget {
  const InfoView({super.key});
  
  @override
  Widget build(BuildContext context) {
    AppAnalytics().trackHelpMenu();
    
    final Rx<UserModel> user = UserModel(subscribe: true).obs;
    user.update((val) => val!.subscribed = Get.arguments.subscribed ?? false);

    final Rx<bool> arrowUp = false.obs;
    Timer.periodic(const Duration(seconds: 3), (timer) {
      arrowUp.value = !arrowUp.value;
      if(Get.currentRoute != '/InfoView'){
        timer.cancel();
      }
    });

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

      body: ListView(
        children: <Widget>[ 
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              'This app is to help organize your Spotify playlists faster. It allows you to select multiple songs by Title or Artist, and move them to another playlist or playlists of your choice. You can also delete multiple songs from a playlist of your choice.',
              style: TextStyle(fontSize: 16, color: spotHelperGreen,),
              textAlign: TextAlign.start,
            )
          ),
          customDivider(),

          const ListTile(
            title: Text(
              'If a playlist is not showing in the app follow these steps:',
              textAlign: TextAlign.start,
            ),
            subtitle: Text(
              '''1) Open Spotify and go to the missing playlist.\n2) Click the playlist settings icon and click 'add to other playlist'.\n3) Create a new playlist.\n4) Reopen Spot Helper and click the Refresh button on the Playlists page''',
            ),
          ),
          customDivider(),

          const Text(
            'Icons/Images',
            textAlign: TextAlign.center,
            textScaler: TextScaler.linear(1.3),
            style: TextStyle(decoration: TextDecoration.underline),
          ),

          // Asc/Desc Sort icon
          ListTile(
            leading: Obx(() => Icon(
              arrowUp.value
              ? Icons.arrow_downward_sharp
              : Icons.arrow_upward_sharp
            )
            ),
            title: const Text('Ascending and Descending Sort button',),
          ),

          // Tracks Sort Icon
          const ListTile(
            leading: Icon(Icons.filter_alt),
            title: Text('Tracks/Episodes Sort button'),
          ),

          ListTile(
            leading: Image.asset(
              assetUnlikeHeart,
              height: 30,
              width: 30,
              color: Colors.green,
            ),
            title: const Text('Mark a Track that is in your Liked Songs'),
          ),
          customDivider(),

          // Tracks Help
          const Text(
            'Tracks',
            textAlign: TextAlign.center,
            textScaler: TextScaler.linear(1.3),
            style: TextStyle(decoration: TextDecoration.underline),
          ),
          const Text(
            'To view the full tracks title click on the artists name. This will open a popup where the Track/Episode title is and all the associated artists. The title & artists names are links to the Spotify track/episode and artist. While searching for a track the Artist filter button makes the search use artists names instead of track titles.',
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20,)
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