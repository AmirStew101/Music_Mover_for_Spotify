// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/storage.dart';
import 'package:spotify_music_helper/src/info/info_page.dart';
import 'package:spotify_music_helper/src/home/home_view.dart';
import 'package:spotify_music_helper/src/settings/settings_view.dart';
import 'package:spotify_music_helper/src/utils/auth.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';

///Side menu for Navigating the app's pages.
Drawer optionsMenu(BuildContext context){
  return Drawer(
    elevation: 16,
    width: 200,
    child: Container(
      alignment: Alignment.bottomLeft,
      child: ListView(
        children: <Widget>[

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
              Get.to(const HomeView());
            },
          ),

          //Navigate to Info page.
          ListTile(
            leading: const Icon(Icons.question_mark),
            title: const Text('Info'),
            onTap: () async{
              Get.to(const InfoView());
            },
          ),

          //Navigate to Settings page.
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Get.to(const SettingsViewWidget());
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
              Get.offNamedUntil('/start', (Route route) => false, arguments: reLogin);
            },
          ),

          //Exit app after user confirmation.
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Exit App'),
            onTap: () {
              Get.dialog(
                AlertDialog.adaptive(
                  title: const Text('Sure you want to exit the App?'),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        //Close Popup
                        Get.back();
                      }, 
                      child: const Text('Cancel')
                    ),
                    TextButton(
                      onPressed: () {
                        //Close App
                        exit(0);
                      },
                      child: const Text('Confirm'),
                    ),
                  ],
                )
              );
            },
          ),
        ],
      ),
    )
  );
}//OptionsMenu
