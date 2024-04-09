
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';

///Model for Spotify User object.
class UserModel{
  String? username;
  final String spotifyId;
  final String uri;
  final bool subscribed;
  final int tier;
  final Timestamp expiration;
  late final DocumentSnapshot<Map<String, dynamic>> userDoc;
  
  ///Model for a Spotify User object.
  UserModel({
    this.username,
    this.spotifyId = '',
    this.uri = '',
    this.subscribed = false,
    this.tier = 0,
    Timestamp? expiration, // Change expiration to be nullable
  }) : expiration = expiration ?? Timestamp.fromDate(DateTime.now());

  ///Defaut Model for a Spotify User object with `expiration` set to the current time.
  UserModel.defaultUser() : 
    spotifyId = '', 
    uri = '',
    subscribed = false,
    tier = 0,
    expiration = Timestamp.now();

  ///Firestore Json representation of this object.
  Map<String, dynamic> toFirestoreJson(){
    return {
        'username': username,
        'uri': uri,
        'subscribed': subscribed,
        'tier': tier,
        'expiration': expiration,
      };
  }

  ///Json representation of this object.
  Map<String, dynamic> toJson(){
    return {
      'spotifyId': spotifyId,
      'username': username,
      'uri': uri,
      'subscribed': subscribed,
      'tier': tier,
      'expiration': expiration.toString(),
    };
  }

  ///Converts a given [Map<String, dynamic>] of a user into a [UserModel].
  UserModel toModel(Map<String, dynamic> userMap){
    if (userMap.isEmpty){
      return UserModel.defaultUser();
    }
    if (!userMap.keys.contains('spotifyId')){
      Object error = "Map is missing the required key 'spotifyId'";
      throw Exception( exceptionText('object_models.dart', 'toModel', error));
    }
    if (!userMap.keys.contains('subscribed')){
      Object error = "Map is missing the required key 'subscribed'";
      throw Exception( exceptionText('object_models.dart', 'toModel', error));
    }
    if (!userMap.keys.contains('tier')){
      Object error = "Map is missing the required key 'tier'";
      throw Exception( exceptionText('object_models.dart', 'toModel', error));
    }
    if (!userMap.keys.contains('uri')){
      Object error = "Map is missing the required key 'uri'";
      throw Exception( exceptionText('object_models.dart', 'toModel', error));
    }
    if (!userMap.keys.contains('username')){
      Object error = "Map is missing the required key 'username'";
      throw Exception( exceptionText('object_models.dart', 'toModel', error));
    }
    if (!userMap.keys.contains('expiration')){
      Object error = "Map is missing the required key 'expiration'";
      throw Exception( exceptionText('object_models.dart', 'toModel', error));
    }

    return UserModel(
      spotifyId: userMap['spotifyId'],
      subscribed: userMap['subscribed'],
      tier: userMap['tier'],
      uri: userMap['uri'],
      username: userMap['username'],
      expiration: getTimestamp(userMap['expiration'])
    );
  }

  ///Returns the day for the Subscription expiration.
  int get getDay{
    final day = expiration.toDate().day;
    return day;
  }

  ///Converts a String of a time stamp into a Timestamp and returns it.
  Timestamp getTimestamp(String timeStampeStr){
    //Receives: Timestamp(seconds=1708192429, nanoseconds=179000000)
    final flush = timeStampeStr.split('seconds=');

    final seconds = int.parse(flush[1].split(',')[0]);
    final nanoSeconds = int.parse(flush[2].split(')')[0]);

    final Timestamp timeStamp = Timestamp(seconds, nanoSeconds);

    return timeStamp;
  }

  @override
  String toString(){
    return 'UserModel(spotifyId: $spotifyId, username: $username, uri: $uri, subscribed: $subscribed, tier: $tier, expiration: $expiration)';
  }
}

///Model for Spotify Track object.
class TrackModel{
  final String id;
  final String imageUrl;
  final String? previewUrl;
  final String artist;
  final String title;
  final int duplicates;
  final bool liked;
  late final DocumentSnapshot<Map<String, dynamic>> trackDoc;

  ///Model for a Spotify Track object.
  TrackModel({
    this.id = '',
    this.imageUrl = '',
    this.previewUrl = '',
    this.artist = '',
    this.title = '',
    this.duplicates = 0,
    this.liked = false,
  });

  ///Firestore Json representation of this object.
  Map<String, dynamic> toFirestoreJson(){
    return {
      'imageUrl': imageUrl,
      'previewUrl': previewUrl,
      'artist': artist,
      'title': title,
      'duplicates': duplicates,
      'liked': liked,
    };
  }

  ///True if the track doesn't have values.
  bool get isEmpty{
    if (id == '' && imageUrl == '' && artist == '' && title == ''){
      return true;
    }
    return false;
  }

  ///True if the track does have values.
  bool get isNotEmpty{
    if (id != '' && imageUrl != '' && artist != '' && title != ''){
      return true;
    }
    return false;
  }

  ///Increments the Track's duplicate value by 1.
  TrackModel get incrementDuplicates{
    TrackModel newTrack = TrackModel(
      id: id,
      artist: artist,
      duplicates: duplicates + 1,
      imageUrl: imageUrl,
      liked: liked,
      previewUrl: previewUrl,
      title: title
    );

    return newTrack;

  }

  ///Converts a given [Map<String, dynamic>] of tracks to a [Map<String, TrackModel>] of tracks.
  Map<String, TrackModel> toModelMap(Map<String, dynamic> tracks){
 
    Map<String, TrackModel> newTracks = {};
    for (var track in tracks.entries){
      String id =  track.key;
      String? imageUrl = track.value['imageUrl'];

      newTracks.putIfAbsent(id, () => TrackModel(
        title: track.value['title'], 
        id: id, 
        artist: track.value['artist'],
        imageUrl: imageUrl ?? '', 
        previewUrl: track.value['previewUrl'],
        duplicates: track.value['duplicates'],
        liked: track.value['liked']
        )
      );
    }

    return newTracks;
  }

