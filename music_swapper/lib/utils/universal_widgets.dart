
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/about/about.dart';
import 'package:spotify_music_helper/src/home/home_view.dart';
import 'package:spotify_music_helper/src/settings/settings_view.dart';
import 'package:spotify_music_helper/utils/object_models.dart';
import 'package:spotify_music_helper/utils/database/databse_calls.dart';
import 'package:spotify_music_helper/utils/globals.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final userRepo = Get.put(UserRepository());
AndroidOptions getAndroidOptions() => const AndroidOptions(encryptedSharedPreferences: true);

class SecureStorage {
  final accessTokenKey = 'access_token';
  final refreshTokenKey = 'refresh_token';
  final expiresAtKey = 'expires_at';

  final userIdKey = 'userId';
  final userNameKey = 'userName';
  final userUriKey = 'userUri';

  final storage = FlutterSecureStorage(aOptions: getAndroidOptions());

  Future<void> saveTokens(CallbackModel tokensModel) async {
    await storage.write(key: accessTokenKey, value: tokensModel.accessToken);
    await storage.write(key: refreshTokenKey, value: tokensModel.refreshToken);
    await storage.write(key: expiresAtKey, value: tokensModel.expiresAt.toString());
  }

  Future<CallbackModel?> getTokens() async {
    final accessToken = await storage.read(key: accessTokenKey);
    final refreshToken = await storage.read(key: refreshTokenKey);
    final expiresAtStr = await storage.read(key: expiresAtKey);

    if (accessToken != null && refreshToken != null && expiresAtStr != null) {
      double expiresAt = double.parse(expiresAtStr);
      CallbackModel callbackModel = CallbackModel(expiresAt: expiresAt, accessToken: accessToken, refreshToken: refreshToken);

      return callbackModel;
    } 
    else {
      return null;
    }
  }

  Future<void> removeTokens() async{

  }

  Future<void> saveUser(UserModel user) async{
    await storage.write(key: 'userId', value: user.spotifyId);
    await storage.write(key: 'userUri', value: user.uri);

    if (user.username != null){
      await storage.write(key: 'userName', value: user.username);
    }
  }

  Future<UserModel?> getUser() async{
    final userId = await storage.read(key: userIdKey);
    final userName = await storage.read(key: userNameKey);
    final userUri = await storage.read(key: userUriKey);

    if (userId != null && userUri != null){
      if (userName != null){
        UserModel userModel = UserModel(spotifyId: userId, uri: userUri, username: userName);
        return userModel;
      }
      else{
        UserModel userModel = UserModel(spotifyId: userId, uri: userUri);
        return userModel;
      }
    }

    return null;
  }

}


class DatabaseStorage { 

  //Syncs the Users Spotify tracks with the tracks in database
  Future<void> syncPlaylistTracksData(String userId, Map<String, dynamic> tracks, String playlistId) async{
    debugPrint('Syncing Tracks: ${tracks.length}');
    try{
    await userRepo.syncPlaylistTracks(userId, tracks, playlistId);
    }
    catch (e){
      debugPrint('Error trying to Sync Playlist Tracks: $e');
    }
    debugPrint('Finished Syncing Tracks');
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
    debugPrint('Syncing Playlists');
    try{
    await userRepo.syncUserPlaylists(userId, playlists);
    }
    catch (e){
      debugPrint('Error trying to Sync Playlists: $e');
    }
    debugPrint('Finished Syncing Playlists');
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

      //Converts user from Spotify to Firestore user
      UserModel user = UserModel(username: userInfo['user_name'] , spotifyId: userInfo['id'], uri: userInfo['uri']);

      //Checks if user is already in the database
      if (!await userRepo.hasUser(user)){
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


  Drawer optionsMenu(BuildContext context){
    return Drawer(
      elevation: 16,
      width: 200,
      child: Container(
        alignment: Alignment.bottomLeft,
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color.fromARGB(255, 6, 163, 11)),
              child: Text(
                'Sidebar',
                style: TextStyle(fontSize: 18),
              )
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Playlists'),
              onTap: () {
                Navigator.restorablePushNamed(context, HomeView.routeName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.question_mark),
              title: const Text('About'),
              onTap: () {
                Navigator.restorablePushNamed(context, AboutViewWidget.routeName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.restorablePushNamed(context, SettingsView.routeName);
              },
            ),
            ListTile(
              title: const Text('Sign Out'),
              onTap: () {
                debugPrint('Sign Out Selected');
              },
            ),
          ],
        ),
      )
    );
  }
