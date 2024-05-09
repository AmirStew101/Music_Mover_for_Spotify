// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:music_mover/main.dart';
import 'package:music_mover/src/login/start_screen.dart';
import 'package:music_mover/src/utils/ads.dart';
import 'package:music_mover/src/utils/backend_calls/spotify_requests.dart';
import 'package:music_mover/src/utils/exceptions.dart';
import 'package:music_mover/src/utils/global_classes/global_objects.dart';
import 'package:music_mover/src/utils/globals.dart';
import 'package:music_mover/src/home/home_body.dart';
import 'package:music_mover/src/tracks/tracks_view.dart';
import 'package:music_mover/src/utils/backend_calls/storage.dart';
import 'package:music_mover/src/utils/global_classes/options_menu.dart';
import 'package:music_mover/src/utils/class%20models/playlist_model.dart';

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
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  final MusicMover _musicMover = MusicMover.instance;

  //bool loaded = false;
  bool error = false;
  bool refresh = false;
  Rx<bool> userLoaded = false.obs;

  final ValueNotifier<bool> _loaded = ValueNotifier<bool>(false);

  @override
  void initState(){
    super.initState();
    _crashlytics.log('InitState Home page');

    _spotifyRequests = SpotifyRequests.instance;

    _checkPlaylists();
  }

  /// Updates how the tracks are sorted.
  void sortUpdate() {
    _crashlytics.log('Sorting Playlists');
    _spotifyRequests.sortPlaylists();
    if(mounted) setState(() {});
  }

  /// Check the saved Tokens & User on device and on successful confirmation get Users playlists.
  Future<void> _checkPlaylists() async {
    try{

      // Initialize the apps Requests and Database user
      if(!_musicMover.isInitialized){
        await _musicMover.initializeApp();
      }

      // App is not Initialized so return to start page
      if(!_musicMover.isInitialized){
        bool reLogin = true;
        Get.offAll(const StartViewWidget(), arguments: reLogin);
      }
      
      // Refresh the Playlists if empty or refresh button is pressed
      if(_spotifyRequests.allPlaylists.isEmpty && !refresh && _musicMover.isInitialized){
        List<PlaylistModel>? plays = await PlaylistsCacheManager().getCachedPlaylists();
        if(plays != null){
          _spotifyRequests.allPlaylists = plays;
          sortUpdate();
        }
      }

      //Fetches Playlists if page is not loaded and on this Page
      if (mounted && !_loaded.value && _musicMover.isInitialized){
        if(mounted && (_spotifyRequests.allPlaylists.isEmpty || !_spotifyRequests.allLoaded || refresh)){
          await _crashlytics.log('Requesting all Playlists & Tracks');
          await _spotifyRequests.requestPlaylists();
          sortUpdate();
          refresh = false;
          _loaded.value = true;
        }
        else{
          await _crashlytics.log('Load Cached Playlists');
          _loaded.value = true;
        }
      }
    }
    on CustomException catch (ee, stack){
      error = true;
      _loaded.value = true;
      _crashlytics.recordError(ee, stack, reason: ee.reason, fatal: true);
    }
    catch (ee, stack){
      error = true;
      _loaded.value = true;
      _crashlytics.recordError(ee, stack, reason: 'Failed during Check Login', fatal: true);
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
      await _checkPlaylists();
    }
  }// refreshPage

  @override
  Widget build(BuildContext context) {
    String loadingText(){
      if(_spotifyRequests.allPlaylists.isEmpty){
        return 'Loading';
      }
      else{
        return 'Loading: ${_spotifyRequests.edittingPlaylist.title}';
      }
    }

    return Scaffold(
        appBar: homeAppbar(),

        drawer: optionsMenu(context, _spotifyRequests.user),

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
              if (_loaded.value && !error && _spotifyRequests.allPlaylists.isNotEmpty && _musicMover.isInitialized) {
                return ImageGridWidget(playlists: _spotifyRequests.allPlaylists, spotifyRequests: _spotifyRequests,);
              }
              else if(!_loaded.value || _spotifyRequests.loading) {
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
          height: !userLoaded.value || _spotifyRequests.user.subscribed
          ? 0
          : 70,
          child: !userLoaded.value || _spotifyRequests.user.subscribed
          ? Container()
          : Ads().setupAds(context, _spotifyRequests.user, home: true),
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
            if(_spotifyRequests.isInitialized){
              Scaffold.of(context).openDrawer();
            }
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
            if(!_spotifyRequests.loading){
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
              if (_loaded.value && !_spotifyRequests.loading){
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