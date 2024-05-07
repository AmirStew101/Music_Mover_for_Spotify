import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:http/http.dart' as http;
import 'package:music_mover/src/utils/class%20models/custom_sort.dart';
import 'package:music_mover/src/utils/dev_global.dart';
import 'package:music_mover/src/utils/exceptions.dart';
import 'package:music_mover/src/utils/backend_calls/storage.dart';
import 'package:music_mover/src/utils/global_classes/global_objects.dart';
import 'package:music_mover/src/utils/globals.dart';
import 'package:music_mover/src/utils/class%20models/callback_model.dart';
import 'package:get/get.dart';
import 'package:music_mover/src/utils/class%20models/playlist_model.dart';
import 'package:music_mover/src/utils/class%20models/track_model.dart';
import 'package:music_mover/src/utils/class%20models/user_model.dart';

const String _fileName = 'spotify_requests.dart';

/// Makes requests to Spotify for a User, refreshing their callback Tokens, editting their Playlists, & editting their Tracks.
/// 
/// Must call the initializeRequests() function before making any functin calls or an error wil be thrown.
class SpotifyRequests extends GetxController{
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Saves and Retreives playlists from cache.
  late final PlaylistsCacheManager _cacheManager;

  /// Contains the Spotify [accessToken], [refreshToken], & time it [expiressAt]
  late CallbackModel _callback;

  /// Contains the Users id and other information.
  UserModel user = UserModel();

  /// All of a Users Spotify Playlists.
  /// 
  /// Key: Playlist id
  /// 
  /// Value: Playlist model with stored tracks.
  final RxList<PlaylistModel> _allPlaylists = <PlaylistModel>[].obs;

  Rx<bool> loading = false.obs;

  final Rx<PlaylistModel> _currentPlaylist = PlaylistModel().obs;

  /// Total number of Tracks in a playlist.
  int _tracksTotal = 0;

  /// Total number of Playlists a user has
  int _playlistsTotal = 0;

  /// List of Tracks to be added back after removing a track id from PLaylist.
  final List<TrackModel> _addBackTracks = [];

  /// A List of unmodified Ids to be removed from a playlist.
  List<String> _removeIds = <String>[];

  /// A List of unmodified Tracks to be added to a playlist.
  List<String> _addIds = <String>[];
  
  /// The callback url with expiresAt and accessToken for API url calls.
  String _urlExpireAccess = '';

  bool isInitialized = false;

  final RefreshTimer _refreshTimer = RefreshTimer();

  /// Get an instance of the User Repository.
  static SpotifyRequests get instance {
    try{
      return Get.find();
    }
    catch (e){
      FirebaseCrashlytics.instance.log('Failed to Get Instance of Spotify Requests');
      return Get.put(SpotifyRequests());
    }
  }

  /// Makes requests to Spotify for a User, refreshing their callback Tokens, editting their Playlists, & editting their Tracks.
  /// 
  /// Must call the initializeRequests() function before making any functin calls or an error wil be thrown.
  SpotifyRequests(){

    try{
      _cacheManager = PlaylistsCacheManager.instance;
    }
    catch (e){
      _cacheManager = Get.put(PlaylistsCacheManager());
    }
  }

  PlaylistModel get currentPlaylist{
    return _currentPlaylist.value;
  }

  set currentPlaylist(PlaylistModel playlist){
    _currentPlaylist.value = playlist;
  }


  bool get playlistsAsc{
    return user.playlistAsc;
  }

  bool get tracksAsc{
    return user.tracksAsc;
  }

  String get tracksSortType{
    return user.tracksSortType;
  }


  set playlistsAsc(bool ascending){
    user.playlistAsc = ascending;
  }

  set tracksAsc(bool ascending){
    user.tracksAsc = ascending;
  }

  set tracksSortType(String sortType){
    user.tracksSortType = sortType;
  }

  /// List of playlists that have finished loading tracks.
  List<String>  get loadedIds{
    List<String> loaded = [];

    for (var element in allPlaylists) {
      loaded.addIf(element.loaded, element.id);
    }
    return loaded;
  }

