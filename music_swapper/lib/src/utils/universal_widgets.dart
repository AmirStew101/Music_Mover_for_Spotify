
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/about/about.dart';
import 'package:spotify_music_helper/src/home/home_view.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/settings/settings_view.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/database/databse_calls.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:spotify_music_helper/src/utils/playlists_requests.dart';
import 'package:spotify_music_helper/src/utils/tracks_requests.dart';

final userRepo = Get.put(UserRepository());
AndroidOptions getAndroidOptions() => const AndroidOptions(encryptedSharedPreferences: true);
final storage = FlutterSecureStorage(aOptions: getAndroidOptions());

int getCurrentLine({int offset = 0}){
  StackTrace trace = StackTrace.current;
  final lines = trace.toString().split('\n');

  String lineStr = lines[1].split(':')[2];
  int lineNum = int.parse(lineStr);

  if (offset > 0){
    lineNum -= offset;
  }

   return lineNum;
}

String getTrackId(String trackId){
  int underScoreIndex = trackId.indexOf('_');
  String result = trackId;

  if (underScoreIndex != -1){
    result = trackId.substring(0, underScoreIndex);
  }

  return result;
}

class SecureStorage {
  final accessTokenKey = 'access_token';
  final refreshTokenKey = 'refresh_token';
  final expiresAtKey = 'expires_at';

  final userIdKey = 'userId';
  final userNameKey = 'userName';
  final userUriKey = 'userUri';

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
    await storage.delete(key: accessTokenKey);
    await storage.delete(key: expiresAtKey);
    await storage.delete(key: refreshTokenKey);
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

  Future<void> removeUser() async{
    await storage.delete(key: userIdKey);
    await storage.delete(key: userNameKey);
    await storage.delete(key: userUriKey);
  }
}

class SecureSubscriptionStorage {
  final subscribedKey = 'subscribed';
  final tierKey = 'tier';

  Future<void> saveSubscription(UserModel user) async{

  }

  Future<void> cancelSubscription() async{

  }

}

//Used to organize what songs a user has in their Liked SOngs playlist
class LikedSongs{
  String likedId = 'Liked_Songs';

  //Checks if the tracks in a playlist is a Liked Song
  Future<Map<String, TrackModel>?> checkLiked(Map<String, TrackModel> playlistTracks, String userId) async{
    Map<String, TrackModel>? likedSongs = await getLikedSongs(userId);

    if (likedSongs != null && likedSongs.isNotEmpty){
      List liked = [];
      for (var trackId in playlistTracks.keys){
        if (likedSongs.containsKey(trackId)){
          liked.add(trackId);
        }
      }
    }
    //User has no liked songs
    if (likedSongs != null && likedSongs.isEmpty){
      return likedSongs;
    }

    //User needs a new callback
    return null;
  }

  //Gets all the users liked songs
  Future<Map<String, TrackModel>?> getLikedSongs(String userId) async{
    Map<String, TrackModel> likedSongs = await userRepo.getTracks(userId, likedId);

    //Database Liked Songs is empty
    if (likedSongs.isEmpty){
      CallbackModel? callback = await SecureStorage().getTokens();

      //Get tracks from spotify
      if (callback != null){
        callback = await checkRefresh(callback, false);
        int totalTracks = await getSpotifyTracksTotal(likedId, callback.expiresAt, callback.accessToken);
        likedSongs = await getSpotifyPlaylistTracks(likedId, callback.expiresAt, callback.accessToken, totalTracks);
      }
      //User needs a new callback
      else{
        return null;
      }
    }

    return likedSongs;
  }

}

class DatabaseStorage { 

  //Syncs the Users Spotify tracks with the tracks in database
  Future<void> syncPlaylistTracksData(String userId, Map<String, TrackModel> tracks, String playlistId) async{
    debugPrint('Syncing Tracks: ${tracks.length}');
    try{
      bool updateDatabase = true;
      await userRepo.syncPlaylistTracks(userId, tracks, playlistId, updateDatabase);
    }
    catch (e){
      debugPrint('Error trying to Sync Playlist Tracks: $e');
    }
    debugPrint('Finished Syncing Tracks');
  }

