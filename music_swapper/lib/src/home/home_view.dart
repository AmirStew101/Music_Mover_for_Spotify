// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/utils/ads.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/spotify_requests.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/home/home_body.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/database_classes.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/storage.dart';
import 'package:spotify_music_helper/src/utils/global_classes/options_menu.dart';
import 'package:spotify_music_helper/src/utils/class%20models/playlist_model.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';

//Creates the state for the home screen to view/edit playlists
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => HomeViewState();
}

class _UiText{
  final String loading = 'Loading Playlists';
  final String syncing = 'Syncing Playlists';
  final String empty = 'No playlists to edit.';
  final String error = 'Error retreiving Playlists. \nCheck connection and Refresh page.';
}

//State widget for the Home screen
class HomeViewState extends State<HomeView> with SingleTickerProviderStateMixin{

  late SpotifyRequests _spotifyRequests;
  late DatabaseStorage _databaseStorage;
  late SecureStorage _secureStorage;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  //bool loaded = false;
  bool error = false;
  bool refresh = false;

  final ValueNotifier<bool> _loaded = ValueNotifier<bool>(false);

  @override
  void initState(){
    super.initState();
    _crashlytics.log('InitState Home page');

    try{
      _spotifyRequests = SpotifyRequests.instance;
    }
    catch (error){
      _spotifyRequests = Get.put(SpotifyRequests());
      _crashlytics.log('Failed to Get Instance of Spotify Requests');
    }

    try{
      _databaseStorage = DatabaseStorage.instance;
    }
    catch (error){
      _databaseStorage = Get.put(DatabaseStorage());
      _crashlytics.log('Failed to Get Instance of Database Storage');
    }

    try{
      _secureStorage = SecureStorage.instance;
    }
    catch (error){
      _secureStorage = Get.put(SecureStorage());
      _crashlytics.log('Failed to Get Instance of Secure Storage');
    }

    _checkLogin();
  }

  /// Updates how the tracks are sorted.
  void sortUpdate() {
    _crashlytics.log('Sorting Playlists');
    _spotifyRequests.sortPlaylists();
    setState(() {});
  }

  /// Check the saved Tokens & User on device and on successful confirmation get Users playlists.
  Future<void> _checkLogin() async {
    try{
      if(!_spotifyRequests.isInitialized || !_databaseStorage.isInitialized){
        await _crashlytics.log('Playlists Page Check Login');
        await _secureStorage.getUser();
        await _secureStorage.getTokens();
        
        // The saved User and Tokens are not corrupted.
        // Initialize the users database connection & spotify requests connection.
        if(_secureStorage.secureUser != null && _secureStorage.secureCallback != null){
          await _crashlytics.log('Initialize Login using Storage');

          if(!_databaseStorage.isInitialized) await _databaseStorage.initializeDatabase(_secureStorage.secureUser!);

          if(_spotifyRequests.isInitialized){
            _spotifyRequests.user = _databaseStorage.user;
          }
          else{
            await _spotifyRequests.initializeRequests(callback: _secureStorage.secureCallback!, savedUser: _databaseStorage.user);
          }

          await _secureStorage.saveUser(_spotifyRequests.user);
        }
        else if(_spotifyRequests.isInitialized){
          await _crashlytics.log('Initialize Login using Spotify');

          await _databaseStorage.initializeDatabase(_spotifyRequests.user);
          _spotifyRequests.user = _databaseStorage.user;
          await _secureStorage.saveUser(_spotifyRequests.user);
        }
        else{
          _crashlytics.log('Login Corrupted');
          bool reLogin = true;
          await Get.offAll(const StartViewWidget(), arguments: reLogin);
        }
      }

      if(_spotifyRequests.allPlaylists.isEmpty && !refresh){
        List<PlaylistModel>? plays = await PlaylistsCacheManager().getCachedPlaylists();
        if(plays != null) _spotifyRequests.allPlaylists = plays;
      }

      //Fetches Playlists if page is not loaded and on this Page
      if (mounted && !_loaded.value){
        if(mounted && (_spotifyRequests.allPlaylists.isEmpty || !_spotifyRequests.allLoaded || refresh)){
          await _crashlytics.log('Requesting all Playlists & Tracks');
          await _spotifyRequests.requestPlaylists();
          refresh = false;
          _loaded.value = true;
        }
        else{
          await _crashlytics.log('Load Cached Playlists');
          _loaded.value = true;
        }
      }
    }
    on CustomException catch (ee){
      error = true;
      _loaded.value = true;
      //_crashlytics.recordError(ee.error, ee.stack, reason: 'Failed during Check Login', fatal: true);
      throw CustomException(stack: ee.stack, fileName: ee.fileName, functionName: ee.functionName, reason: ee.reason, error: ee.error);
    }
    catch (e, stack){
      error = true;
      _loaded.value = true;
      _crashlytics.recordError(e, stack, reason: 'Failed during Check Login', fatal: true);
    }
  }//checkLogin

  /// Navigate to Tracks page for chosen Playlist
  void navigateToTracks(PlaylistModel playlist){
    _crashlytics.log('Navigate to Tracks');
    try{
      _spotifyRequests.currentPlaylist = playlist;
      // Navigate to the tracks page sending the chosen playlist.
      Get.to(const TracksView(), arguments: _spotifyRequests);
    }
    on CustomException catch (ee){
      throw CustomException(stack: ee.stack, fileName: ee.fileName, functionName: ee.functionName, reason: ee.reason, error: ee.error);
    }
    catch (e, stack){
      _crashlytics.recordError(e, stack, reason: 'Failed to Navigate to Tracks', fatal: true);
    }
  }//navigateToTracks

