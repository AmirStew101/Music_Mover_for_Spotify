import 'package:another_flushbar/flushbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';

///Encrypt Android options to make the storage secure.
AndroidOptions getAndroidOptions() => const AndroidOptions(encryptedSharedPreferences: true);
///Unlock the IOS secure storage so values can still be retreived in the background.
IOSOptions getIOSOptions() => const IOSOptions(accessibility: KeychainAccessibility.first_unlock);
///Secure Storage access variable.
final storage = FlutterSecureStorage(aOptions: getAndroidOptions(), iOptions: getIOSOptions());

///Handles app storage of important User and Spotify information.
///
///Stores the Spotify access token, refresh token, access token expiration time, and the users UserModel information.
class SecureStorage {

  //Storage for Spotify callback info
  final _accessTokenKey = 'access_token';
  final _refreshTokenKey = 'refresh_token';
  final _expiresAtKey = 'expires_at';

  ///Save the Spotify tokens info.
  Future<void> saveTokens(CallbackModel tokensModel) async {
    await storage.write(key: _accessTokenKey, value: tokensModel.accessToken);
    await storage.write(key: _refreshTokenKey, value: tokensModel.refreshToken);
    await storage.write(key: _expiresAtKey, value: tokensModel.expiresAt.toString());
  }

  ///Retreives the Spotify tokens info from secure storage.
  Future<CallbackModel?> getTokens() async {
    try{
      final accessToken = await storage.read(key: _accessTokenKey);
      final refreshToken = await storage.read(key: _refreshTokenKey);

      final expiresAtStr = await storage.read(key: _expiresAtKey);

      if (accessToken != null && refreshToken != null && expiresAtStr != null) {
        double expiresAt = double.parse(expiresAtStr);
        CallbackModel callbackModel = CallbackModel(expiresAt: expiresAt, accessToken: accessToken, refreshToken: refreshToken);

        return callbackModel;
      } 
      else {
        return null;
      }
    }
    catch (e){
      debugPrint('Error in secure_storage line ${getCurrentLine(offset: 18)}: $e');
      return null;
    }
  }

  ///Remove Spotify tokens info from secure storage.
  Future<void> removeTokens() async{
    await storage.delete(key: _accessTokenKey);
    await storage.delete(key: _expiresAtKey);
    await storage.delete(key: _refreshTokenKey);
  }

  //Storage for user info
  final _userIdKey = 'userId';
  final _userNameKey = 'userName';
  final _userUriKey = 'userUri';
  final _subscribedKey = 'subscribed';
  final _tierKey = 'tier';
  final _expirationKey = 'expiration';

  ///Save the Apps user info.
  Future<void> saveUser(UserModel user) async{
    await storage.write(key: _userIdKey, value: user.spotifyId);
    await storage.write(key: _userUriKey, value: user.uri);
    await storage.write(key: _subscribedKey, value: user.subscribed.toString());
    await storage.write(key: _tierKey, value: user.tier.toString());
    await storage.write(key: _expirationKey, value: user.expiration.toString());

    if (user.username != null){
      await storage.write(key: _userNameKey, value: user.username);
    }
  }

  ///Retreives the Apps user info from secure storage.
  Future<UserModel?> getUser() async{
    try{
      final userId = await storage.read(key: _userIdKey);
      final userName = await storage.read(key: _userNameKey);
      final userUri = await storage.read(key: _userUriKey);
      final subscribed = await storage.read(key: _subscribedKey);
      final tier = await storage.read(key: _tierKey);
      final expiration = await storage.read(key: _expirationKey);
    

      if (userId != null && userUri != null && subscribed != null && tier != null && expiration != null){
        Timestamp expTime = UserModel(expiration: Timestamp.now()).getTimestamp(expiration);

        if (userName != null){
          UserModel userModel = UserModel(
            spotifyId: userId, 
            uri: userUri, 
            username: userName, 
            subscribed: bool.parse(subscribed), 
            tier: int.parse(tier),
            expiration: expTime,
          );

          return userModel;
        }
        else{
          UserModel userModel = UserModel(
            spotifyId: userId, 
            uri: userUri, 
            subscribed: bool.parse(subscribed), 
            tier: int.parse(tier),
            expiration: expTime,
          );

          return userModel;
        }
      }
    }
    catch (e){
      debugPrint('Error in secure_storage line ${getCurrentLine(offset: 40)}: $e');
      return null;
    }

    return null;
  }