  //Get a list of track names for a given playlits then get there details from
  //the tracks collection using the names
  Future<Map<String, TrackModel>> getDatabaseTracks(String userId, String playlistId, BuildContext context) async{
    final userRepo = Get.put(UserRepository());

    final tracks = await userRepo.getTracks(userId, playlistId)
    .onError((error, stackTrace) {
      Flushbar(
        duration: const Duration(seconds: 3),
        titleColor: const Color.fromARGB(255, 179, 28, 17),
        title: 'Failed to get Tracks From Database',
        message: 'Trying Spotify',
      ).show(context);
      return {};
    });

    debugPrint('Database Tracks Total: ${tracks.length}');

    return tracks;
  }

  Future<void> removeDatabaseTracks(String userId, List<String> trackIds, String playlistId) async{
      try{
        await userRepo.removePlaylistTracks(userId, trackIds, playlistId);
      }
      catch (e){
        debugPrint('Caught Error in universal_widgets.dart function removeDatabaseTracks: $e');
      }
  }


  //Syncs the Users Spotify Playlists with the playlists in database
  Future<void> syncPlaylists(Map<String, PlaylistModel> playlists, String userId) async{
    debugPrint('Syncing Playlists');
    try{
      bool updateDatabase = false;
      await userRepo.syncUserPlaylists(userId, playlists, updateDatabase);
    }
    catch (e){
      debugPrint('Error trying to Sync Playlists: $e');
    }
    debugPrint('Finished Syncing Playlists');
  }

  Future<Map<String, PlaylistModel>> getDatabasePlaylists(String userId) async{
    Map<String, PlaylistModel> allPlaylists = await userRepo.getPlaylists(userId);
    return allPlaylists;
  }


  Future<UserModel?> syncUserData(double expiresAt, String accessToken) async {
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
        //Creates an unsubscribed user
        await userRepo.createUser(user);

        //User was created Successfully and retreived from database
        return user;
      }

