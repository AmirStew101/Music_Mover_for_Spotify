import 'dart:convert';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:http/http.dart' as http;
import 'package:spotify_music_helper/src/utils/class%20models/custom_sort.dart';
import 'package:spotify_music_helper/src/utils/dev_global.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/storage.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/class%20models/callback_model.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/class%20models/playlist_model.dart';
import 'package:spotify_music_helper/src/utils/class%20models/track_model.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';

const String _fileName = 'spotify_requests.dart';

/// Makes requests to Spotify for a User, refreshing their callback Tokens, editting their Playlists, & editting their Tracks.
/// 
/// Must call the initializeRequests() function before making any functin calls or an error wil be thrown.
class SpotifyRequests extends GetxController{
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// User and Callback saved on the device.
  late final SecureStorage _secureStorage;

  /// Saves and Retreives playlists from cache.
  late final PlaylistsCacheManager _cacheManager;
  bool cacheLoaded = false;

  /// Contains the Spotify [accessToken], [refreshToken], & time it [expiressAt]
  late CallbackModel _callback;

  /// Contains the Users id and other information.
  late UserModel user;
  final Rx<bool> _playlistsAsc = true.obs;
  final Rx<bool> _tracksAsc = true.obs;

  /// All of a Users Spotify Playlists.
  /// 
  /// Key: Playlist id
  /// 
  /// Value: Playlist model with stored tracks.
  final RxList<PlaylistModel> _allPlaylists = <PlaylistModel>[].obs;

  /// Listenable List of playlists that have finished loading tracks.
  final RxList<String> _loadedIds = <String>[].obs;
  Rx<bool> loading = false.obs;

  /// Listenable List of playlists that failed to load.
  final RxList<String> _errorLoading = <String>[].obs;

  /// The Id for the currently active playlist.
  late String _playlistId;
  late PlaylistModel _currentPlaylist;

  /// Tracks for the currently active playlist from playlistId. 
  final RxList<TrackModel> _playlistTracks = <TrackModel>[].obs;

  /// Total number of Tracks in a playlist.
  int tracksTotal = 0;

  /// List of Tracks to be added back after removing a track id from PLaylist.
  final List<TrackModel> _addBackTracks = [];

  /// A List of unmodified Ids to be removed from a playlist.
  List<String> _removeIds = <String>[];

  /// A List of unmodified Tracks to be added to a playlist.
  List<String> _addIds = <String>[];
  
  /// The callback url with expiresAt and accessToken for API url calls.
  String _urlExpireAccess = '';

  bool isInitialized = false;
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

