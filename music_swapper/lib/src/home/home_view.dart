// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/utils/ads.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/spotify_requests.dart';
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

  late AnimationController _animationController;

  late SpotifyRequests _spotifyRequests;
  late DatabaseStorage _databaseStorage;
  late SecureStorage _secureStorage;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  UserModel user = UserModel(subscribed: true);

  //bool loaded = false;
  bool error = false;
  bool refresh = false;

  final ValueNotifier<bool> _loaded = ValueNotifier<bool>(false);

  @override
  void initState(){
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3)
    );

    try{
      _spotifyRequests = SpotifyRequests.instance;
      _databaseStorage = DatabaseStorage.instance;
      _secureStorage = SecureStorage.instance;
    }
    catch (e){
      _spotifyRequests = Get.put(SpotifyRequests());
      _databaseStorage = Get.put(DatabaseStorage());
      _secureStorage = Get.put(SecureStorage());
    }

    _checkLogin();
  }

  @override
  void dispose(){
    _databaseStorage.dispose();
    _secureStorage.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Updates how the tracks are sorted.
  void sortUpdate() {
    print('Sort');
    _spotifyRequests.sortPlaylists();
    print('Finish Sort');
  }

  /// Check the saved Tokens & User on device and on successful confirmation get Users playlists.
  Future<void> _checkLogin() async {
    try{
      if(!_spotifyRequests.initialized || !_databaseStorage.initialized){
        print('Check Login');
        await _secureStorage.getUser();
        await _secureStorage.getTokens();
        
        // The saved User and Tokens are not corrupted.
        // Initialize the users database connection & spotify requests connection.
        if(_secureStorage.secureUser != null && _secureStorage.secureCallback != null){
          print('Initialize Login');
          user = _secureStorage.secureUser!;

          await _databaseStorage.initializeDatabase(user);
          await _spotifyRequests.initializeRequests(callback: _secureStorage.secureCallback!, savedUser: _databaseStorage.user);
          await _secureStorage.saveUser(_databaseStorage.user);

          user = _spotifyRequests.user;
        }
        else{
          print('Login corrupted');
          bool reLogin = true;
          Get.to(const StartViewWidget(), arguments: reLogin);
        }
      }

      //Fetches Playlists if page is not loaded and on this Page
      if (mounted && !_loaded.value){
        if(mounted && (_spotifyRequests.loadedIds.isEmpty || _spotifyRequests.errorIds.isNotEmpty || _spotifyRequests.allPlaylists.isEmpty) && !refresh){
          print('Loaded Ids: ${_spotifyRequests.loadedIds.isEmpty} Error Ids: ${_spotifyRequests.errorIds.isNotEmpty} All Playlists: ${_spotifyRequests.allPlaylists.isEmpty}');
          print('Request all Playlists & Tracks');
          await _spotifyRequests.requestPlaylists();
          _loaded.value = true;
          await _spotifyRequests.requestAllTracks();
          print('Finished Requesting all Playlists & Tracks');
        }
        else if(mounted && refresh){
          print('Request all Playlists');
          await _spotifyRequests.requestPlaylists(refresh: refresh);
          refresh = false;
          _loaded.value = true;
          print('Finished Requesting all Playlists');
        }
        else{
          print('Load cached Playlists');
          _loaded.value = true;
        }
      }
    }
    catch (e, stack){
      error = true;
      _loaded.value = true;
      _crashlytics.recordError(e, stack, reason: 'Failed to Check Login', fatal: true);
    }
  }//checkLogin

  /// Navigate to Tracks page for chosen Playlist
  void navigateToTracks(PlaylistModel playlist){
    print('Navigate to Tracks');
    try{
      _spotifyRequests.currentPlaylist = playlist;
      // Navigate to the tracks page sending the chosen playlist.
      Get.to(const TracksView());
    }
    catch (e, stack){
      _crashlytics.recordError(e, stack, reason: 'Failed to Navigate to Tracks', fatal: true);
    }
  }//navigateToTracks

  Future<void> refreshPage() async{
    print('Refresh Page');
    _loaded.value = false;
    error = false;
    refresh = true;
    //_playlistsNotifier.value = {};
    await _checkLogin();

    // Rotate sync icon until syncing has stopped.
    await Future.doWhile(() async{
      while(_spotifyRequests.loading.isTrue){
        await Future.delayed(const Duration(seconds: 1));
      }
      return true;
    });
  }//refreshPage


  @override
  Widget build(BuildContext context) {
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
                  TextButton(
                    onPressed: () {
                      //Close Popup
                      Get.back();
                    }, 
                    child: const Text('Cancel')
                  ),
                  TextButton(
                    onPressed: () {
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
              if (_loaded.value && !error && _spotifyRequests.allPlaylists.isNotEmpty) {
                return Stack(
                  children: <Widget>[
                    ImageGridWidget(playlists: _spotifyRequests.allPlaylists, spotifyRequests: _spotifyRequests,),
                    if (!user.subscribed)
                      Ads().setupAds(context, user)
                  ],
                );
              }
              else if(!_loaded.value && !error) {
                  return Stack(
                    children: <Widget>[
                      const Center( child:  CircularProgressIndicator(strokeWidth: 6)),
                      if (!user.subscribed)
                        Ads().setupAds(context, user),
                    ],
                  ) ;
              }
              else{
                return Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            error ? _UiText().error : _UiText().empty,
                            textAlign: TextAlign.center,
                            textScaler: const TextScaler.linear(2),
                          ),
                          const SizedBox(height: 10,), 
                          IconButton(
                            onPressed: () async{
                              await refreshPage();
                            }, 
                            icon: const Icon(
                              Icons.refresh_sharp,
                              color: Colors.green,
                              size: 50,
                            ) 
                          )
                        ],
                      )
                    ),
                    if (!user.subscribed)
                      Ads().setupAds(context, user),
                  ],
                );
              }
            },
          ),
        )
    
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
        
      automaticallyImplyLeading: false, //Prevents back arrow
      backgroundColor: spotHelperGreen,

      actions: <Widget>[
        Obx(() => IconButton(
          onPressed: () {
            _spotifyRequests.playlistsAsc = !_spotifyRequests.playlistsAsc;
            sortUpdate();
          }, 
          icon: _spotifyRequests.playlistsAsc
          ? const Icon(Icons.arrow_upward_sharp)
          : const Icon(Icons.arrow_downward_sharp)
        )),
        //Search Button
        IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              if (_loaded.value){
                RxList<PlaylistModel> searchedPlaylists = _spotifyRequests.allPlaylists.obs;

                Get.dialog(
                  Dialog.fullscreen(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 50,
                          child: TextField(
                            decoration: InputDecoration(
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


  Widget tabRefresh(){
    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton(
            color: Colors.black,
            icon:  AnimatedBuilder(
              animation: _animationController, 
              builder: (_, __) => Transform.rotate(
                angle: _animationController.value * 2 * 3.14,
                child: const Icon(Icons.sync),
              ),
            ),
            onPressed: () async {
              print('Loaded: ${_loaded.value} Spot loading: ${_spotifyRequests.loading.value}');
              if (_loaded.value && !_spotifyRequests.loading.value){
                print('Refersh');
                if(mounted) _animationController.repeat();
                await refreshPage();
                if(mounted) _animationController.reset();
              }
            },
          ),
          InkWell(
            onTap: () async{
              print('Loaded: ${_loaded.value} Spot loading: ${_spotifyRequests.loading.value}');
              if (_loaded.value && !_spotifyRequests.loading.value){
                print('Refersh');
                if(mounted) _animationController.repeat();
                await refreshPage();
                if(mounted) _animationController.reset();
              }
            },
            child: const Text('Refresh'),
          ),
        ],
    );
  }

}//HomeViewState