      //Gets the user from the database
      else{
        UserModel? retreivedUser = await userRepo.getUser(user);
        if (retreivedUser != null){
          //User was retreived Successfully from database
          return retreivedUser;
        }
      }
    }

    //User was not able to be synced with database
    return null;
  }

}


  Future<void> removeTracks(CallbackModel callback, PlaylistModel currentPlaylist, Map<String, TrackModel> selectedTracksMap, Map<String, TrackModel> allTracks, UserModel user) async {

    String playlistId = currentPlaylist.id;
    String snapId = currentPlaylist.snapshotId;
    debugPrint('Selected Map: $selectedTracksMap');

    if (playlistId != 'Liked_Songs'){
      //Tracks & how many times to remove it
      Map<String, int> removeTracks = {};

      for (var track in selectedTracksMap.entries) {
        String id = getTrackId(track.key);
        //Updates how many tracks are being deleted
        removeTracks.update(id, (value) => value++, ifAbsent: () => 0);
      }
      debugPrint('RemoveTracks: $removeTracks');

      List<String> spotifyAddIds = [];
      //Tracks to be removed from the database starting from the last element
      List<String> databaseRemoveIds = [];

      List<String> removeTrackIds = [];

      //Check to see if tracks should be replaced after deletion
      for (var track in removeTracks.entries){
        //The stored track duplicates for current track
        int tracksTotal = allTracks[track.key]!.duplicates;
        int removeTracks = track.value;
        String id = track.key;

        removeTrackIds.add(id);
        debugPrint('\nRemove Tracks: $removeTracks');
        debugPrint('Tracks Total: $tracksTotal');

        //Remove database tracks starting from the last added track duplicate
        for (int i = tracksTotal; i >= 0; i--){

          //Removes all of database tracks
          if (removeTracks == tracksTotal){
            debugPrint('Remove all Tracks database');
            String remove = '${id}_$i';
            databaseRemoveIds.add(remove);
          }

          //Removes duplicate tracks until user selected amount of tracks are deleted
          if (i <= removeTracks){
            if (i == 0){
              databaseRemoveIds.add(id);
              debugPrint('Database Remove: $id');
            }
            else{
              String remove = '${id}_$i';
              databaseRemoveIds.add(remove);
              debugPrint('Database Remove: $remove');
            }
            
          }
          //If not all tracks are deleted add back the amount user didn't delete
          //Spotify API deletes all tracks whith one delete call
          else{
            spotifyAddIds.add(id);
            debugPrint('Spotify add');
          }
        }
      }

      try{
        callback = await checkRefresh(callback, false);
      }
      catch (e){
        debugPrint('Tracks_view.dart line: ${getCurrentLine(offset: 3)} in function removeTracks $e');
      }
        
        await removeTracksRequest(removeTrackIds, playlistId, snapId, callback.expiresAt, callback.accessToken)
        .catchError((e) => debugPrint('Tracks_view.dart line: ${getCurrentLine()} caught error: $e'));

        await DatabaseStorage().removeDatabaseTracks(user.spotifyId, databaseRemoveIds, playlistId)
        .catchError((e) => debugPrint('Tracks_view.dart line: ${getCurrentLine()} caught error: $e'));

        //Replaces tracks that user wanted to keep
        if (spotifyAddIds.isNotEmpty){
          debugPrint('Add tracks back: $spotifyAddIds');
          List<String> playlistIds = [playlistId];
          await addTracksRequest(spotifyAddIds, playlistIds, callback.expiresAt, callback.accessToken);
        }
      
    }
    //Liked Songs has no duplicates to worry about
    else{

      List<String> trackIds = [];

      for(var track in selectedTracksMap.entries){
        String id = getTrackId(track.key);
        trackIds.add(id);
      }

      try{
        callback = await checkRefresh(callback, false);
      }
      catch (e){
        debugPrint('Tracks_view.dart line ${getCurrentLine(offset: 3)} in function removeTracks $e');
      }
        await removeTracksRequest(trackIds, playlistId, snapId, callback.expiresAt, callback.accessToken)
        .catchError((e) => debugPrint('Tracks_view.dart line: ${getCurrentLine()} caught error: $e'));

        await DatabaseStorage().removeDatabaseTracks(user.spotifyId, trackIds, playlistId)
        .catchError((e) => debugPrint('Tracks_view.dart line: ${getCurrentLine()} caught error: $e'));
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
              'Sidebar Options',
              style: TextStyle(fontSize: 18),
            )
          ),
          ListTile(
            leading: const Icon(Icons.album),
            title: const Text('Playlists'),
            onTap: (){
              Navigator.restorablePushNamed(context, HomeView.routeName);
            },
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text('Store'),
            onTap: () {
              
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
            leading: const Icon(Icons.switch_account),
            title: const Text('Sign Out'),
            onTap: () {
              SecureStorage().removeTokens();
              SecureStorage().removeUser();

              StartArguments startArgs = const StartArguments(reLogin: true, hasUser: true);
              Navigator.pushNamedAndRemoveUntil(context, StartViewWidget.routeName, (route) => false, arguments: startArgs);
              debugPrint('Sign Out Selected');
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Exit App'),
            onTap: () {
              exit(0);
            },
          ),
        ],
      ),
    )
  );
}


void storageCheck(BuildContext context, CallbackModel? secureCall, UserModel? secureUser){

  if (secureUser == null && secureCall == null){
    Flushbar(
      backgroundColor: const Color.fromARGB(255, 212, 27, 27),
      title: 'Error in connection',
      duration: const Duration(seconds: 5),
      flushbarPosition: FlushbarPosition.TOP,
      message: 'Failed to connect to Spotify and get User data',
    ).show(context);
  }
  else if (secureUser == null){
    Flushbar(
      backgroundColor: const Color.fromARGB(255, 212, 27, 27),
      title: 'Error in connection',
      duration: const Duration(seconds: 5),
      flushbarPosition: FlushbarPosition.TOP,
      message: 'Failed to get User data.',
    ).show(context);
  }
  else if (secureCall == null){
    Flushbar(
      backgroundColor: const Color.fromARGB(255, 212, 27, 27),
      title: 'Error in connection',
      duration: const Duration(seconds: 5),
      flushbarPosition: FlushbarPosition.TOP,
      message: 'Failed to connect to Spotify',
    ).show(context);
  }
}