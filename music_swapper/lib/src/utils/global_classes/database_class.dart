

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/databse_calls.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/playlists_requests.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/tracks_requests.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';

final userRepo = Get.put(UserRepository());

class DatabaseStorage { 

  //Syncs the Users Spotify tracks with the tracks in database
  Future<void> syncTracks(String userId, Map<String, TrackModel> tracks, String playlistId) async{
    try{
      await userRepo.syncPlaylistTracks(userId, tracks, playlistId, devMode);
    }
    catch (e){
      debugPrint('Error trying to Sync Playlist Tracks: $e');
    }
  }

  //Get a list of track names for a given playlits then get there details from
  //the tracks collection using the names
  Future<Map<String, TrackModel>> getDatabaseTracks(String userId, String playlistId, BuildContext context) async{
    final tracks = await userRepo.getTracks(userId, playlistId)
    .onError((error, stackTrace) {
      Flushbar(
        duration: const Duration(seconds: 3),
        titleColor: failedRed,
        title: 'Failed to get Tracks From Database',
        message: 'Trying Spotify',
      ).show(context);
      throw Exception('In database_class.dart line: ${getCurrentLine()} : $error');
    });
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

  Future<void> syncPlaylists(Map<String, PlaylistModel> playlists, String userId) async{
    try{
      await userRepo.syncUserPlaylists(userId, playlists);
    }
    catch (e){
      debugPrint('Error trying to Sync Playlists: $e');
    }
  }

  Future<Map<String, PlaylistModel>> getDatabasePlaylists(String userId) async{
    Map<String, PlaylistModel> allPlaylists = await userRepo.getPlaylists(userId);
    return allPlaylists;
  }


  Future<UserModel?> syncUserData(double expiresAt, String accessToken) async {

    final getUserInfo = '$hosted/get-user-info/$expiresAt/$accessToken';
    final response = await http.get(Uri.parse(getUserInfo));
    Map<String, dynamic> userInfo = {};

    if (response.statusCode == 200){
      final responseDecoded = json.decode(response.body);
      userInfo = responseDecoded['data'];

      //Converts user from Spotify to Firestore user
      UserModel user = UserModel(username: userInfo['user_name'] , spotifyId: userInfo['id'], uri: userInfo['uri'], subscribed: false, tier: 0, expiration: Timestamp.now());

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


  /*
  Spotify removes all versions of a track from a playlist when an id is sent to be deleted
  */
  Future<void> removeTracks(CallbackModel callback, PlaylistModel currentPlaylist, Map<String, TrackModel> selectedTracksMap, Map<String, TrackModel> allTracks, UserModel user) async {

    String playlistId = currentPlaylist.id;

    if (playlistId != 'Liked_Songs'){
      //Tracks & how many times to remove it
      Map<String, int> removeTracks = {};
      String id; //unedited Spotify Id of the track

      for (var track in selectedTracksMap.entries) {
        id = getTrackId(track.key);
        //Updates how many duplicates of a track are being deleted
        removeTracks.update(id, (value) => value += 1, ifAbsent: () => 0);
      }

      List<String> spotifyAddIds = []; //Track ids to be re-added after deletion
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

        //Remove database tracks starting from the last added track duplicate
        for (int i = tracksTotal; i >= 0; i--){

          //Removes all of database tracks
          if (removeTracks == tracksTotal){
            String remove = '${id}_$i';
            databaseRemoveIds.add(remove);
          }

          //Removes duplicate tracks until user selected amount of tracks are deleted
          if (i <= removeTracks){
            if (i == 0){
              databaseRemoveIds.add(id);
            }
            else{
              String remove = '${id}_$i';
              databaseRemoveIds.add(remove);
            }
            
          }
          //If not all tracks are deleted add back the amount user didn't delete
          //Spotify API deletes all tracks whith one delete call
          else{
            spotifyAddIds.add(id);
          }
        }
      }

      try{
        final result = await PlaylistsRequests().checkRefresh(callback, false); 

        if (result != null){
          callback = result;
        }

      }
      catch (e){
        debugPrint('Tracks_view.dart line: ${getCurrentLine(offset: 3)} in function removeTracks $e');
      }

        await DatabaseStorage().removeDatabaseTracks(user.spotifyId, databaseRemoveIds, playlistId)
        .catchError((e) => debugPrint('Tracks_view.dart line: ${getCurrentLine()} caught error: $e'));

        //Replaces tracks that user wanted to keep
        if (spotifyAddIds.isNotEmpty){
          List<String> playlistIds = [playlistId];
          await TracksRequests().addTracks(spotifyAddIds, playlistIds, [], callback.expiresAt, callback.accessToken);
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
        final result = await PlaylistsRequests().checkRefresh(callback, false); 

        if (result != null){
          callback = result;
        }
      }
      catch (e){
        debugPrint('Tracks_view.dart line ${getCurrentLine(offset: 3)} in function removeTracks $e');
      }

        await DatabaseStorage().removeDatabaseTracks(user.spotifyId, trackIds, playlistId)
        .catchError((e) => debugPrint('Tracks_view.dart line: ${getCurrentLine()} caught error: $e'));
    }
 }

}//DatabaseStorage

