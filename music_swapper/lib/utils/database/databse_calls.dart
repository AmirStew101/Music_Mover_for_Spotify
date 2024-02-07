
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/utils/database/database_model.dart';


final db = FirebaseFirestore.instance;
class UserRepository extends GetxController {
  static UserRepository get instance => Get.find();
  final usersRef = db.collection('Users');
  final playlistColl  = 'Playlists';//Collection name for Users Playlists
  final tracksColl = 'Tracks'; //Collection name for Users Tracks

  final CacheManager cacheManager = DefaultCacheManager();

  Future<bool> hasUser(UserModel user) async {
    try{
      final DocumentSnapshot<Map<String, dynamic>> userExists = await usersRef.doc(user.spotifyId).get();

      if (userExists.exists) {
        return true;
      }
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
      debugPrint('Syncing Playlists');
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final playlistDocs = await playlistRef.get();

      int databasePlaylists = playlistDocs.docs.length;
      int spotPlaylists = spotifyPlaylists.length;


      //Removes playlists from database that are not in Spotify
      for (var playlistDoc in playlistDocs.docs){
        final playlistId = playlistDoc.id;

        if (!spotifyPlaylists.containsKey(playlistId)){
          databasePlaylists--;
          await removePlaylist(userId, playlistId);
          debugPrint('Removing ${playlistDoc.data()['title']}');
        }
      }

      //Adds playlists that Database is missing
      int i = 0;
      List<PlaylistModel> playlists = [];

      while (databasePlaylists != spotPlaylists && i < spotPlaylists){
        final spotPlaylist = spotifyPlaylists.entries.elementAt(i);

        String playlistId = spotPlaylist.key;
        final dataPlaylist = await playlistRef.doc(playlistId).get();

        if (!dataPlaylist.exists){
          databasePlaylists++;

          PlaylistModel newPlaylist = PlaylistModel(
          title: spotPlaylist.value['title'], 
          id: playlistId, 
          link: spotPlaylist.value['link'], 
          imageUrl: spotPlaylist.value['imageUrl'], 
          snapshotId: spotPlaylist.value['snapshotId'],
          trackIds: []);

          playlists.add(newPlaylist);

          debugPrint('Adding ${newPlaylist.title}');
        }

        i++;
      }

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

      final playlist = await playlistRef.doc(playlistId).get();
      List<dynamic> trackIds = playlist.data()?['trackIds'];

      await playlistRef.doc(playlistId).delete(); //Removes PLaylist from collection

      final tracksRef = usersRef.doc(userId).collection(tracksColl);
      final deleteBatch = db.batch();

      //Removes all of the Playlist's track connections
      for (var id in trackIds){
        final track = await tracksRef.doc().get(id); //Get the tracks Fields

        if (track.exists){
          int totalPlaylists = track.data()?['totalPlaylists']; //Get the number of playlists the track is in
          totalPlaylists--;

          //Removes track that user has removed from all playlists
          if (totalPlaylists == 0){
            deleteBatch.delete(tracksRef.doc(id));
          }
        }
      }

      await deleteBatch.commit();
    }
    catch (e){
      debugPrint('Error Removing Playlist: $e');
    }

  }

  //Check if Track is in Users Playlist in database
  Future<void> syncPlaylistTracks(String userId, Map<String, dynamic> spotifyTracks, String playlistId) async{
    try{
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final playlist = await playlistRef.doc(playlistId).get();
      

      List<dynamic> trackIds = playlist.data()?['trackIds'];

      int databaseTracks = trackIds.length;
      int spotTracks = spotifyTracks.length;
      List<String> removeTracks = [];
      
      //Removes extra tracks from playlist
      for (var id in trackIds){
        if (!spotifyTracks.containsKey(id)){
          databaseTracks--;
          removeTracks.add(id);
          debugPrint('Removing ${spotifyTracks[id]['title']}');
        }
      }

      if(removeTracks.isNotEmpty){
        await removePlaylistTracks(userId, removeTracks, playlistId);
      }

      if (databaseTracks > 0){
        //If Spotify & Database do not have matching tracks it adds
        int i = 0;
        List<TrackModel> createTracks = [];

        while(databaseTracks != spotTracks && i < spotTracks){
          final track = spotifyTracks.entries.elementAt(i);
          String trackId = track.key;

          if (!trackIds.contains(trackId)){
            databaseTracks++;

            TrackModel newTrack = TrackModel(
              totalPlaylists: 1, 
              id: trackId, 
              imageUrl: track.value['imageUrl'], 
              artist: track.value['artist'], 
              title: track.value['title'],
              previewUrl: track.value['previewUrl']
            );

            debugPrint('Adding ${newTrack.title}');
          }

          i++;
        }

        if (createTracks.isNotEmpty){
          await createTrackDocs(userId, createTracks, playlistId);
        }
      }
    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function syncPlaylistTracks: $e');
    }
  }

