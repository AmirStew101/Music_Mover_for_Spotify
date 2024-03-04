// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/utils/ads.dart';
import 'package:spotify_music_helper/src/utils/global_classes/database_classes.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';
import 'package:spotify_music_helper/src/utils/global_classes/sync_services.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> getUser()async{
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
                    iconEnabledColor: spotHelperGreen,
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

                  const SizedBox(height: 10,),

                //Playlists & Tracks Sync Tile
                ListTile(
                  selected: syncingAll,
                  selectedColor: Colors.blue,
                  leading: rotatingSync(allController, allOption),
                  title: const Text(
                    'Sync All Playlists & Tracks. ',
                    textScaler: TextScaler.linear(1.1),
                  ),
                  subtitle: const Text('Updates Paylist Images, Names, & gets missing Tracks and Playlists from Spotify.'),
                  onTap: () async{
                    if (!syncingAll && !syncingPlaylists && !syncingPlaylists){
                      if (mounted)  allController.repeat(); //Start animation
                      syncingAll = true;
                      setState(() {});

                      await SpotifySync().startAll(allOption, scaffoldMessenger);

                      if (mounted) allController.reset(); //FInished Syncing
                      syncingAll = false;
                      setState(() {});

                      scaffoldMessenger.showSnackBar(
                       SnackBar(
                          content: const Text('Finished Syncing Playlists & Tracks'),
                          duration: const Duration(seconds: 4),
                          backgroundColor: spotHelperGreen,

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
                    'Sync All Playlists',
                    textScaler: TextScaler.linear(1.1),
                  ),
                  subtitle: const Text('Updates Images and Names of Playlists'),
                  onTap: () async{
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
                    'Sync All Tracks',
                    textScaler: TextScaler.linear(1.1),
                  ),
                  subtitle: const Text('Retreives any missing tracks for all your playlists.'),
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
                         SnackBar(
                          content: const Text('Finished Syncing Tracks'),
                          duration: const Duration(seconds: 5),
                          backgroundColor: spotHelperGreen,
                        )
                      );
                    }
                  },
                ),
                const Divider(color: Colors.grey),

                ListTile(
                  leading: const Text(
                    'Email:',
                    textScaler: TextScaler.linear(1.3),
                  ),
                  title: TextButton(
                    onPressed: () async => await launchEmail(),
                    child: Text(
                      'spotmusicmover@gmail.com',
                      textScaler: const TextScaler.linear(1.1),
                      style: TextStyle(color: linkBlue),
                    ),
                  ),
                ),
                const Divider(color: Colors.grey),

                ListTile(
                  title: Link(
                    uri: Uri.parse('https://discord.gg/2nRRFtkrhd'), 
                    builder: (context, followLink) {
                      return TextButton(
                        onPressed: followLink, 
                        child: Text(
                          'Discord Link',
                          textScaler: const TextScaler.linear(1.1),
                          style: TextStyle(color: linkBlue),
                        )
                      );
                    },
                  ),
                ),
                const Divider(color: Colors.grey),

                ListTile(
                  title: Link(
                    uri: Uri.parse('https://spot-helper-1688d.firebaseapp.com'), 
                    builder: (context, followLink) {
                      return TextButton(
                        onPressed: followLink,
                        child: Text(
                          'Privacy Policy',
                          textScaler: const TextScaler.linear(1.1),
                          style: TextStyle(color: linkBlue),
                        )
                      );
                    },
                  ),
                ),
                const Divider(color: Colors.grey),
                
                ListTile(
                  title: TextButton(
                    onPressed: () async => await confirmationBox(),
                    child: Text(
                      'Delete Stored App Data',
                      textScaler: const TextScaler.linear(1.1),
                      style: TextStyle(color: failedRed),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

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
                const SizedBox(height: 10),
              ]
            ),
            settingsAdRow(context, user),
          ]
        ),
      ),
    );
  }//Widget

  Future<void> confirmationBox() async{
    bool confirmed = false;
    debugPrint('Remove data');

    await showDialog(
      context: context, 
      builder: (context) {
        return AlertDialog.adaptive(
          title: const Text('Sure you want to delete your app data? Unrelated to Spotify data.'),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                //Close Popup
                Navigator.of(context).pop();
              }, 
              child: const Text('Cancel')
            ),
            TextButton(
              onPressed: () {
                confirmed = true;
                //Close Popup
                Navigator.of(context).pop();
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    
    if(confirmed){
      await getUser();
      try{
        int removeResponse = await DatabaseStorage().removeUser(user);
        if (removeResponse == 0){
          await SecureStorage().removeUser();
        }
        removeUserMessage(removeResponse);
      }
      catch (e){
        debugPrint('settings_view.dart line: ${getCurrentLine()} Caught Error: $e');
        removeUserMessage(-1);
      }
    }
  }

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> launchEmail() async{
    const supportEmail = 'spotmusicmover@gmail.com';

    final supportUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: encodeQueryParameters(<String, String>{
      'subject': 'Music Mover Support',
      })
    );
    debugPrint('Uri: ${supportUri.toString()}');

    await launchUrl(supportUri)
    .catchError((e) {
      throw Exception('Failed to launch email $e');
    });

  }

  ///Animation Builder for the Sync Icons to rotate requiring [AnimationController] and [String] of which 
  ///Sync Icon to rotate.
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

  ///Creates popup for User depending on the success or failure of removing the
  ///users data.
  void removeUserMessage(int code){
    if (code == 0){
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Successfully Removed User Data',
            style: TextStyle(color: spotHelperGreen),
          ),
          duration: const Duration(seconds: 4),
        )
      );
      bool reLogin = true;
      Navigator.of(context).pushReplacementNamed(StartViewWidget.routeName, arguments: reLogin);
    }
    else{
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Failed to Removed User Data',
            style: TextStyle(color: failedRed),
          ),
          duration: const Duration(seconds: 4),
        )
      );
    }
  }

}//State
