import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:music_swapper/utils/globals.dart';
import 'package:http/http.dart' as http;

Future<int> getSpotifyTracksTotal(String playlistId, double expiresAt, String accessToken) async{
  try{
    final getTotalUrl = '$hosted/get-tracks-total/$playlistId/$expiresAt/$accessToken';
    final response = await http.get(Uri.parse(getTotalUrl));

    if (response.statusCode == 200){
      final responseDecoded = json.decode(response.body);

      return responseDecoded['totalTracks'];
    }
  }
  catch (e){
    debugPrint('Caught Error in getSpotifyTracksTotal: $e');
  }
  return 0;
}

Future<Map<String, dynamic>> getSpotifyPlaylistTracks(String playlistId, double expiresAt, String accessToken, int totalTracks) async {
  try{  
    final getTracksUrl ='$hosted/get-all-tracks/$playlistId/$expiresAt/$accessToken/$totalTracks';
    final response = await http.get(Uri.parse(getTracksUrl));

    if (response.statusCode == 200){
      final responseDecoded = json.decode(response.body);
      Map<String, dynamic> tracks = responseDecoded['data'];

      tracks = getPlatformTrackImages(tracks);
      return tracks;
    }

    debugPrint('Error Status code: ${response.statusCode}: $response');
  }
  catch (e){
    debugPrint('Caught Error in getSpotifyPlaylistTracks $e');
  }

  throw Exception('Error getting Spotify tracks');
}

Map<String, dynamic> getPlatformTrackImages(Map<String, dynamic> tracks) {
  //The chosen image url
  String imageUrl = '';

  if (Platform.isAndroid || Platform.isIOS) {
    //Goes through each Playlist {name '', ID '', Link '', Images [{}]} and takes the Images
    for (var item in tracks.entries) {
      List imagesList = item.value['imageUrl']; //The Image list for the current Playlist
      int middleIndex = 0; //position of the smallest image in the list

      if (imagesList.length > 2) {
        middleIndex = imagesList.length ~/ 2;
      }

      imageUrl = item.value['imageUrl'][middleIndex]['url'];
      tracks[item.key]['imageUrl'] = imageUrl;
    }

    return tracks;
  } 
  else if (Platform.isMacOS || Platform.isWindows) {

    for (var item in tracks.entries) {
      //The Image list for the current Playlist
      List<dynamic> imagesList = item.value['imageUrl']; 
      int largestIndex = 0; //position of the largest image in the list
      int largest = 0;
      int index = 0;

      if (imagesList.length > 1) {
        //Iterates through the current Image Map {height, url, width} for the largest image
        for (var image in imagesList) {
          if (image['height'] > largest) {
            largest = image['height'];
            largestIndex = index;
          }
          index++;
        }
      }

      imageUrl = item.value['images'][largestIndex]['url'];
      tracks[item.key]['imageUrl'] = imageUrl;
    }

    return tracks;
  }
  throw Exception("Failed Platform is not supported");
}

Future<bool> moveTracksRequest(List<String> tracks, String originId, String snapshotId, List<String> playlistIds, double expiresAt, String accessToken) async {
  if(originId == 'Liked Songs'){
    originId = 'Liked_Songs';
    snapshotId = 'Liked_Songs';
  }
  final moveTracksUrl ='$ngrok/move-to-playlists/$originId/$snapshotId/$expiresAt/$accessToken';

  final response = await http.post(
    Uri.parse(moveTracksUrl),
    headers: {
    'Content-Type': 'application/json'
    },
    body: jsonEncode({'trackIds': tracks, 'playlistIds': playlistIds})
  );

  if (response.statusCode != 200){
    debugPrint('Failed to Move Tracks');
    return false;
  }
  debugPrint('Moved Tracks');
  return true;
}

Future<void> addTracksRequest(List<String> tracks, List<String> playlistIds, double expiresAt, String accessToken) async {
  final moveTracksUrl ='$hosted/add-to-playlists/$expiresAt/$accessToken';

  final response = await http.post(
    Uri.parse(moveTracksUrl),
    headers: {
    'Content-Type': 'application/json'
    },
    body: jsonEncode({'trackIds': tracks, 'playlistIds': playlistIds})
  );

  if (response.statusCode != 200){
    throw Exception('Error trying to move tracks');
  }
}

Future<void> removeTracksRequest(List<String> tracks, String originId, String snapshotId, double expiresAt, String accessToken) async{
  try{    
    final removeTracksUrl ='$hosted/remove-tracks/$originId/$snapshotId/$expiresAt/$accessToken';

    final response = await http.post(
      Uri.parse(removeTracksUrl),
      headers: {
      'Content-Type': 'application/json'
      },
      body: jsonEncode({'trackIds': tracks})
    );
    debugPrint('Response: ${response.statusCode} ${response.body}');
  }
  catch (e){
    debugPrint('Caught Error in tracks_requests.dart in removeTracksRequest $e');
  }
}