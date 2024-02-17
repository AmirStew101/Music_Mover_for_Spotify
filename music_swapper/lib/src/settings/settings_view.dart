// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/sync_services.dart';
import 'package:spotify_music_helper/src/utils/universal_widgets.dart';

import 'settings_controller.dart';

/// Displays the various settings that can be customized by the user.
///
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.

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
  
  bool isPressed = false;

  bool error = false;
  bool syncing = false;

  String allOption = 'all';
  String tracksOption = 'tracks';
  String playlistsOption = 'playlists';

  //Bypass sync restrictions and check every PLaylist & Track Document
  bool updateDatabase = false;

  Color textColor = Colors.white;

  @override
  void initState(){
    super.initState();

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

  @override
  void dispose(){
    SpotifySync().stop();
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
        child: ListView(
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
              leading: SpotifySync().startIcons(allController, allOption, scaffoldMessenger),
              title: const Text(
                'Deep Sync All Playlists & Tracks. ',
                textScaler: TextScaler.linear(1.1),
              ),
              subtitle: const Text('Updates Images, Names, etc. from Spotify. Slow if you have a lot of Tracks but effective.'),
              onTap: () async{
                syncing = true;
                if (syncing){
                  //Bypass sync restrictions and check every PLaylist & Track Document
                  updateDatabase = true;

                  if (!allController.isDismissed){
                    //Start animation
                    allController.repeat();
                  }

                  await SpotifySync().startAll(allOption, scaffoldMessenger);

                  if (!allController.isDismissed){
                    //FInished Syncing
                    allController.reset();
                  }

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
              leading: SpotifySync().startIcons(playlistsController, playlistsOption, scaffoldMessenger),
              title: const Text(
                'Deep Sync All Playlists',
                textScaler: TextScaler.linear(1.1),
              ),
              subtitle: const Text('Updates Images, Names, etc. of Playlists'),
              onTap: () async{
                //Fast normal sync not checking every Playlist
                updateDatabase = false;

                if (!playlistsController.isDismissed){
                  //Start animation
                  playlistsController.repeat();
                }

                await SpotifySync().startPlaylists(playlistsOption, scaffoldMessenger);

                if (!playlistsController.isDismissed){
                  //FInished Syncing
                  playlistsController.reset();
                }

                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Finished Syncing Playlists'),
                    duration: Duration(seconds: 4),
                    backgroundColor: Color.fromARGB(255, 1, 167, 7),

                  )
                );
              },
            ),
            const Divider(color: Colors.grey),

            //Tracks Sync Tile
            ListTile(
              leading: SpotifySync().syncIcons(tracksController, tracksOption, scaffoldMessenger),
              title: const Text(
                'Deep Sync All Tracks',
                textScaler: TextScaler.linear(1.1),
              ),
              subtitle: const Text('Updates all Tracks data for every Playlist. Time varies depending on how many Tracks you have.'),
              onTap: () async{
                //Fast normal sync not checking every Track
                updateDatabase = false;

                if (!tracksController.isDismissed){
                  //Start animation
                  tracksController.repeat();
                }

                await SpotifySync().startTracks(tracksOption, scaffoldMessenger);

                if (!tracksController.isDismissed){
                  //FInished Syncing
                  tracksController.reset();
                }

                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Finished Syncing Tracks'),
                    duration: Duration(seconds: 5),
                    backgroundColor: Color.fromARGB(255, 1, 167, 7),

                  )
                );
              },
            ),
            const Divider(color: Colors.grey),

            ListTile(
              leading: const Icon(Icons.monetization_on_rounded),
              title: const Text(
                '\$1 monthly subscription to remove adds',
                textScaler: TextScaler.linear(1.1),
                ),
              onTap: () {
                debugPrint('Open purchase Menu');
              },
            ),

        ]),
      ),
    );
  }//Widget

}//State
