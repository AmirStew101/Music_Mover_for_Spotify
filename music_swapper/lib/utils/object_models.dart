


class UserModel{
  final String? username;
  final String spotifyId;
  final String uri;
  
  UserModel({
    this.username,
    this.spotifyId = '',
    this.uri = '',
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

  const TrackModel({
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
    };
  }
}

class PlaylistModel {
  final String id;
  final String link;
  final String imageUrl;
  final String snapshotId;
  final String title;

  const PlaylistModel({
    required this.title,
    required this.id,
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

class CallbackModel{
  double expiresAt;
  String accessToken;
  String refreshToken;

  CallbackModel({
    this.expiresAt = 0,
    this.accessToken = '',
    this.refreshToken = '',
  });
}