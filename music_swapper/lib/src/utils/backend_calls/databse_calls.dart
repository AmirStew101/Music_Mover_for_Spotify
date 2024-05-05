
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';

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
  late String userId;

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
  Future<void> initializeUser(UserModel user) async{
    _crashlytics.log('Initialize User');
    bool has = await _hasUser(user);

    if(!has){
      _newUser = true;
      _user = user;
      _createUser();
    }
    else{
      _user = await _getUser(user);
    }
    
    userId = _user.spotifyId;
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
    catch (e){
      if(_user.spotifyId == '') throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'removeUser',  error: 'User Id is Empty');

      await usersRef.doc(_user.spotifyId).delete()
      .onError((Object? error, StackTrace stackTrace) => throw CustomException(stack: stackTrace, fileName: _fileName, functionName: 'removeUser',  error: error));
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
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'updateUser',  error: e);
    }

    _user = user;
  }//updateUser


  // Private Functions

  /// Check that the late user has been initialized with the Initialization function before other function calls.
  void _checkUserInitialized(){
    try{
      _user.toFirestoreJson();
    }
    catch (ee, stack){
      _crashlytics.recordError(ee, stack, reason: 'User not Initialized. Call the [initializeUser] function before calling other functions.');
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
    catch (ee, stack){
      _crashlytics.recordError(ee, stack, reason: 'Failed to Create User');
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'createUser',  error: ee);
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
    catch (e){
      _user = user;
      await _createUser()
      .onError((Object? error, StackTrace stackTrace) => 
      throw CustomException(stack: stackTrace, fileName: _fileName, functionName: 'getUser',  error: 'Failed to get User from Database $error'));
      return _user;
    }
  }// getUser

}