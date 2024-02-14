
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';


final db = FirebaseFirestore.instance;
class UserRepository extends GetxController {
  static UserRepository get instance => Get.find();
  final usersRef = db.collection('Users');
  final playlistColl  = 'Playlists';//Collection name for Users Playlists
  final tracksColl = 'PlaylistTracks'; //Collection name for Users Tracks

  final CacheManager cacheManager = DefaultCacheManager();

  Future<bool> hasUser(UserModel user) async {
    try{
      final DocumentSnapshot<Map<String, dynamic>> userExists = await usersRef.doc(user.spotifyId).get();

      if (userExists.exists) {
        debugPrint('User exists');
        final newUsername = user.username;
        await usersRef.doc(user.spotifyId).update({'Username': newUsername});
        return true;
      }
      debugPrint('User doesn\'t exist');
      return false;
    }
    catch (e){
        debugPrint('Caught Error in database_calls.dart Function hasUser $e');
    }
    throw Exception('Escaped return in hasUser');
  }

  Future<void> createUser(UserModel user) async {
    try {
      await usersRef.doc(user.spotifyId).set(user.toJson());
    } 
    catch (e) {
      debugPrint('Caught Error in database_calls.dart Function createUser $e');
    }
  }


  //Check if Playlist is in collections
  Future<void> syncUserPlaylists(String userId, Map<String, dynamic> spotifyPlaylists) async{
    try{
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final playlistDocs = await playlistRef.get();

      //Removes playlists from database that are not in Spotify
      for (var playlistDoc in playlistDocs.docs){
        final playlistId = playlistDoc.id;

        if (!spotifyPlaylists.containsKey(playlistId)){
          await removePlaylist(userId, playlistId);
        }
      }

      //Adds playlists that Database is missing or Updates existing
      List<PlaylistModel> playlists = [];
      List updateIdRefs = [];
      List updateModels = [];

      final updateBatch = db.batch();

      for (var playlist in spotifyPlaylists.entries){
        String playlistId = playlist.key;
        final dataPlaylist = await playlistRef.doc(playlistId).get();

        PlaylistModel newPlaylist = PlaylistModel(
          title: playlist.value['title'], 
          id: playlistId, 
          link: playlist.value['link'], 
          imageUrl: playlist.value['imageUrl'], 
          snapshotId: playlist.value['snapshotId'],
        );

        if (!dataPlaylist.exists){
          playlists.add(newPlaylist);
        }
        else{
          updateIdRefs.add(playlistRef.doc(playlistId));
          updateModels.add(newPlaylist.toJson());
        }
      }

      for (var i=0; i < updateIdRefs.length; i++){
        updateBatch.update(updateIdRefs[i], updateModels[i]);
      }

      await updateBatch.commit();

      if (playlists.isNotEmpty){
        await createPlaylists(userId, playlists);
      }

    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function syncUserPlaylists $e');
    }
  }

  Future<Map<String, dynamic>> getPlaylists(String userId) async{
    try {
      //Gets all the Docs in the Playlist Ref
      QuerySnapshot<Map<String, dynamic>> playlistDocs = await usersRef.doc(userId).collection(playlistColl).get();
      Map<String, dynamic> allPlaylists = {};

      //For every Doc it adds its fields to the Spotify Id as a Map
      //Ignoring the list of trackIds
      for (var element in playlistDocs.docs) {
        String imageUrl = element.data()['imageUrl'];
        String link = element.data()['link'];
        String snapshotId = element.data()['snapshotId'];
        String title = element.data()['title'];

        allPlaylists[element.id] = {'imageUrl': imageUrl, 'link': link, 'snapshotId': snapshotId, 'title': title};
      }

      return allPlaylists;
    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function getPlaylists: $e');
    }
    throw Exception('Escaped return in getPlaylists');
  }

  //Add all Playlists as collections to database
  Future<void> createPlaylists(String userId, List<PlaylistModel> playlists) async{
    try{
      final addBatch = db.batch();

      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      for(var model in playlists){
        addBatch.set(playlistRef.doc(model.id), model.toJson());
      }

      await addBatch.commit();
    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function createPlaylist $e');
    }

  }

