
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/about/about.dart';
import 'package:spotify_music_helper/src/home/home_view.dart';
import 'package:spotify_music_helper/src/settings/settings_view.dart';
import 'package:spotify_music_helper/utils/database/database_model.dart';
import 'package:spotify_music_helper/utils/database/databse_calls.dart';
import 'package:spotify_music_helper/utils/globals.dart';
import 'package:http/http.dart' as http;

class OptionsMenu extends StatelessWidget {
  const OptionsMenu({required this.callback, required this.user, super.key});
  final Map<String, dynamic> callback;
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu(
      leadingIcon: const Icon(Icons.menu),
      trailingIcon: const Icon(null),
      selectedTrailingIcon: const Icon(null),
      inputDecorationTheme: const InputDecorationTheme(
          outlineBorder: BorderSide(color: Colors.black)),
      dropdownMenuEntries: const [
        DropdownMenuEntry(
            value: 'home',
            label: 'Home',
            leadingIcon: Icon(Icons.home),
            style: ButtonStyle(
                overlayColor:
                    MaterialStatePropertyAll(Color.fromARGB(255, 6, 163, 11)))),
        DropdownMenuEntry(
            value: 'settings',
            label: 'Settings',
            leadingIcon: Icon(Icons.settings),
            style: ButtonStyle(
                overlayColor:
                    MaterialStatePropertyAll(Color.fromARGB(255, 6, 163, 11)))),
        DropdownMenuEntry(
            value: 'about',
            label: 'About',
            leadingIcon: Icon(Icons.question_mark),
            style: ButtonStyle(
                overlayColor:
                    MaterialStatePropertyAll(Color.fromARGB(255, 6, 163, 11)))),
        DropdownMenuEntry(
            value: 'contact',
            label: 'Contact',
            leadingIcon: Icon(Icons.question_answer),
            style: ButtonStyle(
                overlayColor:
                    MaterialStatePropertyAll(Color.fromARGB(255, 6, 163, 11))))
      ],
      onSelected: (value) {
        if (value == 'home') {
          Map<String, dynamic> multiArgs = {
                'callback': callback,
                'user': user,
              };
          Navigator.restorablePushNamed(context, HomeView.routeName, arguments: multiArgs);
        } else if (value == 'settings') {
          Navigator.restorablePushNamed(context, SettingsView.routeName);
        } else if (value == 'about') {
          Map<String, dynamic> multiArgs = {
                'callback': callback,
                'user': user,
              };
          Navigator.restorablePushNamed(context, AboutView.routeName,
              arguments: multiArgs);
        } else {
          debugPrint('Contact Selected');
        }
      },
    );
  }
}

final userRepo = Get.put(UserRepository());

//Syncs the Users Spotify tracks with the tracks in database
Future<bool> syncPlaylistTracksData(String userId, Map<String, dynamic> tracks, String playlistId) async{
  debugPrint('Syncing Tracks');
  try{
  await userRepo.syncPlaylistTracks(userId, tracks, playlistId);
  }
  catch (e){
    debugPrint('Error trying to Sync Playlist Tracks: $e');
    return false;
  }
  debugPrint('Finished Syncing Tracks');
  return true;
}

//Get a list of track names for a given playlits then get there details from
//the tracks collection using the names
Future<Map<String, dynamic>> getDatabaseTracks(String userId, String playlistId) async{
  final userRepo = Get.put(UserRepository());

  final tracks = await userRepo.getTracks(userId, playlistId);
  debugPrint('Database Tracks Total: ${tracks.length}');

  return tracks;
}


//Syncs the Users Spotify Playlists with the playlists in database
Future<void> syncPlaylists(Map<String, dynamic> playlists, String userId) async{
  await userRepo.syncUserPlaylists(userId, playlists);
}

Future<Map<String, dynamic>> getDatabasePlaylists(String userId) async{
  Map<String, dynamic> allPlaylists = await userRepo.getPlaylists(userId);
  return allPlaylists;
}


Future<UserModel> syncUserData(double expiresAt, String accessToken) async {
  final userRepo = Get.put(UserRepository());

  final getUserInfo = '$hosted/get-user-info/$expiresAt/$accessToken';
  final response = await http.get(Uri.parse(getUserInfo));
  Map<String, dynamic> userInfo = {};

  if (response.statusCode == 200){
    final responseDecoded = json.decode(response.body);
    userInfo = responseDecoded['data'];
    //{user_name: '', 'id': '', 'uri': ''}

    UserModel user;

    //Converts user from Spotify to Firestore user
    if (userInfo['user_name'] != null || userInfo['user_name'] != ''){
      user = UserModel(username: userInfo['user_name'] , spotifyId: userInfo['id'], uri: userInfo['uri']);
    }
    else{
      user = UserModel(spotifyId: userInfo['id'], uri: userInfo['uri']);
    }

    //Checks if user is already in the database
    final bool userExists = await userRepo.hasUser(user);

    if (!userExists){
      await userRepo.createUser(user);
    }
    return user;
  }
  throw Exception('Error getting User info');
}

Future<void> removeDatabaseTracks(String userId, List<String> trackIds, String playlistId) async{
  try{
    await userRepo.removePlaylistTracks(userId, trackIds, playlistId);
  }
  catch (e){
    debugPrint('Caught Error in universal_widgets.dart function removeDatabaseTracks: $e');
  }
}

String modifyBadQuery(String query){
  List badInput = ['\\', ';', '\'', '"', '@', '|'];
  String newQuery = '';
  for (var char in query.characters){
    if (!badInput.contains(char)){
      newQuery = newQuery + char;
    }
  }
  return newQuery;
}