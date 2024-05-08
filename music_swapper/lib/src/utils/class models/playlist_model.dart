
import 'dart:convert';

import 'package:get/get.dart';
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
  final List<TrackModel> _tracks = <TrackModel>[];

  ///Model for a Spotify Playlist object.
  PlaylistModel({
    this.id = '',
    this.title = '',
    this.link = '',
    this.imageUrl = '',
    this.snapshotId = '',
    this.loaded = false,
    List<TrackModel>? tracks,
  }){
    if(tracks != null){
      _tracks.assignAll(tracks);
    }
    else{
      _tracks.clear();
    }
    _makeDuplicates();
  }

  bool get isEmpty{
    if(id == likedSongs){
      return tracks.isEmpty;
    }
    return id == '' || link == '' || title == '' || tracks.isEmpty;
  }

  bool get isNotEmpty{
    if(id == likedSongs){
      return _tracks.isNotEmpty;
    }
    return id != '' || link != '' || title != '' || tracks.isNotEmpty;
  }

  List<TrackModel> get tracks{
    return _tracks;
  }

  set tracks(List<TrackModel> newTracks){
    _tracks.assignAll(newTracks);
    _makeDuplicates();
  }

  void addInitial(TrackModel newTrack){
    if(newTrack.duplicates == 0){
      _tracks.add(newTrack.copyWith(dupeId: newTrack.id));
    }
    else{
      for(int ii = 0; ii <= newTrack.duplicates; ii++){
        String dupeId = ii == 0
        ? newTrack.id
        : '${newTrack.id}_$ii';

        _tracks.add(newTrack.copyWith(dupeId: dupeId));
      }
    }
  }

  /// Add a track to a playlist or increase the tracks duplicates if it already exists in the playlist.
  void addTrack(TrackModel newTrack){
    if(_tracks.contains(newTrack)){
      print('Add duplicate');
      int index = _tracks.indexWhere((_) => _ == newTrack);
      _tracks[index].duplicates++;
      _tracks.add(newTrack.copyWith(dupeId: '${newTrack.id}_${_tracks[index].duplicates}'));
    }
    else{
      print('Add Original');
      _tracks.add(newTrack);
    }
  }

  /// Decrease a tracks dupicates and removes track if dupicatess reach negative.
  void decrementTrack(TrackModel track){
    if(_tracks.contains(track)){
      int index = _tracks.indexWhere((_) => _ == track);
      _tracks[index].duplicates--;

      if(_tracks[index].duplicates < 0){
        _tracks.remove(track);
      }
    }
  }

  /// Make duplicates of tracks that have duplicates.
  void _makeDuplicates(){

    int duplicates;
    List<TrackModel> newTracks = [];

    for (TrackModel track in _tracks){
      duplicates = track.duplicates;

      // Make duplicates of a track with duplicate ids.
      if (duplicates > 0){
        for (int i = 0; i <= duplicates; i++){
          String dupeId = i == 0
          ? track.id
          : '${track.id}_$i';

          // Create a dupicate with a modified Id
          newTracks.add(track.copyWith(dupeId: dupeId));
        }
      }
      // Create the original track with an unmodified dupelicate Id
      else{
        newTracks.add(track.copyWith(dupeId: track.id));
      }
    }

    _tracks.assignAll(newTracks);
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
    'tracks': _tracksToJson(),
    'loaded': loaded
  };

  List<dynamic> _tracksToJson(){
    List<dynamic> jsonTracks = [];

    for(TrackModel track in _tracks){
      jsonTracks.add(track.toJson());
    }

    return jsonTracks;
  }


    @override
  bool operator==(Object other){
    if(identical(this, other)) return true;
    if(other is! PlaylistModel) return false;
    
    return other.id == id 
    && other.title == title
    && other.imageUrl == imageUrl
    && other.link == link;
  }
  
  @override
  int get hashCode => 
  id.hashCode 
  ^ title.hashCode
  ^ imageUrl.hashCode
  ^ link.hashCode;

  @override
  String toString(){
    return 'PlaylistModel(id: $id, title: $title, snapshotId: $snapshotId, link: $link, imageUrl: $imageUrl, tracks: ${_tracks.toString()})';
  }

}