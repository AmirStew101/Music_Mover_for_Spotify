
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/database_classes.dart';
import 'package:spotify_music_helper/src/utils/class%20models/custom_sort.dart';

/// Model for Spotify User object.
class UserModel{
  final String spotifyId;
  final String url;
  final Rx<bool> subscribed = false.obs;
  final int tier;
  Timestamp expiration;
  final Rx<bool> _playlistAsc = true.obs; 
  final Rx<bool> _tracksAsc = true.obs;
  String _tracksSortType = Sort().title;
  late final DocumentReference<Map<String, dynamic>> userDoc;

  late final DatabaseStorage _databaseStorage;
  
  /// Model for a Spotify User object.
  UserModel({
    this.spotifyId = '',
    this.url = '',
    bool subscribe = false,
    this.tier = 0,
    Timestamp? expiration,
    bool playlistAsc = true,
    bool tracksAsc = true,
    String? sortType,
    DocumentReference<Map<String, dynamic>>? userDocRef
  }) 
  : expiration = expiration ?? Timestamp.fromDate(DateTime.now())
  {
    subscribed.value = subscribe;
    _playlistAsc.value = playlistAsc;
    _tracksAsc.value = tracksAsc;
    tracksSortType = sortType ?? Sort().title;

    if(userDocRef != null){
      userDoc = userDocRef;
    }

    try{
      _databaseStorage = DatabaseStorage.instance;
    }
    catch (e){
      _databaseStorage = Get.put(DatabaseStorage());
    }
  }

  /// Returns the day for the Subscription expiration.
  int get getDay{
    final int day = expiration.toDate().day;
    return day;
  }

  bool get playlistAsc{
    return _playlistAsc.value;
  }

  set playlistAsc(bool ascending){
    _playlistAsc.value = ascending;
    _databaseStorage.updateUser(this);
  }

  bool get tracksAsc{
    return _tracksAsc.value;
  }

  set tracksAsc(bool ascending){
    _tracksAsc.value = ascending;
    _databaseStorage.updateUser(this);
  }

  String get tracksSortType{
    return _tracksSortType;
  }

  set tracksSortType(String sortType){
    if(sortType == Sort().artist){
        _tracksSortType = Sort().artist;
      }
      else if(sortType == Sort().addedAt){
        _tracksSortType = Sort().addedAt;
      }
      else if(sortType == Sort().type){
        _tracksSortType = Sort().type;
      }
      else{
        _tracksSortType = Sort().title;
      }
  }


  /// Firestore Json representation of this object.
  Map<String, dynamic> toFirestoreJson(){
    return <String, dynamic>{
        'url': url,
        'subscribed': subscribed,
        'tier': tier,
        'expiration': expiration,
        'playlistAsc': _playlistAsc.value,
        'tracksAsc': _tracksAsc.value,
        'tracksSortType': _tracksSortType
      };
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
    return 'UserModel(spotifyId: $spotifyId, url: $url, subscribed: $subscribed, tier: $tier, expiration: $expiration)';
  }
}
