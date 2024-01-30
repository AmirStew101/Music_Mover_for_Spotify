

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel{
  final String? username;
  final String spotifyId;
  final String uri;
  
  const UserModel({
    this.username,
    required this.spotifyId,
    required this.uri,
  });

  toJson(){
    return {
      'Username': username,
      'Uri': uri,
    };
  }
}

class TrackModel{
  final String trackId;
  final String imageUrl;
  final String? previewUrl;
  final String artist;
  final String title;
  final List playlistIds;

  const TrackModel({
    required this.playlistIds,
    required this.trackId,
    required this.imageUrl,
    this.previewUrl,
    required this.artist,
    required this.title,
  });

  toJson(){
    return {
      'imageUrl': imageUrl,
      'previewUrl': previewUrl,
      'artist': artist,
      'title': title,
      'playlistIds': playlistIds,
    };
  }
}

class PlaylistModel {
  final String playlistId;
  final String link;
  final String imageUrl;
  final String snapshotId;
  final String title;

  const PlaylistModel({
    required this.title,
    required this.playlistId,
    required this.link,
    required this.imageUrl,
    required this.snapshotId,
  });

  toJson(){
    return {
      'title': title,
      'link': link,
      'imageUrl': imageUrl,
      'snapshotId': snapshotId,
    };
  }
}

