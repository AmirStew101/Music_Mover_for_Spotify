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

  ///Syncs a Users database tracks with tracks from Spotify.
  Future<void> syncTracks(String userId, Map<String, TrackModel> tracks, String playlistId) async{
    await userRepo.syncPlaylistTracks(userId, tracks, playlistId, devMode)
    .onError((error, stackTrace) => throw Exception( exceptionText('database_class.dart', 'syncTracks', error, offset: 1) ));
  }

  ///Get tracks from playlist with [playlistId] for user with [userId].
  Future<Map<String, TrackModel>> getDatabaseTracks(String userId, String playlistId, BuildContext context) async{
    final tracks = await userRepo.getTracks(userId, playlistId)
    .onError((error, stackTrace) {
      debugPrint('Error $error');
      Flushbar(
        duration: const Duration(seconds: 3),
        titleColor: failedRed,
        title: 'Failed to get Tracks From Database',
        message: 'Trying Spotify',
      ).show(context);
      throw Exception( exceptionText('database_class.dart', 'getDatabaseTracks', error, offset: 9) );
    });
    return tracks;
  }

  ///Add given [selectedTracks] to the Users playlists. Given the User id [userId] and List of playlist Ids [playlistIds]
  Future<void> addTracks(String userId, Map<String, TrackModel> selectedTracks, List<String> playlistIds) async{
    try{
      List<TrackModel> tracksUpdate = [];

      for (var track in selectedTracks.entries){
        String trueId = getTrackId(track.key);
        TrackModel newTrack = tracksUpdate.firstWhere((element) => element.id == trueId, orElse: () => TrackModel());
        
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
        await userRepo.updateTracks(userId, tracksUpdate, playId);
      }
    }
    catch (e){
      throw Exception( exceptionText('database_class.dart', 'addTracks', e, offset: 32) );
    }
  }

  ///Remove selected tracks with [selectedIds]. Given the User id [userId] and playlist with id [playlistId].
  Future<void> removeTracks(String userId, String playlistId, List<String> selectedIds) async {
    await userRepo.removePlaylistTracks(userId, selectedIds, playlistId)
    .onError((error, stackTrace) => throw Exception( exceptionText('database_class.dart', 'removeTracks', error, offset: 1) ));
 }


  ///Syncs a Users database playlists with playlists from Spotify.
  Future<void> syncPlaylists(Map<String, PlaylistModel> playlists, String userId) async{
    await userRepo.syncUserPlaylists(userId, playlists)
    .onError((error, stackTrace) => throw Exception( exceptionText('database_class.dart', 'syncPlaylists', error, offset: 1) ));
  }

  ///Get playlist from database for user with [userId].
  Future<Map<String, PlaylistModel>?> getDatabasePlaylists(String userId) async{
    try{
      final hasPlaylists = await userRepo.hasPlaylistsColl(userId);

      if (hasPlaylists){
        Map<String, PlaylistModel> allPlaylists = await userRepo.getPlaylists(userId);
        return allPlaylists;
      }

      return null;
    }
    catch (e){
      throw Exception( exceptionText('database_class.dart', 'getDatabasePlaylists', e, offset: 9) );
    }
  }


  ///Checks if [user] is already in the database and adds them if they are not.
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

  ///Removes a [user] and all of their data from the database.
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
      throw Exception( exceptionText('database_class.dart', 'removeUser', e, offset: 11) );
    }
  }

}

