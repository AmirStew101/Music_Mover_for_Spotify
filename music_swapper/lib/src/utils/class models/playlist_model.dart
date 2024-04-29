
import 'package:spotify_music_helper/src/utils/class%20models/track_model.dart';

///Model for Spotify Playlist object.
class PlaylistModel {
  final String id;
  final String link;
  final String imageUrl;
  final String snapshotId;
  final String title;
  List<TrackModel> _tracks;
  Map<String, TrackModel> _tracksDupes = {};

  ///Model for a Spotify Playlist object.
  PlaylistModel({
    this.id = '',
    this.title = '',
    this.link = '',
    this.imageUrl = '',
    this.snapshotId = '',
    List<TrackModel>? tracks,
  }) : _tracks = tracks ?? const <TrackModel>[]{
    _makeDuplicates();
  }

  List<TrackModel> get tracks{
    return _tracks;
  }

  set tracks(List<TrackModel> newTracks){
    _tracks = newTracks;
    _makeDuplicates();
  }

  Map<String, TrackModel> get tracksDupes{
    return _tracksDupes;
  }

  /// Add a track to a playlist or increase the tracks duplicates if it already exists in the playlist.
  void addTrack(TrackModel trackModel){
    if(_tracks.contains(trackModel)){
      int index = _tracks.indexWhere((_) => _ == trackModel);
      _tracks[index].duplicates++;
    }
    else{
      _tracks.add(trackModel);
    }
  }

  /// Decrease a tracks dupicates and removes track if dupicatess reach negative.
  void removeTrack(TrackModel trackModel){
    if(_tracks.contains(trackModel)){
      int index = _tracks.indexWhere((_) => _ == trackModel);
      _tracks[index].duplicates--;

      if(_tracks[index].duplicates < 0){
        _tracks.remove(trackModel);
      }
    }
  }

  /// Make duplicates of tracks that have duplicates.
  void _makeDuplicates(){

    int duplicates;
    String dupeId;

    for (TrackModel track in _tracks){
      duplicates = track.duplicates;

      // Make duplicates of a track with duplicates.
      if (duplicates > 0){
        for (int i = 0; i <= duplicates; i++){
          dupeId = i == 0
          ? track.id
          : '${track.id}_$i';

          // Create a dupicate with a modified Id
          tracksDupes.addAll(<String, TrackModel>{dupeId: track});
        }
      }
      // Create the original track with an unmodified Id
      else{
        tracksDupes.addAll(<String, TrackModel>{track.id: track});
      }
    }
  }

  factory PlaylistModel.fromJson(Map<String, dynamic> json){
    List<dynamic> jsonTracks = json['tracks'];
    List<TrackModel> tracksList = [];

    for(dynamic item in jsonTracks){
      tracksList.add(TrackModel.fromJson(item));
    }

    return PlaylistModel(
        id: json['id'],
        link: json['link'],
        imageUrl: json['imageUrl'],
        snapshotId: json['snapshotId'],
        title: json['title'],
        tracks: tracksList,
      );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'link': link,
    'imageUrl': imageUrl,
    'snapshotId': snapshotId,
    'title': title,
    'tracks': _tracksToJson()
  };

  List<dynamic> _tracksToJson(){
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
    && other.title == title
    && other.imageUrl == imageUrl
    && other.snapshotId == snapshotId
    && other.link == link;
  }
  
  @override
  int get hashCode => 
  id.hashCode 
  ^ title.hashCode
  ^ imageUrl.hashCode
  ^ snapshotId.hashCode
  ^ link.hashCode;

  @override
  String toString(){
    return 'PlaylistModel(id: $id, title: $title, snapshotId: $snapshotId, link: $link, imageUrl: $imageUrl, tracks: ${_tracks.toString()}, tracksDupes: ${_tracksDupes.toString()})';
  }

}