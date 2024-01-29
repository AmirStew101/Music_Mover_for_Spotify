import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:music_swapper/utils/globals.dart';

Future<Map<String, dynamic>> getSpotifyPlaylists(double expiresAt, String accessToken) async {
  try {
  final getPlaylistsUrl = '$hosted/get-playlists/$expiresAt/$accessToken';

  final response = await http.get(Uri.parse(getPlaylistsUrl));
  if (response.statusCode == 200){
    final responseDecode = json.decode(response.body);
    if (responseDecode['status'] == 'Success'){
      Map<String, dynamic> playlists = responseDecode['data'];
      playlists = getPlaylistImages(playlists);
      return playlists;
    }
  }
  }
  catch (e){
    debugPrint('Caught Error while in getSpotifyPlaylists: $e');
  }

  throw Exception('Failed to get playlists');
}

//Gives each playlist the image size based on current platform
Map<String, dynamic> getPlaylistImages(Map<String, dynamic> playlists) {
  Map<String, dynamic> images = {};
  if (Platform.isAndroid || Platform.isIOS) {
    //Goes through each Playlist and takes the Image size based on current users platform
    for (var item in playlists.entries) {
      List imagesList = item.value['imageUrl']; //The Image list for the current Playlist
      int middleIndex = 0; //position of the smallest image in the list

      if (imagesList.length > 2) {
        middleIndex = imagesList.length ~/ 2;
      }

      //Some Playlists have no images this checks if a Playlist has images or not
      if (imagesList.isNotEmpty) {
        images.putIfAbsent(item.key, () => item.value['imageUrl'][middleIndex]['url']);
        playlists[item.key]['imageUrl'] = images[item.key];
      } else {
        images.putIfAbsent(item.key, () => 'assets/images/no_image.png');
        playlists[item.key]['imageUrl'] = images[item.key];
      }
    }
    return playlists;
  } 
  else if (Platform.isMacOS || Platform.isWindows) {
    for (var item in playlists.entries) {
      List imagesList = item.value['imageUrl']; //The Image list for the current Playlist
      int largestIndex = 0; //position of the largest image in the list

      if (imagesList.length > 1) {
        int largest = 0;
        int index = 0;

        //Iterates through the current Image Map {height, url, width} for the largest image
        for (var image in imagesList) {
          if (image['height'] > largest) {
            largest = image['height'];
            largestIndex = index;
          }
          index++;
        }
      }

      //Some Playlists have no images this checks if a Playlist has images or not
      if (imagesList.isNotEmpty) {
        images.putIfAbsent(item.key, () => item.value['imageUrl'][largestIndex]['url']);
        playlists[item.key]['imageUrl'] = images[item.key];
      } else {
        images.putIfAbsent(item.key, () => 'assets/images/no_image.png');
        playlists[item.key]['imageUrl'] = images[item.key];
      }
    }
    return playlists;
  }
  throw Exception("Failed Platform is not supported");
}

Future<Map<String, dynamic>> spotRefreshToken(double expiresAt, String refreshToken) async {
  final refreshUrl = '$hosted/refresh-token/$expiresAt/$refreshToken';

  final response = await http.get(Uri.parse(refreshUrl));
  final responseDecode = json.decode(response.body);

  if (responseDecode['status'] == 'Success') {
    Map<String, dynamic> info = responseDecode['data'];
    return info;
  } else {
    return responseDecode;
  }
}

//Checks if the Token has expired
Future<Map<String, dynamic>> checkRefresh(Map<String, dynamic> checkCall, bool forceRefresh) async {
  //Get the current time in seconds to be the same as in Python
  double currentTime = DateTime.now().millisecondsSinceEpoch.toDouble() / 1000;

  //Checks if the token is expired and gets a new one if so
  if (currentTime > checkCall['expiresAt'] || forceRefresh) {
    final response = await spotRefreshToken(checkCall['expiresAt'], checkCall['refreshToken']);

    //The function deals with the status if response has a status token is still good
    //response without status is the new token data
    if (!response.containsKey('status')) {
      checkCall = response;
    }
  }

  return checkCall;
}