  //Get track names for a given playlist
  Future<Map<String, dynamic>> getTracks(String userId, String playlistId) async{
    try{
      final playlist = await usersRef.doc(userId).collection(playlistColl).doc(playlistId).get();
      final trackIds = playlist.data()?['trackIds'];

      final tracksRef = usersRef.doc(userId).collection(tracksColl);

      Map<String, dynamic> playlistTracks = {};
      List<Future<DocumentSnapshot<Map<String, dynamic>>>> trackFutures = [];

      for (var id in trackIds){
        trackFutures.add(tracksRef.doc(id).get());
      }

      final trackSnaps = await Future.wait(trackFutures);

      for (var i=0; i < trackSnaps.length; i++){
        final track = trackSnaps[i];

        String artist = track.data()?['artist'];
        String imageUrl = track.data()?['imageUrl'];
        String previewUrl = track.data()?['previewUrl'] ?? '';
        String title = track.data()?['title'];
        String id = track.id;
        
        playlistTracks[id] = {'artist': artist, 'imageUrl': imageUrl, 'previewUrl': previewUrl, 'title': title};
      }

      return playlistTracks;
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
      final tracksRef = usersRef.doc(userId).collection(tracksColl);
      final playlist = await playlistRef.doc(playlistId).get();
      final batch = db.batch();

      List<dynamic> trackIds = playlist.data()?['trackIds'];

      for (var model in trackModels){
        String trackId = model.id;

        //Adds the track Id to the Playlist's tracks
        if (!trackIds.contains(trackId)){
          trackIds.add(trackId);
          batch.update(playlistRef.doc(playlistId), {'trackIds': trackIds});
        }

        final trackDoc = await tracksRef.doc(trackId).get();
        
        //Updates Track data if it exists already
        if (trackDoc.exists){
          batch.update(tracksRef.doc(trackId), {'totalPlaylists': FieldValue.increment(1)});
          debugPrint('Track Exists ${trackDoc.data()}');
        }
        //Creates a new Track document if none exits
        else{
          debugPrint('New Track ${model.title}');
          //Creates the track document with the tracks ID as the key & fills the fields with track data
          batch.set(tracksRef.doc(model.id), model.toJson());
        }
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
      final playlist = await playlistRef.doc(playlistId).get();
      final tracksRef = usersRef.doc(userId).collection(tracksColl);
      final batch = db.batch();

      if (!playlist.exists){
        throw Exception('Playlist does not exist');
      }

      for (var id in trackIds){
        final track = await tracksRef.doc(id).get();

        //Get Track ids and remove the chosen track from the list
        batch.update(playlistRef.doc(playlistId), {'trackIds': FieldValue.arrayRemove([id])});

        if (track.exists){
          //Updates the total number of playlists the track is in
          batch.update(tracksRef.doc(id), {'totalPlaylists':FieldValue.increment(-1)});
          int totalPlaylists = track.data()?['totalPlaylists'];

          //Removes track from Collection if user has removed the Track from all playlists
          if (totalPlaylists == 0){
            batch.delete(tracksRef.doc(id));
          }
        }
        
      }

      await batch.commit();
    }
    catch (e){
      debugPrint('Caught an Error in database_calls.dart function removePlaylistTracks: $e');
    }

  }

}