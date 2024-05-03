

import 'dart:convert';

import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';

///Model for Spotify Track object.
class TrackModel extends Object{
  final String id;
  final String imageUrl;
  final String? previewUrl;

  /// Contains the artsits 'name' and 'link' to their Spotify page.
  final Map<String, dynamic> _artists;
  final List<String> _artistNames = <String>[];
  final List<String> _artistLinks = <String>[];

  /// Contains the tracks 'album name' and 'link' to the albums Spotify page.
  final Map<String, dynamic> _album;
  late final String _albumTitle;
  late final String _albumLink;

  final String title;
  final DateTime _addedAt;

  /// If the Track is a 'track' or an 'episode'
  late final String _type;

  int duplicates;
  bool liked;

  String dupeId = '';

  static const String _episode = 'episode';
  static const String _track = 'track';

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
    String? type,
    DateTime? addedAt,
    String? dupeId
  }) 
  : 
  _artists = artists ?? const <String, dynamic>{}, 
  _album = album ?? const <String, dynamic>{},
  _addedAt = addedAt ?? DateTime.now()
  {
    if(_artists.isNotEmpty){
      _artists.forEach((String key, dynamic value) {
        _artistNames.add(key);
        _artistLinks.add(value);
      });
    }
    if(_album.isNotEmpty){
      _albumTitle = _album.keys.first;
      _albumLink = _album.values.first;
    }

    if(type == null){
      _type = _track;
    }
    else if(type != _track && type != _episode){
      _type = _track;
    }
    else{
      _type = type;
    }

    if(dupeId != null){
      this.dupeId = dupeId;
    }
  }

  String get type{
    return _type;
  }

  /// The time the track was added to the playist.
  DateTime get addedAt{
    return _addedAt;
  }

  Map<String, dynamic> get artists{
    return _artists;
  }

  List<String> get artistNames{
    return _artistNames;
  }

  List<String> get artistLinks{
    return _artistLinks;
  }

  String get albumTitle{
    return _albumTitle;
  }

  String get albumLink{
    return _albumLink;
  }

  /// True if the track doesn't have values.
  /// 
  /// Ignores the type, addedAt, liked, and duplicates values since their values are always set.
  bool get isEmpty{
    return id == '' && imageUrl == '' && _artists.isEmpty && title == '' && _album.isEmpty;
  }

  /// True if the track does have values.
  ///
  /// Ignores the type, addedAt, liked, and duplicates values since their values are always set.
  bool get isNotEmpty{
    return !(id == '' && imageUrl == '' && _artists.isEmpty && title == '' && _album.isEmpty);
  }

  bool get isTrack{
    return _type == _track;
  }

  bool get isEpisode{
    return _type == _episode;
  }

  TrackModel copyWith({
    String? id, 
    String? imageUrl, 
    String? previewUrl, 
    Map<String, dynamic>? artists,
    Map<String, dynamic>? album,
    String? title,
    DateTime? addedAt,
    String? type,
    int? duplicates,
    bool? liked,
    String? dupeId
    })
    {

      return TrackModel(
        id: id ?? this.id,
        imageUrl: imageUrl ?? this.imageUrl,
        previewUrl: previewUrl ?? this.previewUrl,
        artists: artists ?? _artists,
        album: album ?? _album,
        title: title ?? this.title,
        addedAt: addedAt ?? this.addedAt,
        type: type ?? this.type,
        duplicates: duplicates ?? this.duplicates,
        liked: liked ?? this.liked,
        dupeId: dupeId ?? this.dupeId
      );

  }

  /// Converts a Json track to a TrackModel
  factory TrackModel.fromJson(Map<String, dynamic> json) {
    List<String> keys = ['id', 'title', 'imageUrl', 'previewUrl', 'artists', 'album', 'addedAt', 'duplicates', 'dupeId', 'type'];
    mapKeysCheck(keys, json, 'PlaylistModel.fromJson');

    String encodedArtists = jsonEncode(json['artists']);
    final String encodeAlbum = jsonEncode(json['album']);

    Map<String, dynamic> artists = jsonDecode(encodedArtists);
    Map<String, dynamic> album = jsonDecode(encodeAlbum);

    return TrackModel(
      id: json['id'],
      title: json['title'],
      imageUrl: json['imageUrl'],
      previewUrl: json['previewUrl'],
      artists: artists,
      album: album,
      addedAt: DateTime.tryParse(json['addedAt']),
      duplicates: json['duplicates'],
      dupeId: json['dupeId'],
      type: json['type']
    );
  }

  /// Converts a TrackModel to a Json track
  Map<String, dynamic> toJson() => 
  <String, dynamic>{
    'id': id,
    'title': title,
    'imageUrl': imageUrl,
    'previewUrl': previewUrl,
    'artists': _artists,
    'album': _album,
    'addedAt': _addedAt.toString(),
    'duplicates': duplicates,
    'dupeId': dupeId,
    'type': _type,
    'liked': liked
  };

  @override
  String toString(){
    return 'TrackModel(id: $id, title: $title)';
  }

  @override
  bool operator==(Object other){
    if(identical(this, other)) return true;
    if(other is! TrackModel) return false;
    if(other.isEmpty && isNotEmpty) return false;
    if(other.isEmpty && isEmpty) return true;
    
    return other.id == id 
    && other.title == title
    && other.imageUrl == imageUrl
    && other._type == _type
    && other.liked == liked
    && other.duplicates == duplicates
    && other.addedAt == addedAt
    && other._artistNames == _artistNames
    && other._artistLinks == _artistLinks
    && other._albumTitle == _albumTitle
    && other._albumLink == _albumLink;
  }
  
  @override
  int get hashCode => 
  id.hashCode 
  ^ title.hashCode
  ^ imageUrl.hashCode
  ^ _type.hashCode
  ^ liked.hashCode
  ^ duplicates.hashCode
  ^ addedAt.hashCode
  ^ _artistNames.hashCode
  ^ _artistLinks.hashCode
  ^ _albumTitle.hashCode
  ^ _albumLink.hashCode;
  
  
}