  ///Converts a given [Map<String, TrackModel>] of tracks to a [Map<String, dynamic>] of tracks.
  Map<String, dynamic> toDynamicMap(Map<String, TrackModel> tracks){
    Map<String, dynamic> newTracks = {};
    
    for (var track in tracks.entries){
      String id = track.key;
      String title = track.value.title;
      String artist = track.value.artist;
      String imageUrl = track.value.imageUrl;
      String previewUrl = track.value.previewUrl ?? '';
      int duplicates = track.value.duplicates;
      bool liked = track.value.liked;

      newTracks.putIfAbsent(id, () => {
        'title': title, 
        'artist': artist, 
        'duplicates': duplicates, 
        'imageUrl': imageUrl, 
        'previewUrl': previewUrl,
        'liked': liked,
        }
      );
    }

    return newTracks;
  }

  @override
  String toString(){
    return 'TrackModel(id: $id, title: $title, artist: $artist, duplicates: $duplicates, imageUrl: $imageUrl, liked: $liked)';
  }
  
}

///Model for Spotify Playlist object.
class PlaylistModel {
  final String id;
  final String link;
  final String imageUrl;
  final String snapshotId;
  final String title;

  ///Model for a Spotify Playlist object.
  const PlaylistModel({
    this.id = '',
    this.title = '',
    this.link = '',
    this.imageUrl = '',
    this.snapshotId = '',
  });

  ///Firestore Json representation of this object.
  Map<String, dynamic> toJsonFirestore(){
    return {
      'title': title,
      'link': link,
      'imageUrl': imageUrl,
      'snapshotId': snapshotId,
    };
  }

  ///Json representation of this object.
  Map<String, dynamic> toJson(){
    return {
      id: {
        'title': title,
        'link': link,
        'imageUrl': imageUrl,
        'snapshotId': snapshotId
      }
    };
  }

  ///Converts a given [Map<String, dynamic>] of a playlist into a [PlaylistModel].
  PlaylistModel toPlaylistModel(Map<String, dynamic> playlist){
    return PlaylistModel(
      id: playlist.entries.single.key,
      title: playlist.entries.single.value['title'],
      snapshotId: playlist.entries.single.value['snapshotId'],
      link: playlist.entries.single.value['link'],
      imageUrl: playlist.entries.single.value['imageUrl'],
    );
  }

  @override
  String toString(){
    return 'PlaylistModel(id: $id, title: $title, snapshotId: $snapshotId, link: $link, imageUrl: $imageUrl)';
  }

}

///Model for Spotify API callback object.
///
///Stores the `accessToken`, `refreshToken`, and `expiresAt` (the time the access token expires).
class CallbackModel{
  ///Access token expiration time.
  final double expiresAt;
  ///Used to interact with Spotify API.
  final String accessToken;
  ///Used to refresh the Access token.
  final String refreshToken;

  ///Model for a Spotify API callback object.
  const CallbackModel({
    this.expiresAt = 0,
    this.accessToken = '',
    this.refreshToken = '',
  });

  CallbackModel.defaultCall():
    expiresAt = 0,
    accessToken = '',
    refreshToken = '';

  ///True if the callback doesn't have values.
  bool get isEmpty{
    if (expiresAt == 0 || accessToken == '' || refreshToken == ''){
      return true;
    }
    return false;
  }

  ///True if the callback does have values.
  bool get isNotEmpty{
    if (expiresAt > 0 || accessToken != '' || refreshToken != ''){
      return true;
    }
    return false;
  }
}

///Model for app TrackArguments object. Used to pass tracks between pages.
class TrackArguments{
  final Map<String, TrackModel> selectedTracks;
  final PlaylistModel currentPlaylist;
  final String option;
  final Map<String, TrackModel> allTracks;

  ///Model for app TrackArguments object. Used to pass tracks between pages.
  const TrackArguments({
    this.selectedTracks = const {},
    this.currentPlaylist = const PlaylistModel(),
    this.option = '',
    this.allTracks = const {},
  });

  ///Json representation of this object.
  Map<String, dynamic> toJson(){
    Map<String, dynamic> newSelected = TrackModel().toDynamicMap(selectedTracks);
    Map<String, dynamic> newTracks = TrackModel().toDynamicMap(allTracks);

    return {
      'selectedTracks': newSelected,
      'currentPlaylist': currentPlaylist.toJson(),
      'option': option,
      'allTracks': newTracks
    };
  }

  ///Converts a given [Map<String, dynamic>] of track arguments into [TrackArguments].
  TrackArguments toTrackArgs(Map<String, dynamic> trackArgs){
    Map<String, TrackModel> allTracks = TrackModel().toModelMap(trackArgs['allTracks']);
    Map<String, TrackModel> selectedTracks = TrackModel().toModelMap(trackArgs['selectedTracks']);

    return TrackArguments(
      selectedTracks: selectedTracks, 
      currentPlaylist: const PlaylistModel().toPlaylistModel(trackArgs['currentPlaylist']), 
      option: trackArgs['option'], 
      allTracks: allTracks
    );
  }
}

///Model for grouping Synced Playlists, Tracks, and Callback.
class SyncGroupingModel{
  final Map<String, PlaylistModel> playlists;
  final Map<String, TrackModel> tracks;
  final CallbackModel? callback;

  ///Model for grouping Synced Playlists, Tracks, and Callback.
  const SyncGroupingModel({
    this.playlists = const {},
    this.tracks = const {},
    this.callback = const CallbackModel()
  });
}