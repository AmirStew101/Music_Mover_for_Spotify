import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/databse_calls.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';
import 'package:spotify_music_helper/src/utils/playlist_model.dart';
import 'package:spotify_music_helper/src/utils/track_model.dart';
import 'package:spotify_music_helper/src/utils/user_model.dart';

const String _fileName = 'database_classes.dart';
final UserRepository _userRepository = Get.put(UserRepository());

class DatabaseStorage extends GetxController{

  /// All of a users saved Playlists.
  Map<String, PlaylistModel> allPlaylists = <String, PlaylistModel>{};

  /// All of a users saved tracks.
  Map<String, TrackModel> tracks = <String, TrackModel>{};
  
  ///Tracks with an underscore and their duplicate number.
  Map<String, TrackModel> tracksDupes = <String, TrackModel>{};

  late UserModel _user;

  static DatabaseStorage get instance => Get.find();

  UserModel get user{
    return _user;
  }

  /// Initialize the User by getting the user from the database or creating one if no user exists.
  /// 
  /// Must be called before any of the other functions.
  Future<void> initializeDatabase(UserModel user) async{
    await _userRepository.initializeUser(user);
    _user = _userRepository.user;
  }

  /// Removes a [user] and all of their data from the database.
  /// 
  /// Must Initialize Database before use.
  Future<void> removeUser() async{
    
    await _userRepository.removeUser()
    .onError((Object? error, StackTrace stackTrace) => throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'removeUser',  error: error));
  }

}

