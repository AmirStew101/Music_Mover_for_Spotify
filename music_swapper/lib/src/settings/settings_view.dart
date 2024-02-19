// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/utils/ads.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';
import 'package:spotify_music_helper/src/utils/global_classes/sync_services.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';

import 'settings_controller.dart';

/// Displays the various settings that can be customized by the user.
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
/// Users are provided multiple Sync options
/// Ad removal services are placed here

class SettingsViewWidget extends StatefulWidget{
  const SettingsViewWidget({
    required this.controller,
    super.key,
  });

  final SettingsController controller;

  static const routeName = '/settings';

  @override
  State<SettingsViewWidget> createState() => SettingsViewState();
}

class SettingsViewState extends State<SettingsViewWidget> with TickerProviderStateMixin{
  late AnimationController allController;
  late AnimationController playlistsController;
  late AnimationController tracksController;
  late ScaffoldMessengerState scaffoldMessenger;
  
  UserModel user = UserModel.defaultUser();

  bool syncingAll = false;
  bool syncingPlaylists = false;
  bool syncingTracks = false;

  String allOption = 'all';
  String tracksOption = 'tracks';
  String playlistsOption = 'playlists';

  Color textColor = Colors.white;

  @override
  void initState(){
    super.initState();

    if (!syncingAll && !syncingPlaylists && !syncingTracks){
      if (widget.controller.themeMode == ThemeMode.light){
        textColor = Colors.black;
      }

      //Animation controllers for different Sync Icons
      allController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3)
      );

