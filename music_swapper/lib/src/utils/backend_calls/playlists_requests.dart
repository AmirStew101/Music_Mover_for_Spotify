import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:spotify_music_helper/src/utils/dev_global.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';

class PlaylistsRequests{

  Future<Map<String, PlaylistModel>> getPlaylists(double expiresAt, String accessToken, String userId) async {
    try {
      final getPlaylistsUrl = '$hosted/get-playlists/$expiresAt/$accessToken';

      final response = await http.get(Uri.parse(getPlaylistsUrl));
      if (response.statusCode != 200){
        throw Exception('Line ${getCurrentLine(offset: 2)} Failed to get Spotify Playlists: ${response.body}');
      }

      final responseDecode = json.decode(response.body);

      Map<String, dynamic> playlists = responseDecode['data'];

      //Removes all playlists not made by the User
      playlists.removeWhere((key, value) => value['owner'] != userId && key != 'Liked_Songs');

      Map<String, PlaylistModel> newPlaylists = getPlaylistImages(playlists);
      return newPlaylists;
    }
    catch (e){
      throw Exception('Line ${getCurrentLine()} : $e');
    }
  }

  //Gives each playlist the image size based on current platform
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
        return newPlaylists;
      } 
      
    }
    catch (e){
      throw Exception('Line: ${getCurrentLine()} : $e');
    }
    throw Exception("Failed Platform is not supported");
  }

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
      throw Exception('Line: ${getCurrentLine()} : $e');
    }
  }

  //Checks if the Token has expired
  Future<CallbackModel?> checkRefresh(CallbackModel checkCall, bool forceRefresh) async {
    try{
      if (checkCall.isEmpty){
        return null;
      }
      
      //Get the current time in seconds to be the same as in Python
      double currentTime = DateTime.now().millisecondsSinceEpoch.toDouble() / 1000;

      //Checks if the token is expired and gets a new one if so
      if (currentTime > checkCall.expiresAt || forceRefresh) {
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
      throw Exception('playlists_requests.dart line: ${getCurrentLine()} Caught Error: $e');
    }
  }

}