  List<PlaylistModel> get loadedPlaylists{
    List<PlaylistModel> loaded = [];

    for (var element in allPlaylists) {
      loaded.addIf(element.loaded, element);
    }
    return loaded;
  }

  /// True when all playlists are Loaded and False otherwise.
  bool get allLoaded{
    return _allPlaylists.length == loadedIds.length;
  }


  /// All of a Users Spotify Playlists.
  /// 
  /// Key: Playlist id
  /// 
  /// Value: Playlist model with stored tracks.
  List<PlaylistModel> get allPlaylists{
    return _allPlaylists;
  }

  set allPlaylists(List<PlaylistModel> playlists){
    _allPlaylists.assignAll(playlists);
  }

  /// Update if a playlist in allPlaylists is loaded or not
  void _updateLoaded({required String playlistId, required bool loaded}){
    int index = allPlaylists.indexWhere((_) => _.id == playlistId);
    allPlaylists[index].loaded = loaded;
    if(currentPlaylist.id == playlistId) currentPlaylist.loaded = loaded;
  }

  /// Get the playlist with the associated Id from the List of allPlaylists.
  PlaylistModel getPlaylist(String playlistId){
    return _allPlaylists.firstWhere((_) => _.id == playlistId);
  }

  /// Tracks for the currently active playlist from playlistId.
  List<TrackModel> get playlistTracks{
    return _currentPlaylist.value.tracks;
  }

  /// An unmodified List of Ids to be removed from a playlist.
  List<String> get removeIds{
    return _removeIds;
  }

  /// Contains the Spotify [accessToken], [refreshToken], & time it [expiressAt]
  CallbackModel get callback{
    return _callback;
  }

  /// Check if Refresh button should be Pressed.
  bool shouldRefresh(bool loaded, bool refresh){
    return _refreshTimer.shouldRefresh(loaded, loading.value, refresh);
  }

  void sortPlaylists(){
    _crashlytics.log('Spotify Requests: Sort Playlists');

    // Sorts Playlists in ascending or descending order based on the current sort type.
    _allPlaylists.assignAll(Sort().playlistsListSort(_allPlaylists, ascending: user.playlistAsc));
  }

  List<TrackModel> sortTracks({bool artist = false, bool type = false, bool addedAt = false, bool id = false}){
    _crashlytics.log('Spotify Requests: Sort Tracks');

    if(user.tracksSortType == Sort().addedAt){
      _currentPlaylist.value.tracks.assignAll(Sort().tracksListSort(tracksList: _currentPlaylist.value.tracks, addedAt: true, ascending: user.tracksAsc));
    }
    else if(user.tracksSortType == Sort().artist){
      _currentPlaylist.value.tracks.assignAll(Sort().tracksListSort(tracksList: _currentPlaylist.value.tracks, artist: true, ascending: user.tracksAsc));
    }
    else if(user.tracksSortType == Sort().type){
      _currentPlaylist.value.tracks.assignAll(Sort().tracksListSort(tracksList: _currentPlaylist.value.tracks, type: true, ascending: user.tracksAsc));
    }
    // Default title sort
    else{
      _currentPlaylist.value.tracks.assignAll(Sort().tracksListSort(tracksList: _currentPlaylist.value.tracks, ascending: user.tracksAsc));
    }

    return _currentPlaylist.value.tracks;
  }

  /// Must initialize the requests with a Spotify [CallbackModel] before calling any other functions.
  /// This sets the callback for requests and gets the User associated with callback tokens.
  Future<bool> initializeRequests({CallbackModel? callback, UserModel? savedUser, String? callRequest}) async{
    try{
      _crashlytics.log('Spotify Requests: Initialize Requests');
      loading.value = true;

      if(isInitialized){
        isInitialized = false;
        _allPlaylists.clear();
      }

      if(callRequest != null){
        await _getTokens(callRequest);
      }
      else if (callback != null){
        _callback = callback;
      }
      else{
        return isInitialized;
      }

      _urlExpireAccess = '${_callback.expiresAt}/${_callback.accessToken}';
      
      if(savedUser == null){
        await _getUser();
      }
      else{
        user = savedUser;
      }

      await _cacheManager.getCachedPlaylists();
      
      // Set Payists retreived from cache and add them to the loaded playlists.
      if(_cacheManager.storedPlaylists.isNotEmpty){
        allPlaylists = _cacheManager.storedPlaylists;
      }

      isInitialized = true;
      loading.value = false;
      return isInitialized;
    }
    catch (_){
      isInitialized = false;
      loading.value = false;
      return isInitialized;
    }
  }

