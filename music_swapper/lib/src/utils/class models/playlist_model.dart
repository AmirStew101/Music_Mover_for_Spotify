
import 'dart:convert';

import 'package:music_mover/src/utils/class%20models/track_model.dart';
import 'package:music_mover/src/utils/global_classes/global_objects.dart';
import 'package:music_mover/src/utils/globals.dart';

///Model for Spotify Playlist object.
class PlaylistModel {
  final String id;
  final String link;
  final String imageUrl;
  final String snapshotId;
  final String title;
  bool loaded = false;
  List<TrackModel> tracks = <TrackModel>[];

  ///Model for a Spotify Playlist object.
  PlaylistModel({
    this.id = '',
    this.title = '',
    this.link = '',
    this.imageUrl = '',
    this.snapshotId = '',
    this.loaded = false,
    this.tracks = const[],
  });

  bool get isEmpty{
    if(id == likedSongs){
      return tracks.isEmpty;
    }
    return id == '' || link == '' || title == '' || tracks.isEmpty;
  }

  bool get isNotEmpty{
    if(id == likedSongs){
      return tracks.isNotEmpty;
    }
    return id != '' || link != '' || title != '' || tracks.isNotEmpty;
  }

  /// Add a track to a playlist or increase the tracks duplicates if it already exists in the playlist.
  void addTrack(TrackModel newTrack){
    TrackModel element = tracks.firstWhere((element) => element.id == newTrack.id, orElse:() => TrackModel());
    if(element.isNotEmpty){
      element.duplicates++;
    }
    else{
      tracks.add(newTrack.copyWith(dupeId: newTrack.id, duplicates: 0));
    }
  }

  /// Removes a Track from the playlist and decrements all other copies duplicate value.
  void removeTrack(TrackModel track){

    tracks.removeWhere((element) {
      if(element.id == track.id){
        element.duplicates--;

        if(element.duplicates < 0) return true;
      }

      return false;
    });
  }

    /// Make duplicates of tracks that have duplicates.
  List<TrackModel> makeDuplicates(){

    int duplicates;
    List<TrackModel> duplicateTracks = [];

    for (TrackModel track in tracks){
      duplicates = track.duplicates;

      // Make duplicates of a track with duplicate ids.
      if (duplicates > 0){
        for (int ii = 0; ii <= duplicates; ii++){
          String dupeId = ii == 0
          ? track.id
          : '${track.id}_$ii';

          // Create a dupicate with a modified Id
          duplicateTracks.add(track.copyWith(dupeId: dupeId));
        }
      }
      // Create the original track with an unmodified dupelicate Id
      else{
        duplicateTracks.add(track.copyWith(dupeId: track.id));
      }
    }

    return duplicateTracks;
  }


  factory PlaylistModel.fromJson(Map<String, dynamic> json){
    List<String> keys = ['id', 'link', 'imageUrl', 'snapshotId', 'title', 'loaded', 'tracks'];
    mapKeysCheck(keys, json, 'PlaylistModel.fromJson');

    List<dynamic> jsonTracks = json['tracks'];
    List<TrackModel> tracksList = [];

    for(dynamic item in jsonTracks){
      /// Encode the Map as a Json map with "" around each key
      final String encoded = jsonEncode(item);

      /// Decode the String to a Map.
      Map<String, dynamic> mapItem = jsonDecode(encoded);
      tracksList.add(TrackModel.fromJson(mapItem));
    }

    return PlaylistModel(
      id: json['id'],
      link: json['link'],
      imageUrl: json['imageUrl'],
      snapshotId: json['snapshotId'],
      title: json['title'],
      loaded: json['loaded'],
      tracks: tracksList,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'link': link,
    'imageUrl': imageUrl,
    'snapshotId': snapshotId,
    'title': title,
    'tracks': tracksToJson(),
    'loaded': loaded
  };

  List<dynamic> tracksToJson(){
    List<dynamic> jsonTracks = [];

    for(TrackModel track in tracks){
      jsonTracks.add(track.toJson());
    }

    return jsonTracks;
  }


    @override
  bool operator==(Object other){
    if(identical(this, other)) return true;
    if(other is! PlaylistModel) return false;
    
    return other.id == id 
    && other.title == title;
  }
  
  @override
  int get hashCode => 
  id.hashCode 
  ^ title.hashCode;

  @override
  String toString(){
    return 'PlaylistModel(id: $id, title: $title, snapshotId: $snapshotId, link: $link, imageUrl: $imageUrl, tracks: ${tracks.toString()})';
  }

}