    try{
      _cacheManager = PlaylistsCacheManager.instance;
    }
    catch (e){
      _cacheManager = Get.put(PlaylistsCacheManager());
    }
  }

  PlaylistModel get currentPlaylist{
    return _currentPlaylist;
  }

  set currentPlaylist(PlaylistModel playlist){
    _currentPlaylist = playlist;
    _playlistTracks.value = _currentPlaylist.tracks;
    _playlistId = _currentPlaylist.id;
  }


  bool get playlistsAsc{
    return _playlistsAsc.value;
  }

  bool get tracksAsc{
    return _tracksAsc.value;
  }

  set playlistsAsc(bool ascending){
    user.playlistAsc = ascending;
    _playlistsAsc.value = ascending;
  }

  set tracksAsc(bool ascending){
    user.tracksAsc = ascending;
    _tracksAsc.value = ascending;
  }

  /// Listenable List of playlists that have finished loading tracks.
  RxList<String>  get loadedIds{
    return _loadedIds;
  }

  /// Listenable List of playlists that failed to load.
  List<String> get errorIds{
    return _errorLoading;
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
    _checkTracks(_allPlaylists);
  }

  /// Tracks for the currently active playlist from playlistId.
  List<TrackModel> get playlistTracks{
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

  void sortPlaylists(){
    // Sorts Playlists in ascending or descending order based on the current sort type.
    _allPlaylists.value = Sort().playlistsListSort(_allPlaylists, ascending: user.playlistAsc);
    _checkTracks(_allPlaylists);
  }

  List<TrackModel> sortTracks(String sortType, {bool artist = false, bool type = false, bool addedAt = false, bool id = false}){
    if(sortType == Sort().addedAt){
      _currentPlaylist.tracks = Sort().tracksListSort(tracksList: _playlistTracks, addedAt: true, ascending: user.tracksAsc);
    }
    else if(sortType == Sort().artist){
      _currentPlaylist.tracks = Sort().tracksListSort(tracksList: _playlistTracks, artist: true, ascending: user.tracksAsc);
    }
    else if(sortType == Sort().type){
      _currentPlaylist.tracks = Sort().tracksListSort(tracksList: _playlistTracks, type: true, ascending: user.tracksAsc);
    }
    // Default title sort
    else{
      _currentPlaylist.tracks = Sort().tracksListSort(tracksList: _playlistTracks, ascending: user.tracksAsc);
    }

    _playlistTracks.value = _currentPlaylist.tracks;

    return _playlistTracks;
  }

  /// Must initialize the requests with a Spotify [CallbackModel] before calling any other functions.
  /// This sets the callback for requests and gets the User associated with callback tokens.
  Future<void> initializeRequests({CallbackModel? callback, UserModel? savedUser, String? callRequest}) async{
    print('Initialize Requests');
    loading.value = true;

    if(callRequest != null){
      await _getTokens(callRequest);
    }
    else if (callback != null){
      _callback = callback;
    }
    else{
      throw CustomException(error: 'Error a ''callback\' or \'callRequest\' is needed');
    }

    _urlExpireAccess = '${_callback.expiresAt}/${_callback.accessToken}';
    
    if(savedUser == null){
      await _getUser();
    }
    else{
      user = savedUser;
      _playlistsAsc.value = user.playlistAsc;
      _tracksAsc.value = user.tracksAsc;
    }

    await _cacheManager.getCachedPlaylists()
    .onError((Object? error, StackTrace stack) {
      cacheLoaded = false;
      _crashlytics.recordError(error, stack, reason: 'Faied to retreive cached playlists');
      return null;
    });
    
    // Set Payists retreived from cache and add them to the loaded playlists.
    if(_cacheManager.storedPlaylists.isNotEmpty){
      print('Non Empty Cached Playlists');
      allPlaylists = _cacheManager.storedPlaylists;
      _checkTracks(_allPlaylists);
      cacheLoaded = true;
      print('Cached Playlists ids loaded');
    }
    isInitialized = true;
    loading.value = false;
    print('Done Initializing Requests');
  }

  /// Get a users Spotify playlists from a Spotify API request.
  /// 
  /// Must initialize Requests before calling function.
  Future<void> requestPlaylists({bool refresh = false}) async {
    if(loading.value){
      print('Requests Loading');
      return;
    }

    print('Request Playlists');
    await _checkInitialized();
    try {
      loading.value = true;
  
      final String getPlaylistsUrl = '$hosted/get-playlists/$_urlExpireAccess';

      http.Response response = await http.get(Uri.parse(getPlaylistsUrl));

      if (response.statusCode != 200){
        if(response.body.contains('Need refresh token')){
          await _checkRefresh(forceRefresh: true);
          response = await http.get(Uri.parse(getPlaylistsUrl));
        }
        if(response.statusCode != 200){
          loading.value = false;
          throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'requestPlaylists', error: response.body);
        }
      }

      Map<String, dynamic> responsePlay = jsonDecode(response.body);

      //Removes all playlists not made by the User
      responsePlay.removeWhere((String key, dynamic value) => value['owner'] != user.spotifyId && key != likedSongs);

      _getPlaylistImages(responsePlay);

      if(refresh){
        requestAllTracks(refresh: refresh);
      }
      else{
        loading.value = false;
      }

    }
    catch (e, stack){
      loading.value = false;
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'requestPlaylists', error: e);
    }
    print('Playlists Requested');
  }

  /// Request tracks for a given Spotify paylist.
  /// 
  /// Must initialize Requests before calling function.
  Future<void> requestTracks(String playlistId) async{
    if(loading.value){
      print('Requests Loading');
      return;
    }

    print('Request Tracks');
    await _checkInitialized();
    
    loading.value = true;

    _loadedIds.remove(playlistId);
    _errorLoading.remove(playlistId);

    _playlistId = playlistId;
    _currentPlaylist = _allPlaylists.firstWhere((_) => _.id == _playlistId);

    await _getTracks()
    .onError((_, __) => _errorLoading.addIf(!_errorLoading.contains(_playlistId), _playlistId));

    if(!_errorLoading.contains(_playlistId)){
      _loadedIds.addIf(!_loadedIds.contains(_playlistId), _playlistId);

      await _cacheManager.cachePlaylists(allPlaylists)
      .onError((Object? error, StackTrace stack) => _crashlytics.recordError(error, stack, reason: 'Failed to cache Playlists'));
    }

    loading.value = false;
    print('Done Requesting Tracks');
  }

  /// Makes multpile calls to Spotify to get all of a users Tracks.
  Future<void> requestAllTracks({bool refresh = false}) async{
    if(loading.value){
      print('Requests Loading');
      return;
    }

    print('Request All Tracks');
    await _checkInitialized();
    loading.value = true;
    

    if(refresh){
      _loadedIds.clear();
      _errorLoading.clear();
    }

    for (PlaylistModel playlist in _allPlaylists){
      _playlistId = playlist.id;

      if(refresh || !_loadedIds.contains(_playlistId) || _errorLoading.contains(_playlistId)){
        await _getTracks(singleRequest: false)
        .onError((_, __) {
          _crashlytics.recordError(_, __, reason: 'Failed to requst Playlist tracks during requestAllTracks()');
          _errorLoading.addIf(!_errorLoading.contains(_playlistId), _playlistId);
        });

        if(!_errorLoading.contains(_playlistId)){
          _loadedIds.addIf(!_loadedIds.contains(_playlistId), _playlistId);
        }
      }
    }

    await _cacheManager.cachePlaylists(allPlaylists)
    .onError((Object? error, StackTrace stack) =>_crashlytics.recordError(error, stack, reason: 'Failed to cache Playlists during requestAllTracks()'));

    loading.value = false;
    print('Requested All Tracks');
  }

  /// Make a SPotify request to Add tracks to each playlist in the List.
  ///
  /// Must initialize Requests before calling function.
  Future<void> addTracks(List<PlaylistModel> playlists, List<TrackModel> tracksList) async {
    if(loading.value){
      print('Requests Loading');
      return;
    }

    print('Add Tracks');
    await _checkInitialized();
    loading.value = true;
    

    _addIds = _getUnmodifiedIds(tracksList);

    final String addTracksUrl ='$hosted/add-to-playlists/$_urlExpireAccess';

    try{
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
            throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'addTracks', error: '${response.statusCode} ${response.body}') ;
          }
        }
      }
    }
    catch (e, stack){
      loading.value = false;
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'addTracks', error: e);
    }

    if(_addBackTracks.isEmpty){
      await _addTracksToApp(playlists, tracksList);
    }
    else{
      _addBackTracks.clear();
    }

    loading.value = false;
    print('Added Tracks');
  }

  /// Remove tracks from a Spotify Playlist, and add back tracks that had duplicates that were not removed.
  /// 
  /// Must initialize Requests before calling function.
  Future<void> removeTracks(List<TrackModel> selectedTracks, PlaylistModel playlist, String snapshotId) async{
    if(loading.value){
      print('Requests Loading');
      return;
    }

    print('Remove Tracks');
    await _checkInitialized();
    _playlistId = playlist.id;
    try{
      loading.value = true;
      

      _removeIds = _getUnmodifiedIds(selectedTracks);

      final String removeTracksUrl ='$hosted/remove-tracks/${playlist.id}/$snapshotId/$_urlExpireAccess';

      final http.Response response = await http.post(
        Uri.parse(removeTracksUrl),
          headers: <String, String>{
          'Content-Type': 'application/json'
          },
          body: jsonEncode({'trackIds': _removeIds})
      );

      if (response.statusCode != 200){
        loading.value = false;
        
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'removeTracks', error: 'Failed Response: ${response.statusCode} ${response.body}');
      }

      await _removeTracksFromApp(playlist);

      _getAddBackTracks(selectedTracks);
      if(_addBackTracks.isNotEmpty){
        await addTracks([playlist], _addBackTracks);
      }
    }
    catch (e, stack){
      loading.value = false;
      
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'removeTracks', error: e);
    }
    loading.value = false;
    print('Removed Tracks');
    
  }//removeTracks


  // Private Functions

  /// Check that the class has been initialized before use.
  Future<void> _checkInitialized() async{
    try{
      _callback.toString();
      if(!isInitialized){
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'checkInitialized',  
        error:  'Requests not Initialized. Must call the [initializeRequests] function before calling on other functions.');
      }
    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'checkInitialized',  
      error:  'Requests not Initialized. Must call the [initializeRequests] function before calling on other functions.');
    }
    await _checkRefresh();
  }

  /// Decides what to do when /callback is called.
  Future<void> _getTokens(String callRequest) async {

    final http.Response response = await http.get(Uri.parse(callRequest));

    if (response.statusCode != 200){
      throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'getTokens', error: 'Response: ${response.body.toString()}');
    }

    Map<String, dynamic> responseDecoded = jsonDecode(response.body);

    _callback = CallbackModel(expiresAt: responseDecoded['expiresAt'], accessToken: responseDecoded['accessToken'], refreshToken: responseDecoded['refreshToken']);
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

  /// Makes the Spotify request to refresh the Access Token. Makes the call whether the Token has expired.
  Future<void> _spotRefreshToken() async {
    try{
      final String refreshUrl = '$hosted/refresh-token/${callback.expiresAt}/${callback.refreshToken}';

      final http.Response response = await http.get(Uri.parse(refreshUrl));
      if (response.statusCode != 200){
        throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'spotRefreshToken',  
        error: response.body);
      }

      final Map<String, dynamic> responseDecode = json.decode(response.body);

      _callback = CallbackModel(expiresAt: responseDecode['expiresAt'], accessToken: responseDecode['accessToken'], refreshToken: responseDecode['refreshToken']);
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

    Map<String, dynamic> userInfo = jsonDecode(response.body);

    //Converts user from Spotify to Firestore user
    user = UserModel(username: userInfo['user_name'] , spotifyId: userInfo['id'], url: userInfo['url'], playlistAsc: _playlistsAsc.value, tracksAsc: _tracksAsc.value);
  }//getUser

  /// Gives each playlist the image size based on current platform.
  void _getPlaylistImages(Map<String, dynamic> playlists) {
    print('Get Playlist Images');
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

          PlaylistModel newPlaylist = PlaylistModel(
            title: item.value['title'], 
            id: item.key, 
            link: item.value['link'], 
            imageUrl: imageUrl, 
            snapshotId: item.value['snapshotId']
          );

          // Add playlists to a temp List for comparison
          newPlaylists.addIf(!_allPlaylists.contains(newPlaylist), newPlaylist);
        }

        // Remove Playlists that have been deleted on Spotify
        _allPlaylists.removeWhere((PlaylistModel element) {
          if(!newPlaylists.contains(element)){
            _loadedIds.remove(element.id);
            _errorLoading.remove(element.id);
            return true;
          }
          return false;
        });
        

        // Add playlists that have been added on Spotify
        for(var newPlay in newPlaylists){
          if(!_allPlaylists.contains(newPlay)){
            _allPlaylists.add(newPlay);
          }
        }
        print('Retreived playlists images ${newPlaylists.length}');
        print('New Playlists w/ images ${_allPlaylists.length}');
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

      tracksTotal = jsonDecode(response.body);
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
        http.Response response = await http.get(Uri.parse(getTracksUrl));

        if (response.statusCode != 200){
          if(response.body.contains('Need refresh token')){
            await _checkRefresh(forceRefresh: true);
            response = await http.get(Uri.parse(getTracksUrl));

            if(response.statusCode != 200){
              _errorLoading.addIf(!_errorLoading.contains(_playlistId), _playlistId);
              throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'getTracks',  error: response.body);
            }
          }
          else{
            _errorLoading.addIf(!_errorLoading.contains(_playlistId), _playlistId);
            throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'getTracks',  error: response.body);
          }
        }

        checkTracks.addAll(jsonDecode(response.body));

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
        }
        else{
          receivedTracks.addAll(checkTracks);
        }

        //Clears temp tracks map for next batch of received tracks
        checkTracks = {};
    
      }

      _getTrackImages(receivedTracks);
      //Returns a PLaylist's tracks and checks if they are in liked.
      if (_playlistId != 'Liked_Songs'){
        await _checkLiked();
      }

      int index = _allPlaylists.indexWhere((_) => _.id == _playlistId);
      _allPlaylists[index].tracks = _playlistTracks;
      _currentPlaylist = _allPlaylists[index];
      _loadedIds.addIf(!_loadedIds.contains(_playlistId), _playlistId);
      _errorLoading.remove(_playlistId);
    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'getTracks',  error: e);
    }
    
  }

  /// Get the medium sized image for the track or the smallest sized image when there is only two extremes.
  /// 
  /// Adds each track to '_playlistsTracks' variable as a new track.
  void _getTrackImages(Map<String, dynamic> responseTracks) {
    _playlistTracks.value = [];

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

          TrackModel newTrack = TrackModel(
            id: item.key, 
            imageUrl: imageUrl, 
            artists: item.value['artists'], 
            title: item.value['title'], 
            duplicates: item.value['duplicates'],
            liked: item.value['liked'],
            album: item.value['album'],
            addedAt: DateTime.tryParse(item.value['addedAt']),
            type: item.value['type'],
          );

          _playlistTracks.addIf(!_playlistTracks.contains(newTrack), newTrack);
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
    List<dynamic> boolList = [];

    List<String> sendingIds = <String>[];
    TrackModel track;
    
    final String checkUrl = '$hosted/check-liked/$_urlExpireAccess';

    try{
      for (int i = 0; i < _playlistTracks.length; i++){
        track = _playlistTracks[i];
        trackIds.add(track.id);
        sendingIds.add(track.id);
        
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

            boolList.addAll(jsonDecode(response.body));
            sendingIds = [];
          }
      }

      TrackModel currTrack;
      
      for (int i = 0; i < _playlistTracks.length; i++){
        currTrack = _playlistTracks[i];

        if (boolList[i]){
          //Updates each Track in the Map of tracks.
          _playlistTracks[i] = currTrack.copyWith(liked: true);
        }
        
      }
    }
    catch (e, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'checkLiked',  error:e);
    }
  }

  /// Get the track ids to add back to Spotify.
  void _getAddBackTracks(List<TrackModel> selectedTracks){
    _addBackTracks.clear();

    selectedTracks = Sort().tracksListSort(tracksList: selectedTracks, id: true);
    int addStart = 0;

    for(int ii = 0; ii < selectedTracks.length; ii++){
      
      // Check track when reaching a new unique Track id.
      if(ii == addStart){
        TrackModel currTrack = selectedTracks[ii];

        int lastIndex = selectedTracks.lastIndexWhere((_) => _.id == currTrack.id);
        int diff = currTrack.duplicates - (lastIndex - addStart);

        // Check how many instances of the track are being deleted.
        if(diff > 0){
          for(int jj = 0; jj < diff; jj++){
            _addBackTracks.add(currTrack);
          }
        }
        addStart = lastIndex+1;
      }
    }

  }// getAddBackIds

  /// Returns a List of the unmodified track Ids.
  List<String> _getUnmodifiedIds(List<TrackModel> tracksList){
    List<String> unmodifiedIds = <String>[];

    
    for(TrackModel track in tracksList){
      unmodifiedIds.add(track.id);
    }

    return unmodifiedIds;
  }

  /// Add tracks to multiple playlists in the app.
  Future<void> _addTracksToApp(List<PlaylistModel> playlists, List<TrackModel> tracksList) async{
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

      if(_currentPlaylist == playlist){
        _playlistTracks.value = playlist.tracks;
      }
    }

    await _cacheManager.cachePlaylists(allPlaylists)
    .onError((Object? error, StackTrace stack) => _crashlytics.recordError(error, stack, reason: 'Failed to cache Playlists'));
  }

  /// Remove tracks from a playlist in the app.
  Future<void> _removeTracksFromApp(PlaylistModel playlist) async{
    // Remove the tracks from the apps Tracks.
    for(String trackId in _removeIds){
      int index = playlist.tracks.indexWhere((_) => _.id == trackId);
      playlist.tracks[index].duplicates--;
      
      // Remove the track when it is completely removed from a playlist.
      if (playlist.tracks[index].duplicates < 0){
        playlist.tracks.remove(playlist.tracks[index]);
      }
    }

    int index = _allPlaylists.indexWhere((_) => _.id == _playlistId);
    _allPlaylists[index] = playlist;
    _removeIds = [];
    
    if(_currentPlaylist == playlist){
      _playlistTracks.value = playlist.tracks;
    }

    await _cacheManager.cachePlaylists(allPlaylists)
    .onError((Object? error, StackTrace stack) => _crashlytics.recordError(error, stack, reason: 'Failed to cache Playlists'));
  }

  /// Check if a playlists tracks are empty.
  void _checkTracks(List<PlaylistModel> playlists){
    for (PlaylistModel playlist in _allPlaylists) {
      if(playlist.tracks.isNotEmpty){
        _loadedIds.addIf(!_loadedIds.contains(playlist.id), playlist.id);
        _errorLoading.remove(playlist.id);
      }
      else{
        _errorLoading.addIf(!_errorLoading.contains(playlist.id), playlist.id);
      }
    }
    print('Loaded Ids: ${_loadedIds.length}');
    print('Error Ids: ${_errorLoading.length}');
  }

}