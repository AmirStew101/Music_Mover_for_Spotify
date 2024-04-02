// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';
import 'package:spotify_music_helper/src/info/info_page.dart';
import 'package:spotify_music_helper/src/home/home_view.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/settings/settings_view.dart';
import 'package:spotify_music_helper/src/utils/auth.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';

///Side menu for Navigating the app's pages.
Drawer optionsMenu(BuildContext context){
  return Drawer(
    elevation: 16,
    width: 200,
    child: Container(
      alignment: Alignment.bottomLeft,
      child: ListView(
        children: [

          //Top Space for the side menu with the menu's title.
          DrawerHeader(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(color: spotHelperGreen),
            child: const Text(
              'Options',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            )
          ),

          //Navigate to Playlists page.
          ListTile(
            leading: const Icon(Icons.album),
            title: const Text('Playlists'),
            onTap: (){
              if (ModalRoute.of(context)?.settings.name != HomeView.routeName){
                Navigator.restorablePushNamed(context, HomeView.routeName);
              }
            },
          ),

          //Navigate to Info page.
          ListTile(
            leading: const Icon(Icons.question_mark),
            title: const Text('Info'),
            onTap: () async{
              if (ModalRoute.of(context)?.settings.name != InfoView.routeName){
                UserModel? user = await SecureStorage().getUser();
                if (user != null){
                  Map<String, dynamic> userMap = user.toJson();
                  Navigator.restorablePushNamed(context, InfoView.routeName, arguments: userMap);
                }
                else{
                  bool reLogin = true;
                  Navigator.of(context).pushReplacementNamed(StartViewWidget.routeName, arguments: reLogin);
                }
              }
            },
          ),

          //Navigate to Settings page.
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              if (ModalRoute.of(context)?.settings.name != SettingsViewWidget.routeName){
                Navigator.restorablePushNamed(context, SettingsViewWidget.routeName);
              }
            },
          ),

          //Sign out user and navigate to Start page.
          ListTile(
            leading: const Icon(Icons.switch_account),
            title: const Text('Sign Out'),
            onTap: () async{
              await SecureStorage().removeTokens();
              await SecureStorage().removeUser();
              await UserAuth().signOutUser();

              bool reLogin = true;
              Navigator.pushNamedAndRemoveUntil(context, StartViewWidget.routeName, (route) => false, arguments: reLogin);
            },
          ),

          //Exit app after user confirmation.
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Exit App'),
            onTap: () async {
              bool confirmed = false;

              await showDialog(
                context: context, 
                builder: (context) {
                  return AlertDialog.adaptive(
                    title: const Text('Sure you want to exit the App?'),
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
                exit(0);
              }
            },
          ),
        ],
      ),
    )
  );
}//OptionsMenu
