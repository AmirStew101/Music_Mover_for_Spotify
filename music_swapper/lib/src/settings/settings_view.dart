// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/utils/ads.dart';
import 'package:spotify_music_helper/src/utils/auth.dart';
import 'package:spotify_music_helper/src/utils/global_classes/database_classes.dart';
import 'package:spotify_music_helper/src/utils/global_classes/options_menu.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';
import 'package:spotify_music_helper/src/utils/global_classes/sync_services.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart';

import 'settings_controller.dart';

/// Displays the various settings that can be customized by the user.
/// 
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
/// 
/// Users are provided a Sync option.
/// Support links for email and discord.
/// Option to delete their data from the database.

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
  late AnimationController syncController;
  late ScaffoldMessengerState scaffoldMessenger;
  
  UserModel user = UserModel.defaultUser();
  bool syncing = false;
  String allOption = 'all';

  @override
  void initState(){
    super.initState();
    getUser();

    if (!syncing){
      //Initializes animation controller for Sync Icon
      syncController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3)
      );
    }

  }

  @override
  void dispose(){
    //Manually diposes the sync controller.
    syncController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    //Initializes the page ScaffoldMessenger before the page is loaded in the initial state.
    scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  ///Gets the saved user from the Secure storage and Navigates to the Start page on failure.
  Future<void> getUser()async{
    final response = await SecureStorage().getUser();

    if (response != null){
      user = response;
    }
    else{
      bool reLogin = true;
      Navigator.of(context).pushReplacementNamed(StartViewWidget.routeName, arguments: reLogin);
      SecureStorage().errorCheck(const CallbackModel(), response, context: context);
    }
  }

  ///Gets the name of the current theme, and returns it as a String.
  String getThemeName(){
    switch(widget.controller.themeMode){
      case ThemeMode.system:
        return 'System Theme';
      case ThemeMode.dark:
        return 'Dark Theme';
      case ThemeMode.light:
        return 'Light Theme';
      default:
        return 'Unknown Theme';
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

                //App Theme selection Popup button
                PopupMenuButton(
                  //Current Theme's name
                  child: ListTile(
                    title: Text(
                      getThemeName(),
                      textScaler: const TextScaler.linear(1.1),
                    ),
                  ),
                  
                  //Theme options for the User to choose from
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem(
                        child: const Text(
                          'System Theme',
                          textScaler: TextScaler.linear(1.1),
                        ),
                        onTap: () => widget.controller.updateThemeMode(ThemeMode.system),
                      ),
                      PopupMenuItem(
                        child: const Text(
                          'Light Theme',
                          textScaler: TextScaler.linear(1.1),
                        ),
                        onTap: () => widget.controller.updateThemeMode(ThemeMode.light),
                      ),
                      PopupMenuItem(
                        child: const Text(
                          'Dark Theme',
                          textScaler: TextScaler.linear(1.1),
                        ),
                        onTap: () => widget.controller.updateThemeMode(ThemeMode.dark),
                      )
                    ];
                  },
                ),
                customDivider(),

                //Playlists & Tracks Sync Tile
                ListTile(
                  selected: syncing,
                  selectedColor: Colors.blue,
                  leading: rotatingSync(syncController, allOption),
                  title: const Text(
                    'Sync All Tracks',
                    textScaler: TextScaler.linear(1.1),
                  ),
                  subtitle: const Text('Updates Paylist Images, Names, & gets missing Tracks and Playlists from Spotify.'),
                  onTap: () async{
                    if (!syncing){
                      if (mounted)  syncController.repeat(); //Start animation
                      syncing = true;
                      setState(() {});

                      await SpotifySync().startSyncAllTracks(scaffoldMessenger);

                      if (mounted) syncController.reset(); //FInished Syncing
                      syncing = false;
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
                customDivider(),

                //Support email Tile
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
                customDivider(),

                //Discord link Tile
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
                customDivider(),

                //Privacy Policy Tile
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
                customDivider(),
                
                //Remove User database data Tile
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
                customDivider(),
                
                const Padding(
                  padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                ),
              ]
            ),
            
            if (!user.subscribed)
              Ads().setupAds(context, user),
          ]
        ),
      ),
    );
  }//Widget

  ///Confirmation Popup box for deleting a users database data.
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
          await UserAuth().deleteUser();
        }
        removeUserMessage(removeResponse);
      }
      catch (e){
        debugPrint('settings_view.dart line: ${getCurrentLine()} Caught Error: $e');
        removeUserMessage(-1);
      }
    }
  }


  ///Encode email creation parameters.
  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  ///Opens the Users preferred email app to send an email to the Support email.
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
    .onError((error, stackTrace) {
      throw Exception( exceptionText('settings_view.dart', 'launchEmail', error, offset: 14) );
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

              setState(() {syncing = true;}); //Start rotating

              if (mounted) controller.repeat(); //Start animation
              
              await SpotifySync().startSyncAllTracks(scaffoldMessenger);
            
              if (mounted) controller.reset(); // Stop the animation when finished Syncing and app is on the same screen

              setState(() {syncing = false;}); //stop rotation
              
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
