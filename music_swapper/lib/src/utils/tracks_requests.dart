import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/universal_widgets.dart';

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

Future<Map<String, TrackModel>> getSpotifyPlaylistTracks(String playlistId, double expiresAt, String accessToken, int totalTracks) async {
  try{
    Map<String, dynamic> tracks = {};

    //Gets Tracks 50 at a time because of Spotify's limit
    for (var offset = 0; offset < totalTracks; offset +=50){

      final getTracksUrl ='$hosted/get-all-tracks/$playlistId/$expiresAt/$accessToken/$totalTracks/$offset';
      final response = await http.get(Uri.parse(getTracksUrl));

      final responseDecoded = json.decode(response.body);

      if (response.statusCode == 200){
        tracks.addAll(responseDecoded['data']);
      }
      else{
      debugPrint('Failed to get Spotify Tracks : ${responseDecoded['message']}');
      }
    }

    Map<String, TrackModel> newTracks = getPlatformTrackImages(tracks);
    return newTracks;
  }
  catch (e){
    debugPrint('Caught Error in getSpotifyPlaylistTracks $e');
  }

  throw Exception('Error getting Spotify tracks');
}

Map<String, TrackModel> getPlatformTrackImages(Map<String, dynamic> tracks) {
  //The chosen image url
  String imageUrl = '';
  Map<String, TrackModel> newTracks = {};

  if (Platform.isAndroid || Platform.isIOS) {
    //Goes through each Playlist {name '', ID '', Link '', Images [{}]} and takes the Images
    for (var item in tracks.entries) {
      List<dynamic> imagesList = item.value['imageUrl']; //The Image list for the current Playlist
      int middleIndex = 0; //position of the smallest image in the list

      if (imagesList.length > 2) {
        middleIndex = imagesList.length ~/ 2;
      }

      imageUrl = item.value['imageUrl'][middleIndex]['url'];

      TrackModel newTrack = TrackModel(
        id: item.key, 
        imageUrl: imageUrl, 
        artist: item.value['artist'], 
        title: item.value['title'], 
        duplicates: item.value['duplicates']
      );

      newTracks[newTrack.id] = newTrack;
    }

    return newTracks;
  } 

  throw Exception("Failed Platform is not supported");
}

Future<void> addTracksRequest(List<String> tracks, List<String> playlistIds, double expiresAt, String accessToken) async {
  final addTracksUrl ='$hosted/add-to-playlists/$expiresAt/$accessToken';

  final response = await http.post(
    Uri.parse(addTracksUrl),
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