  /// Get a users Spotify playlists from a Spotify API request.
  /// 
  /// Must initialize Requests before calling function.
  Future<void> requestPlaylists() async {
    if(loading.value){
      _crashlytics.log('Spotify Requests: Requests Loading');
      return;
    }
    try {
      loading.value = true;

      _crashlytics.log('Spotify Requests: Request Playlists');
      await _checkInitialized();
    
      await _getPlaylistsTotal();

      /// All of a users owned playlists.
      Map<String, dynamic> receivedPlaylists = {};

      for(int offset = 0; offset < _playlistsTotal; offset += 50){
        
        final String getPlaylistsUrl = '$hosted/get-playlists/$offset/$_urlExpireAccess';

        http.Response response = await _retrySpotifyResponse(getPlaylistsUrl);

        if (response.statusCode != 200){
          loading.value = false;
          throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'requestPlaylists', reason: 'Bad Response while requesting PLaylists', error: response.body);
        }

        Map<String, dynamic> responsePlay = jsonDecode(response.body);

        //Removes all playlists not made by the User
        responsePlay.removeWhere((String key, dynamic value) => value['owner'] != user.spotifyId && key != likedSongs);

        receivedPlaylists.addAll(responsePlay);
      }

      _getPlaylistImages(receivedPlaylists);

      await _requestAllTracks();
      loading.value = false;

    }
    on CustomException catch (error){
      loading.value = false;
      throw CustomException(stack: error.stack, fileName: error.fileName, functionName: error.functionName, reason: error.reason, error: error.error);
    }
    catch (error, stack){
      loading.value = false;
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'requestPlaylists', reason: 'Failed to retreive Playlists from Spotify', error: error);
    }
  }

  /// Request tracks for a given Spotify paylist.
  /// 
  /// Must initialize Requests before calling function.
  Future<void> requestTracks(String playlistId) async{
    if(loading.value){
      _crashlytics.log('Spotify Requests: Requests Loading');
      return;
    }

    _crashlytics.log('Spotify Requests: Request Tracks');
    await _checkInitialized();
    
    loading.value = true;
    _updateLoaded(playlistId: playlistId, loaded: false);

    currentPlaylist = getPlaylist(playlistId);

    await _getTracks()
    .onError((_, __) => _updateLoaded(playlistId: playlistId, loaded: false));
    
    currentPlaylist.loaded = true;
    int index = _allPlaylists.indexWhere((_) => _.id == currentPlaylist.id);
    _allPlaylists[index] = currentPlaylist;

    if(currentPlaylist.loaded){
      await _cacheManager.cachePlaylists(allPlaylists)
      .onError((Object? error, StackTrace stack) async => await _crashlytics.recordError(error, stack, reason: 'Failed to cache Playlists'));
    }

    loading.value = false;
  }

  /// Make a SPotify request to Add tracks to each playlist in the List.
  ///
  /// Must initialize Requests before calling function.
  Future<void> addTracks(List<PlaylistModel> playlists, List<TrackModel> tracksList) async {
    if(loading.value){
      _crashlytics.log('Spotify Requests: Requests Loading');
      return;
    }

    try{
      _crashlytics.log('Spotify Requests: Add Tracks');
      await _checkInitialized();

      loading.value = true;

      _addIds = _getUnmodifiedIds(tracksList);

      final String addTracksUrl ='$hosted/add-to-playlists/$_urlExpireAccess';

      List<String> sendAdd = <String>[];
      http.Response response;

      for (int i = 0; i < playlists.length; i++){
        sendAdd.add(playlists[i].id);

        if (((i % 50) == 0 && i != 0) || i == playlists.length-1){
          response = await http.post(
            Uri.parse(addTracksUrl),
              headers: <String, String>{
              'Content-Type': 'application/json'
              },
              body: jsonEncode({'trackIds': _addIds, 'playlistIds': sendAdd})
          );
          if (response.statusCode != 200) {
            loading.value = false;
            throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'addTracks', reason: 'Bad Response while Adding tracks', error: response.body) ;
          }
        }
      }
    }
    on CustomException catch (error){
      loading.value = false;
      throw CustomException(stack: error.stack, fileName: error.fileName, functionName: error.functionName, reason: error.reason, error: error.error);
    }
    catch (error, stack){
      loading.value = false;
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'addTracks', reason: 'Failed to Add Tracks to Playlists', error: error);
    }

    if(_addBackTracks.isEmpty){
      await _addTracksToApp(playlists, tracksList);
    }
    else{
      _addBackTracks.clear();
    }

    loading.value = false;
  }

  /// Remove tracks from a Spotify Playlist, and add back tracks that had duplicates that were not removed.
  /// 
  /// Must initialize Requests before calling function.
  Future<void> removeTracks(List<TrackModel> selectedTracks, String snapshotId) async{
    if(loading.value){
      _crashlytics.log('Spotify Requests: Requests Loading');
      return;
    }

    try{
      _crashlytics.log('Spotify Requests: Remove Tracks');
      await _checkInitialized();

      loading.value = true;
    
      _removeIds = _getUnmodifiedIds(selectedTracks);

      final String removeTracksUrl ='$hosted/remove-tracks/${currentPlaylist.id}/$snapshotId/$_urlExpireAccess';

      final http.Response response = await http.post(
        Uri.parse(removeTracksUrl),
          headers: <String, String>{
          'Content-Type': 'application/json'
          },
          body: jsonEncode({'trackIds': _removeIds})
      );

      if (response.statusCode != 200){
        loading.value = false;
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'removeTracks', reason: 'Bad Response while Removing Tracks', error: response.body);
      }

      await _removeTracksFromApp();

      _getAddBackTracks(selectedTracks);
      if(_addBackTracks.isNotEmpty){
        await addTracks([currentPlaylist], _addBackTracks);
      }
    }
    on CustomException catch (error){
      loading.value = false;
      throw CustomException(stack: error.stack, fileName: error.fileName, functionName: error.functionName, reason: error.reason, error: error.error);
    }
    catch (error, stack){
      loading.value = false;
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'removeTracks', reason: 'Failed to Remove Tracks from Playlist', error: error);
    }
    loading.value = false;
    
  }//removeTracks


  // Private Functions

  /// Check that the class has been initialized before use.
  Future<void> _checkInitialized() async{
    _crashlytics.log('Spotify Requests: Check Initialized');
    try{
      _callback.toString();
      if(!isInitialized){
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'checkInitialized',  reason: 'Requests not Initialized',
        error:  'Must call the [initializeRequests] function before calling on other functions.');
      }
    }
    on CustomException catch (error){
      throw CustomException(stack: error.stack, fileName: error.fileName, functionName: error.functionName, reason: error.reason, error: error.error);
    }
    catch (error, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'checkInitialized',  reason: 'Requests not Initialized',
      error:  'Must call the [initializeRequests] function before calling on other functions.');
    }
    await _checkRefresh();
  }

  /// Gets the Tokens from Spotify by making a call to the API.
  Future<void> _getTokens(String callRequest) async {
    _crashlytics.log('Spotify Requests: Get Tokens');
    final http.Response response = await _retrySpotifyResponse(callRequest);

    if (response.statusCode != 200){
      throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'getTokens', reason: 'Bad Response while getting tokens from Spotify Sign In', error: response.body);
    }

    Map<String, dynamic> responseDecoded = jsonDecode(response.body);

    _callback = CallbackModel(expiresAt: responseDecoded['expiresAt'], accessToken: responseDecoded['accessToken'], refreshToken: responseDecoded['refreshToken']);
    await SecureStorage().saveTokens(_callback);
  }

  /// Checks if the Spotify Token has expired. Updates the Token if its expired or [forceRefresh] is true.
  /// 
  /// Must initialize Requests before calling function.
  Future<void> _checkRefresh({bool forceRefresh = false}) async {
    _crashlytics.log('Spotify Requests: Check Refresh');

    try{
      if (_callback.isEmpty){
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'checkRefresh', error: 'Missing Callback');
      }
      
      //Get the current time in seconds to be the same as in Python
      double currentTime = DateTime.now().millisecondsSinceEpoch.toDouble() / 1000;

      //Checks if the token is expired and gets a new one if so
      if (currentTime > _callback.expiresAt || forceRefresh) {
        await _spotRefreshToken();
        return;
      }
    }
    catch (error, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'checkRefresh', reason: 'Failed to Check Refresh Token', error: error);
    }
  }

  /// Makes the Spotify request to refresh the Access Token. Makes the call whether the Token has expired.
  Future<void> _spotRefreshToken() async {
    _crashlytics.log('Spotify Requests: Get Refresh Token');

    try{
      final String refreshUrl = '$hosted/refresh-token/${callback.expiresAt}/${callback.refreshToken}';

      final http.Response response = await _retrySpotifyResponse(refreshUrl);
      if (response.statusCode != 200){
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'spotRefreshToken', reason: 'Bad Status Code when Refreshing Token', error: response.body);
      }

      final Map<String, dynamic> responseDecode = json.decode(response.body);

      _callback = CallbackModel(expiresAt: responseDecode['expiresAt'], accessToken: responseDecode['accessToken'], refreshToken: responseDecode['refreshToken']);
      _urlExpireAccess = '${_callback.expiresAt}/${_callback.accessToken}';

      await SecureStorage().saveTokens(_callback);
    }
    catch (error, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'spotRefreshToken', reason: 'Failed to Ger ne Refresh Token', error: error);
    }
  }

