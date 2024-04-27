import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:spotify_music_helper/src/utils/dev_global.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/callback_model.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/playlist_model.dart';
import 'package:spotify_music_helper/src/utils/track_model.dart';
import 'package:spotify_music_helper/src/utils/user_model.dart';

const String _fileName = 'spotify_requests.dart';

/// Makes requests to Spotify for a User, refreshing their callback Tokens, editting their Playlists, & editting their Tracks.
/// 
/// Must call the initializeRequests() function before making any functin calls or an error wil be thrown.
class SpotifyRequests extends GetxController{
  /// User and Callback saved on the device.
  late final SecureStorage _secureStorage;

  /// Contains the Spotify [accessToken], [refreshToken], & time it [expiressAt]
  late CallbackModel _callback;

  /// Contains the Users id and other information.
  late UserModel user;

  /// All of a Users Spotify Playlists.
  /// 
  /// Key: Playlist id
  /// 
  /// Value: Playlist model with stored tracks.
  final Map<String , PlaylistModel> _allPlaylists = <String, PlaylistModel>{};

  /// Listenable List of playlists that have finished loading tracks.
  final RxList<String> _loadedIds = <String>[].obs;
  Rx<bool> loading = false.obs;

  /// Listenable List of playlists that failed to load.
  final RxList<String> _errorLoading = <String>[].obs;

  /// The Id for the currently active playlist.
  late String _playlistId;

  /// Tracks for the currently active playlist from playlistId. 
  Map<String, TrackModel> _playlistTracks = <String, TrackModel>{};

  /// Total number of Tracks in a playlist.
  int tracksTotal = 0;

  ///Tracks with an underscore and their duplicate number.
  Map<String, TrackModel> tracksDupes = <String, TrackModel>{};
  int dupesTotal = 0;

  /// Ids of tracks to be added back after removing a track id from PLaylist.
  final List<String> _addBackIds = <String>[];

  /// An unmodified List of Ids to be removed from a playlist.
  List<String> _removeIds = <String>[];
  
  /// The callback url with expiresAt and accessToken for API url calls.
  String _urlExpireAccess = '';

  /// Makes requests to Spotify for a User, refreshing their callback Tokens, editting their Playlists, & editting their Tracks.
  /// 
  /// Must call the initializeRequests() function before making any functin calls or an error wil be thrown.
  SpotifyRequests(){
    try{
      _secureStorage = SecureStorage.instance;
    }
    catch (e){
      _secureStorage = Get.put(SecureStorage());
    }
  }

  /// Listenable List of playlists that have finished loading tracks.
  RxList<String>  get loadedIds{
    return _loadedIds;
  }

  /// Listenable List of playlists that failed to load.
  RxList<String> get errorIds{
    return _errorLoading;
  }

  /// All of a Users Spotify Playlists.
  /// 
  /// Key: Playlist id
  /// 
  /// Value: Playlist model with stored tracks.
  Map<String, PlaylistModel> get allPlaylists{
    return _allPlaylists;
  }

  /// Tracks for the currently active playlist from playlistId.
  Map<String, TrackModel> get playlistTracks{
    return _playlistTracks;
  }

  /// An unmodified List of Ids to be removed from a playlist.
  List<String> get removeIds{
    return _removeIds;
  }

  /// Contains the Spotify [accessToken], [refreshToken], & time it [expiressAt]
  CallbackModel get callback{
    return _callback;
  }

  /// Get the instance of the User Repository.
  static SpotifyRequests get instance => Get.find();


  /// Must initialize the requests with a Spotify [CallbackModel] before calling any other functions.
  /// This sets the callback for requests and gets the User associated with callback tokens.
  Future<void> initializeRequests(CallbackModel newCallback, {UserModel? savedUser}) async{
    _callback = newCallback;
    _urlExpireAccess = '${_callback.expiresAt}/${_callback.accessToken}';
    if(savedUser == null){
      await _getUser();
    }
    else{
      user = savedUser;
    }
  }

