
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:music_swapper/src/about/about.dart';
import 'package:music_swapper/src/home/home_view.dart';
import 'package:music_swapper/src/settings/settings_view.dart';
import 'package:music_swapper/utils/database/database_model.dart';
import 'package:music_swapper/utils/database/databse_calls.dart';
import 'package:music_swapper/utils/globals.dart';
import 'package:http/http.dart' as http;

class OptionsMenu extends StatelessWidget {
  const OptionsMenu({required this.callback, required this.userId, super.key});
  final Map<String, dynamic> callback;
  final String userId;

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
                'user': userId,
              };
          Navigator.restorablePushNamed(context, HomeView.routeName, arguments: multiArgs);
        } else if (value == 'settings') {
          Navigator.restorablePushNamed(context, SettingsView.routeName);
        } else if (value == 'about') {
          Map<String, dynamic> multiArgs = {
                'callback': callback,
                'user': userId,
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

//Check if User has track in their collection and if it is connected to given playlist
//Creates Track and/or Playlist connection if either doesn't exist
Future<void> checkUserTrackData(String userId, MapEntry<String, dynamic> track, String playlistId) async{
  final userRepo = Get.put(UserRepository());

  String trackId = track.key;
  bool has = await userRepo.hasTrack(userId, trackId);

  if (!has){
    TrackModel newTrack = TrackModel(
      playlistIds: [], 
      trackId: trackId, 
      imageUrl: track.value['imageUrl'], 
      artist: track.value['artist'], 
      title: track.value['title']);

    await userRepo.createTrackDoc(userId, newTrack, trackId);
    await userRepo.addTrackPlaylist(userId, trackId, playlistId);
  }
}

//Get a list of track names for a given playlits then get there details from
//the tracks collection using the names
Future<Map<String, dynamic>> getPlaylistTracksData(String userId, String playlistId) async{
  final userRepo = Get.put(UserRepository());

  final tracks = await userRepo.getTracks(userId, playlistId);
  debugPrint('Database Tracks Total: ${tracks.length}');

  return tracks;
}


Future<void> checkPlaylists(Map<String, dynamic> playlists, String userId) async{
  for (var item in playlists.entries){
    dynamic value = item.value;
    PlaylistModel playModel = PlaylistModel(
      title: value['title'], 
      playlistId: item.key, 
      link: value['link'], 
      imageUrl: value['imageUrl'], 
      snapshotId: value['snapshotId']);

    await checkPlaylistData(userId, playModel);
  }
}

Future<Map<String, dynamic>> getDatabasePlaylists(String userId) async{
  Map<String, dynamic> allPlaylists = await userRepo.getPlaylists(userId);
  return allPlaylists;
}

Future<bool> checkPlaylistData(String userId, PlaylistModel playlist) async{
  final userRepo = Get.put(UserRepository());

  bool has = await userRepo.hasPlaylist(userId, playlist.playlistId);

  if (!has){
    userRepo.createPlaylist(userId, playlist);
  }

  return has;
}


Future<UserModel> checkUserData(double expiresAt, String accessToken) async {
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