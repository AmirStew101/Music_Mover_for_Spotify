
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get/get.dart';
import 'package:music_mover/src/utils/analytics.dart';
import 'package:music_mover/src/utils/exceptions.dart';
import 'package:music_mover/src/utils/class%20models/user_model.dart';

const String _fileName = 'database_calls.dart';
final FirebaseFirestore db = FirebaseFirestore.instance;
final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;


/// Repository for the Users database interaction.
/// 
/// Must call the initializeUser() function before making any additional function calls or an error will be thrown.
class UserRepository extends GetxController{
  
  /// Reference to Users collection.
  final CollectionReference<Map<String, dynamic>> usersRef = db.collection('Users');

  late UserModel _user;

  bool _newUser = false;

  get newUser{
    return _newUser;
  }

  get user{
    return _user;
  }

  ///Get the instance of the User Repository.
  static UserRepository get instance => Get.find();


  /// Initialize the User by getting the user from the database or creating one if no user exists.
  /// 
  /// Must be called before any of the other functions.
  Future<bool> initializeUser(UserModel user) async{
    try{
      _crashlytics.log('Initialize User');
      bool has = await _hasUser(user);
      if(!has){
        _newUser = true;
        _user = user;
        await AppAnalytics().trackNewUser(user);
        await _createUser();
      }
      else{
        _user = await _getUser(user);
      }
      return true;
    }
    catch (e){
      return false;
    }
  }

  /// Remove a user and their associated data from the database.
  /// 
  /// Must Initialize User before use.
  Future<void> removeUser() async{
    _crashlytics.log('Remove User');
    _checkUserInitialized();

    try{
    await _user.userDoc.delete();
    }
    catch (error, stack){
      if(_user.spotifyId == '') throw CustomException(stack: stack, fileName: _fileName, functionName: 'removeUser', reason: 'Failed to remove User',  error: 'User Id is Empty');

      await usersRef.doc(_user.spotifyId).delete()
      .onError((Object? error, StackTrace stackTrace) => throw CustomException(stack: stackTrace, fileName: _fileName, functionName: 'removeUser', reason: 'Failed to remove User',  error: error));
    }

    _user = UserModel();
  }//removeUser

  /// Updates the users information.
  ///
  /// Must Initialize User before use.
  Future<void> updateUser(UserModel user) async{
    _crashlytics.log('Update User');
    try{
      late final DocumentSnapshot<Map<String, dynamic>> databaseUser;

      try{
        databaseUser = await user.userDoc.get();
      }
      catch (e){
        databaseUser = await usersRef.doc(user.spotifyId).get();
      }

      if (databaseUser.exists){
        await _user.userDoc.update({
          'subscribed': user.subscribed, 
          'tier': user.tier, 
          'expiration': user.expiration, 
          'url': user.url, 
          'playlistAsc': user.playlistAsc,
          'tracksAsc': user.tracksAsc,
          'tracksSortType': user.tracksSortType
        });
      }
    }
    catch (error, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'updateUser', reason: 'Failed to Update User',  error: error);
    }

    _user = user;
  }//updateUser


  // Private Functions

  /// Check that the late user has been initialized with the Initialization function before other function calls.
  void _checkUserInitialized(){
    try{
      _user.toFirestoreJson();
    }
    catch (error, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: '_checkUserInitialized',  error: 'User not Initialized. Call the [initializeUser] function before calling other functions.');
    }
  }

  /// Checks if the user is in the database. 
  /// Returns true or false.
  Future<bool> _hasUser(UserModel user) async{
    _crashlytics.log('Check Has User');
    try{
      final DocumentSnapshot<Map<String, dynamic>> userExists = await usersRef.doc(user.spotifyId).get();

      if (userExists.exists) {
        return true;
      }
      return false;
    }
    catch (ee){
      _crashlytics.log('_hasUser() function error Returned False');
      return false;
    }
  }// hasUser
  
  /// Create a new user in the databse or sets an existing user to new values.
  Future<void> _createUser() async{
    _crashlytics.log('Create User');
    try{
      await usersRef.doc(_user.spotifyId).set(_user.toFirestoreJson());

      _user.userDoc = usersRef.doc(_user.spotifyId);
    }
    catch (error, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'createUser', reason: 'Failed to Create User',  error: error);
    }
  }// createUser

  /// Get the user from the database and converts to a `UserModel`.
  Future<UserModel> _getUser(UserModel user) async{
    _crashlytics.log('Get User');
    try{
      final DocumentSnapshot<Map<String, dynamic>> databaseUser = await usersRef.doc(user.spotifyId).get();
      
      if (databaseUser.exists){
        UserModel retreivedUser = UserModel(
          spotifyId: databaseUser.id,
          subscribe: databaseUser.data()?['subscribed'],
          tier: databaseUser.data()?['tier'],
          url: databaseUser.data()?['url'],
          expiration: databaseUser.data()?['expiration'],
          userDocRef: usersRef.doc(user.spotifyId),
          playlistAsc: databaseUser.data()?['playlistAsc'],
          tracksAsc: databaseUser.data()?['tracksAsc'],
          sortType: databaseUser.data()?['tracksSortType']
        );

        return retreivedUser;
      }
      else{
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'getUser',  error: 'Failed User doesn\'t Exist');
      }
    }
    catch (ee){
      _user = user;
      await _createUser()
      .onError((Object? error, StackTrace stack) {
        error as CustomException;
        throw CustomException(stack: stack, fileName: _fileName, functionName: 'getUser', reason: 'Failed to get User from Database',  error: '${error.reason}: ${error.error}');
      }
      );
      return _user;
    }
  }// getUser

}