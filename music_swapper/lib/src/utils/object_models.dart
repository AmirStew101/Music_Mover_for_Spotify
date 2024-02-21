
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel{
  String? username;
  final String spotifyId;
  final String uri;
  final bool subscribed;
  final int tier;
  final Timestamp expiration;
  
  UserModel({
    this.username,
    this.spotifyId = '',
    this.uri = '',
    this.subscribed = false,
    this.tier = 0,
    required this.expiration,
  });

  UserModel.defaultUser() : 
    spotifyId = '', 
    uri = '',
    subscribed = false,
    tier = 0,
    expiration = Timestamp.now();

  toJson(){
    return {
        'username': username,
        'uri': uri,
        'subscribed': subscribed,
        'tier': tier,
        'expiration': expiration,
      };
  }

  //Returns the day for the Models expiration
  int get getDay{
    final day = expiration.toDate().day;
    return day;
  }

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
    return 'TrackModel(spotifyId: $spotifyId, username: $username, uri: $uri, subscribed: $subscribed, tier: $tier, expiration: $expiration)';
  }
}

class TrackModel{
  final String id;
  final String imageUrl;
  final String? previewUrl;
  final String artist;
  final String title;
  final int duplicates;
  final bool liked;

  const TrackModel({
    this.id = '',
    this.imageUrl = '',
    this.previewUrl = '',
    this.artist = '',
    this.title = '',
    this.duplicates = 0,
    this.liked = false,
  });

  TrackModel.defaultTracks() : 
    id = '', 
    imageUrl = '',
    previewUrl = '',
    artist = '',
    title = '',
    duplicates = 0,
    liked = false;

  toJson(){
    return {
      'imageUrl': imageUrl,
      'previewUrl': previewUrl,
      'artist': artist,
      'title': title,
      'duplicates': duplicates,
      'liked': liked,
    };
  }

  @override
  String toString(){
    return 'TrackModel(id: $id, title: $title, artist: $artist, duplicates: $duplicates, imageUrl: $imageUrl, liked: $liked)';
  }

  bool get isEmpty{
    if (id == '' && imageUrl == '' && artist == '' && title == ''){
      return true;
    }
    return false;
  }

  bool get isNotEmpty{
    if (id == '' && imageUrl == '' && artist == '' && title == ''){
      return false;
    }
    return true;
  }

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

