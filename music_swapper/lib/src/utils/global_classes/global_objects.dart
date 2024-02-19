
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spotify_music_helper/src/info/info_page.dart';
import 'package:spotify_music_helper/src/home/home_view.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/settings/settings_view.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/databse_calls.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/playlists_requests.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/tracks_requests.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';

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
}//getCurrentLine

String getTrackId(String trackId){
  int underScoreIndex = trackId.indexOf('_');
  String result = trackId;

  if (underScoreIndex != -1){
    result = trackId.substring(0, underScoreIndex);
  }

  return result;
}//getTrackId

void selectViewError(dynamic e, int line){
  debugPrint('Caught error in select_view.dart line: $line error: $e');
}

Image spotifyHeart(){
  return Image.asset(
    unlikeHeart,
    width: 21.0,
    height: 21.0,
    color: Colors.green,
    fit: BoxFit.cover,
  );
}

//Used to organize what songs a user has in their Liked Songs playlist
class LikedSongs{
  String likedId = 'Liked_Songs';

  //Use the check API

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
        
        if (callback != null){
          int totalTracks = await getSpotifyTracksTotal(likedId, callback.expiresAt, callback.accessToken);
          likedSongs = await getSpotifyPlaylistTracks(likedId, callback.expiresAt, callback.accessToken, totalTracks);
        }
      }
      //User needs a new callback
      else{
        return null;
      }
    }

    return likedSongs;
  }

}//LikedSongs


String modifyBadQuery(String query){
  List badInput = ['\\', ';', '\'', '"', '@', '|'];
  String newQuery = '';
  for (var char in query.characters){
    if (!badInput.contains(char)){
      newQuery = newQuery + char;
    }
  }
  return newQuery;
}//modifyBadQuery


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
            leading: const Icon(Icons.question_mark),
            title: const Text('Info'),
            onTap: () {
              Navigator.restorablePushNamed(context, InfoView.routeName);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.restorablePushNamed(context, SettingsViewWidget.routeName);
            },
          ),
          ListTile(
            leading: const Icon(Icons.switch_account),
            title: const Text('Sign Out'),
            onTap: () {
              SecureStorage().removeTokens();
              SecureStorage().removeUser();

              bool reLogin = true;
              Navigator.pushNamedAndRemoveUntil(context, StartViewWidget.routeName, (route) => false, arguments: reLogin);
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
}//OptionsMenu


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
}//storageCheck
