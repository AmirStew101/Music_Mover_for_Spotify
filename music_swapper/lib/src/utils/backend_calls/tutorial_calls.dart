
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spotify_music_helper/src/utils/class%20models/playlist_model.dart';
import 'package:spotify_music_helper/src/utils/class%20models/track_model.dart';

final FirebaseFirestore db = FirebaseFirestore.instance;

class TutorialCalls extends Object{
  /// Test user data for viewing.
  static const String test_user = '31rzpaxkysira77u2durfkotvtoi';
  static const playCol = 'Playlists';

  final List<PlaylistModel> allPlaylists = [];

  /// Reference to Users collection.
  final CollectionReference<Map<String, dynamic>> usersRef = db.collection('Users');

  Future<void> devInitTests(List<PlaylistModel> playlists) async{
    final playlistRef = db.collection(playCol);
    
    for(PlaylistModel playlist in playlists){
      await playlistRef.add(playlist.toJson());
    }

    await initializeTest();

  }

  Future<void> initializeTest() async{
    final playlistRef = await db.collection(playCol).get();

    if(playlistRef.docs.isNotEmpty){

      for(var doc in playlistRef.docs){

        List<dynamic> jsonTracks = doc.data()['tracks'];
        List<TrackModel> tracksList = [];

        for(dynamic item in jsonTracks){
          tracksList.add(TrackModel.fromJson(item));
        }

        allPlaylists.add(PlaylistModel(
          id: doc.id,
          imageUrl: doc.data()['imageUrl'],
          link: doc.data()['link'],
          snapshotId: doc.data()['snapshotId'],
          title: doc.data()['title'],
          tracks: tracksList
        ));
      }
    }
  }


}