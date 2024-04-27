
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spotify_music_helper/src/utils/track_model.dart';

///Model for Spotify Playlist object.
class PlaylistModel {
  final String id;
  final String link;
  final String imageUrl;
  final String snapshotId;
  final String title;
  late final DocumentReference<Object> playlistRef;
  Map<String, TrackModel> tracks;

  ///Model for a Spotify Playlist object.
  PlaylistModel({
    this.id = '',
    this.title = '',
    this.link = '',
    this.imageUrl = '',
    this.snapshotId = '',
    this.tracks = const <String, TrackModel>{},
    DocumentReference<Object>? reference
  }){
    if(reference != null){
      playlistRef = reference;
    }
  }


  @override
  String toString(){
    return 'PlaylistModel(id: $id, title: $title, snapshotId: $snapshotId, link: $link, imageUrl: $imageUrl)';
  }

}