  Map<String, TrackModel> toModel(Map<String, dynamic> tracks){
 
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

  MapEntry<String, dynamic> toMapEntry(MapEntry<String, dynamic> track){
    track as MapEntry<String, TrackModel>; 

    String id = track.key;
    String title = track.value.title;
    String artist = track.value.imageUrl;
    String imageUrl = track.value.imageUrl;
    String previewUrl = track.value.previewUrl ?? '';
    int duplicates = track.value.duplicates;
    bool liked = track.value.liked;

    return MapEntry(id, {'title': title, 'artist': artist, 'duplicates': duplicates, 'imageUrl': imageUrl, 'previewUrl': previewUrl, 'liked': liked});
  }

  Map<String, dynamic> toMap(Map<String, TrackModel> tracks){
    Map<String, dynamic> newTracks = {};
    
    for (var track in tracks.entries){
      String id = track.key;
      String title = track.value.title;
      String artist = track.value.imageUrl;
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
  
}

class PlaylistModel {
  final String id;
  final String link;
  final String imageUrl;
  final String snapshotId;
  final String title;

  const PlaylistModel({
    this.id = '',
    this.title = '',
    this.link = '',
    this.imageUrl = '',
    this.snapshotId = '',
  });

  PlaylistModel.defaultPlaylist() : 
    id = '',
    title = '',
    link = '',
    imageUrl = '',
    snapshotId = '';

  toJsonFirestore(){
    return {
      'title': title,
      'link': link,
      'imageUrl': imageUrl,
      'snapshotId': snapshotId,
    };
  }

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

  PlaylistModel mapToModel(Map<String, dynamic> playlist){
    return PlaylistModel(
      id: playlist.entries.single.key,
      title: playlist.entries.single.value['title'],
      snapshotId: playlist.entries.single.value['snapshotId'],
      link: playlist.entries.single.value['link'],
      imageUrl: playlist.entries.single.value['imageUrl'],
    );
  }

  Map<String, PlaylistModel> toMapModel(Map<String, dynamic> playlists){
    Map<String, PlaylistModel> newPlaylists = {};

    for (var playlist in playlists.entries){
      String id = playlist.key;
      String? imageUrl = playlist.value['imageUrl'];

      newPlaylists.putIfAbsent(id, () => PlaylistModel(
        title: playlist.value['title'], 
        id: id, 
        link: playlist.value['link'], 
        imageUrl: imageUrl ?? '', 
        snapshotId: playlist.value['snapshotId']
        )
      );
    }

    return newPlaylists;
  }

  MapEntry<String, dynamic> toMapEntry(MapEntry<String, PlaylistModel> playlist){

    String id = playlist.key;
    String title = playlist.value.title;
    String artist = playlist.value.imageUrl;
    String link = playlist.value.link;
    String snapshotId = playlist.value.snapshotId;

    return MapEntry(id, {
      'title': title, 
      'artist': artist, 
      'link': link, 
      'snapshotId': snapshotId}
    );
  }

  Map<String, dynamic> toMap(Map<String, dynamic> playlists){
    playlists as Map<String, PlaylistModel>;
    Map<String, dynamic> newPlaylists = {};

    for (var playlist in playlists.entries){
      String id = playlist.key;
      String title = playlist.value.title;
      String artist = playlist.value.imageUrl;
      String link = playlist.value.link;
      String snapshotId = playlist.value.snapshotId;

      newPlaylists.putIfAbsent(id, () => {
        'title': title, 
        'artist': artist, 
        'link': link, 
        'snapshotId': snapshotId}
      );
    }

    return newPlaylists;
  }

  @override
  String toString(){
    return 'PlaylistModel(id: $id, title: $title, snapshotId: $snapshotId, link: $link, imageUrl: $imageUrl)';
  }

}

class CallbackModel{
  double expiresAt;
  String accessToken;
  String refreshToken;

  CallbackModel({
    this.expiresAt = 0,
    this.accessToken = '',
    this.refreshToken = '',
  });

  CallbackModel.defaultCall() : 
    expiresAt = 0,
    accessToken = '',
    refreshToken = '';

  bool get isEmpty{
    if (expiresAt > 0 || accessToken != '' || refreshToken != ''){
      return false;
    }
    else{
      return true;
    }
  }

  bool get isNotEmpty{
    if (expiresAt == 0 || accessToken == '' || refreshToken == ''){
      return false;
    }
    else{
      return true;
    }
  }
}

class TrackArguments{
  final Map<String, TrackModel> selectedTracks;
  final PlaylistModel currentPlaylist;
  final String option;
  final Map<String, TrackModel> allTracks;

  const TrackArguments({
    this.selectedTracks = const {},
    this.currentPlaylist = const PlaylistModel(),
    this.option = '',
    this.allTracks = const {},
  });

  TrackArguments.defaultTrack() : 
    selectedTracks = {},
    currentPlaylist = PlaylistModel.defaultPlaylist(),
    option = '',
    allTracks = {};

  Map<String, dynamic> toJson(){
    Map<String, dynamic> newSelected = const TrackModel().toMap(selectedTracks);
    Map<String, dynamic> newTracks = const TrackModel().toMap(allTracks);

    return {
      'selectedTracks': newSelected,
      'currentPlaylist': currentPlaylist.toJson(),
      'option': option,
      'allTracks': newTracks
    };
  }

  TrackArguments toTrackArgs(Map<String, dynamic> trackArgs){
    Map<String, TrackModel> allTracks = const TrackModel().toModel(trackArgs['allTracks']);
    Map<String, TrackModel> selectedTracks = const TrackModel().toModel(trackArgs['selectedTracks']);

    return TrackArguments(
      selectedTracks: selectedTracks, 
      currentPlaylist: const PlaylistModel().mapToModel(trackArgs['currentPlaylist']), 
      option: trackArgs['option'], 
      allTracks: allTracks
    );
  }
}
