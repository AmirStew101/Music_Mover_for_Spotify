import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';

class TracksRequests{

  Future<int> getTracksTotal(String playlistId, double expiresAt, String accessToken) async{
    try{
      dynamic responseDecoded;

      final getTotalUrl = '$hosted/get-tracks-total/$playlistId/$expiresAt/$accessToken';
      final response = await http.get(Uri.parse(getTotalUrl));

      if (response.statusCode != 200){
        throw Exception('Failed to get Spotify Total Tracks : ${responseDecoded['message']}');
      }
      responseDecoded = json.decode(response.body);

      return responseDecoded['totalTracks'];
    }
    catch (e){
      throw Exception('Line ${getCurrentLine()} : $e');
    }

  }


  Future<Map<String, TrackModel>> getPlaylistTracks(String playlistId, double expiresAt, String accessToken, int totalTracks) async {
    try{
      Map<String, dynamic> checkTracks = {};
      Map<String, dynamic> receivedTracks = {};
      dynamic responseDecoded;

      //Gets Tracks 50 at a time because of Spotify's limit
      for (var offset = 0; offset < totalTracks; offset +=50){

        final getTracksUrl ='$ngrok/get-all-tracks/$playlistId/$expiresAt/$accessToken/$offset';
        final response = await http.get(Uri.parse(getTracksUrl));

        if (response.statusCode != 200){
          throw Exception('line ${getCurrentLine()}; Failed to get Spotify Tracks : ${responseDecoded['message']}');
        }

        responseDecoded = json.decode(response.body);

        //Don't check if a song is in Liked Songs if the playlist is Liked Songs
        if (playlistId == 'Liked_Songs'){
          receivedTracks.addAll(responseDecoded['data']);
        }
        //Check the 50 tracks received if they are in Liked Songs
        else{
          receivedTracks.addAll(responseDecoded['data']);

          String id;
          for (var track in receivedTracks.entries){
            id = track.key;
            if (checkTracks.containsKey(id)){
              checkTracks.update(id, (value)  {
                debugPrint('\nTrack val: ${track.value}, \nValue: $value');
                return value['duplicates'] += 1;
                });
            }
            else{
              checkTracks.putIfAbsent(id, () => track.value);
            }
          }

          receivedTracks.clear();
        }
    
      }

      for (var track in checkTracks.entries){
        if (track.value['title'] == 'Imposters Among Us') debugPrint('Track ${track.value['title']} Dupes: ${track.value['duplicates']}');
      }
      //final checkResponse = await checkLiked(checkTracks, expiresAt, accessToken);

      //Map<String, TrackModel> newTracks = getPlatformTrackImages(receivedTracks);
      return {};
    }
    catch (e){
      throw Exception('Line: ${getCurrentLine()} : $e');
    }
    
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


  Future<Map<String, dynamic>> checkLiked(Map<String, dynamic> tracksMap, double expiresAt, String accessToken) async{
    List<String> trackIds = [];
    List<dynamic> boolList = [];
    dynamic track;
    String trueId;
    
    final checkUrl = '$hosted/check-liked/$expiresAt/$accessToken';

    try{
      for (var i = 0; i < tracksMap.length; i++){
        track = tracksMap.entries.elementAt(i);
        trueId = getTrackId(track.key);
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
              throw Exception('In tracks_requests.dart line: ${getCurrentLine()} : ${response.body}');
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
      throw Exception('line: ${getCurrentLine()}; $e');
    }
  }


  Future<void> addTracks(List<String> tracks, List<String> notLikedTracks, List<String> playlistIds, double expiresAt, String accessToken) async {
    final addTracksUrl ='$hosted/add-to-playlists/$expiresAt/$accessToken';
    try{
      final response = await http.post(
        Uri.parse(addTracksUrl),
          headers: {
          'Content-Type': 'application/json'
          },
          body: jsonEncode({'trackIds': tracks, 'playlistIds': playlistIds, 'notLiked': notLikedTracks})
      );

      if (response.statusCode != 200){
        throw Exception('tracks_requests.dart line ${getCurrentLine(offset: 9)} : ${response.statusCode} ${response.body}');
      }
    }
    catch (e){
      throw Exception('tracks_requests.dart line ${getCurrentLine(offset: 12)} : $e');
    }
  }


  Future<void> removeTracks(Map<String, TrackModel> selectedTracks, String originId, String snapshotId, double expiresAt, String accessToken) async{
    final removeTracksUrl ='$hosted/remove-tracks/$originId/$snapshotId/$expiresAt/$accessToken';

    List<String> addBack = handleDuplicates(selectedTracks);

    final response = await http.post(
      Uri.parse(removeTracksUrl),
        headers: {
        'Content-Type': 'application/json'
        },
        body: jsonEncode({'trackIds': selectedTracks})
    );

    if (response.statusCode != 200){
      throw Exception('tracks_requests.dart line ${getCurrentLine()} Response: ${response.statusCode} ${response.body}');
    }
    
  }//removeTracks

  List<String> handleDuplicates(Map<String, TrackModel> selectedTracks){
    throw Exception('Not Implemented');
  }

}