  ///Remove the Apps user info from secure storage.
  Future<void> removeUser() async{
    await storage.delete(key: _userIdKey);
    await storage.delete(key: _userNameKey);
    await storage.delete(key: _userUriKey);
    await storage.delete(key: _subscribedKey);
    await storage.delete(key: _tierKey);
    await storage.delete(key: _expirationKey);
  }

  ///Shows an error message to the user depending on what type of error was incountered if any was incountered at all.
  void errorCheck(CallbackModel? secureCall, UserModel? secureUser, {BuildContext? context, ScaffoldMessengerState? scaffoldMessengerState}){

    if (secureUser == null && secureCall == null && context != null){
      Flushbar(
        backgroundColor: Colors.grey,
        titleColor: failedRed,
        title: 'Error in connection',
        duration: const Duration(seconds: 5),
        flushbarPosition: FlushbarPosition.TOP,
        message: 'Failed to connect to Spotify and get User data',
      ).show(context);
    }
    else if (secureUser == null && context != null){
      Flushbar(
        backgroundColor: Colors.grey,
        titleColor: failedRed,
        title: 'Error in connection',
        duration: const Duration(seconds: 5),
        flushbarPosition: FlushbarPosition.TOP,
        message: 'Failed to get User data.',
      ).show(context);
    }
    else if (secureCall == null && context != null){
      Flushbar(
        backgroundColor: Colors.grey,
        titleColor: failedRed,
        title: 'Error in connection',
        duration: const Duration(seconds: 5),
        flushbarPosition: FlushbarPosition.TOP,
        message: 'Failed to connect to Spotify',
      ).show(context);
    }
    else if(secureUser == null && secureCall == null && scaffoldMessengerState != null){
      scaffoldMessengerState.hideCurrentSnackBar();

      scaffoldMessengerState.showSnackBar(
        SnackBar(
          content: Column(
            children: [
              Text(
                'Error in connection',
                style: TextStyle(color: failedRed),
              ),
              const Text(
                  'Failed to connect to Spotify and get User data',
                  textScaler: TextScaler.linear(0.9),
              )
            ],
          ),
          duration: const Duration(seconds: 8),
          backgroundColor: Colors.grey,
        ));
    }
    else if (secureUser == null && scaffoldMessengerState != null){
      scaffoldMessengerState.hideCurrentSnackBar();

      scaffoldMessengerState.showSnackBar(
        SnackBar(
          content: Column(
            children: [
              Text(
                'Error in connection',
                style: TextStyle(color: failedRed),
              ),
              const Text(
                  'Failed to get User data.',
                  textScaler: TextScaler.linear(0.9),
              )
            ],
          ),
          duration: const Duration(seconds: 8),
          backgroundColor: Colors.grey,
        ));
    }
    else if (secureCall == null && scaffoldMessengerState != null){
      scaffoldMessengerState.hideCurrentSnackBar();

      scaffoldMessengerState.showSnackBar(
        SnackBar(
          content: Column(
            children: [
              Text(
                'Error in connection',
                style: TextStyle(color: failedRed),
              ),
              const Text(
                  'Failed to connect to Spotify',
                  textScaler: TextScaler.linear(0.9),
              )
            ],
          ),
          duration: const Duration(seconds: 8),
          backgroundColor: Colors.grey,
        ));
    }
  }//storageCheck
}

