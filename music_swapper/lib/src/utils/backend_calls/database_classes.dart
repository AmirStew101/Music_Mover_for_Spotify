import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/databse_calls.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';

const String _fileName = 'database_classes.dart';
final UserRepository _userRepository = Get.put(UserRepository());

class DatabaseStorage extends GetxController{
  late UserModel _user;

  bool isInitialized = false;
  bool _newUser = false;

  get newUser{
    return _newUser;
  }

  static DatabaseStorage get instance {
    try{
      return Get.find();
    }
    catch (e){
      FirebaseCrashlytics.instance.log('Failed to Get Instance of Database Storage');
      return Get.put(DatabaseStorage());
    }
  }

  UserModel get user{
    return _user;
  }

  /// Initialize the User by getting the user from the database or creates one if no user exists.
  /// Returns True on Success.
  /// 
  /// Must be called before any of the other functions.
  Future<UserModel?> initializeDatabase(UserModel user) async{
    isInitialized = await _userRepository.initializeUser(user);

    if(isInitialized){
      _user = _userRepository.user;
      _newUser = _userRepository.newUser;
    }
    
    return _user;
  }

  /// Removes a [user] and all of their data from the database. Returns True on Success.
  /// 
  /// Must Initialize Database before use.
  Future<bool> removeUser() async{
    if(isInitialized){
      try{
        await _userRepository.removeUser();
      }
      catch (_){
        return false;
      }
      return true;
    }
    else{
      return false;
    }
  }

  /// Updates a Users info in the database and returns True on Success.
  Future<bool> updateUser(UserModel newUser) async{
    try{
      await _userRepository.updateUser(newUser);
      _user = newUser;
      return true;
    }
    catch (_){
      return false;
    }

  }

}

