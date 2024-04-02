import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:spotify_music_helper/src/utils/dev_global.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';

class SpotifyRequests{
  ///Get the total amount of tracks in a playlist to assist in retreiving all of that playlists tracks.
  Future<int> getTracksTotal(String playlistId, double expiresAt, String accessToken) async{
    try{
      final getTotalUrl = '$hosted/get-tracks-total/$playlistId/$expiresAt/$accessToken';
      final response = await http.get(Uri.parse(getTotalUrl));

      if (response.statusCode != 200){
        throw Exception( exceptionText('spotify_requests.dart', 'getTracksTotal', response.body, offset: 3) );
      }

      final responseDecoded = json.decode(response.body);
      return responseDecoded['totalTracks'];
    }
    catch (e){
      throw Exception( exceptionText('spotify_requests.dart', 'getTracksTotal', e, offset: 14));
    }

  }//getTracksTotal

  ///Make the Spotify request for the users tracks in a playlist.
  Future<Map<String, TrackModel>> getPlaylistTracks(String playlistId, double expiresAt, String accessToken, int totalTracks) async {
    try{
      Map<String, dynamic> checkTracks = {};
      Map<String, dynamic> receivedTracks = {};

      //Gets Tracks 50 at a time because of Spotify's limit
      for (var offset = 0; offset < totalTracks; offset +=50){
        final getTracksUrl ='$hosted/get-tracks/$playlistId/$expiresAt/$accessToken/$offset';
        final response = await http.get(Uri.parse(getTracksUrl));

        if (response.statusCode != 200){
          throw Exception( exceptionText('spotify_requests.dart', 'getPlaylistTracks', response.body, offset: 3));
        }

        final responseDecoded = json.decode(response.body);

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
      //Returns a Playlist's tracks and checks if they are in liked
      else{
        final checkResponse = await checkLiked(checkTracks, expiresAt, accessToken);
        Map<String, TrackModel> newTracks = getPlatformTrackImages(checkResponse);
        return newTracks;
      }
    }
    catch (e){
      throw Exception( exceptionText('spotify_requests.dart', 'getPlaylistTracks', e) );
    }
    
  }//getPlaylistTracks

  ///Gets the images of the tracks.
  Map<String, TrackModel> getPlatformTrackImages(Map<String, dynamic> tracks) {
    try{
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
    }
    catch (e){
      throw Exception( exceptionText('spotify_requests.dart', 'getPlatformTrackImages', e) );
    }

    Object error = "Platform is not supported!";
    throw Exception( exceptionText('spotify_requests.dart', 'getPlatformTrackImages', error) );
  }//getPlatformTrackImages

  ///Check if a Song is in the Liked Songs playlist.
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
              throw Exception( exceptionText('spotify_requests.dart', 'checkLiked', response.body, offset: 9) );
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
      throw Exception( exceptionText('spotify_requests.dart', '', e) );
    }
  }//checkLiked

  ///Add tracks to a Sotify playlist.
  Future<void> addTracks(List<String> tracks, List<String> playlistIds, double expiresAt, String accessToken) async {
    final addTracksUrl ='$hosted/add-to-playlists/$expiresAt/$accessToken';
    try{
      List<String> sendAdd = [];

      for (var i = 0; i < playlistIds.length; i++){
        sendAdd.add(playlistIds[i]);

        if (((i % 50) == 0 && i != 0) || i == playlistIds.length-1){
          final response = await http.post(
            Uri.parse(addTracksUrl),
              headers: {
              'Content-Type': 'application/json'
              },
              body: jsonEncode({'trackIds': tracks, 'playlistIds': sendAdd})
          );

          if (response.statusCode != 200){
            Object error = '${response.statusCode} ${response.body}';
            throw Exception( exceptionText('spotify_requests.dart', 'addTracks', error, offset: 12) );
          }
        }
      }

      
    }
    catch (e){
      throw Exception( exceptionText('spotify_requests.dart', 'addTracks', e) );
    }
  }//addTracks

  ///Removes the received tracks from the Spotify playlist using its snapshot.
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
      Object error = '${response.statusCode} ${response.body}';
      throw Exception( exceptionText('spotify_requests.dart', 'removeTracks', error, offset: 10) );
    }
    
  }//removeTracks

  ///Makes duplicates of tracks that are marked to have a duplicate.
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
  }//makeDuplicates

  ///Returns a `List` of the unmodified track Ids. Removing the '_modified number' from the end of the id.
  List<String> getUnmodifiedIds(Map<String, TrackModel> selectedTracks){

    List<String> unmodifiedIds = [];

    for (var track in selectedTracks.entries){
      String trueId = getTrackId(track.key);
      unmodifiedIds.add(trueId);
    }

    return unmodifiedIds;
  }//getUnmodifiedIds

  ///Returns the `List` of track ids to be added back to Spotify after removal.
  ///Used for when a track is duplicated.
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
  }//getAddBackIds


  ///Get a users Spotify playlists from a Spotify API request.
  Future<Map<String, PlaylistModel>> getPlaylists(double expiresAt, String accessToken, String userId) async {
    try {
      final getPlaylistsUrl = '$hosted/get-playlists/$expiresAt/$accessToken';

      final response = await http.get(Uri.parse(getPlaylistsUrl));
      if (response.statusCode != 200){
        throw Exception( exceptionText('spotify_requests.dart', 'getPlaylists', response.body, offset: 2) );
      }

      final responseDecode = json.decode(response.body);

      Map<String, dynamic> playlists = responseDecode['data'];

      //Removes all playlists not made by the User
      playlists.removeWhere((key, value) => value['owner'] != userId && key != 'Liked_Songs');

      Map<String, PlaylistModel> newPlaylists = getPlaylistImages(playlists);
      return newPlaylists;
    }
    catch (e){
      throw Exception( exceptionText('spotify_requests.dart', 'getPlaylists', e) );
    }
  }//getPlaylists

  ///Gives each playlist the image size based on current platform
  Map<String, PlaylistModel> getPlaylistImages(Map<String, dynamic> playlists) {

    //The chosen image url
    String imageUrl = '';
    Map<String, PlaylistModel> newPlaylists = {};

    try{
      if (Platform.isAndroid || Platform.isIOS) {
        //Goes through each Playlist and takes the Image size based on current users platform
        for (var item in playlists.entries) {
          //Item is a Playlist and not Liked Songs
          if (item.key != 'Liked_Songs'){
            List<dynamic>? imagesList = item.value['imageUrl']; //The Image list for the current Playlist

            //Playlist has an image
            if (imagesList != null && imagesList.isNotEmpty) {
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
        return newPlaylists;
      } 
      
    }
    catch (e){
      throw Exception( exceptionText('spotify_requests.dart', 'getPlaylistImages', e));
    }
    Object error = "Failed Platform is not supported";
    throw Exception( exceptionText('spotify_requests.dart', 'getPlaylistImages', error) );
  }//getPlaylistImages
 

  ///Makes the Spotify request to refresh the Access Token.
  Future<CallbackModel?> spotRefreshToken(double expiresAt, String refreshToken) async {
    try{
      final refreshUrl = '$hosted/refresh-token/$expiresAt/$refreshToken';

      final response = await http.get(Uri.parse(refreshUrl));
      final responseDecode = json.decode(response.body);

      if (responseDecode['status'] == 'Success') {
        Map<String, dynamic> info = responseDecode['data'];
        CallbackModel callbackModel = CallbackModel(expiresAt: info['expiresAt'], accessToken: info['accessToken'], refreshToken: info['refreshToken']);
        SecureStorage().saveTokens(callbackModel);

        return callbackModel;
      } 
      else {
        return null;
      }
    }
    catch (e){
      throw Exception( exceptionText('spotify_requests.dart', 'spotRefreshToken', e) );
    }
  }//spotRefreshToken

  ///Checks the expiration time of the Access token and returns the updated Token or the received token.
  Future<CallbackModel?> checkRefresh(CallbackModel checkCall) async {
    try{
      if (checkCall.isEmpty){
        return null;
      }
      
      //Get the current time in seconds to be the same as in Python
      double currentTime = DateTime.now().millisecondsSinceEpoch.toDouble() / 1000;

      //Checks if the token is expired and gets a new one if so
      if (currentTime > checkCall.expiresAt) {
        final response = await spotRefreshToken(checkCall.expiresAt, checkCall.refreshToken);

        //The function deals with the status if response has a status token is still good
        //response without status is the new token data
        if (response != null) {
          checkCall = response;
        }
        else{
          return null;
        }
      }

      return checkCall;
    }
    catch (e){
      throw Exception( exceptionText('spotify_requests.dart', 'checkRefresh', e) );
    }
  }//checkRefresh


  ///Make a Spotify request to get the required Spotify User information.
  Future<UserModel?> getUser(double expiresAt, String accessToken ) async{
    final getUserInfo = '$hosted/get-user-info/$expiresAt/$accessToken';
    final response = await http.get(Uri.parse(getUserInfo));
    Map<String, dynamic> userInfo = {};

    if (response.statusCode != 200){
      return null;
    }

    final responseDecoded = json.decode(response.body);
    userInfo = responseDecoded['data'];

    //Converts user from Spotify to Firestore user
    UserModel user = UserModel(username: userInfo['user_name'] , spotifyId: userInfo['id'], uri: userInfo['uri'], expiration: Timestamp.now());
    return user;

  }//getUser

}