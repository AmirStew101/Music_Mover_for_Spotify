


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
  final String id;
  final String imageUrl;
  final String? previewUrl;
  final String artist;
  final String title;
  final int totalPlaylists;

  const TrackModel({
    required this.totalPlaylists,
    required this.id,
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
      'totalPlaylists': totalPlaylists,
    };
  }
}

class PlaylistModel {
  final String id;
  final String link;
  final String imageUrl;
  final String snapshotId;
  final String title;
  final List trackIds;

  const PlaylistModel({
    required this.title,
    required this.id,
    required this.link,
    required this.imageUrl,
    required this.snapshotId,
    required this.trackIds,
  });

  toJson(){
    return {
      'title': title,
      'link': link,
      'imageUrl': imageUrl,
      'snapshotId': snapshotId,
      'trackIds': trackIds,
    };
  }
}

