import 'dart:convert';

import 'package:another_flushbar/flushbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_music_helper/src/utils/class%20models/playlist_model.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/class%20models/callback_model.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';

const String _fileName = 'secure_storage.dart';

/// Encrypt Android options to make the storage secure.
AndroidOptions getAndroidOptions() => const AndroidOptions(encryptedSharedPreferences: true);
/// Unlock the IOS secure storage so values can still be retreived in the background.
IOSOptions getIOSOptions() => const IOSOptions(accessibility: KeychainAccessibility.first_unlock);
/// Secure Storage access variable.
final FlutterSecureStorage _storage = FlutterSecureStorage(aOptions: getAndroidOptions(), iOptions: getIOSOptions());

final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

/// Handles app storage of important User and Spotify information.
///
/// Stores the Spotify access token, refresh token, access token expiration time, and the users UserModel information.
class SecureStorage extends GetxController{
  CallbackModel? _secureCall; 
  UserModel? _secureUser;

  CallbackModel? get secureCallback{
    return _secureCall;
  }

  UserModel? get secureUser{
    return _secureUser;
  }

  static SecureStorage get instance {
    try{
      return Get.find();
    }
    catch (e){
      FirebaseCrashlytics.instance.log('Failed to Get Instance of Secure Storage');
      return Get.put(SecureStorage());
    }
  }

  // Storage for Spotify callback info

  final String _accessTokenKey = 'access_token';
  final String _refreshTokenKey = 'refresh_token';
  final String _expiresAtKey = 'expires_at';

  /// Save the Spotify tokens info.
  Future<void> saveTokens(CallbackModel tokensModel) async {
    try{
      await _storage.write(key: _accessTokenKey, value: tokensModel.accessToken);
      await _storage.write(key: _refreshTokenKey, value: tokensModel.refreshToken);
      await _storage.write(key: _expiresAtKey, value: tokensModel.expiresAt.toString());
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to Save Tokens');
    }
    _secureCall = tokensModel;
  }

  /// Retreives the Spotify tokens info from secure _storage.
  Future<CallbackModel?> getTokens() async {
    try{
      final String? accessToken = await _storage.read(key: _accessTokenKey);
      final String? refreshToken = await _storage.read(key: _refreshTokenKey);
      final String? expiresAtStr = await _storage.read(key: _expiresAtKey);

      if (accessToken != null && refreshToken != null && expiresAtStr != null) {
        double expiresAt = double.parse(expiresAtStr);
        _secureCall = CallbackModel(expiresAt: expiresAt, accessToken: accessToken, refreshToken: refreshToken);
        return _secureCall;
      } 
      else {
        errorCheck();
      }
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to Get Tokens');
    }
    return null;
  }

