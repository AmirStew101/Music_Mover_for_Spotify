
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for Spotify User object.
class UserModel{
  final String? username;
  final String spotifyId;
  final String url;
  final bool subscribed;
  final int tier;
  final Timestamp expiration;
  late final DocumentReference<Map<String, dynamic>> userDoc;
  
  /// Model for a Spotify User object.
  UserModel({
    this.username,
    this.spotifyId = '',
    this.url = '',
    this.subscribed = false,
    this.tier = 0,
    Timestamp? expiration,
    DocumentReference<Map<String, dynamic>>? userDocRef
  }) : expiration = expiration ?? Timestamp.fromDate(DateTime.now()){
    if(userDocRef != null){
      userDoc = userDocRef;
    }
  }

  /// Firestore Json representation of this object.
  Map<String, dynamic> toFirestoreJson(){
    return <String, dynamic>{
        'username': username,
        'url': url,
        'subscribed': subscribed,
        'tier': tier,
        'expiration': expiration,
      };
  }

  /// Returns the day for the Subscription expiration.
  int get getDay{
    final int day = expiration.toDate().day;
    return day;
  }

  /// Converts a String of a time stamp into a Timestamp and returns it.
  Timestamp getTimestamp(String timeStampeStr){
    // Receives: Timestamp(seconds=1708192429, nanoseconds=179000000)
    final List<String> flush = timeStampeStr.split('seconds=');

    final int seconds = int.parse(flush[1].split(',')[0]);
    final int nanoSeconds = int.parse(flush[2].split(')')[0]);

    final Timestamp timeStamp = Timestamp(seconds, nanoSeconds);

    return timeStamp;
  }

  @override
  String toString(){
    return 'UserModel(spotifyId: $spotifyId, username: $username, url: $url, subscribed: $subscribed, tier: $tier, expiration: $expiration)';
  }
}
