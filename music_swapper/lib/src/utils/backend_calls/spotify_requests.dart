import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:spotify_music_helper/src/utils/dev_global.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:get/get.dart';

class SpotifyRequests extends GetxController{
  CallbackModel callBack = const CallbackModel();
  UserModel user = UserModel();

  Map<String , PlaylistModel> playlists = {};

  Map<String, TrackModel> tracks = {};
  Map<String, TrackModel> tracksDupes = {};
  int tracksTotal = 0;
  String _playlistId = '';
  String urlExpireAccess = '';

  ///Set the playlist Id and get tracks for 
  Future<void> requestTracksforPlaylist(String id) async{
    _playlistId = id;
    urlExpireAccess = '${callBack.expiresAt}/${callBack.accessToken}';
    await _getPlaylistTracks();
  }

   Future<void> addTracks(List<String> tracks, List<String> playlistIds) async {
    final addTracksUrl ='$hosted/add-to-playlists/$urlExpireAccess';
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


  Future<void> removeTracks(List<String> selectedIds, String originId, String snapshotId) async{
    final removeTracksUrl ='$hosted/remove-tracks/$originId/$snapshotId/$urlExpireAccess';

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

  ///Get the track ids to add back to Spotify.
  List<String> getAddBackIds(Map<String, TrackModel> selectedTracks){
    Map<String, TrackModel> selectedNoDupes = {};
    List<String> removeIds = _getUnmodifiedIds(selectedTracks);
    List<String> addBackIds = [];

    for(var track in selectedTracks.entries){
      String trueId = getTrackId(track.key);

      selectedNoDupes.putIfAbsent(trueId, () => track.value);
    }

    // Dupes is 0 if its only one track
    // First item in a list is at location 0
    removeIds.sort();
    for (var track in selectedNoDupes.entries){
      int dupes = track.value.duplicates;

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
      //Removes the tracks that have been checked
      removeIds.removeRange(removeStart, removeTotal+1);
    }

    return addBackIds;
  }


  //Private

  ///Get the total number of tracks in a playlist.
  Future<void> _getTracksTotal() async{
    try{
      dynamic responseDecoded;

      final getTotalUrl = '$hosted/get-tracks-total/$_playlistId/$urlExpireAccess';
      final response = await http.get(Uri.parse(getTotalUrl));

      if (response.statusCode != 200){
        throw Exception('Failed to get Spotify Total Tracks : ${responseDecoded['message']}');
      }
      responseDecoded = json.decode(response.body);

      tracksTotal = responseDecoded['totalTracks'];
    }
    catch (e){
      throw Exception('Line ${getCurrentLine()} : $e');
    }

  }

  ///Get the the tracks in a playlist.
  Future<void> _getPlaylistTracks() async {
    try{
      await _getTracksTotal();
      Map<String, dynamic> checkTracks = {};
      Map<String, dynamic> receivedTracks = {};
      dynamic responseDecoded;

      //Gets Tracks 50 at a time because of Spotify's limit
      for (var offset = 0; offset < tracksTotal; offset +=50){
        final getTracksUrl ='$hosted/get-tracks/$urlExpireAccess/$_playlistId/$offset';
        final response = await http.get(Uri.parse(getTracksUrl));

        if (response.statusCode != 200){
          throw Exception('line ${getCurrentLine()}; Failed to get Spotify Tracks : ${responseDecoded['message']}');
        }

        responseDecoded = json.decode(response.body);

        //Don't check if a song is in Liked Songs if the playlist is Liked Songs
        if (_playlistId == 'Liked_Songs'){
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
      if (_playlistId == 'Liked_Songs'){
        tracks = _getPlatformTrackImages(receivedTracks);
      }
      //Returns a PLaylist's tracks and checks if they are in liked
      else{
        final checkResponse = await _checkLiked(checkTracks, callBack.expiresAt, callBack.accessToken);
        tracks = _getPlatformTrackImages(checkResponse);
        _makeDuplicates();
      }
    }
    catch (e){
      throw Exception('Line: ${getCurrentLine()} : $e');
    }
    
  }

  Map<String, TrackModel> _getPlatformTrackImages(Map<String, dynamic> tracks) {
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


  Future<Map<String, dynamic>> _checkLiked(Map<String, dynamic> tracksMap, double expiresAt, String accessToken) async{
    List<String> trackIds = [];
    List<dynamic> boolList = [];

    List<String> sendingIds = [];
    MapEntry<String, dynamic> track;
    
    final checkUrl = '$hosted/check-liked/$urlExpireAccess';

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

  ///Make duplicates of tracks that have duplicates.
  void _makeDuplicates(){
    Map<String, TrackModel> newAllTracks = {};
    int trackDupes;
    String dupeId;

    for (var track in tracks.entries){
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
  }

  ///Returns a List of the unmodified track Ids
  List<String> _getUnmodifiedIds(Map<String, TrackModel> tracks){

    List<String> unmodifiedIds = [];

    for (var track in tracks.entries){
      String trueId = getTrackId(track.key);
      unmodifiedIds.add(trueId);
    }

    return unmodifiedIds;
  }


  

  Future<void> getPlaylists() async {
    try {
      final getPlaylistsUrl = '$hosted/get-playlists/${callBack.expiresAt}/${callBack.accessToken}';

      final response = await http.get(Uri.parse(getPlaylistsUrl));
      if (response.statusCode != 200){
        throw Exception('Line ${getCurrentLine(offset: 2)} Failed to get Spotify Playlists: ${response.body}');
      }

      final responseDecode = json.decode(response.body);

      Map<String, dynamic> responsePlay = responseDecode['data'];

      //Removes all playlists not made by the User
      responsePlay.removeWhere((key, value) => value['owner'] != user.spotifyId && key != 'Liked_Songs');

      getPlaylistImages(playlists);
    }
    catch (e){
      throw Exception('Line ${getCurrentLine()} : $e');
    }
  }

  //Gives each playlist the image size based on current platform
  void getPlaylistImages(Map<String, dynamic> playlists) {

    //The chosen image url
    String imageUrl = '';
    Map<String, PlaylistModel> newPlaylists = {};

    try{
      if (Platform.isAndroid || Platform.isIOS) {
        //Goes through each Playlist and takes the Image size based on current users platform
        for (var item in playlists.entries) {
          //Item is a Playlist and not Liked Songs
          if (item.key != 'Liked_Songs'){
            List<dynamic> imagesList = item.value['imageUrl']; //The Image list for the current Playlist

            //Playlist has an image
            if (imagesList.isNotEmpty) {
              imageUrl = item.value['imageUrl'][0]['url'];         
            }
            //Playlist is missing an image so use default blank
            else {
              imageUrl = assetNoImage;
            }
          }
          //Use the Liked_Songs image
          else{
            imageUrl = assetLikedSongs;
          }

          PlaylistModel newPlaylist = PlaylistModel(
            title: item.value['title'], 
            id: item.key, 
            link: item.value['link'], 
            imageUrl: imageUrl, 
            snapshotId: item.value['snapshotId']
          );

          newPlaylists[newPlaylist.id] = newPlaylist;

        }
        playlists = newPlaylists;
      } 
      
    }
    catch (e){
      throw Exception('Line: ${getCurrentLine()} : $e');
    }
    throw Exception("Failed Platform is not supported");
  }

  Future<void> spotRefreshToken() async {
    try{
      final refreshUrl = '$hosted/refresh-token/${callBack.expiresAt}/${callBack.refreshToken}';

      final response = await http.get(Uri.parse(refreshUrl));
      final responseDecode = json.decode(response.body);

      if (responseDecode['status'] == 'Success') {
        Map<String, dynamic> info = responseDecode['data'];
        callBack = CallbackModel(expiresAt: info['expiresAt'], accessToken: info['accessToken'], refreshToken: info['refreshToken']);
        SecureStorage().saveTokens(callBack);
      } 
    }
    catch (e){
      throw Exception('Line: ${getCurrentLine()} : $e');
    }
  }

  ///Checks if the Spotify Token has expired.
  Future<void> checkRefresh({bool forceRefresh = false}) async {
    try{
      if (callBack.isEmpty){
        return;
      }
      
      //Get the current time in seconds to be the same as in Python
      double currentTime = DateTime.now().millisecondsSinceEpoch.toDouble() / 1000;

      //Checks if the token is expired and gets a new one if so
      if (currentTime > callBack.expiresAt || forceRefresh) {
        await spotRefreshToken();
      }
    }
    catch (e){
      throw Exception('playlists_requests.dart line: ${getCurrentLine()} Caught Error: $e');
    }
  }

  ///Get the Spotify user.
  Future<void> getUser() async{
    final getUserInfo = '$hosted/get-user-info/${callBack.expiresAt}/${callBack.accessToken}';
    final response = await http.get(Uri.parse(getUserInfo));
    Map<String, dynamic> userInfo = {};

    if (response.statusCode != 200){
      debugPrint('spotify_requests.dart line: ${getCurrentLine()} Failed to get Spotify User: ${response.body}');
      throw Exception('Failed to get user');
    }

    final responseDecoded = json.decode(response.body);
    userInfo = responseDecoded['data'];

    //Converts user from Spotify to Firestore user
    user = UserModel(username: userInfo['user_name'] , spotifyId: userInfo['id'], uri: userInfo['uri'], expiration: Timestamp.now());
  }

}