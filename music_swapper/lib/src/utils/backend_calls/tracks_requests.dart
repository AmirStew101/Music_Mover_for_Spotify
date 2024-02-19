import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';

Future<int> getSpotifyTracksTotal(String playlistId, double expiresAt, String accessToken) async{
  try{
    dynamic responseDecoded;

    final getTotalUrl = '$hosted/get-tracks-total/$playlistId/$expiresAt/$accessToken';
    final response = await http.get(Uri.parse(getTotalUrl));

    if (response.statusCode == 200){
      responseDecoded = json.decode(response.body);

      if (responseDecoded['status'] == 'Success'){
        return responseDecoded['totalTracks'];
      }
    }
    else{
      debugPrint('Failed to get Spotify Total Tracks : ${responseDecoded['message']}');
      return -1;
    }
  }
  catch (e){
    debugPrint('Caught Error in getSpotifyTracksTotal: $e');
  }
  return -1;
}

Future<Map<String, TrackModel>> getSpotifyPlaylistTracks(String playlistId, double expiresAt, String accessToken, int totalTracks) async {
  try{
    Map<String, dynamic> checkTracks = {};
    Map<String, dynamic> receivedTracks = {};
    dynamic responseDecoded;

    //Gets Tracks 50 at a time because of Spotify's limit
    for (var offset = 0; offset < totalTracks; offset +=50){

      final getTracksUrl ='$hosted/get-all-tracks/$playlistId/$expiresAt/$accessToken/$offset';
      final response = await http.get(Uri.parse(getTracksUrl));

      if (response.statusCode == 200){
        responseDecoded = json.decode(response.body);

        //Don't check if a song is in Liked Songs if the playlist is Liked Songs
          if (playlistId == 'Liked_Songs'){
            receivedTracks.addAll(responseDecoded['data']);
          }
          //Check the 50 tracks received if they are in Liked Songs
          else{
            checkTracks.addAll(responseDecoded['data']);
            final checkResponse = await checkLiked(checkTracks, expiresAt, accessToken);

            //Add checked tracks to the total tracks and reset the checked tracks
            if (checkResponse != null){
              receivedTracks.addAll(checkResponse);
              checkTracks.clear();
            }
          }
      }
      else{
        throw Exception('tracks_requests.dart line ${getCurrentLine()}. Failed to get Spotify Tracks : ${responseDecoded['message']}');
      }
    }

    Map<String, TrackModel> newTracks = getPlatformTrackImages(receivedTracks);
    return newTracks;
  }
  catch (e){
    debugPrint('tracks_requests.dart line: ${getCurrentLine()} caught error: $e');
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
        duplicates: item.value['duplicates'],
        liked: item.value['liked']
      );

      newTracks[newTrack.id] = newTrack;
    }

    return newTracks;
  } 

  throw Exception("Failed Platform is not supported");
}

Future<Map<String, dynamic>?> checkLiked(Map<String, dynamic> tracksMap, double expiresAt, String accessToken) async{
  List<String> trackIds = [];
  List<dynamic> boolList = [];
  
  final checkUrl = '$hosted/check-liked/$expiresAt/$accessToken';
  var response;

  try{
    for (var i = 0; i < tracksMap.length; i++){
      final track = tracksMap.entries.elementAt(i);
      final trueId = getTrackId(track.key);
      trackIds.add(trueId);
      
        if ( (i+1 % 50) == 0 || i == tracksMap.length-1){
          //Check the Ids of up to 50 tracks
          final response = await http.post(Uri.parse(checkUrl),
            headers: {
              'Content-Type': 'application/json'
            },
            body: jsonEncode({'trackIds': trackIds})
          );

          //Not able to receive the checked result from Spotify
          if (response.statusCode != 200){
            return null;
          }

          final responseDecoded = jsonDecode(response.body);

          boolList.addAll(responseDecoded['boolArray']);
        }
    }

    Map<String, dynamic> checkedTracks = {};

    for (var i = 0; i < tracksMap.length; i++){
      final currTrack = tracksMap.entries.elementAt(i);

      if (boolList[i]){
        checkedTracks
        .putIfAbsent(currTrack.key, () => {
          'title': currTrack.value['title'], 
          'imageUrl': currTrack.value['imageUrl'],
          'artist': currTrack.value['artist'],
          'preview_url': currTrack.value['preview_url'],
          'duplicates': currTrack.value['duplicates'],
          'liked': boolList[i],}
        );
      }
      else{
        checkedTracks.putIfAbsent(currTrack.key, () => currTrack.value);
      }
      
    }
    return checkedTracks;
  }
  catch (e){
    debugPrint('tracks_requests.dart line: ${getCurrentLine()} Caught error $e');
    return null;
  }
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
