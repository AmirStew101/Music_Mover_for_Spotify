
import 'package:cloud_firestore/cloud_firestore.dart';

///Model for Spotify Track object.
class TrackModel{
  final String id;
  final String imageUrl;
  final String? previewUrl;
  /// Contains the artsits 'name' and 'link' to their Spotify page.
  final Map<String, dynamic> _artists;
  final List<String> _artistName = <String>[];
  final List<String> _artistLink = <String>[];

  /// Contains the tracks 'album name' and 'link' to the albums Spotify page.
  final Map<String, dynamic> _album;
  late final String _albumTitle;
  late final String _albumLink;

  final String title;
  int duplicates;
  bool liked;
  late final DocumentReference<Object> trackReference;

  ///Model for a Spotify Track object.
  TrackModel({
    this.id = '',
    this.imageUrl = '',
    this.previewUrl = '',
    Map<String, dynamic>? artists,
    Map<String, dynamic>? album,
    this.title = '',
    this.duplicates = 0,
    this.liked = false,
    DocumentReference<Object>? trackDocRef
  }) 
  : 
  _artists = artists ?? const <String, dynamic>{}, 
  _album = album ?? const <String, dynamic>{}
  {
    if(trackDocRef != null){
      trackReference = trackDocRef;
    }
    if(_artists.isNotEmpty){
      _artists.forEach((String key, value) {
        _artistName.add(key);
        _artistLink.add(value['spotify']);
      });
    }
    if(_album.isNotEmpty){
      _albumTitle = _album.keys.first;
      _albumLink = _album.values.first['spotify'];
    }
  }

  Map<String, dynamic> get artists{
    return _artists;
  }

  List<String> get artistName{
    return _artistName;
  }

  List<String> get artistLink{
    return _artistLink;
  }

  String get albumTitle{
    return _albumTitle;
  }

  String get albumLink{
    return _albumLink;
  }

  /// True if the track doesn't have values.
  bool get isEmpty{
    return (id == '' && imageUrl == '' && _artists.isEmpty && title == '' && _album.isEmpty);
  }

  /// True if the track does have values.
  bool get isNotEmpty{
    return !(id == '' && imageUrl == '' && _artists.isEmpty && title == '' && _album.isEmpty);
  }

  @override
  String toString(){
    return 'TrackModel(id: $id, title: $title, artists: ${_artists.toString()}, album: ${_album.toString()} duplicates: $duplicates, imageUrl: $imageUrl, liked: $liked)';
  }
  
}
