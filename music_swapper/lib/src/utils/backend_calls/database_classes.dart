import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/databse_calls.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';
import 'package:spotify_music_helper/src/utils/class%20models/playlist_model.dart';
import 'package:spotify_music_helper/src/utils/class%20models/track_model.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';

const String _fileName = 'database_classes.dart';
final UserRepository _userRepository = Get.put(UserRepository());

class DatabaseStorage extends GetxController{
  late UserModel _user;

  bool initialized = false;

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
    initialized = true;
  }

  /// Removes a [user] and all of their data from the database.
  /// 
  /// Must Initialize Database before use.
  Future<void> removeUser() async{
    
    await _userRepository.removeUser()
    .onError((Object? error, StackTrace stackTrace) => throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'removeUser',  error: error));
  }

}

