import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:spotify_music_helper/utils/globals.dart';

Future<int> getSpotifyTracksTotal(String playlistId, double expiresAt, String accessToken) async{
  try{
    final getTotalUrl = '$hosted/get-tracks-total/$playlistId/$expiresAt/$accessToken';
    final response = await http.get(Uri.parse(getTotalUrl));

    final responseDecoded = json.decode(response.body);

    if (response.statusCode == 200){
      return responseDecoded['totalTracks'];
    }
    else{
      debugPrint('Failed to get Spotify Total Tracks : ${responseDecoded['message']}');
      return -1;
    }
  }
  catch (e){
    debugPrint('Caught Error in getSpotifyTracksTotal: $e');
  }
  return 0;
}

Future<Map<String, dynamic>> getSpotifyPlaylistTracks(String playlistId, double expiresAt, String accessToken, int totalTracks) async {
  try{  
    final getTracksUrl ='$ngrok/get-all-tracks/$playlistId/$expiresAt/$accessToken/$totalTracks';
    final response = await http.get(Uri.parse(getTracksUrl));

    final responseDecoded = json.decode(response.body);

    if (response.statusCode == 200){
      Map<String, dynamic> tracks = responseDecoded['data'];
      debugPrint('Spotify Tracks: ${tracks.length}');

      tracks = getPlatformTrackImages(tracks);
      return tracks;
    }
    else{
      debugPrint('Failed to get Spotify Tracks : ${responseDecoded['message']}');
    }
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
  try{
    await addTracksRequest(tracks, playlistIds, expiresAt, accessToken);
    await removeTracksRequest(tracks, originId, snapshotId, expiresAt, accessToken);
  }
  catch (e){
    debugPrint('Failed to move Tracks $e');
    return false;
  }
  
  debugPrint('Moved Tracks');
  return true;
}

Future<void> addTracksRequest(List<String> tracks, List<String> playlistIds, double expiresAt, String accessToken) async {
  final moveTracksUrl ='$ngrok/add-to-playlists/$expiresAt/$accessToken';

  final response = await http.post(
    Uri.parse(moveTracksUrl),
    headers: {
    'Content-Type': 'application/json'
    },
    body: jsonEncode({'trackIds': tracks, 'playlistIds': playlistIds})
  );

  if (response.statusCode != 200){
    throw Exception('Error trying to add tracks ${response.statusCode} ${response.body}');
  }
}

Future<void> removeTracksRequest(List<String> tracks, String originId, String snapshotId, double expiresAt, String accessToken) async{
  try{
    debugPrint('Remove Tracks Request: $tracks');
    final removeTracksUrl ='$ngrok/remove-tracks/$originId/$snapshotId/$expiresAt/$accessToken';

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