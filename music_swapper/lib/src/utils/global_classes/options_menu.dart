// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:music_mover/src/utils/backend_calls/storage.dart';
import 'package:music_mover/src/info/info_page.dart';
import 'package:music_mover/src/home/home_view.dart';
import 'package:music_mover/src/settings/settings_view.dart';
import 'package:music_mover/src/utils/auth.dart';
import 'package:music_mover/src/utils/class%20models/user_model.dart';
import 'package:music_mover/src/utils/globals.dart';

final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

///Side menu for Navigating the app's pages.
Drawer optionsMenu(BuildContext context, UserModel user){
  _crashlytics.log('Open Options Drawer');

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
              _crashlytics.log('Navigate to Playlists Page');
              Get.to(const HomeView());
            },
          ),

          //Navigate to Info page.
          ListTile(
            leading: const Icon(Icons.question_mark),
            title: const Text('Help'),
            onTap: () async{
              _crashlytics.log('Navigate to Info Page');
              await Get.to(const InfoView(), arguments: user);
            },
          ),

          //Navigate to Settings page.
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              _crashlytics.log('Navigate to Settings Page');
              Get.to(const SettingsViewWidget());
            },
          ),

          //Sign out user and navigate to Start page.
          ListTile(
            leading: const Icon(Icons.switch_account),
            title: const Text('Sign Out'),
            onTap: () async{
              _crashlytics.log('Sign Out User');

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
              _crashlytics.log('Open Confirmation Box');
              Get.dialog(
                AlertDialog.adaptive(
                  title: const Text(
                    'Sure you want to exit the App?',
                    textAlign: TextAlign.center
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        _crashlytics.log('Cancel Exit');
                        //Close Popup
                        Get.back();
                      }, 
                      child: const Text('Cancel')
                    ),
                    TextButton(
                      onPressed: () {
                        _crashlytics.log('Confirm Exit');
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