  Future<void> removePlaylist(String userId, String playlistId) async{
    try{    
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      await playlistRef.doc(playlistId).delete(); //Removes PLaylist from collection
    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart function removePlaylist: $e');
    }

  }

  //Check if Track is in Users Playlist in database
  Future<void> syncPlaylistTracks(String userId, Map<String, dynamic> spotifyTracks, String playlistId) async{
    try{
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final tracksRef = playlistRef.doc(playlistId).collection(tracksColl);
      
      final playlistTracks = await tracksRef.get();

      int databaseTracks = playlistTracks.docs.length;
      int spotTracks = spotifyTracks.entries.length;
      List<String> removeTracks = [];
      
      //Removes extra tracks from playlist
      for (var track in playlistTracks.docs){
        if (!spotifyTracks.containsKey(track.id)){
          databaseTracks--;
          removeTracks.add(track.id);
        }
      }

      if(removeTracks.isNotEmpty){
        await removePlaylistTracks(userId, removeTracks, playlistId);
      }

      //If Spotify & Database do not have matching tracks it adds
      int i = 0;
      List<TrackModel> createTracks = []; //List of databse missing tracks

      while(databaseTracks != spotTracks && i < spotTracks){
        final spotifyTrack = spotifyTracks.entries.elementAt(i);
        String trackId = spotifyTrack.key;

        final databaseTrack = await tracksRef.doc(trackId).get();

        //Track document is not in Database
        if (!databaseTrack.exists){
          databaseTracks++;

          TrackModel newTrack = TrackModel(
            id: trackId, 
            imageUrl: spotifyTrack.value['imageUrl'], 
            artist: spotifyTrack.value['artist'], 
            title: spotifyTrack.value['title'],
            previewUrl: spotifyTrack.value['previewUrl']
          );

          createTracks.add(newTrack);
        }

        i++;
      }

      if (createTracks.isNotEmpty){
        await createTrackDocs(userId, createTracks, playlistId);
      }

    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function syncPlaylistTracks: $e');
    }
  }

  //Get track names for a given playlist
  Future<Map<String, dynamic>> getTracks(String userId, String playlistId) async{
    try{
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final tracksRef = playlistRef.doc(playlistId).collection(tracksColl);
      final playlistTracks = await tracksRef.get();

      Map<String, dynamic> newTracks = {};

      for (var track in playlistTracks.docs){
        String artist = track.data()['artist'];
        String imageUrl = track.data()['imageUrl'];
        String previewUrl = track.data()['previewUrl'] ?? '';
        String title = track.data()['title'];
        String id = track.id;
        
        newTracks[id] = {'artist': artist, 'imageUrl': imageUrl, 'previewUrl': previewUrl, 'title': title};
      }

      return newTracks;
    }
    catch (e){
      debugPrint('Caught Error in database_calls function getTracks: $e');
    }
    throw Exception('Escaped return in getTracks');
  }

  //Add Track to Tracks Collection
  Future<void> createTrackDocs(String userId, List<TrackModel> trackModels, String playlistId) async{
    try{
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final tracksRef = playlistRef.doc(playlistId).collection(tracksColl);
      final batch = db.batch();

      for (var model in trackModels){
        //Creates/Updates the track document with the tracks ID as the key & fills the fields with track data
        batch.set(tracksRef.doc(model.id), model.toJson());
      }

      await batch.commit();
    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function creatTrackDoc: $e');
    }
  }

  //Removes the playlist connection in the database
  Future<void> removePlaylistTracks(String userId, List<String> trackIds, String playlistId) async{
      try{
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final tracksRef = playlistRef.doc(playlistId).collection(tracksColl);
      final playlist = await playlistRef.doc(playlistId).get();

      final batch = db.batch();

      if (!playlist.exists){
        throw Exception('Playlist does not exist');
      }

      //Adds all tracks to be deleted to the batch
      for (var id in trackIds){
        batch.delete(tracksRef.doc(id));
      }

      //Deletes all batched tracks
      await batch.commit();
    }
    catch (e){
      debugPrint('Caught an Error in database_calls.dart function removePlaylistTracks: $e');
    }

  }

}