import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:music_swapper/utils/globals.dart';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> getSpotifyTracksTotal(String playlistId, double expiresAt, String accessToken) async{
  try{
    final getTotalUrl = '$hosted/get-tracks-total/$playlistId/$expiresAt/$accessToken';
    debugPrint('Get Total Url: $getTotalUrl');
    final response = await http.get(Uri.parse(getTotalUrl));

    if (response.statusCode == 200){
      final responseDecoded = json.decode(response.body);

      return responseDecoded;
    }
  }
  catch (e){
    debugPrint('Caught Error in getSpotifyTracksTotal: $e');
  }
  throw Exception('Error getting Spotify tracks total');
}

Future<Map<String, dynamic>> getSpotifyPlaylistTracks(String playlistId, double expiresAt, String accessToken, int totalTracks) async {
  try{  
    final getTracksUrl ='$hosted/get-all-tracks/$playlistId/$expiresAt/$accessToken/$totalTracks';
    final response = await http.get(Uri.parse(getTracksUrl));

    if (response.statusCode == 200){
      final responseDecoded = json.decode(response.body);

      return responseDecoded;
    }
    debugPrint('Error Status code: ${response.statusCode}');
  }
  catch (e){
    debugPrint('Caught Error in getSpotifyPlaylistTracks $e');
  }

  throw Exception('Error getting Spotify tracks');
}

Map<String, dynamic> getPlatformTrackImages(Map<String, dynamic> tracks) {
  Map<String, dynamic> images = {};
  if (Platform.isAndroid || Platform.isIOS) {
    //Goes through each Playlist {name '', ID '', Link '', Images [{}]} and takes the Images
    for (var item in tracks.entries) {
      List imagesList =
          item.value['imageUrl']; //The Image list for the current Playlist
      int middleIndex = 0; //position of the smallest image in the list

      if (imagesList.length > 2) {
        middleIndex = imagesList.length ~/ 2;
      }

      images.putIfAbsent(item.key, () {
        Map<String, dynamic> itemValMap = item.value;
        Map<String, dynamic> entry = {};
        entry.addAll({
          'title': item.value['title'],
          'imageUrl': item.value['imageUrl'][middleIndex]['url'],
          'previewUrl': itemValMap['previewUrl'],
          'artist': itemValMap['artist']
        });
        return entry;
      });
    }
    return images;
  } else if (Platform.isMacOS || Platform.isWindows) {
    for (var item in tracks.entries) {
      List imagesList =
          item.value['imageUrl']; //The Image list for the current Playlist
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

      images.putIfAbsent(item.key, () {
        Map<String, dynamic> itemValMap = item.value;
        Map<String, dynamic> entry = {};
        entry.addAll({
          'title': item.value['title'],
          'images': item.value['images'][largestIndex]['url'],
          'previewUrl': itemValMap['previewUrl'],
          'artist': itemValMap['artist']
        });
        return entry;
      });

    }
    return images;
  }
  throw Exception("Failed Platform is not supported");
}

Future<void> moveTracksRequest(List<String> tracks, String originId, String snapshotId, List<String> playlistIds, double expiresAt, String accessToken) async {
  final moveTracksUrl ='$hosted/move-to-playlists/$originId/$snapshotId/$expiresAt/$accessToken';

  final response = await http.post(
    Uri.parse(moveTracksUrl),
    headers: {
    'Content-Type': 'application/json'
    },
    body: jsonEncode({'track_ids': tracks, 'playlist_ids': playlistIds})
  );

  if (response.statusCode != 200){
    throw Exception('Error trying to move tracks');
  }
}

Future<void> addTracksRequest(List<String> tracks, List<String> playlistIds, double expiresAt, String accessToken) async {
  final moveTracksUrl ='$hosted/add-to-playlists/$expiresAt/$accessToken';

  final response = await http.post(
    Uri.parse(moveTracksUrl),
    headers: {
    'Content-Type': 'application/json'
    },
    body: jsonEncode({'track_ids': tracks, 'playlist_ids': playlistIds})
  );

  if (response.statusCode != 200){
    throw Exception('Error trying to move tracks');
  }
}

Future<void> removeTracksRequest(List<String> tracks, String originId, String snapshotId, double expiresAt, String accessToken) async{
  final removeTracksUrl ='$hosted/remove-tracks/$originId/$snapshotId/$expiresAt/$accessToken';

  final response = await http.post(
    Uri.parse(removeTracksUrl),
    headers: {
    'Content-Type': 'application/json'
    },
    body: jsonEncode({'track_ids': tracks})
  );

  if (response.statusCode != 200){
    throw Exception('Error trying to remove tracks');
  }
}