      playlistsController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3)
      );

      tracksController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3)
      );
    }

  }



  @override
  void dispose(){
    //SpotifySync().stop();
    allController.dispose();
    playlistsController.dispose();
    tracksController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  Future<void> getUSer()async{
    final response = await SecureStorage().getUser();

    if (response != null){
      user = response;
    }
    else{
      bool reLogin = true;
      Navigator.of(context).pushReplacementNamed(StartViewWidget.routeName, arguments: reLogin);
      storageCheck(context, CallbackModel.defaultCall(), response);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),

        //Options menu button
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu), 
            onPressed: ()  {
              Scaffold.of(context).openDrawer();
            },
          )
        ),
        //Removes back arrow
        automaticallyImplyLeading: false,
      ),
      drawer: optionsMenu(context),
      body: Padding(
        padding: const EdgeInsets.all(20),
        // Glue the SettingsController to the theme selection DropdownButton.
        //
        // When a user selects a theme from the dropdown list, the
        // SettingsController is updated, which rebuilds the MaterialApp.
        child: Stack(
          children: [
            ListView(
              children: [
                DropdownButton<ThemeMode>(
                    style: Theme.of(context).textTheme.titleMedium,
                    iconSize: 35,
                    iconEnabledColor: const Color.fromARGB(255, 35, 177, 40),
                    isExpanded: true,
                    alignment: Alignment.center,
                    // Read the selected themeMode from the controller
                    value: widget.controller.themeMode,
                    // Call the updateThemeMode method any time the user selects a theme.
                    onChanged: widget.controller.updateThemeMode,
                    items:  const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text(
                          'System Theme',
                          textScaler: TextScaler.linear(1.1),
                        ),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text(
                          'Light Theme',
                          textScaler: TextScaler.linear(1.1),
                        ),
                      ),

                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text(
                          'Dark Theme',
                          textScaler: TextScaler.linear(1.1),
                        ),
                      )
                    ],
                  ),

                //Playlists & Tracks Sync Tile
                ListTile(
                  selected: syncingAll,
                  selectedColor: Colors.blue,
                  leading: rotatingSync(allController, allOption),
                  title: const Text(
                    'Deep Sync All Playlists & Tracks. ',
                    textScaler: TextScaler.linear(1.1),
                  ),
                  subtitle: const Text('Updates Images, Names, etc. from Spotify. Slow if you have a lot of Tracks but effective.'),
                  onTap: () async{
                    if (!syncingAll && !syncingPlaylists && !syncingPlaylists){
                      if (mounted)  allController.repeat(); //Start animation
                      syncingAll = true;
                      setState(() {});

                      await SpotifySync().startAll(allOption, scaffoldMessenger);

                      if (mounted) allController.reset(); //FInished Syncing
                      syncingTracks = false;
                      setState(() {});

                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Finished Syncing Playlists & Tracks'),
                          duration: Duration(seconds: 4),
                          backgroundColor: Color.fromARGB(255, 1, 167, 7),

                        )
                      );
                    }

                  },
                ),
                const Divider(color: Colors.grey),

                //Playlists Sync Tile
                ListTile(
                  selected: syncingPlaylists,
                  selectedColor: Colors.blue,
                  leading: rotatingSync(playlistsController, playlistsOption),
                  title: const Text(
                    'Deep Sync All Playlists',
                    textScaler: TextScaler.linear(1.1),
                  ),
                  subtitle: const Text('Updates Images and Names of Playlists'),
                  onTap: () async{
                    debugPrint('Dismissed? ${!playlistsController.isDismissed}, !syncingPlaylists: ${!syncingPlaylists}');
                    if (!syncingAll && !syncingPlaylists && !syncingPlaylists){
                      if (mounted) playlistsController.repeat(); //Start animation
                      syncingPlaylists = true;
                      setState(() {});
                      
                      await SpotifySync().startPlaylists(playlistsOption, scaffoldMessenger);
                    
                      if (mounted) playlistsController.reset(); //FInished Syncing
                      syncingPlaylists = false;
                      setState(() {});
                    }

                  },
                ),
                const Divider(color: Colors.grey),

                //Tracks Sync Tile
                ListTile(
                  selected: syncingTracks,
                  selectedColor: Colors.blue,
                  leading: rotatingSync(tracksController, tracksOption),
                  title: const Text(
                    'Deep Sync All Tracks',
                    textScaler: TextScaler.linear(1.1),
                  ),
                  subtitle: const Text('Updates all Tracks data for every Playlist. Time varies depending on how many Tracks you have.'),
                  onTap: () async{
                    if (!syncingTracks && !syncingPlaylists && !syncingAll){
                      if (mounted) tracksController.repeat(); //Start animation
                      syncingTracks = true;
                      setState(() {});

                      await SpotifySync().startTracks(tracksOption, scaffoldMessenger);
                      
                      if (mounted) tracksController.reset(); //FInished Syncing
                      syncingTracks = false;
                      setState(() {});

                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Finished Syncing Tracks'),
                          duration: Duration(seconds: 5),
                          backgroundColor: Color.fromARGB(255, 1, 167, 7),

                        )
                      );
                    }
                  },
                ),
                const Divider(color: Colors.grey),
                // if (user.subscribed)
                //   ListTile(
                //   leading: const Icon(Icons.monetization_on_rounded),
                //   title: const Text(
                //     'Cancel Subscription',
                //     textScaler: TextScaler.linear(1.1),
                //     ),
                //   onTap: () {
                //     debugPrint('Open purchase Menu');
                //   },
                // ),
                //
                // if(!user.subscribed)
                //   ListTile(
                //     leading: const Icon(Icons.monetization_on_rounded),
                //     title: const Text(
                //       '\$1 monthly subscription to remove adds',
                //       textScaler: TextScaler.linear(1.1),
                //       ),
                //     onTap: () {
                //       debugPrint('Open purchase Menu');
                //     },
                //   ),
              ]
            ),
            settingsAdRow(context, user),
          ]
        ),
      ),
    );
  }//Widget

  AnimatedBuilder rotatingSync(AnimationController controller, String option){
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: controller.value * 2 * 3.14,
          child: IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {

              if (!syncingPlaylists){
                if (option == allOption && !syncingPlaylists && !syncingTracks) syncingAll = true;
                if (option == playlistsOption && !syncingAll && !syncingTracks) syncingPlaylists = true;
                if (option == tracksOption && !syncingPlaylists && !syncingAll) syncingTracks = true;
                setState(() {}); //start rotating

                if (mounted) controller.repeat(); //Start animation
                
                await SpotifySync().startPlaylists(option, scaffoldMessenger);
              
                if (mounted) controller.reset(); // Stop animation Finished Syncing

                if (option == allOption ) syncingAll = false;
                if (option == playlistsOption) syncingPlaylists = false;
                if (option == tracksOption) syncingTracks = false;
                setState(() {}); //stop rotation
              }
            },
          ),
        );
      },
    );
  }

}//State
