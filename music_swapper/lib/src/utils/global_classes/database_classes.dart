import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/databse_calls.dart';
import 'package:spotify_music_helper/src/utils/dev_global.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';

final userRepo = Get.put(UserRepository());

class DatabaseStorage { 

  ///Syncs the Users Spotify tracks with the tracks in database
  Future<void> syncTracks(String userId, Map<String, TrackModel> tracks, String playlistId) async{
    try{
      await userRepo.syncPlaylistTracks(userId, tracks, playlistId, devMode);
    }
    catch (e){
      throw Exception('Error trying to Sync Playlist Tracks: $e');
    }
  }

  ///Get a list of track names for a given playlits then get there details from
  ///the tracks collection using the names
  Future<Map<String, TrackModel>> getDatabaseTracks(String userId, String playlistId, BuildContext context) async{
    final tracks = await userRepo.getTracks(userId, playlistId)
    .catchError((error, stackTrace) {
      debugPrint('Error $error');
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
        throw Exception('Caught Error in universal_widgets.dart function removeDatabaseTracks: $e');
      }
  }

  ///Add [selectedTracks] to the Users playlists. Given the Users id [userId] and List of playlist Ids [playlistIds]
  Future<void> addTracks(String userId, Map<String, TrackModel> selectedTracks, List<String> playlistIds) async{
    try{
      List<TrackModel> tracksUpdate = [];

      for (var track in selectedTracks.entries){
        String trueId = getTrackId(track.key);
        TrackModel newTrack = tracksUpdate.firstWhere((element) => element.id == trueId, orElse: () => const TrackModel());
        
        if (newTrack.isEmpty){

          tracksUpdate.add(TrackModel(
            id: trueId,
            title: track.value.title,
            artist: track.value.artist,
            imageUrl: track.value.imageUrl,
            previewUrl: track.value.previewUrl,
            liked: track.value.liked,
            duplicates: track.value.duplicates + 1
          ));
        }
        else{
          int newTrackLoc = tracksUpdate.indexOf(newTrack);
          tracksUpdate[newTrackLoc] = newTrack.incrementDuplicates;
        }

      }

      for (var playId in playlistIds){
        await userRepo.addTrackDocs(userId, tracksUpdate, playId);
      }
    }
    catch (e){
      throw Exception('database_class.dart ine: ${getCurrentLine()} CAught Error: $e');
    }
  }

  Future<void> syncPlaylists(Map<String, PlaylistModel> playlists, String userId) async{
    try{
      await userRepo.syncUserPlaylists(userId, playlists);
    }
    catch (e){
      throw Exception('Error trying to Sync Playlists: $e');
    }
  }

  Future<Map<String, PlaylistModel>> getDatabasePlaylists(String userId) async{
    Map<String, PlaylistModel> allPlaylists = await userRepo.getPlaylists(userId);
    return allPlaylists;
  }


  ///Checks if user is already in the database and adds them if they are not.
  Future<UserModel> syncUserData(UserModel user) async {
    if (await userRepo.hasUser(user)){
      user = (await userRepo.getUser(user))!;
    }
    else{
      //Creates an unsubscribed user
      await userRepo.createUser(user);
    }

    //User was Synced Successfully
    return user;
  }

  Future<int> removeUser(UserModel user) async{
    try{
      if (await userRepo.hasUser(user)){
        await userRepo.removeUser(user);
      }
      else{
        return -1;
      }
      return 0;
    }
    catch (e){
      throw Exception('database_classes.dart line: ${getCurrentLine(offset: 11)} Caught Error: $e');
    }
  }


  ///Spotify removes all versions of a track from a playlist when an id is sent to be deleted
  Future<void> removeTracks(PlaylistModel currentPlaylist, List<String> selectedIds, UserModel user) async {

    String playlistId = currentPlaylist.id;

    await userRepo.removePlaylistTracks(user.spotifyId, selectedIds, playlistId)
    .onError((error, stackTrace) => throw Exception('database_class.dart line: ${getCurrentLine(offset: 1)} Caught Error: $error'));
    
 }

}//DatabaseStorage

