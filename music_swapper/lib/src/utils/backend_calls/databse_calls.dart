
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';

const String _fileName = 'database_calls.dart';
final FirebaseFirestore db = FirebaseFirestore.instance;

/// Repository for the Users database interaction.
/// 
/// Must call the initializeUser() function before making any additional function calls or an error will be thrown.
class UserRepository extends GetxController{
  
  /// Reference to Users collection.
  final CollectionReference<Map<String, dynamic>> usersRef = db.collection('Users');

  late UserModel _user;
  late String userId;

  bool _new_user = false;

  get newUser{
    return _new_user;
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
    bool has = await _hasUser(user);
    if(!has){
      _new_user = true;
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
    _checkUserInitialized();
    
    await _user.userDoc.delete()
    .onError((Object? error, StackTrace stackTrace) => throw CustomException(stack: stackTrace, fileName: _fileName, functionName: 'removeUser',  error: error));

    _user = UserModel();
  }//removeUser

  /// Updates the users information.
  ///
  /// Must Initialize User before use.
  Future<void> updateUser(UserModel user) async{
    _checkUserInitialized();
    try{
      final DocumentSnapshot<Map<String, dynamic>> databaseUser = await _user.userDoc.get();

      if (databaseUser.exists){
        await _user.userDoc.update(<Object, Object?>{'subscribed': user.subscribed, 'tier': user.tier, 'username': user.username, 'expiration': user.expiration, 'url': user.url});
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
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: '_checkUserInitialized',  error: 'User not Initialized. Call the [initializeUser] function before calling other functions.');
    }
  }

  /// Checks if the user is in the database. 
  /// Returns true or false.
  Future<bool> _hasUser(UserModel user) async{
    try{
      final DocumentSnapshot<Map<String, dynamic>> userExists = await usersRef.doc(user.spotifyId).get();

      if (userExists.exists) {
        return true;
      }
      return false;
    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'hasUser',  error: e);
    }
  }// hasUser
  
  /// Create a new user in the databse or sets an existing user to new values.
  Future<void> _createUser() async{
    try{
      await usersRef.doc(_user.spotifyId).set(_user.toFirestoreJson());

      _user.userDoc = usersRef.doc(_user.spotifyId);
    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'createUser',  error: e);
    }
  }// createUser

  /// Get the user from the database and converts to a `UserModel`.
  Future<UserModel> _getUser(UserModel user) async{
    try{
      final DocumentSnapshot<Map<String, dynamic>> databaseUser = await usersRef.doc(user.spotifyId).get();
      
      if (databaseUser.exists){
        UserModel retreivedUser = UserModel(
          spotifyId: databaseUser.id,
          subscribed: databaseUser.data()?['subscribed'],
          tier: databaseUser.data()?['tier'],
          url: databaseUser.data()?['url'],
          username: databaseUser.data()?['username'],
          expiration: databaseUser.data()?['expiration'],
          userDocRef: usersRef.doc(user.spotifyId),
          playlistAsc: databaseUser.data()?['playlistAsc'],
          tracksAsc: databaseUser.data()?['tracksAsc'],
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