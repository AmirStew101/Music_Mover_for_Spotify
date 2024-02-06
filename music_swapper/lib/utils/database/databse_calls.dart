
import 'package:another_flushbar/flushbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:music_swapper/utils/database/database_model.dart';

class UserRepository extends GetxController {
  static UserRepository get instance => Get.find();
  final usersRef = FirebaseFirestore.instance.collection('Users');
  final playlistColl  = 'Playlists';//Collection name for Users Playlists
  final tracksColl = 'Tracks'; //Collection name for Users Tracks
  final batch = FirebaseFirestore.instance.batch();

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
      while (databasePlaylists != spotPlaylists && i < spotPlaylists){
        final spotPlaylist = spotifyPlaylists.entries.elementAt(i);

        String playlistId = spotPlaylist.key;
        final dataPlaylist = await playlistRef.doc(playlistId).get();

        if (!dataPlaylist.exists){
          databasePlaylists++;

          PlaylistModel playlistModel = PlaylistModel(
          title: spotPlaylist.value['title'], 
          id: playlistId, 
          link: spotPlaylist.value['link'], 
          imageUrl: spotPlaylist.value['imageUrl'], 
          snapshotId: spotPlaylist.value['snapshotId'],
          trackIds: []);

          await createPlaylist(userId, playlistModel);
          debugPrint('Adding ${playlistModel.title}');
        }

        i++;
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
  Future<void> createPlaylist(String userId, PlaylistModel playlist) async{
    try{
    final playlistRef = usersRef.doc(userId).collection(playlistColl);
    await playlistRef.doc(playlist.id).set(playlist.toJson());
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

      //Removes all of the Playlist's track connections
      if (trackIds.isNotEmpty){      
        for (var id in trackIds){
          final track = await tracksRef.doc().get(id); //Get the tracks Fields

          if (track.exists){
            int totalPlaylists = track.data()?['totalPlaylists']; //Get the number of playlists the track is in
            totalPlaylists--;

            //Removes track that user has removed from all playlists
            if (totalPlaylists == 0){
              await tracksRef.doc(id).delete();
            }
          }
        }
      }
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
      
      //Removes extra tracks from playlist
      for (var id in trackIds){
        if (!spotifyTracks.containsKey(id)){
          databaseTracks--;
          await removePLaylistTrack(userId, id, playlistId);
          debugPrint('Removing ${spotifyTracks[id]['title']}');
        }
      }

      if (databaseTracks > 0){
        //If Spotify & Database do not have matching tracks it adds
        int i = 0;
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

            await createTrackDoc(userId, newTrack, playlistId);
            debugPrint('Adding ${newTrack.title}');
          }

          i++;
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

      for (var id in trackIds){
        final track = await tracksRef.doc(id).get();

        String artist = track.data()?['artist'];
        String imageUrl = track.data()?['imageUrl'];
        String previewUrl = track.data()?['previewUrl'] ?? '';
        String title = track.data()?['title'];
        
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
  Future<void> createTrackDoc(String userId, TrackModel trackModel, String playlistId) async{
    try{
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final tracksRef = usersRef.doc(userId).collection(tracksColl);

      final playlist = await playlistRef.doc(playlistId).get();
      List<dynamic> trackIds = playlist.data()?['trackIds'];
      String trackId = trackModel.id;

      //Adds the track Id to the Playlist's tracks
      if (!trackIds.contains(trackId)){
        trackIds.add(trackId);
        await playlistRef.doc(playlistId).update({'trackIds': trackIds});
      }

      final trackDoc = await tracksRef.doc(trackId).get();
      
      //Updates Track data if it exists already
      if (trackDoc.exists){
        int totalPlaylists = trackDoc.data()?['totalPlaylists'];
        totalPlaylists++;
        await tracksRef.doc(trackId).update({'totalPlaylists': totalPlaylists});
        debugPrint('Track Exists ${trackDoc.data()}');
      }
      //Creates a new Track document if none exits
      else{
        debugPrint('New Track ${trackModel.title}');
        //Creates the track document with the tracks ID as the key & fills the fields with track data
        await tracksRef.doc(trackModel.id).set(trackModel.toJson());
      }
    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function creatTrackDoc: $e');
    }
  }

  //Removes the playlist connection in the database
  Future<void> removePLaylistTrack(String userId, String trackId, String playlistId) async{
    final playlistRef = usersRef.doc(userId).collection(playlistColl);
    final playlist = await playlistRef.doc(playlistId).get();

    final tracksRef = usersRef.doc(userId).collection(tracksColl);
    final track = await tracksRef.doc(trackId).get();

    if (playlist.exists){

      //Get Track ids and remove the chosen track from the list
      List<String> trackIds = playlist.data()?['trackIds'];
      trackIds.remove(trackId);
      await playlistRef.doc(playlistId).update({'trackIds': trackIds});

      //Get the total number of playlists the track is in
      int totalPlaylists = track.data()?['totalPlaylists'];
      totalPlaylists--;

      //Removes track from Collection if user has removed the Track from all playlists
      if (totalPlaylists == 0){
        await tracksRef.doc(trackId).delete();
      }
      //Updates Collection if track is connected to atleast one of the users playlist
      else{
        await tracksRef.doc(trackId).update({'totalPlaylists': totalPlaylists});
      }
    }

  }

  Future<void> batchDeleteTracks(String userId, List<String> trackIds, String playlistId) async{
    // final playlistRef = usersRef.doc(userId).collection(playlistColl);
    // final playlist = await playlistRef.doc(playlistId).get();

    // final tracksRef = usersRef.doc(userId).collection(tracksColl);
    // final track = await tracksRef.doc(trackId).get();

    // for (var id in trackIds){
      
    // }

    // if (playlist.exists){

    //   //Get Track ids and remove the chosen track from the list
    //   List<String> trackIds = playlist.data()?['trackIds'];
    //   trackIds.remove(trackId);
    //   await playlistRef.doc(playlistId).update({'trackIds': trackIds});

    //   //Get the total number of playlists the track is in
    //   int totalPlaylists = track.data()?['totalPlaylists'];
    //   totalPlaylists--;

    //   //Removes track from Collection if user has removed the Track from all playlists
    //   if (totalPlaylists == 0){
    //     await tracksRef.doc(trackId).delete();
    //   }
    //   //Updates Collection if track is connected to atleast one of the users playlist
    //   else{
    //     await tracksRef.doc(trackId).update({'totalPlaylists': totalPlaylists});
    //   }
    // }
  }

}