/// Retries a Response given a url. Max Retries and a good Status code can be set.
/// The good status code will be compared to the responses status code and if Response status code is not equal then it will return response.
Future<http.Response> _retrySpotifyResponse(String customUrl, {int maxRetries = 3, int goodStatusCode = 200}) async{
  int retries = 0;
  http.Response newResponse = await http.get(Uri.parse(customUrl));

  while (newResponse.statusCode != goodStatusCode && retries < maxRetries){
    // Refresh Tokens if Response failed because it needed to Refresh.
    if(newResponse.body.contains('Need refresh token')) await _checkRefresh(forceRefresh: true);

    newResponse = await http.get(Uri.parse(customUrl));
    retries++;
  }

  return newResponse;
}

  /// Make a Spotify request to get the required Spotify User information.
  Future<void> _getUser() async{
    _crashlytics.log('Spotify Requests: Get User');
    late Map<String, dynamic> userInfo;

    try{
      final String getUserInfo = '$hosted/get-user-info/$_urlExpireAccess';
      final http.Response response = await _retrySpotifyResponse(getUserInfo);

      if (response.statusCode != 200){
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'getUser', reason: 'Bad Status Code when Retrieving User', error: response.body);
      }
      userInfo = jsonDecode(response.body);
    }
    on CustomException catch (error, stack){
      throw CustomException(stack: stack, error: error.error, reason: error.reason, fileName: error.fileName, functionName: error.functionName);
    }
    catch (error, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'getUser', reason: 'Failed to Retrieve User from Spotify', error: error);
    }

    //Converts user from Spotify to Firestore user
    user = UserModel(spotifyId: userInfo['id'], url: userInfo['url'], subscribe: true);
  }//getUser

  Future<void> _getPlaylistsTotal() async{
    _crashlytics.log('Spotify Requests: Get Playlists Total');

    try{
      final String getTotalUrl = '$hosted/get-playlists-total/$_urlExpireAccess';
      final http.Response response = await _retrySpotifyResponse(getTotalUrl);

      if (response.statusCode != 200){
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'getPlaylistsTotal', reason: 'Bad Status when Getting Playlists Total',  error:response.body);
      }

      _playlistsTotal = jsonDecode(response.body);
    }
    catch (error, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'getPlaylistsTotal', reason: 'Failed to Retrieve Playlists Total',  error: error);
    }
  }

  /// Gives each playlist the image size based on current platform.
  void _getPlaylistImages(Map<String, dynamic> playlists) {
    _crashlytics.log('Spotify Requests: Get Playlist Images');

    try{
      //The chosen image url
      String imageUrl = '';
      List<PlaylistModel> newPlaylists = [];

      if (Platform.isAndroid || Platform.isIOS) {
        //Goes through each Playlist and takes the Image size based on current users platform
        for (MapEntry<String, dynamic> item in playlists.entries) {
          //Item is a Playlist and not Liked Songs
          if (item.key != likedSongs){
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

          // Add playlists to a temp List for comparison
          newPlaylists.add(PlaylistModel(
            title: item.value['title'], 
            id: item.key, 
            link: item.value['link'], 
            imageUrl: imageUrl, 
            snapshotId: item.value['snapshotId']
          ));
        }

        // Remove Playlists that have been deleted on Spotify
        _allPlaylists.removeWhere((PlaylistModel element) => !newPlaylists.contains(element));

        // Add playlists that have been added on Spotify
        for(var newPlay in newPlaylists){
          if(!_allPlaylists.contains(newPlay)){
            _allPlaylists.add(newPlay);
          }
        }
      } 
      
    }
    catch (error, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'getPlaylistImages', reason: 'Failed to edit Playlists in getPlaylistImages', error: error);
    }
  }

  /// Makes multpile calls to Spotify to get all of a users Tracks.
  Future<void> _requestAllTracks({bool refresh = false}) async{

    _crashlytics.log('Spotify Requests: Request All Tracks');
    await _checkInitialized();
    loading.value = true;

    for (PlaylistModel playlist in _allPlaylists){
      currentPlaylist = playlist;
      await _getTracksTotal();

      if(refresh || !currentPlaylist.loaded || currentPlaylist.tracks.length < _tracksTotal){
        _updateLoaded(playlistId: currentPlaylist.id, loaded: true);

        await _getTracks(singleRequest: false)
        .onError((_, __) async{
          _crashlytics.recordError(_, __, reason: 'Failed to load Tracks adding to Error Ids');
          _updateLoaded(playlistId: currentPlaylist.id, loaded: false);
        });
      }
    }

    sortPlaylists();

    await _cacheManager.cachePlaylists(allPlaylists.where((element) => element.loaded).toList())
    .onError((Object? error, StackTrace stack) async =>
    await _crashlytics.recordError(error, stack, reason: 'Failed to cache Playlists during requestAllTracks()'));

  }

  /// Get the total number of tracks in a playlist.
  Future<void> _getTracksTotal() async{
    _crashlytics.log('Spotify Requests: Get Tracks Total');

    try{
      final String getTotalUrl = '$hosted/get-tracks-total/${currentPlaylist.id}/$_urlExpireAccess';
      final http.Response response = await _retrySpotifyResponse(getTotalUrl);

      if (response.statusCode != 200){
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'getTracksTotal', reason: 'Bad Response when Getting Tracks Total',  error:response.body);
      }

      _tracksTotal = jsonDecode(response.body);
    }
    catch (error, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'getTracksTotal', reason: 'Failed to Retrieve Tracks Total',  error: error);
    }
  }//getTracksTotal

  /// Get the the tracks in a playlist.
  Future<void> _getTracks({bool singleRequest = true}) async {
    try{
      // Limit the logs when requesting all tracks to not have uneccesarry repeats.
      if(singleRequest){
        _crashlytics.log('Spotify Requests: Get Tracks for a Playlist');
        // Called during request all tracks before this function call.
        await _getTracksTotal();
      }

      Map<String, dynamic> receivedTracks = <String, dynamic>{};

      //Gets Tracks 50 at a time because of Spotify's limit
      for (int offset = 0; offset < _tracksTotal; offset +=50){
        Map<String, dynamic> checkTracks = <String, dynamic>{};

        final String getTracksUrl ='$hosted/get-tracks/${currentPlaylist.id}/$offset/$_urlExpireAccess';
        http.Response response = await _retrySpotifyResponse(getTracksUrl);

        if (response.statusCode != 200){
          throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'getTracks', reason: 'Bad Response while Getting Tracks from Spotify',  error: response.body);
        }

        checkTracks.addAll(jsonDecode(response.body));

        //Adds to the duplicate values if a track has duplicates.
        if (currentPlaylist.id != 'Liked_Songs'){
          String id;
          for (MapEntry<String, dynamic> track in checkTracks.entries){
            id = track.key;

            //Add a duplicate to an existing track, or add a new Track.
            receivedTracks.update(id, (dynamic value)  {
              value['duplicates']++;
              return value;
            },
            ifAbsent: () => receivedTracks.putIfAbsent(id, () => track.value));
          }
        }
        else{
          receivedTracks.addAll(checkTracks);
        }
      }

      _getTrackImages(receivedTracks);

      // Checks if tracks are in the Liked Songs playlist.
      if (currentPlaylist.id != 'Liked_Songs'){
        await _checkLiked()
        .onError((error, stack) => _crashlytics.recordError(error, stack, reason: 'Failed to Check Liked songs'));
      }
    }
    catch (error, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'getTracks', reason: 'Failed to Get Tracks',  error: error);
    }
    
  }

  /// Get the medium sized image for the track or the smallest sized image when there is only two extremes.
  /// 
  /// Adds each track to '_playlistsTracks' variable as a new track.
  void _getTrackImages(Map<String, dynamic> responseTracks) {
    _crashlytics.log('Spotify Requests: Get Track Images');
    if(responseTracks.isEmpty) return;

    try{
      //The chosen image url
      String imageUrl = '';

      currentPlaylist.tracks.clear();

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

          currentPlaylist.addTrack(TrackModel(
            id: item.key, 
            imageUrl: imageUrl, 
            artists: item.value['artists'], 
            title: item.value['title'], 
            duplicates: item.value['duplicates'],
            liked: item.value['liked'],
            album: item.value['album'],
            addedAt: DateTime.tryParse(item.value['addedAt']),
            type: item.value['type'],
          ));
        }
      }
    }
    catch (error, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'getTrackImages', reason: 'Failed to edit Tracks images',  error: error);
    }
  }

  /// Check if a Track is in the Liked Songs playlist.
  Future<void> _checkLiked() async{
    _crashlytics.log('Spotify Requests: Check Liked');
    if(currentPlaylist.tracks.isEmpty){
      return;
    }

    List<dynamic> boolList = [];
    List<String> sendingIds = [];
    
    final String checkUrl = '$hosted/check-liked/$_urlExpireAccess';

    try{
      for (int i = 0; i < currentPlaylist.tracks.length; i++){
        sendingIds.add(currentPlaylist.tracks[i].id);
        
          if ( (i % 50) == 0 || i == currentPlaylist.tracks.length-1){
            //Check the Ids of up to 50 tracks
            final http.Response response = await http.post(Uri.parse(checkUrl),
              headers: <String, String>{
                'Content-Type': 'application/json'
              },
              body: jsonEncode(<String, List<String>>{'trackIds': sendingIds})
            );

            //Not able to receive the checked result from Spotify
            if (response.statusCode != 200){
              throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'checkLiked', reason: 'Bad Response while Checking if Liked',  error:response.body);
            }

            boolList.addAll(jsonDecode(response.body));
            sendingIds = [];
          }
      }
      
      for (int i = 0; i < currentPlaylist.tracks.length; i++){

        if (boolList[i]){
          //Updates each Track in the Map of tracks.
          currentPlaylist.tracks[i] = currentPlaylist.tracks[i].copyWith(liked: true);
        }
        
      }
    }
    on CustomException catch (error){
      throw CustomException(stack: error.stack, error: error.error, reason: error.reason, fileName: error.fileName, functionName: error.functionName);
    }
    catch (error, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'checkLiked', reason: 'Failed checking if a Song is Liked',  error: error);
    }
  }

  /// Get the track ids to add back to Spotify.
  void _getAddBackTracks(List<TrackModel> selectedTracks){
    _crashlytics.log('Spotify Requests: Get Add Back Tracks');

    _addBackTracks.clear();

    selectedTracks.assignAll(Sort().tracksListSort(tracksList: selectedTracks, id: true));

    // Location of a different unique track id in a sorted list.
    // ex [123,123,343,434] // addStart = 0 then the next unique id addStart = 2
    int addStart = 0;

    for(int ii = 0; ii < selectedTracks.length; ii++){
      
      // Check track when reaching a new unique Track id.
      if(ii == addStart){

        int lastIndex = selectedTracks.lastIndexWhere((_) => _.id == selectedTracks[ii].id);
        int diff = selectedTracks[ii].duplicates - (lastIndex - addStart);

        // Check how many instances of the track are being deleted.
        if(diff > 0){
          for(int jj = 0; jj < diff; jj++){
            _addBackTracks.add(selectedTracks[ii]);
          }
        }
        addStart = lastIndex+1;
      }
    }

  }// getAddBackIds

  /// Returns a List of the unmodified track Ids.
  List<String> _getUnmodifiedIds(List<TrackModel> tracksList){
    _crashlytics.log('Spotify Requests: Get Unmodified Ids');

    List<String> unmodifiedIds = <String>[];
    
    for(TrackModel track in tracksList){
      unmodifiedIds.add(track.id);
    }

    return unmodifiedIds;
  }

  /// Add tracks to multiple playlists in the app.
  Future<void> _addTracksToApp(List<PlaylistModel> playlists, List<TrackModel> tracksList) async{
    _crashlytics.log('Spotify Requests: Add Tracks to App');

    bool addingLiked = playlists.any((_) => _.id == likedSongs);

    // Add tracks to each Playlist stored in the app.
    for(PlaylistModel playlist in playlists){
      for(TrackModel tracksM in tracksList){

        if(playlist.title == likedSongs){
          // Add track to liked Songs if it doesn't exist. Liked Songs can't have duplicates.
          if(!playlist.tracks.contains(tracksM)) playlist.addTrack(tracksM);
        }
        else{
          if(addingLiked){
            playlist.addTrack(tracksM.copyWith(liked: true));
          }
          else{
            playlist.addTrack(tracksM);
          }
          
        }
      }
      int index = _allPlaylists.indexWhere((_) => _.id == playlist.id);
      _allPlaylists[index] = playlist;

      if(_currentPlaylist.value == playlist){
        currentPlaylist.tracks = playlist.tracks;
      }
    }

    await _cacheManager.cachePlaylists(allPlaylists)
    .onError((Object? error, StackTrace stack) async => await _crashlytics.recordError(error, stack, reason: 'Failed to cache Playlists'));
  }

  /// Remove tracks from a playlist in the app.
  Future<void> _removeTracksFromApp() async{
    _crashlytics.log('Spotify Requests: Remove Tracks from App');

    // Remove the tracks from the apps Tracks.
    for(String trackId in _removeIds){
      int index = currentPlaylist.tracks.indexWhere((_) => _.id == trackId);
      currentPlaylist.tracks[index].duplicates--;
      
      // Remove the track when it is completely removed from a playlist.
      if (currentPlaylist.tracks[index].duplicates < 0){
        currentPlaylist.tracks.remove(currentPlaylist.tracks[index]);
      }
    }

    int index = _allPlaylists.indexWhere((_) => _.id == currentPlaylist.id);
    _allPlaylists[index] = currentPlaylist;
    _removeIds = [];

    await _cacheManager.cachePlaylists(allPlaylists)
    .onError((Object? error, StackTrace stack) async => await _crashlytics.recordError(error, stack, reason: 'Failed to cache Playlists'));
  }

}