  Future<void> refreshPage() async{
    if(_spotifyRequests.shouldRefresh(_loaded.value, refresh)){
      _crashlytics.log('Refresh Playlists Page');
      _loaded.value = false;
      error = false;
      refresh = true;
      await _checkLogin();
    }
  }// refreshPage

  @override
  Widget build(BuildContext context) {
    String loadingText(){
      if(_spotifyRequests.allPlaylists.isEmpty){
        return 'Loading';
      }
      else{
        return 'Loading: ${_spotifyRequests.currentPlaylist.title}';
      }
    }

    return Scaffold(
        appBar: homeAppbar(),

        drawer: optionsMenu(context),

        body: PopScope(
          canPop: false,
          onPopInvoked: (_) {
            Get.dialog(
              AlertDialog.adaptive(
                title: const Text(
                  'Sure you want to exit the App?',
                  textAlign: TextAlign.center,
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: <Widget>[
                  // Cancel exit button
                  TextButton(
                    onPressed: () {
                      _crashlytics.log('Cancel exit pressed');
                      //Close Popup
                      Get.back();
                    }, 
                    child: const Text('Cancel')
                  ),
                  // Confirm exit button
                  TextButton(
                    onPressed: () {
                      _crashlytics.log('Exit app update User');
                      _crashlytics.log('Exit app');
                      //Close App
                      exit(0);
                    },
                    child: const Text('Confirm'),
                  ),
                ],
              )
            );
          },
          child: ValueListenableBuilder(
            valueListenable: _loaded, 
            builder: (_, __, ___) {
              if (_loaded.value && !error && !_spotifyRequests.loading.value) {
                return ImageGridWidget(playlists: _spotifyRequests.allPlaylists, spotifyRequests: _spotifyRequests,);
              }
              else if(!_loaded.value || _spotifyRequests.loading.value) {
                return Center( 
                  child:Obx(() => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(strokeWidth: 6),
                      const SizedBox(height: 20),
                      Text(
                        loadingText(),
                        textScaler: const TextScaler.linear(1.8),
                      )
                    ],
                  ))
                );
              }
              else{
                // No tracks were found or an error
                return Center(
                  child: Text(
                    error ? _UiText().error : _UiText().empty,
                    textAlign: TextAlign.center,
                    textScaler: const TextScaler.linear(2),
                  ),
                );
              }
            },
          ),
        ),

        bottomNavigationBar: Obx(() => BottomAppBar(
          height: _spotifyRequests.user.subscribed
          ? 0
          : 70,
          child: Ads().setupAds(context, _spotifyRequests.user, home: true),
        )),
    
    );
  }// build



  AppBar homeAppbar(){
    return AppBar(
      
      title: const Text(
        'Music Mover',
        textAlign: TextAlign.center,
      ),
      centerTitle: true,

      //The Options Menu containing other navigation options
      leading: Builder(
        builder: (BuildContext context) => IconButton(
          icon: const Icon(Icons.menu), 
          onPressed: ()  {
            Scaffold.of(context).openDrawer();
          },
        )
      ),

      // Refresh the page button
      bottom: Tab(
        child: InkWell(
          onTap: () => refreshPage(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[ 
              IconButton(
                icon: const Icon(Icons.sync_sharp),
                onPressed: () => refreshPage(),
              ),
              const Text('Refresh'),
            ],
          ),
        ),
      ),
        
      automaticallyImplyLeading: false, //Prevents back arrow
      backgroundColor: spotHelperGreen,

      actions: <Widget>[
        IconButton(
          onPressed: () {
            if(!_spotifyRequests.loading.value){
              _spotifyRequests.playlistsAsc = !_spotifyRequests.playlistsAsc;
              sortUpdate();
            }
          }, 
          icon: _spotifyRequests.playlistsAsc == true
          ? const Icon(Icons.arrow_upward_sharp)
          : const Icon(Icons.arrow_downward_sharp)
        ),
        //Search Button
        IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              if (_loaded.value && !_spotifyRequests.loading.value){
                _crashlytics.log('Searching Playlists');
                RxList<PlaylistModel> searchedPlaylists = _spotifyRequests.allPlaylists.obs;

                Get.dialog(
                  Dialog.fullscreen(
                    child: Column(
                      children: [
                        // Search box
                        SizedBox(
                          height: 70,
                          child: TextField(
                            decoration: InputDecoration(
                              // Exit serach
                              prefixIcon: IconButton(
                                onPressed: () => Get.back(), 
                                icon: const Icon(Icons.arrow_back_sharp)
                              ),
                              hintText: 'Search'
                            ),
                            onChanged: (String query) {
                              searchedPlaylists.value = _spotifyRequests.allPlaylists.where((playlist){
                                final String result;
                                result = playlist.title.toLowerCase();
                                
                                final String input = modifyBadQuery(query).toLowerCase();

                                return result.contains(input);
                              }).toList();
                            },
                          )
                        ),

                        Expanded(
                          child: Obx(() => ListView.builder(
                            itemCount: searchedPlaylists.length,
                            itemBuilder: (context, index) {
                              PlaylistModel currPlaylist = searchedPlaylists[index];
                              String playImage = currPlaylist.imageUrl;

                              return ListTile(
                                onTap: () {
                                  Get.back();
                                  navigateToTracks(currPlaylist);
                                },

                                // Playlist name and Artist
                                title: Text(
                                  currPlaylist.title, 
                                  textScaler: const TextScaler.linear(1.2)
                                ),
                                
                                trailing: playImage.contains('asset')
                                ?Image.asset(playImage)
                                :Image.network(playImage),
                              );
                            }
                          ))
                        )
                      ],
                    ),
                  )
                );
              }
            }
        ),
      ],
    );
  }//homeAppbar

}//HomeViewState