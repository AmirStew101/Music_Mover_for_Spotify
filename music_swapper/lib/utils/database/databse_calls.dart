import 'package:another_flushbar/flushbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:music_swapper/utils/database/database_model.dart';

class UserRepository extends GetxController {
  static UserRepository get instance => Get.find();
  final usersRef = FirebaseFirestore.instance.collection('Users');
  final playlistColl  = 'playlists';

  hasUser(UserModel user) async {
    final DocumentSnapshot<Map<String, dynamic>> userExists = await usersRef.doc(user.spotifyId).get();

    if (userExists.exists) {
      return true;
    }
    return false;
  }

  createUser(UserModel user) async {
    try {
      await usersRef.doc(user.spotifyId).set(user.toJson());

      PlaylistModel likedSongs = const PlaylistModel(
        tracks: [], 
        title: 'Liked Songs', 
        playlistId: 'Liked Songs', 
        link: '', 
        imageUrl: 'assets/images/spotify_liked_songs.jpg', 
        snapshotId: '');

      await createPlaylist(user.spotifyId, likedSongs);
    } catch (e) {
      debugPrint('Caught Error: ${e.toString()}');
    }
  }

  //Check if Playlist is in collections
  hasPlaylist(String userId, String playlistId) async{
    QuerySnapshot<Map<String, dynamic>> hasPlaylists = await usersRef
    .doc(userId)
    .collection(playlistColl)
    .get();

    if (hasPlaylists.docs.isNotEmpty){
      final playlistRef = usersRef
      .doc(userId)
      .collection(playlistColl);

      DocumentSnapshot<Map<String, dynamic>> hasPlaylist = await playlistRef.doc(playlistId).get();

      if (hasPlaylist.exists){
        return true;
      }
    }
    return false;
  }

  //Add all Playlists as collections to database
  createPlaylist(String userId, PlaylistModel playlist) async{
    try{
    final playlistRef = usersRef.doc(userId).collection(playlistColl);
    await playlistRef.doc(playlist.playlistId).set(playlist.toJson());
    }
    catch (e){
      debugPrint('Caught Error during createPlaylist $e');
    }

  }

  getPlaylists(String userId) async{
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
      debugPrint('Caught Error in getPlaylists: $e');
    }
  }

  //Check if Track is in Playlist in database
  hasTrack(String userId, String trackName, String playlistId) async{
    try{
      if (await hasPlaylist(userId, playlistId)){
        final collectionRef = usersRef.doc(userId).collection(playlistColl);
        final playlistRef = await collectionRef.doc(playlistId).get();
        final tracksList = playlistRef.data()?['tracks']; //If the document has a 'tracks' field it receives it

        if(tracksList != null){
          if (tracksList.contains(trackName)){
            return true;
          }
        }
      }
    }
    catch (e){
      debugPrint('Caught Error in hasTrack: $e');
    }

    debugPrint('Playlist doesn\'t have track');
    return false;
  }

  //Add Playlist Tracks to Playlists collection in database
  createTrackDoc(String userId, String trackName, String playlistId) async{
    try{
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final playlist = await playlistRef.doc(playlistId).get();

      List<dynamic> currTracks = playlist.data()?['tracks'];
      currTracks.add(trackName);

      await playlistRef.doc(playlistId).update({'tracks': currTracks});
    }
    catch (e){
      debugPrint('Caught Error in creatTrackDoc: $e');
    }
  }

  getTracks(String userId, String playlistId) async{
    try{
      final playlistRef =  usersRef.doc(userId).collection(playlistColl);
    final playlist = await playlistRef.doc(playlistId).get();

    Map<String, dynamic> tracks = playlist.data()?['tracks'];
    debugPrint('\nTracks: $tracks');
    //return tracks
    }
    catch (e){
      debugPrint('Caught Error in database_calls function getTracks: $e');
    }

  }

}