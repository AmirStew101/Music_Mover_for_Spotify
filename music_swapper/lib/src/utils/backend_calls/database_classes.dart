import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/databse_calls.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';

const String _fileName = 'database_classes.dart';
final UserRepository _userRepository = Get.put(UserRepository());
final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

class DatabaseStorage extends GetxController{
  late UserModel _user;

  bool isInitialized = false;
  bool _newUser = false;

  get newUser{
    return _newUser;
  }

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
    _newUser = _userRepository.newUser;
    isInitialized = true;
  }

  /// Removes a [user] and all of their data from the database.
  /// 
  /// Must Initialize Database before use.
  Future<void> removeUser() async{
    if(initialized){
      await _userRepository.removeUser()
      .onError((Object? error, StackTrace stack)  {
        _crashlytics.recordError(error, stack, reason: 'Failed to Remove User');
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'removeUser',  error: error);
      });
    }
    else{
      throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'removeUser',  error: 'Not initialized');
    }
  }

  Future<void> updateUser(UserModel newUser) async{
    try{
    await _userRepository.updateUser(newUser);
    _user = newUser;
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to Update User');
      throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'updateUser',  error: error);
    }

  }

}