  /// Remove Spotify tokens info from secure _storage.
  Future<void> removeTokens() async{
    try{
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _expiresAtKey);
      await _storage.delete(key: _refreshTokenKey);
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to Remove Tokens');
    }
    _secureCall = null;
  }

  // Storage for user info

  final String _userIdKey = 'userId';
  final String _userUrlKey = 'userUrl';
  final String _subscribedKey = 'subscribed';
  final String _tierKey = 'tier';
  final String _expirationKey = 'expiration';
  final String _playlistsAscKey = 'playlistsAscKey';
  final String _tracksAscKey = 'tracksAsc';
  final String _tracksSortKey = 'tracksSort';

  /// Save the Apps user info.
  Future<void> saveUser(UserModel user) async{
    try{
      await _storage.write(key: _userIdKey, value: user.spotifyId);
      await _storage.write(key: _userUrlKey, value: user.url);
      await _storage.write(key: _subscribedKey, value: user.subscribed.toString());
      await _storage.write(key: _tierKey, value: user.tier.toString());
      await _storage.write(key: _expirationKey, value: user.expiration.toString());
      await _storage.write(key: _playlistsAscKey, value: user.playlistAsc.toString());
      await _storage.write(key: _tracksAscKey, value: user.tracksAsc.toString());
      await _storage.write(key: _tracksSortKey, value: user.tracksSortType);
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to Save User to Secure Storage');
    }
    _secureUser = user;
  }

  /// Retreives the Apps user info from secure _storage.
  Future<UserModel?> getUser() async{
    try{
      final String? userId = await _storage.read(key: _userIdKey);
      final String? userUri = await _storage.read(key: _userUrlKey);
      final String? subscribed = await _storage.read(key: _subscribedKey);
      final String? tier = await _storage.read(key: _tierKey);
      final String? expiration = await _storage.read(key: _expirationKey);
      final String? playlistAsc = await _storage.read(key: _playlistsAscKey);
      final String? tracksAsc = await _storage.read(key: _tracksAscKey);
      final String? tracksSort = await _storage.read(key: _tracksSortKey);
    

      if (userId != null && userUri != null && subscribed != null && tier != null && expiration != null){
        Timestamp expTime = UserModel(expiration: Timestamp.now()).getTimestamp(expiration);

        _secureUser = UserModel(
          spotifyId: userId, 
          url: userUri, 
          subscribe: bool.parse(subscribed), 
          tier: int.parse(tier),
          expiration: expTime,
          playlistAsc: bool.parse(playlistAsc ?? 'true'),
          tracksAsc: bool.parse(tracksAsc ?? 'true'),
          sortType: tracksSort
        );

        return _secureUser;
      }
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to Get user from Secure Storage');
    }

    return null;
  }

  ///Remove the Apps user info from secure _storage.
  Future<void> removeUser() async{
    try{
      await _storage.delete(key: _userIdKey);
      await _storage.delete(key: _userUrlKey);
      await _storage.delete(key: _subscribedKey);
      await _storage.delete(key: _tierKey);
      await _storage.delete(key: _expirationKey);
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to Remove User from Secure Storage');
    }
    _secureUser = null;
  }

  ///Shows an error message to the user depending on what type of error was incountered if any was incountered at all.
  void errorCheck({ScaffoldMessengerState? scaffoldMessengerState}){
    final BuildContext? context = Get.context;

    if (_secureUser == null && _secureCall == null && context != null){
      Flushbar(
        backgroundColor: Colors.grey,
        titleColor: failedRed,
        title: 'Error in connection',
        duration: const Duration(seconds: 5),
        flushbarPosition: FlushbarPosition.TOP,
        message: 'Failed to connect to Spotify and get User data',
      ).show(context);
    }
    else if (_secureUser == null && context != null){
      Flushbar(
        backgroundColor: Colors.grey,
        titleColor: failedRed,
        title: 'Error in connection',
        duration: const Duration(seconds: 5),
        flushbarPosition: FlushbarPosition.TOP,
        message: 'Failed to get User data.',
      ).show(context);
    }
    else if (_secureCall == null && context != null){
      Flushbar(
        backgroundColor: Colors.grey,
        titleColor: failedRed,
        title: 'Error in connection',
        duration: const Duration(seconds: 5),
        flushbarPosition: FlushbarPosition.TOP,
        message: 'Failed to connect to Spotify',
      ).show(context);
    }
    else if(_secureUser == null && _secureCall == null && scaffoldMessengerState != null){
      scaffoldMessengerState.hideCurrentSnackBar();

      scaffoldMessengerState.showSnackBar(
        SnackBar(
          content: Column(
            children: <Widget>[
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
    else if (_secureUser == null && scaffoldMessengerState != null){
      scaffoldMessengerState.hideCurrentSnackBar();

      scaffoldMessengerState.showSnackBar(
        SnackBar(
          content: Column(
            children: <Widget>[
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
    else if (_secureCall == null && scaffoldMessengerState != null){
      scaffoldMessengerState.hideCurrentSnackBar();

      scaffoldMessengerState.showSnackBar(
        SnackBar(
          content: Column(
            children: <Widget>[
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

class PlaylistsCacheManager extends GetxController{
  static const String _key = 'cached_playlists';

  List<PlaylistModel> _storedPlaylists = [];

  static PlaylistsCacheManager get instance {
    try{
      return Get.find();
    }
    catch (e){
      return Get.put(PlaylistsCacheManager());
    }
  }

  List<PlaylistModel> get storedPlaylists{
    return _storedPlaylists;
  }

  /// Cache a sorted list of playlists for the user.
  Future<void> cachePlaylists(List<PlaylistModel> playlists) async {
    try{
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      List<Map<String, dynamic>> storeList = <Map<String, dynamic>>[];

      for(PlaylistModel playlist in playlists){
        storeList.add(playlist.toJson());
      }
      await prefs.setString(_key, jsonEncode(storeList));
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to cache Playlists');
    }
  }

  Future<void> clearPlaylists() async{
    try{
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to Clear Cached Playlists');
    }
  }

  /// Get the Playlists from cache.
  Future<List<PlaylistModel>?> getCachedPlaylists() async {
    try{
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString(_key);

      if(jsonData == null){
        return null;
      }

      List<dynamic> storedList = jsonDecode(jsonData);
      List<PlaylistModel> playlists = <PlaylistModel>[];

      for(Map<String, dynamic> item in storedList){
        playlists.add(PlaylistModel.fromJson(item));
      }
      _storedPlaylists = playlists;
      
      return _storedPlaylists;

    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Error Cache Decoding');
      return null;
    }
  }
}