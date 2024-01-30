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
  Future<bool> hasPlaylist(String userId, String playlistId) async{
    try{
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final hasPlaylist = await playlistRef.doc(playlistId).get(); 

      if (hasPlaylist.exists){
          return true;
      }

      return false;
    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function hasPlaylist $e');
    }
    throw Exception('Escaped return in hasPlaylist');
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


  //Check if Track is in Users Playlist in database
 Future<bool> hasTrack(String userId, String trackId) async{
    try{
      final tracksRef = usersRef.doc(userId).collection(tracksColl);
      final hasTrack = await tracksRef.doc(trackId).get();

      if (hasTrack.exists){
        return true;
      }

      return false;
    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function hasTrack: $e');
    }

    debugPrint('Playlist doesn\'t have track');
    return false;
  }

  //Add Track to Tracks Collection
  Future<void> createTrackDoc(String userId, TrackModel track, String trackId) async{
    try{
      final trackRef = usersRef.doc(userId).collection(tracksColl);
      await trackRef.doc(trackId).set(track.toJson());
    }
    catch (e){
      debugPrint('Caught Error in database_calls.dart Function creatTrackDoc: $e');
    }
  }

  //Adds a connection to a Playlist for a Track
  Future<void> addTrackPlaylist(String userId, String trackId, String playlistId) async{
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

  //Get track names for a given playlist
  Future<Map<String, dynamic>> getTracks(String userId, String playlistId) async{
    try{
      final tracksDocs = await usersRef.doc(userId).collection(tracksColl).get();
      Map<String, dynamic> playlistTracks = {};

      final data = tracksDocs.docs.where((element) => element.data()['playlistIds'].contains(playlistId));
      debugPrint('Data: $data');

      // for (var track in tracksDocs.docs){
      //   Map<String, dynamic> trackData = track.data();
      //   List<dynamic> playlistIds = trackData['playlistIds'];

      //   if (playlistIds.contains(playlistId)){

      //   }
      // }
      return playlistTracks;

    }
    catch (e){
      debugPrint('Caught Error in database_calls function getTracks: $e');
    }
    throw Exception('Escaped return in getTracks');
  }

}