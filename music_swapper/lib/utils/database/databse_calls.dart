
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

      PlaylistModel likedSongs = const PlaylistModel(
        title: 'Liked Songs', 
        playlistId: 'Liked Songs', 
        link: '', 
        imageUrl: 'assets/images/spotify_liked_songs.jpg', 
        snapshotId: '');

      await createPlaylist(user.spotifyId, likedSongs);
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

      //Removes playlists from database that are not in Spotify
      for (var playlistDoc in playlistDocs.docs){
        final playlistId = playlistDoc.id;

        if (!spotifyPlaylists.containsKey(playlistId)){
          await removePlaylist(userId, playlistId);
          debugPrint('Removing ${playlistDoc.data()['title']}');
        }
      }

      //Adds playlists to database that are in Spotify
      for (var spotPlaylist in spotifyPlaylists.entries){
        final playlistId = spotPlaylist.key;
        final dataPlaylist = await playlistRef.doc(playlistId).get();

        if (!dataPlaylist.exists){

          PlaylistModel playlistModel = PlaylistModel(
          title: spotPlaylist.value['title'], 
          playlistId: playlistId, 
          link: spotPlaylist.value['link'], 
          imageUrl: spotPlaylist.value['imageUrl'], 
          snapshotId: spotPlaylist.value['snapshotId']);

          createPlaylist(userId, playlistModel);
          debugPrint('Adding ${playlistModel.title}');
        }
      }

    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function hasPlaylist $e');
    }
  }

  //Add all Playlists as collections to database
  Future<void> createPlaylist(String userId, PlaylistModel playlist) async{
    try{
    final playlistRef = usersRef.doc(userId).collection(playlistColl);
    await playlistRef.doc(playlist.playlistId).set(playlist.toJson());
    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function createPlaylist $e');
    }

  }

  Future<Map<String, dynamic>> getPlaylists(String userId) async{
    try {
      //Gets all the Docs in the Playlist Ref
      QuerySnapshot<Map<String, dynamic>> playlistDocs = await usersRef.doc(userId).collection(playlistColl).get();
      Map<String, dynamic> allPlaylists = {};

      //For every Doc it adds its fields to the Spotify Id as a Map
      for (var element in playlistDocs.docs) {
        allPlaylists[element.id] = element.data();
      }

      return allPlaylists;
    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function getPlaylists: $e');
    }
    throw Exception('Escaped return in getPlaylists');
  }

  Future<void> removePlaylist(String userId, String playlistId) async{
    try{    
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      await playlistRef.doc(playlistId).delete(); //Removes PLaylist from collection

      final tracksRef = usersRef.doc(userId).collection(tracksColl);
      final tracksDocs = await tracksRef.get();

      //Removes all of the Playlist's track connections
      if (tracksDocs.docs.isNotEmpty){      
        for (var trackDoc in tracksDocs.docs){
          final trackId = trackDoc.id;

          final trackField = await tracksRef.doc(trackId).get();
          List<dynamic> playlistIds = trackField.data()?['playlistIds'];

          if (playlistIds.contains(playlistId)){
            await removePLaylistTrack(userId, trackId, playlistId);
          }
        }
      }
    }
    catch (e){
      debugPrint('Error Removing Playlist: $e');
    }

  }


  //Get track names for a given playlist
  Future<Map<String, dynamic>> getTracks(String userId, String playlistId) async{
    try{
      final tracksDocs = await usersRef.doc(userId).collection(tracksColl).get();
      Map<String, dynamic> playlistTracks = {};

      final data = tracksDocs.docs.where((element) => element.data()['playlistIds'].contains(playlistId));
      for (var doc in tracksDocs.docs){
        //All the playlists the current track is in
        List<dynamic> playlistIds = doc.data()['playlistIds'];

        if (playlistIds.contains(playlistId)){
          String trackId = doc.id;

          //Data that makes up a track
          Map<String, dynamic> trackMap = {
            'title': doc.data()['title'], 
            'artist': doc.data()['artist'], 
            'previewUrl': doc.data()['previewUrl'] ?? '', 
            'imageUrl': doc.data()['imageUrl']};

          playlistTracks.putIfAbsent(trackId, () => trackMap);
        }
      }
      return playlistTracks;

    }
    catch (e){
      debugPrint('Caught Error in database_calls function getTracks: $e');
    }
    throw Exception('Escaped return in getTracks');
  }

  //Check if Track is in Users Playlist in database
 Future<void> syncPlaylistTracks(String userId, Map<String, dynamic> spotifyTracks, String playlistId) async{
    try{
      final tracksRef = usersRef.doc(userId).collection(tracksColl);
      final trackDocs = await tracksRef.get();

      //Compares each track with tracks in Spotify playlist
      for (var trackDoc in trackDocs.docs){
        final trackId = trackDoc.id;

        //Remove playlist ID from Tracks playlistIds
        if (!spotifyTracks.containsKey(trackId)){
          await removePLaylistTrack(userId, trackId, playlistId);
        }
      }

      //Adds Spotify Tracks to database 
      for (var track in spotifyTracks.entries){
        String trackId = track.key;
        bool hasTrack = trackDocs.docs.any((doc) => doc.id == trackId);

        //Updates Tracks playlistIds by adding current playlistId
        if (hasTrack){
          await addPlaylistTrack(userId, trackId, playlistId);
        }
        //Creates a new Track with given playlistId connection
        else{
          TrackModel newTrack = TrackModel(
            playlistIds: [playlistId], 
            trackId: trackId, 
            imageUrl: track.value['imageUrl'], 
            artist: track.value['artist'], 
            title: track.value['title']);

          await createTrackDoc(userId, newTrack, playlistId);
        }
      }
    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function syncPlaylistTracks: $e');
    }
  }

  //Add Track to Tracks Collection
  Future<void> createTrackDoc(String userId, TrackModel trackModel, String playlistId) async{
    try{
      final trackRef = usersRef.doc(userId).collection(tracksColl);

      //Creates the track document with the tracks ID as the key & fills the fields with track data
      await trackRef.doc(trackModel.trackId).set(trackModel.toJson());

      //Adds the playlist to Tracks playlistIds
      await addPlaylistTrack(userId, trackModel.trackId, playlistId);
    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function creatTrackDoc: $e');
    }
  }

  //Adds a connection to a Playlist for a Track
  Future<void> addPlaylistTrack(String userId, String trackId, String playlistId) async{
    try{
    final tracksRef = usersRef.doc(userId).collection(tracksColl);
    final trackFields = await tracksRef.doc(trackId).get();

    List<dynamic> playlistIds = trackFields.data()?['playlistIds'];

    if (!playlistIds.contains(playlistId)){
      playlistIds.add(playlistId);
      
      await tracksRef.doc(trackId).update({'playlistIds': playlistIds});
    }

    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function addTrackPlaylist: $e');
    }
  }

  //Removes the playlist connection in the database
  Future<void> removePLaylistTrack(String userId, String trackId, String playlistId) async{
    final tracksRef = usersRef.doc(userId).collection(tracksColl);
    final track = await tracksRef.doc(trackId).get();

    if (track.exists){
      List<dynamic> playlistIds = track.data()?['playlistIds'];
      playlistIds.remove(playlistId);

      //Updates Collection if track is connected to one of the users playlist
      if (playlistIds.isNotEmpty){
        tracksRef.doc(trackId).update({'playlistIds': playlistIds});
      }
      //Removes track from Collection if user has removed the Track from all playlists
      else{
        tracksRef.doc(trackId).delete();
      }
    }



  }
}