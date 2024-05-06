// ignore_for_file: use_build_context_synchronously

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/utils/ads.dart';
import 'package:spotify_music_helper/src/utils/auth.dart';
import 'package:spotify_music_helper/src/utils/dev_global.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/database_classes.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';
import 'package:spotify_music_helper/src/utils/global_classes/options_menu.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/storage.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';


/// Displays the various settings that can be customized by the user.
/// 
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
/// 
/// Users are provided a Sync option.
/// Support links for email and discord.
/// Option to delete their data from the database.

class SettingsViewWidget extends StatefulWidget{
  const SettingsViewWidget({super.key});

  @override
  State<SettingsViewWidget> createState() => SettingsViewState();
}

class SettingsViewState extends State<SettingsViewWidget> with TickerProviderStateMixin{
  late ScaffoldMessengerState scaffoldMessenger;

  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  final DatabaseStorage _databaseStorage = Get.put(DatabaseStorage());
  final SecureStorage _secureStorage = Get.put(SecureStorage());
  
  late UserModel user;

  @override
  void initState(){
    super.initState();
    
    _crashlytics.log('Init Settings View Page');
    if(_secureStorage.secureUser == null){
      bool reLogin = true;
      Get.off(const StartViewWidget(), arguments: reLogin);
      _secureStorage.errorCheck();
    }
    else{
      user = _secureStorage.secureUser!;
    }

  }

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    //Initializes the page ScaffoldMessenger before the page is loaded in the initial state.
    scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  ///Gets the name of the current theme, and returns it as a String.
  String getThemeName(){
    _crashlytics.log('Get Theme');
    switch(settingsController.themeMode){
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

        // Options menu button
        leading: Builder(
          builder: (BuildContext context) => IconButton(
            icon: const Icon(Icons.menu), 
            onPressed: ()  {
              Scaffold.of(context).openDrawer();
            },
          )
        ),
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
          children: <Widget>[

            ListView(
              children: <Widget>[

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
                  itemBuilder: (BuildContext context) {
                    _crashlytics.log('Theme Selection');

                    return <PopupMenuItem>[
                      PopupMenuItem(
                        child: const Text(
                          'System Theme',
                          textScaler: TextScaler.linear(1.1),
                        ),
                        onTap: () => settingsController.updateThemeMode(ThemeMode.system),
                      ),
                      PopupMenuItem(
                        child: const Text(
                          'Light Theme',
                          textScaler: TextScaler.linear(1.1),
                        ),
                        onTap: () => settingsController.updateThemeMode(ThemeMode.light),
                      ),
                      PopupMenuItem(
                        child: const Text(
                          'Dark Theme',
                          textScaler: TextScaler.linear(1.1),
                        ),
                        onTap: () => settingsController.updateThemeMode(ThemeMode.dark),
                      )
                    ];
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
                    builder: (BuildContext context, followLink) {
                      return TextButton(
                        onPressed: () {
                          _crashlytics.log('Open discord link');
                          followLink;
                        }, 
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
                    builder: (BuildContext context, followLink) {
                      return TextButton(
                        onPressed: () {
                          _crashlytics.log('Open Privacy Policy');
                          followLink;
                        },
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
    _crashlytics.log('Open COnfiramtion box');

    await showDialog(
      context: context, 
      builder: (_) {
        return AlertDialog.adaptive(
          title: const Text(
            'Sure you want to delete your app data? Unrelated to Spotify data.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              onPressed: () {
                _crashlytics.log('Cancel Confirmation');
                //Close Popup
                Get.back();
              }, 
              child: const Text('Cancel')
            ),
            TextButton(
              onPressed: () {
                confirmed = true;
                _databaseStorage.updateUser(user);
                _crashlytics.log('Confirm Confirmation');
                //Close Popup
                Get.back();
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    
    if(confirmed){
      try{
        await _databaseStorage.removeUser();
        await SecureStorage().removeUser();
        await UserAuth().deleteUser();
        await PlaylistsCacheManager().clearPlaylists();
        removeUserMessage();
      }
      on CustomException catch (ee){
        removeUserMessage(success: false);
        throw CustomException(stack: ee.stack, fileName: ee.fileName, functionName: ee.functionName, reason: ee.reason, error: ee.error);
      }
      catch (error, stack){
        removeUserMessage(success: false);
        _crashlytics.recordError(error, stack, reason: 'Failed to remove user data');
      }
    }
  }


  ///Encode email creation parameters.
  String? encodeQueryParameters(Map<String, String> params) {
    _crashlytics.log('Encode Parameters');

    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  ///Opens the Users preferred email app to send an email to the Support email.
  Future<void> launchEmail() async{
    _crashlytics.log('Launch Email');
    const String supportEmail = 'spotmusicmover@gmail.com';

    final Uri supportUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: encodeQueryParameters(<String, String>{
      'subject': 'Music Mover Support',
      })
    );

    bool launched = await launchUrl(supportUri)
    .onError((Object? error, StackTrace stack) {
      _crashlytics.recordError(error, stack, reason: 'Failed to Launch email');
      return false;
    });

    if(!launched){
      Get.snackbar(
        'Error', 
        'Failed to open email',
        colorText: failedRed
      );
    }
  }


  ///Creates popup for User depending on the success or failure of removing the
  ///users data.
  void removeUserMessage({bool success = true}){
    _crashlytics.log('Remove User Message');
    
    if (success){
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
      Get.offAll(const StartViewWidget(), arguments: reLogin);
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