  /// Request tracks for a given Spotify paylist.
  /// 
  /// Must initialize Requests before calling function.
  Future<void> requestTracks(String playlistId) async{
    await _checkInitialized();
    loading.value = true;

    _loadedIds.remove(playlistId);
    _errorLoading.remove(playlistId);

    _playlistId = playlistId;
    _playlistTracks = _allPlaylists[_playlistId]!.tracks;

    await _getTracks()
    .onError((_, __) => _errorLoading.add(_playlistId));

    if(!_errorLoading.contains(_playlistId)){
      _loadedIds.add(_playlistId);
    }

    loading.value = false;
  }

  /// Makes multpile calls to Spotify to get all of a users Tracks.
  Future<void> requestAllTracks({bool refresh = false}) async{
    await _checkInitialized();

    loading.value = true;
    if(refresh){
      _loadedIds.clear();
      _errorLoading.clear();
    }

    try{
      for (MapEntry<String, PlaylistModel> playlist in _allPlaylists.entries){
        _playlistId = playlist.key;

        if(refresh || !_loadedIds.contains(_playlistId) || _errorLoading.contains(_playlistId)){
          _playlistId = playlist.key;
          await _getTracks(singleRequest: false)
          .onError((_, __) => _errorLoading.add(_playlistId));

          if(!_errorLoading.contains(_playlistId)){
            _loadedIds.add(_playlistId);
          }
        }
      }
      loading.value = false;
    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'requestAllTracks', error: e);
    }
  }

  /// Add tracks to each playlist in the List.
  ///
  /// Must initialize Requests before calling function.
  Future<void> addTracks(List<String> playlistIds,{Map<String, TrackModel>? tracksMap, List<String>? addIds}) async {
    await _checkInitialized();

    final List<String> tracks;

    if(tracksMap != null){
      tracks = _getUnmodifiedIds(tracksMap);
    }
    else if(addIds != null){
      tracks = addIds;
    }
    else{
      throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'addTracks', error: 'Map or List not given for adding tracks');
    }

    final String addTracksUrl ='$hosted/add-to-playlists/$_urlExpireAccess';

    try{
      List<String> sendAdd = <String>[];
      http.Response response;

      for (int i = 0; i < playlistIds.length; i++){
        sendAdd.add(playlistIds[i]);

        if (((i % 50) == 0 && i != 0) || i == playlistIds.length-1){
          response = await http.post(
            Uri.parse(addTracksUrl),
              headers: <String, String>{
              'Content-Type': 'application/json'
              },
              body: jsonEncode(<String, List<String>>{'trackIds': tracks, 'playlistIds': sendAdd})
          );
          if (response.statusCode != 200) {
            throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'addTracks', error: '${response.statusCode} ${response.body}') ;
          }
        }
      }
    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'addTracks', error: e);
    }
  }

  /// Remove tracks from a Spotify Playlist, and add back tracks that had duplicates that were not removed.
  /// 
  /// Must initialize Requests before calling function.
  Future<void> removeTracks(Map<String, TrackModel> selectedTracks, String playlistId, String snapshotId) async{
    await _checkInitialized();

    _removeIds = _getUnmodifiedIds(selectedTracks);
    _getAddBackIds(selectedTracks);

    final String removeTracksUrl ='$hosted/remove-tracks/$playlistId/$snapshotId/$_urlExpireAccess';

    final http.Response response = await http.post(
      Uri.parse(removeTracksUrl),
        headers: <String, String>{
        'Content-Type': 'application/json'
        },
        body: jsonEncode(<String, List<String>>{'trackIds': _removeIds})
    );

    if (response.statusCode != 200){
      throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'removeTracks', error: '${response.statusCode} ${response.body}', offset: 10);
    }

    // Remove the tracks from the apps Tracks.
    for(String id in _removeIds){
      _allPlaylists[playlistId]!.tracks[id]!.duplicates--;
      
      // Remove the track when it is completely removed from a playlist.
      if (_allPlaylists[playlistId]!.tracks[id]!.duplicates < 0){
        _allPlaylists[playlistId]!.tracks.remove(id);
      }
    }

    if(_addBackIds.isNotEmpty){
      await addTracks(<String>[playlistId], addIds: _addBackIds);
      _addBackIds.clear();
    }
    
  }//removeTracks


  /// Get a users Spotify playlists from a Spotify API request.
  /// 
  /// Must initialize Requests before calling function.
  Future<void> requestPlaylists({bool refresh = false}) async {
    await _checkInitialized();
    try {
      loading.value = true;
  
      final String getPlaylistsUrl = '$hosted/get-playlists/$_urlExpireAccess';

      final http.Response response = await http.get(Uri.parse(getPlaylistsUrl));
      if (response.statusCode != 200){
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'requestPlaylists', error: response.body);
      }

      final dynamic responseDecode = json.decode(response.body);

      Map<String, dynamic> responsePlay = responseDecode['data'];

      //Removes all playlists not made by the User
      responsePlay.removeWhere((String key, dynamic value) => value['owner'] != user.spotifyId && key != 'Liked_Songs');

      _getPlaylistImages(responsePlay);

      if(refresh){
        requestAllTracks(refresh: refresh);
      }
      else{
        loading.value = false;
      }

    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'requestPlaylists', error: e);
    }
  }


  // Private Functions

  /// Check that the class has been initialized before use.
  Future<void> _checkInitialized() async{
    try{
      _callback.toString();
    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'checkInitialized',  
      error:  'Requests not Initialized. Must call the [initializeRequests] function before calling on other functions.');
    }
    await _checkRefresh();
  }

  /// Checks if the Spotify Token has expired. Updates the Token if its expired or [forceRefresh] is true.
  /// 
  /// Must initialize Requests before calling function.
  Future<void> _checkRefresh({bool forceRefresh = false}) async {
    try{
      if (_callback.isEmpty){
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'checkRefresh', error: 'Callback is Empty.');
      }
      
      //Get the current time in seconds to be the same as in Python
      double currentTime = DateTime.now().millisecondsSinceEpoch.toDouble() / 1000;

      //Checks if the token is expired and gets a new one if so
      if (currentTime > _callback.expiresAt || forceRefresh) {
        await _spotRefreshToken();
        return;
      }
    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'checkRefresh', error: e);
    }
  }

  /// Makes the Spotify request to refresh the Access Token.
  Future<void> _spotRefreshToken() async {
    try{
      final String refreshUrl = '$hosted/refresh-token/${callback.expiresAt}/${callback.refreshToken}';

      final http.Response response = await http.get(Uri.parse(refreshUrl));
      if (response.statusCode != 200){
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'spotRefreshToken',  
        error: response.body);
      }
      final Map<String, dynamic> responseDecode = json.decode(response.body);

      _callback = CallbackModel(expiresAt: responseDecode['data']['expiresAt'], accessToken: responseDecode['data']['accessToken'], refreshToken: responseDecode['data']['refreshToken']);
      _urlExpireAccess = '${_callback.expiresAt}/${_callback.accessToken}';
      await _secureStorage.saveTokens(_callback);
    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'spotRefreshToken', error: e);
    }
  }

  /// Make a Spotify request to get the required Spotify User information.
  Future<void> _getUser() async{

    final String getUserInfo = '$hosted/get-user-info/$_urlExpireAccess';
    final http.Response response = await http.get(Uri.parse(getUserInfo));

    if (response.statusCode != 200){
      throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'getUser', error: 'Failed to get Spotify User: ${response.body}');
    }

    final dynamic responseDecoded = json.decode(response.body);
    Map<String, dynamic> userInfo = responseDecoded['data'];

    //Converts user from Spotify to Firestore user
    user = UserModel(username: userInfo['user_name'] , spotifyId: userInfo['id'], uri: userInfo['uri'], expiration: Timestamp.now());
  }//getUser


  /// Gives each playlist the image size based on current platform.
  void _getPlaylistImages(Map<String, dynamic> playlists) {
    _allPlaylists.clear();

    try{
      //The chosen image url
      String imageUrl = '';

      if (Platform.isAndroid || Platform.isIOS) {
        //Goes through each Playlist and takes the Image size based on current users platform
        for (MapEntry<String, dynamic> item in playlists.entries) {
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

          _allPlaylists[newPlaylist.id] = newPlaylist;
        }
      } 
      
    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'getPlaylistImages', error:e);
    }
  }


  /// Get the total number of tracks in a playlist.
  Future<void> _getTracksTotal() async{
    try{
  
      final String getTotalUrl = '$hosted/get-tracks-total/$_playlistId/$_urlExpireAccess';
      final http.Response response = await http.get(Uri.parse(getTotalUrl));

      if (response.statusCode != 200){
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'getTracksTotal',  error:response.body);
      }
      final responseDecoded = json.decode(response.body);

      tracksTotal = responseDecoded['totalTracks'];
    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'getTracksTotal',  error: e);
    }
  }//getTracksTotal

  /// Get the the tracks in a playlist.
  Future<void> _getTracks({bool singleRequest = true}) async {
    try{
      await _getTracksTotal();

      Map<String, dynamic> checkTracks = <String, dynamic>{};
      Map<String, dynamic> receivedTracks = <String, dynamic>{};

      //Gets Tracks 50 at a time because of Spotify's limit
      for (int offset = 0; offset < tracksTotal; offset +=50){
        final String getTracksUrl ='$hosted/get-tracks/$_playlistId/$_urlExpireAccess/$offset';
        final http.Response response = await http.get(Uri.parse(getTracksUrl));

        if (response.statusCode != 200){
          throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'getTracks',  error: response.body);
        }

        final Map<String,dynamic>  responseDecoded = json.decode(response.body);
        checkTracks.addAll(responseDecoded['data']);

        //Adds to the duplicate values if a track has duplicates.
        if (_playlistId != 'Liked_Songs'){
          String id;
          for (MapEntry<String, dynamic> track in checkTracks.entries){
            id = track.key;

            //Add a duplicate to an existing track.
            if (receivedTracks.containsKey(id)){
              receivedTracks.update(id, (dynamic value)  {
                value['duplicates']++;
                return value;
              });
            }
            //Add a new track to the map.
            else{
              receivedTracks.putIfAbsent(id, () => track.value);
            }
          }

          //Clears temp tracks map for next received tracks
          checkTracks.clear();
        }
    
      }

      _getTrackImages(receivedTracks);
      //Returns a PLaylist's tracks and checks if they are in liked.
      if (_playlistId != 'Liked_Songs'){
        await _checkLiked();

        if(singleRequest) _makeDuplicates();
      }
      _allPlaylists[_playlistId]!.tracks = _playlistTracks;
      _loadedIds.addIf(!_loadedIds.contains(_playlistId), _playlistId);
    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'getTracks',  error: e);
    }
    
  }

  /// Get the medium sized image for the track or the smallest sized image when there is only two extremes.
  void _getTrackImages(Map<String, dynamic> responseTracks) {
    _playlistTracks.clear();

    try{
      //The chosen image url
      String imageUrl = '';

      if (Platform.isAndroid || Platform.isIOS) {
        //Goes through each Playlist {name '', ID '', Link '', Images [{}]} and takes the Images
        for (MapEntry<String, dynamic> item in responseTracks.entries) {
          List<dynamic> imagesList = item.value['imageUrl']; //The Image list for the current Playlist
          int middleIndex = 0; //position of the smallest image in the list

          // Get middle index by usiing truncating division to round the result down to get an integer.
          if (imagesList.length > 2) {
            middleIndex = imagesList.length ~/ 2;
          }

          imageUrl = item.value['imageUrl'][middleIndex]['url'];

          _playlistTracks[item.key] = TrackModel(
            id: item.key, 
            imageUrl: imageUrl, 
            artists: item.value['artists'], 
            title: item.value['title'], 
            duplicates: item.value['duplicates'],
            liked: item.value['liked'],
            album: item.value['album']
          );
        }
      } 
    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'getTrackImages',  error: e);
    }
  }

  /// Check if a Track is in the Liked Songs playlist.
  Future<void> _checkLiked() async{
    List<String> trackIds = <String>[];
    List<bool> boolList = <bool>[];

    List<String> sendingIds = <String>[];
    MapEntry<String, dynamic> track;
    
    final String checkUrl = '$hosted/check-liked/$_urlExpireAccess';

    try{
      for (int i = 0; i < _playlistTracks.length; i++){
        track = _playlistTracks.entries.elementAt(i);
        trackIds.add(track.key);
        sendingIds.add(track.key);
        
          if ( (i % 50) == 0 || i == _playlistTracks.length-1){
            //Check the Ids of up to 50 tracks
            final http.Response response = await http.post(Uri.parse(checkUrl),
              headers: <String, String>{
                'Content-Type': 'application/json'
              },
              body: jsonEncode(<String, List<String>>{'trackIds': sendingIds})
            );

            //Not able to receive the checked result from Spotify
            if (response.statusCode != 200){
              throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'checkLiked',  error:response.body);
            }

            final Map<String, dynamic> responseDecoded = jsonDecode(response.body);
            boolList.addAll(responseDecoded['boolArray']);
            sendingIds.clear();
          }
      }

      MapEntry<String, TrackModel> currTrack;
      
      for (int i = 0; i < _playlistTracks.length; i++){
        currTrack = _playlistTracks.entries.elementAt(i);

        if (boolList[i]){
          //Updates each Track in the Map of tracks.
          _playlistTracks.update(currTrack.key, (TrackModel value) {
            value.liked = true; 
            return value;
          });
        }
        
      }
    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'checkLiked',  error:e);
    }
  }

  /// Make duplicates of tracks that have duplicates.
  void _makeDuplicates(){
    // Reset the duplicates track to be reset
    tracksDupes.clear();

    int duplicates;
    String dupeId;

    for (MapEntry<String, TrackModel> track in _playlistTracks.entries){
      duplicates = track.value.duplicates;

      //Make duplicates of a track with duplicates.
      if (duplicates > 0){
        for (int i = 0; i <= duplicates; i++){
          dupeId = i == 0
          ? track.key
          : '${track.key}_$i';

          tracksDupes.addAll(<String, TrackModel>{dupeId: track.value});
        }
      }
      else{
        tracksDupes.addAll(<String, TrackModel>{track.key: track.value});
      }
    }

    dupesTotal = tracksDupes.length;
  }

  /// Get the track ids to add back to Spotify.
  void _getAddBackIds(Map<String, TrackModel> selectedTracks){
    _addBackIds.clear();

    /// Map of tracks with their unmodified Ids and tracks stored as TrackModels
    Map<String, TrackModel> selectedNoDupes = <String, TrackModel>{};

    /// List of Ids to be removed
    List<String> removeIds = _getUnmodifiedIds(selectedTracks);

    for(MapEntry<String, TrackModel> track in selectedTracks.entries){
      String trueId = getTrackId(track.key);

      selectedNoDupes.putIfAbsent(trueId, () => track.value);
    }

    // Dupes is 0 if its only one track
    // First item in a list is at location 0
    removeIds.sort();
    for (MapEntry<String, TrackModel> track in selectedNoDupes.entries){
      int dupes = track.value.duplicates;

      // Gets location of element in sorted list
      final int removeTotal = removeIds.lastIndexOf(track.key);
      final int removeStart = removeIds.indexOf(track.key);

      //Gets the difference between the deleted tracks and its duplicates
      int diff = dupes - removeTotal;

      //There is no difference and you are deleting them all
      if (diff > 0){
        for (int i = 0; i < diff; i++){
          _addBackIds.add(track.key);
        }
      }
      //Removes the tracks that have been checked
      removeIds.removeRange(removeStart, removeTotal+1);
    }

  }//getAddBackIds

  /// Returns a List of the unmodified track Ids.
  List<String> _getUnmodifiedIds(Map<String, TrackModel> modifiedTracks){

    List<String> unmodifiedIds = <String>[];

    for (MapEntry<String, TrackModel> track in modifiedTracks.entries){
      String trueId = getTrackId(track.key);
      unmodifiedIds.addIf(!unmodifiedIds.contains(trueId), trueId);
    }

    return unmodifiedIds;
  }

}