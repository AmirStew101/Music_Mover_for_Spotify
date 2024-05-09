import 'dart:convert';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:http/http.dart' as http;
import 'package:music_mover/main.dart';
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
  UserModel _user = UserModel();

  /// All of a Users Spotify Playlists.
  /// 
  /// Key: Playlist id
  /// 
  /// Value: Playlist model with stored tracks.
  final RxList<PlaylistModel> _allPlaylists = <PlaylistModel>[].obs;

  bool loading = false;

  final Rx<PlaylistModel> _currentPlaylist = PlaylistModel().obs;
  List<TrackModel> _trackDuplicates = [];

  /// Playlist that is currently being editted
  final Rx<PlaylistModel> _edittingPlaylist = PlaylistModel().obs;

  /// Total number of Tracks in a playlist.
  int _tracksTotal = 0;

  /// Total number of Playlists a user has
  int _playlistsTotal = 0;

  /// List of Tracks to be added back after removing a track id from PLaylist.
  List<TrackModel> _addBackTracks = [];

  /// A List of unmodified Ids to be removed from a playlist.
  List<String> _removeIds = <String>[];

  /// A List of unmodified Tracks to be added to a playlist.
  List<String> _addIds = <String>[];

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

  PlaylistModel get edittingPlaylist => _edittingPlaylist.value;

  UserModel get user => _user;

  set user(UserModel newUser){
    _user = newUser;
    SecureStorage.instance.saveUser(newUser);
  }

  PlaylistModel get currentPlaylist{
    return _currentPlaylist.value;
  }

  set currentPlaylist(PlaylistModel playlist){
    _currentPlaylist.value = playlist;
    _trackDuplicates = _currentPlaylist.value.makeDuplicates();
  }

  /// Get a List of duplicate tracks
  List<TrackModel> get currentDuplicates {
    if(currentPlaylist.tracks.isEmpty){
      _trackDuplicates = [];
      return [];
    }
    return _trackDuplicates;
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
    _allPlaylists.value = playlists;
  }

  /// Update if a playlist in allPlaylists is loaded or not
  void _updateLoaded({required PlaylistModel playlist, required bool loaded}){
    int index = allPlaylists.indexWhere((_) => _ == playlist);
    allPlaylists[index].loaded = loaded;
    if(currentPlaylist == playlist) currentPlaylist.loaded = loaded;
    if(_edittingPlaylist.value == playlist) _edittingPlaylist.value.loaded = loaded;
  }

  /// Get the playlist with the associated Id from the List of allPlaylists.
  PlaylistModel getPlaylist(PlaylistModel playlist){
    return _allPlaylists.firstWhere((_) => _ == playlist);
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
    return _refreshTimer.shouldRefresh(loaded, loading, refresh);
  }

  void sortPlaylists(){
    _crashlytics.log('Spotify Requests: Sort Playlists');

    // Sorts Playlists in ascending or descending order based on the current sort type.
    _allPlaylists.value = Sort().playlistsListSort(_allPlaylists, ascending: user.playlistAsc);
  }

  List<TrackModel> sortTracks({bool artist = false, bool type = false, bool addedAt = false, bool id = false}){
    _crashlytics.log('Spotify Requests: Sort Tracks');

    if(addedAt || user.tracksSortType == Sort().addedAt){
      _currentPlaylist.value.tracks = Sort().tracksListSort(tracksList: _currentPlaylist.value.tracks, addedAt: addedAt, ascending: user.tracksAsc);
      _trackDuplicates = Sort().tracksListSort(tracksList: _trackDuplicates, addedAt: addedAt, ascending: user.tracksAsc);
    }
    else if(artist || user.tracksSortType == Sort().artist){
      _currentPlaylist.value.tracks = Sort().tracksListSort(tracksList: _currentPlaylist.value.tracks, artist: artist, ascending: user.tracksAsc);
      _trackDuplicates = Sort().tracksListSort(tracksList: _trackDuplicates, artist: artist, ascending: user.tracksAsc);
    }
    else if(type || user.tracksSortType == Sort().type){
      _currentPlaylist.value.tracks = Sort().tracksListSort(tracksList: _currentPlaylist.value.tracks, type: type, ascending: user.tracksAsc);
      _trackDuplicates = Sort().tracksListSort(tracksList: _trackDuplicates, type: type, ascending: user.tracksAsc);
    }
    // Default title sort
    else{
      _currentPlaylist.value.tracks = Sort().tracksListSort(tracksList: _currentPlaylist.value.tracks, ascending: user.tracksAsc);
      _trackDuplicates = Sort().tracksListSort(tracksList: _trackDuplicates, ascending: user.tracksAsc);
    }

    return _currentPlaylist.value.tracks;
  }

  /// Must initialize the requests with a Spotify [CallbackModel] before calling any other functions.
  /// This sets the callback for requests and gets the User associated with callback tokens.
  Future<bool> initializeRequests({required CallbackModel callback, UserModel? savedUser}) async{
    try{
      _crashlytics.log('Spotify Requests: Initialize Requests');
      loading = true;

      if(isInitialized){
        isInitialized = false;
        _allPlaylists.value = [];
      }

      _callback = callback;
      
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
      loading = false;
      return isInitialized;
    }
    catch (_){
      isInitialized = false;
      loading = false;
      return isInitialized;
    }
  }

  /// Get a users Spotify playlists from a Spotify API request.
  /// 
  /// Must initialize Requests before calling function.
  Future<bool> requestPlaylists() async {
    if(loading){
      _crashlytics.log('Spotify Requests: Requests Loading');
      return false;
    }
    try {
      loading = true;

      _crashlytics.log('Spotify Requests: Request Playlists');
      _checkInitialized();
    
      await _getPlaylistsTotal();

      /// All of a users owned playlists.
      Map<String, dynamic> receivedPlaylists = {};

      for(int offset = 0; offset < _playlistsTotal; offset += 50){
        
        final String getPlaylistsUrl = '$hosted/get-playlists/$offset';

        http.Response response = await _retrySpotifyResponse(getPlaylistsUrl);

        if (response.statusCode != 200){
          loading = false;
          throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'requestPlaylists', reason: 'Bad Response while requesting Playlists', error: response.body);
        }

        Map<String, dynamic> responsePlay = jsonDecode(response.body);

        //Removes all playlists not made by the User
        responsePlay.removeWhere((String key, dynamic value) => value['owner'] != user.spotifyId && key != likedSongs);

        receivedPlaylists.addAll(responsePlay);
      }

      _getPlaylistImages(receivedPlaylists);

      await _requestAllTracks();
      loading = false;
      return true;

    }
    on CustomException catch (error, stack){
      loading = false;
      _crashlytics.recordError(error.error, stack, reason: error.reason);
      return false;
    }
    catch (error, stack){
      loading = false;
      _crashlytics.recordError(error, stack, reason: 'Failed to retreive Playlists from Spotify');
      return false;
    }
  }

  /// Request tracks for the current playlist Spotify paylist.
  /// 
  /// Must initialize Requests before calling function.
  Future<bool> requestTracks(PlaylistModel playlist) async{
    loading = true;

    try{
      _crashlytics.log('Spotify Requests: Request Tracks');
      _checkInitialized();
      
      _updateLoaded(playlist: playlist, loaded: false);

      _edittingPlaylist.value = getPlaylist(playlist);

      List<TrackModel>? updatedTracks = await _getTracks();

      if(updatedTracks == null){
        _updateLoaded(playlist: playlist, loaded: false);
      }
      else if(playlist == currentPlaylist){
        currentPlaylist.tracks = updatedTracks;
        _trackDuplicates = currentPlaylist.makeDuplicates();
        currentPlaylist.loaded = true;
      }
      
      
      int index = _allPlaylists.indexWhere((_) => _.id == _edittingPlaylist.value.id);
      _allPlaylists[index] = _edittingPlaylist.value;

      if(_edittingPlaylist.value.loaded){
        await _cachePlaylists();
      }
    }
    on CustomException catch(error, stack){
      loading = false;
      _crashlytics.recordError(error.error, stack, reason: error.reason);
      return false;
    }

    loading = false;
    return true;
  }

  /// Make a Spotify request to Add tracks to each playlist in the List.
  ///
  /// Must initialize Requests before calling function.
  Future<bool> addTracks(List<PlaylistModel> playlists, List<TrackModel> tracksList) async {
    if(loading && _addBackTracks.isEmpty){
      _crashlytics.log('Spotify Requests: Requests Loading');
      return false;
    }
    loading = true;

    try{
      _crashlytics.log('Spotify Requests: Add Tracks');
      _checkInitialized();

      _addIds = _getIdsList(tracksList);

      final String addTracksUrl ='$hosted/add-to-playlists/${_callback.accessToken}';

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

          // Retry adding tracks before accepting failure
          int retries = 0;
          while (response.statusCode != 200 && retries < 3){
            if(_refreshText(response.body)) await _checkRefresh(forceRefresh: true);

            retries++;
            response = await http.post(
              Uri.parse(addTracksUrl),
                headers: <String, String>{
                'Content-Type': 'application/json'
                },
                body: jsonEncode({'trackIds': _addIds, 'playlistIds': sendAdd})
            );
          }
          if (response.statusCode != 200) {
            loading = false;
            _crashlytics.recordError(response.body, StackTrace.current, reason: 'Bad Response while Adding tracks');
            return false;
          }
        }
      }

      if(_addBackTracks.isEmpty){
        _addTracksToApp(playlists, tracksList);
      }
      else{
        _addBackTracks = [];
      }

      loading = false;
      return true;

    }
    on CustomException catch (error, stack){
      loading = false;
      _crashlytics.recordError(error, stack, reason: error.reason);
      return false;
    }
    catch (error, stack){
      loading = false;
      _crashlytics.recordError(error, stack, reason: 'Failed to Add Tracks to Playlists');
      return false;
    }
  }

  /// Remove tracks from the current Spotify Playlist, and add back tracks that had duplicates that were not removed.
  /// 
  /// Must initialize Requests before calling function.
  Future<bool> removeTracks(List<TrackModel> selectedTracks) async{
    if(loading){
      _crashlytics.log('Spotify Requests: Requests Loading');
      return false;
    }

    try{
      _crashlytics.log('Spotify Requests: Remove Tracks');
      _checkInitialized();

      loading = true;
    
      _removeIds = _getIdsList(selectedTracks);

      final String removeTracksUrl ='$hosted/remove-tracks/${currentPlaylist.id}/${_callback.accessToken}';

      http.Response response = await http.post(
        Uri.parse(removeTracksUrl),
          headers: <String, String>{
          'Content-Type': 'application/json'
          },
          body: jsonEncode({'trackIds': _removeIds, 'snapshotId': currentPlaylist.snapshotId})
      );

      // Retry the call 3 times before recording error
      int retries = 0;
      while (response.statusCode != 200 && retries < 3){
        if(_refreshText(response.body)) await _checkRefresh(forceRefresh: true);

        retries++;
        response = await http.post(
          Uri.parse(removeTracksUrl),
            headers: <String, String>{
            'Content-Type': 'application/json'
            },
            body: jsonEncode({'trackIds': _removeIds, 'snapshotId': currentPlaylist.snapshotId})
        );
      }

      if (response.statusCode != 200){
        loading = false;
        _crashlytics.recordError(response.body, StackTrace.current, reason: 'Bad Response while Removing Tracks');
        return false;
      }

      _getAddBackTracks(selectedTracks);
      if(_addBackTracks.isNotEmpty){
        await addTracks([currentPlaylist], _addBackTracks);
      }

      _removeTracksFromApp(selectedTracks);

      _removeIds = [];
    }
    on CustomException catch (error, stack){
      loading = false;
      _crashlytics.recordError(error, stack, reason: error.reason);
      return false;
    }
    catch (error, stack){
      loading = false;
      _crashlytics.recordError(error, stack, reason: 'Failed to Remove Tracks from Playlist');
      return false;
    }

    // Successful Tracks Removal
    loading = false;
    return true;
    
  }//removeTracks


  // Private Functions

  /// Check that the class has been initialized before use.
  void _checkInitialized(){
    _crashlytics.log('Spotify Requests: Check Initialized');
    if(!isInitialized){
      throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'checkInitialized',  reason: 'Requests not Initialized',
      error:  'Must call the [initializeRequests] function before calling on other functions.');
    }
  }

  /// Checks if the Spotify Token has expired. Updates the Token if its expired or [forceRefresh] is true.
  /// 
  /// Must initialize Requests before calling function.
  Future<bool> _checkRefresh({bool forceRefresh = false}) async {
    _crashlytics.log('Spotify Requests: Check Refresh');
    try{
      _checkInitialized();

      //Get the current time in seconds to be the same as in Python
      double currentTime = DateTime.now().millisecondsSinceEpoch.toDouble() / 1000;

      //Checks if the token is expired and gets a new one if so
      if (currentTime > _callback.expiresAt || forceRefresh) {
        await _spotRefreshToken();
      }
      return true;
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to Check Refresh Token');
      return false;
    }
  }

  /// Makes the Spotify request to refresh the Access Token. Makes the call whether the Token has expired.
  Future<bool> _spotRefreshToken() async {
    _crashlytics.log('Spotify Requests: Get Refresh Token');

    try{
      final String refreshUrl = '$hosted/refresh-token/${callback.refreshToken}';

      final http.Response response = await http.get(Uri.parse(refreshUrl));

      if (response.statusCode != 200){
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'spotRefreshToken', reason: 'Bad Status Code when Refreshing Token', error: response.body);
      }

      final Map<String, dynamic> responseDecode = json.decode(response.body);

      _callback.updateTokens(expires: responseDecode['expiresAt'], access: responseDecode['accessToken'], refresh: responseDecode['refreshToken']);

      await SecureStorage().saveTokens(_callback);
      return true;
    }
    on CustomException catch (error, stack){
      _crashlytics.recordError(error.error, stack, reason: error.reason);
      return false;
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to Ger ne Refresh Token');
      return false;
    }
  }

  /// Retries a Response given a url. Max Retries and a good Status code can be set.
  /// The good status code will be compared to the responses status code and if Response status code is not equal then it will return response.
  Future<http.Response> _retrySpotifyResponse(String customUrl, {int maxRetries = 3, int goodStatusCode = 200}) async{
    int retries = 0;
    http.Response newResponse = await http.get(Uri.parse('$customUrl/${callback.accessToken}'));

    while (newResponse.statusCode != goodStatusCode && retries < maxRetries){
      // Refresh Tokens if Response failed because it needed to Refresh. 
      if(_refreshText(newResponse.body)) await _checkRefresh(forceRefresh: true);

      newResponse = await http.get(Uri.parse('$customUrl/${callback.accessToken}'));
      retries++;
    }

    return newResponse;
  }

  bool _refreshText(String responseText){
    return responseText.contains('Need refresh token') || responseText.contains('No Expiration time received') || responseText.contains('The access token expired');
  }

  /// Make a Spotify request to get the required Spotify User information.
  Future<bool> _getUser() async{
    _crashlytics.log('Spotify Requests: Get User');
    late Map<String, dynamic> userInfo;

    try{
      const String getUserInfo = '$hosted/get-user-info';
      final http.Response response = await _retrySpotifyResponse(getUserInfo);

      if (response.statusCode != 200){
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'getUser', reason: 'Bad Status Code when Retrieving User', error: response.body);
      }
      userInfo = jsonDecode(response.body);

      //Converts user from Spotify to Firestore user
      user = UserModel(spotifyId: userInfo['id'], url: userInfo['url'], subscribe: true);

      return true;

    }
    on CustomException catch (error, stack){
      _crashlytics.recordError(error.error, stack, reason: error.reason);
      return false;
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to Retrieve User from Spotify');
      return false;
    }
  }//getUser

  Future<bool> _getPlaylistsTotal() async{
    _crashlytics.log('Spotify Requests: Get Playlists Total');

    try{
      const String getTotalUrl = '$hosted/get-playlists-total';
      final http.Response response = await _retrySpotifyResponse(getTotalUrl);

      if (response.statusCode != 200){
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'getPlaylistsTotal', reason: 'Bad Status when Getting Playlists Total',  error:response.body);
      }

      _playlistsTotal = jsonDecode(response.body);
      return true;
    }
    on CustomException catch (error, stack){
      _crashlytics.recordError(error.error, stack, reason: error.reason);
      return false;
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to Retrieve Playlists Total');
      return false;
    }
  }

  /// Gives each playlist the image size based on current platform.
  bool _getPlaylistImages(Map<String, dynamic> playlists) {
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
      return true;
      
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to edit Playlists in getPlaylistImages');
      return false;
    }
  }

  /// Makes multpile calls to Spotify to get all of a users Tracks.
  Future<void> _requestAllTracks() async{

    _crashlytics.log('Spotify Requests: Request All Tracks');
    _checkInitialized();

    for (PlaylistModel playlist in _allPlaylists){
      _edittingPlaylist.value = playlist;

      if(!_edittingPlaylist.value.loaded){

        _updateLoaded(playlist: _edittingPlaylist.value, loaded: true);
        _edittingPlaylist.value.tracks = [];

        if(await _getTracks(singleRequest: false) == null){
          if(MusicMover.instance.isInitialized){
            _crashlytics.recordError('Requsting All Tracks failed to retreive tracks', StackTrace.current, reason: 'Failed to load Tracks; adding to Error Ids');
            _updateLoaded(playlist: _edittingPlaylist.value, loaded: false);
          }
        }
        
      }
    }

    sortPlaylists();

    await _cachePlaylists(allPlaylists.where((element) => element.loaded).toList());
  }

  /// Get the total number of tracks in a playlist.
  Future<bool> _getTracksTotal() async{
    _crashlytics.log('Spotify Requests: Get Tracks Total');

    try{
      final String getTotalUrl = '$hosted/get-tracks-total/${_edittingPlaylist.value.id}';
      final http.Response response = await _retrySpotifyResponse(getTotalUrl);

      if (response.statusCode != 200){
        _crashlytics.recordError(response.body, StackTrace.current, reason: 'Bad Response when Getting Tracks Total');
        return false;
      }

      _tracksTotal = jsonDecode(response.body);
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to Retrieve Tracks Total');
      return false;
    }

    return true;
  }//getTracksTotal

  /// Get the the tracks in a playlist.
  Future<List<TrackModel>?> _getTracks({bool singleRequest = true}) async {
    try{
      // Limit the logs when requesting all tracks to not have uneccesarry repeats.
      if(singleRequest){
        _crashlytics.log('Spotify Requests: Get Tracks for a Playlist');
        // Called during request all tracks before this function call.
        bool totalRetreived = await _getTracksTotal();
        if(!totalRetreived) return null;
      }

      Map<String, dynamic> receivedTracks = <String, dynamic>{};

      //Gets Tracks 50 at a time because of Spotify's limit
      for (int offset = 0; offset < _tracksTotal; offset +=50){
        Map<String, dynamic> checkTracks = <String, dynamic>{};

        final String getTracksUrl ='$hosted/get-tracks/${_edittingPlaylist.value.id}/$offset';
        http.Response response = await _retrySpotifyResponse(getTracksUrl);

        if (response.statusCode != 200){
          throw CustomException(stack: StackTrace.current, reason: 'Bad Response while Getting Tracks from Spotify',  error: response.body);
        }

        checkTracks.addAll(jsonDecode(response.body));

        //Adds to the duplicate values if a track has duplicates.
        if (_edittingPlaylist.value.id != 'Liked_Songs'){
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
      if (_edittingPlaylist.value.id != likedSongs){
        if(!await _checkLiked()){
          _crashlytics.recordError('Failed to check if tracks are in the Liked Songs', StackTrace.current, reason: 'Failed to Check Liked songs');
        }
      }

      return _edittingPlaylist.value.tracks;
    }
    on CustomException catch (error, stack){
      _crashlytics.recordError(error.error, stack, reason: error.reason);
      return null;
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to Get Tracks');
      return null;
    }
    
  }

  /// Get the medium sized image for the track or the smallest sized image when there is only two extremes.
  /// 
  /// Adds each track to '_playlistsTracks' variable as a new track.
  PlaylistModel? _getTrackImages(Map<String, dynamic> responseTracks) {
    _crashlytics.log('Spotify Requests: Get Track Images');
    if(responseTracks.isEmpty) return null;

    try{
      //The chosen image url
      String imageUrl = '';
      _edittingPlaylist.value.tracks = [];

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

          _edittingPlaylist.value.tracks.add(TrackModel(
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

      return _edittingPlaylist.value;
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to edit Tracks images');
      return null;
    }
  }

  /// Check if a Track is in the Liked Songs playlist.
  Future<bool> _checkLiked() async{
    _crashlytics.log('Spotify Requests: Check Liked');

    // No need to check if an empty playlist has liked tracks.
    if(_edittingPlaylist.value.tracks.isEmpty) return true;

    List<dynamic> boolList = [];
    List<String> sendingIds = [];
    
    final String checkUrl = '$hosted/check-liked/${_callback.accessToken}';

    try{
      for (int i = 0; i < _edittingPlaylist.value.tracks.length; i++){
        sendingIds.add(_edittingPlaylist.value.tracks[i].id);
        
          if ( (i % 50) == 0 || i == _edittingPlaylist.value.tracks.length-1){
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
      
      for (int i = 0; i < _edittingPlaylist.value.tracks.length; i++){

        if (boolList[i]){
          //Updates each Track in the Map of tracks.
          _edittingPlaylist.value.tracks[i] = _edittingPlaylist.value.tracks[i].copyWith(liked: true);
        }
        
      }

      return true;
    }
    on CustomException catch (error, stack){
      _crashlytics.recordError(error.error, stack, reason: error.reason);
      return false;
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed checking if a Song is Liked');
      return false;
    }
  }

  /// Get the track ids to add back to Spotify.
  void _getAddBackTracks(List<TrackModel> selectedTracks){
    _crashlytics.log('Spotify Requests: Get Add Back Tracks');

    _addBackTracks = [];

    selectedTracks = Sort().tracksListSort(tracksList: selectedTracks, id: true);

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
  List<String> _getIdsList(List<TrackModel> tracksList){
    _crashlytics.log('Spotify Requests: Get Unmodified Ids');

    List<String> unmodifiedIds = <String>[];
    
    for(TrackModel track in tracksList){
      unmodifiedIds.add(track.id);
    }

    return unmodifiedIds;
  }

  /// Add tracks to multiple playlists in the app.
  void _addTracksToApp(List<PlaylistModel> playlists, List<TrackModel> tracksList){
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

      if(currentPlaylist == playlist){
        currentPlaylist = playlist;
      }
    }
  }

  /// Remove tracks from the current playlist in the app.
  void _removeTracksFromApp(List<TrackModel> removeTracks){
    _crashlytics.log('Spotify Requests: Remove Tracks from App');
    // Remove the tracks from the apps Tracks.
    for(TrackModel track in removeTracks){
      currentPlaylist.removeTrack(track);
    }
    int index = _allPlaylists.indexWhere((_) => _.id == currentPlaylist.id);
    _allPlaylists[index] = currentPlaylist;
    _trackDuplicates = currentPlaylist.makeDuplicates();
  }

  /// Cache all of a users playlists and tracks.
  Future<void> _cachePlaylists([List<PlaylistModel>? cachePlaylists]) async{
    if(!await _cacheManager.cachePlaylists(cachePlaylists ?? allPlaylists)){
     _crashlytics.recordError('Failed to cache Playlists', StackTrace.current, reason: 'Failed to cache Playlists');
    }
  }

}