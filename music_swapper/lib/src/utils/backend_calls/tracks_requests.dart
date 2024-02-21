import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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
        final getTracksUrl ='$hosted/get-tracks/$playlistId/$expiresAt/$accessToken/$offset';
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
                value['duplicates']++;
                return value;
                });
            }
            else{
              checkTracks.putIfAbsent(id, () => track.value);
            }
          }

          receivedTracks.clear();
        }
    
      }

      //Returns the Liked Songs with no duplicates
      if (playlistId == 'Liked_Songs'){
        Map<String, TrackModel> newTracks = getPlatformTrackImages(receivedTracks);
        return newTracks;
      }
      //Returns a PLaylist's tracks and checks if they are in liked
      else{
        final checkResponse = await checkLiked(checkTracks, expiresAt, accessToken);
        Map<String, TrackModel> newTracks = getPlatformTrackImages(checkResponse);
        return newTracks;
      }
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

    List<String> sendingIds = [];
    MapEntry<String, dynamic> track;
    
    final checkUrl = '$hosted/check-liked/$expiresAt/$accessToken';

    try{
      for (var i = 0; i < tracksMap.length; i++){
        track = tracksMap.entries.elementAt(i);
        trackIds.add(track.key);
        sendingIds.add(track.key);
        
          if ( (i % 50) == 0 || i == tracksMap.length-1){
            //Check the Ids of up to 50 tracks
            final response = await http.post(Uri.parse(checkUrl),
              headers: {
                'Content-Type': 'application/json'
              },
              body: jsonEncode({'trackIds': sendingIds})
            );

            //Not able to receive the checked result from Spotify
            if (response.statusCode != 200){
              throw Exception('In tracks_requests.dart line: ${getCurrentLine(offset: 8)} : ${response.body}');
            }

            final responseDecoded = jsonDecode(response.body);
            boolList.addAll(responseDecoded['boolArray']);
            sendingIds.clear();
          }
      }

      MapEntry<String, dynamic> currTrack;
      for (var i = 0; i < tracksMap.length; i++){
        currTrack = tracksMap.entries.elementAt(i);

        if (boolList[i]){
          tracksMap.update(currTrack.key, (value) {
            value['liked'] = true; 
            return value;
          });
        }
        
      }
      
      return tracksMap;
    }
    catch (e){
      throw Exception('line: ${getCurrentLine()}; $e');
    }
  }


  Future<void> addTracks(List<String> tracks, List<String> playlistIds, double expiresAt, String accessToken) async {
    final addTracksUrl ='$hosted/add-to-playlists/$expiresAt/$accessToken';
    try{
      List<String> sendAdd = [];
      dynamic response;

      for (var i = 0; i < playlistIds.length; i++){
        sendAdd.add(playlistIds[i]);

        if (((i % 50) == 0 && i != 0) || i == playlistIds.length-1){
          response = await http.post(
            Uri.parse(addTracksUrl),
              headers: {
              'Content-Type': 'application/json'
              },
              body: jsonEncode({'trackIds': tracks, 'playlistIds': sendAdd})
          );
        }
      }

      if (response.statusCode != 200){
        throw Exception('tracks_requests.dart line ${getCurrentLine(offset: 9)} : ${response.statusCode} ${response.body}');
      }
    }
    catch (e){
      throw Exception('tracks_requests.dart line ${getCurrentLine(offset: 12)} : $e');
    }
  }


  Future<void> removeTracks(List<String> selectedIds, String originId, String snapshotId, double expiresAt, String accessToken) async{
    final removeTracksUrl ='$hosted/remove-tracks/$originId/$snapshotId/$expiresAt/$accessToken';

    final response = await http.post(
      Uri.parse(removeTracksUrl),
        headers: {
        'Content-Type': 'application/json'
        },
        body: jsonEncode({'trackIds': selectedIds})
    );

    if (response.statusCode != 200){
      throw Exception('tracks_requests.dart line ${getCurrentLine()} Response: ${response.statusCode} ${response.body}');
    }
    
  }//removeTracks

  Map<String, TrackModel> makeDuplicates(Map<String, TrackModel> allTracks){
    Map<String, TrackModel> newAllTracks = {};
    int trackDupes;
    String dupeId;

    for (var track in allTracks.entries){
      trackDupes = track.value.duplicates;

      if (trackDupes > 0){
        for (var i = 0; i <= trackDupes; i++){
          dupeId = i == 0
          ? track.key
          : '${track.key}_$i';

          newAllTracks.addAll({dupeId: track.value});
        }
      }
      else{
        newAllTracks.addAll({track.key: track.value});
      }
    }

    return newAllTracks;
  }

  ///Returns a List of the unmodified track Ids
  List<String> getUnmodifiedIds(Map<String, TrackModel> selectedTracks){

    List<String> unmodifiedIds = [];

    for (var track in selectedTracks.entries){
      String trueId = getTrackId(track.key);
      unmodifiedIds.add(trueId);
    }

    return unmodifiedIds;
  }

  List<String> getAddBackIds(Map<String, TrackModel> selectedTracks){
    Map<String, TrackModel> selectedNoDupes = {};
    List<String> removeIds = getUnmodifiedIds(selectedTracks);
    List<String> addBackIds = [];

    for(var track in selectedTracks.entries){
      String trueId = getTrackId(track.key);

      selectedNoDupes.putIfAbsent(trueId, () => track.value);
    }

    // Dupes is 0 if its only one track
    // First item in a list is at location 0
    removeIds.sort();
    debugPrint('selectedNoDupes $selectedNoDupes');
    for (var track in selectedNoDupes.entries){
      int dupes = track.value.duplicates;

      debugPrint('Searching for ${track.key}');
      //Gets location of element in sorted list
      final removeTotal = removeIds.lastIndexOf(track.key);
      final removeStart = removeIds.indexOf(track.key);

      //Gets the difference between the deleted tracks and its duplicates
      int diff = dupes - removeTotal;

      //There is no difference and you are deleting them all
      if (diff > 0){
        for (var i = 0; i < diff; i++){
          addBackIds.add(track.key);
        }
      }

      debugPrint('Remove range 0 to ${removeTotal+1}');
      debugPrint('Remove Ids before $removeIds');
      //Removes the tracks that have been checked
      removeIds.removeRange(removeStart, removeTotal+1);
      debugPrint('Remove Ids after $removeIds');
    }

    return addBackIds;
  }

}