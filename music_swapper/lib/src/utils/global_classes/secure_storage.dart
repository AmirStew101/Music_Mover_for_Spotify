
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';

class SecureStorage {

  //Storage for Spotify callback info
  final accessTokenKey = 'access_token';
  final refreshTokenKey = 'refresh_token';
  final expiresAtKey = 'expires_at';

  Future<void> saveTokens(CallbackModel tokensModel) async {
    await storage.write(key: accessTokenKey, value: tokensModel.accessToken);
    await storage.write(key: refreshTokenKey, value: tokensModel.refreshToken);
    await storage.write(key: expiresAtKey, value: tokensModel.expiresAt.toString());
  }

  Future<CallbackModel?> getTokens() async {
    try{
      final accessToken = await storage.read(key: accessTokenKey);
      final refreshToken = await storage.read(key: refreshTokenKey);

      final expiresAtStr = await storage.read(key: expiresAtKey);

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

  Future<void> removeTokens() async{
    await storage.delete(key: accessTokenKey);
    await storage.delete(key: expiresAtKey);
    await storage.delete(key: refreshTokenKey);
  }

  //Storage for user info
  final userIdKey = 'userId';
  final userNameKey = 'userName';
  final userUriKey = 'userUri';
  final subscribedKey = 'subscribed';
  final tierKey = 'tier';
  final expirationKey = 'expiration';

  Future<void> saveUser(UserModel user) async{
    await storage.write(key: userIdKey, value: user.spotifyId);
    await storage.write(key: userUriKey, value: user.uri);
    await storage.write(key: subscribedKey, value: user.subscribed.toString());
    await storage.write(key: tierKey, value: user.tier.toString());
    await storage.write(key: expirationKey, value: user.expiration.toString());

    if (user.username != null){
      await storage.write(key: userNameKey, value: user.username);
    }
  }

  Future<UserModel?> getUser() async{
    try{
      final userId = await storage.read(key: userIdKey);
      final userName = await storage.read(key: userNameKey);
      final userUri = await storage.read(key: userUriKey);
      final subscribed = await storage.read(key: subscribedKey);
      final tier = await storage.read(key: tierKey);
      final expiration = await storage.read(key: expirationKey);
    

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
      debugPrint('failed to Get');
    }
    catch (e){
      debugPrint('Error in secure_storage line ${getCurrentLine(offset: 40)}: $e');
      return null;
    }

    return null;
  }

  Future<void> removeUser() async{
    await storage.delete(key: userIdKey);
    await storage.delete(key: userNameKey);
    await storage.delete(key: userUriKey);
    await storage.delete(key: subscribedKey);
    await storage.delete(key: tierKey);
    await storage.delete(key: expirationKey);
  }

}//SecureStorage

