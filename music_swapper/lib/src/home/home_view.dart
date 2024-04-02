// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/home/home_appbar.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/utils/analytics.dart';
import 'package:spotify_music_helper/src/utils/ads.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/spotify_requests.dart';
import 'package:spotify_music_helper/src/utils/global_classes/sync_services.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/home/home_body.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/src/utils/global_classes/database_classes.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/global_classes/options_menu.dart';

//Creates the state for the home screen to view/edit playlists
class HomeView extends StatefulWidget {
  static const routeName = '/Home';

  //Class definition with the required callback data needed from Spotify
  const HomeView({super.key, required this.initial});
  final bool initial;

  @override
  State<HomeView> createState() => HomeViewState();
}

//State widget for the Home screen
class HomeViewState extends State<HomeView> with SingleTickerProviderStateMixin{
  late ScaffoldMessengerState _scaffoldMessengerState;

  CallbackModel receivedCall = const CallbackModel(); //required passed callback variable
  UserModel user = UserModel.defaultUser();

  Map<String, PlaylistModel> playlists = {}; //all the users playlists
  bool loaded = false;
  bool error = false;
  bool refresh = false;
  bool checkedLogin = false;

  late TabController tabController;

  @override
  void initState(){
    super.initState();
    tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    //Initializes the page ScaffoldMessenger before the page is loaded in the initial state.
    _scaffoldMessengerState = ScaffoldMessenger.of(context);
  }

  Future<void> _checkLogin() async {
    final refreshResponse = await SpotifyRequests().checkRefresh(receivedCall);

    if (mounted && !checkedLogin || refreshResponse == null){
      checkedLogin = true;
      
      //Make a function that returns a bool to check
      CallbackModel? secureCall = await SecureStorage().getTokens();
      UserModel? secureUser = await SecureStorage().getUser();
      bool initial = widget.initial;

      if (secureCall == null || secureUser == null){
        checkedLogin = false;
        bool reLogin = true;

        Navigator.of(context).pushReplacementNamed(StartViewWidget.routeName, arguments: reLogin);

        if (!initial){
          SecureStorage().errorCheck(secureCall, secureUser, context: context);
        }
      }
      else{
        receivedCall = secureCall;
        user = secureUser;
      }

      // Successful Login if User & Callback is in Storage
      if (initial){
        await AppAnalytics().trackSavedLogin(user);
        initial = !initial;
      }
    }

    //Fetches Playlists if page is not loaded and on this Page
    if (mounted && !loaded){
      if (!refresh){
        await fetchDatabasePlaylists()
        .onError((error, stackTrace) {
          //error = true;
          throw Exception('home_view.dart line: ${getCurrentLine(offset: 3)} Caught Error $error');
        });
      }
      
      if (mounted){
        await fetchSpotifyPlaylists()
        .onError((error, stackTrace) {
          error = true;
          throw Exception('home_view.dart line: ${getCurrentLine(offset: 3)} Caught Error $error');
        });
      }
    }
  }//checkLogin

  Future<void> fetchDatabasePlaylists() async{
    Map<String, PlaylistModel>? databasePlaylists = await DatabaseStorage().getDatabasePlaylists(user.spotifyId);

    //More than just the Liked Songs playlist & not Refreshing the page
    if (databasePlaylists != null && databasePlaylists.length > 1 && !refresh){
      playlists = databasePlaylists;
      loaded = true;
    }
    else if (mounted){
      await fetchSpotifyPlaylists()
      .onError((error, stackTrace) {
          throw Exception('home_view.dart line: ${getCurrentLine(offset: 3)} Caught Error $error');
      });
    }

  }//fetchDatabasePlaylists

  //Gets all the Users Playlists and platform specific images
  Future<void> fetchSpotifyPlaylists() async {

      final playlistsSync = await SpotifySync().startPlaylistsSync(user, receivedCall, _scaffoldMessengerState)
      .onError((error, stackTrace) {
        checkedLogin = false;
        throw Exception( exceptionText('home_view.dart', 'fetchSpotifyPLaylists', error) );
      });

      if (playlistsSync.callback == null){
        checkedLogin = false;
        throw Exception( exceptionText('home_view.dart', 'fetchSpotifyPLaylists', error, offset: 8) );
      }

      playlists = playlistsSync.playlists;
      receivedCall = playlistsSync.callback!;
      
    refresh = false;
    loaded = true; //Future methods have complete
  }//fetchSpotifyPlaylists


   //Navigate to Tracks page for chosen Playlist
  void navigateToTracks(String playlistName){
    try{
      MapEntry<String, PlaylistModel> currEntry = playlists.entries.firstWhere((element) => element.value.title == playlistName);
      Map<String, dynamic> currPlaylist = currEntry.value.toJson();

      Navigator.restorablePushNamed(context, TracksView.routeName, arguments: currPlaylist);
    }
    catch (e){
      throw Exception('Home_view line ${getCurrentLine()} caught error: $e');
    }
  }//navigateToTracks


  Future<void> refreshPage() async{
    loaded = false;
    error = false;
    refresh = true;
    setState(() {
      //update refresh variables
    });
  }//refreshPage

  //The main Widget for the page
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: homeAppbar(),

        drawer: optionsMenu(context),

        body: PopScope(
          onPopInvoked: (didPop) => SpotifySync().stop(),
          child: FutureBuilder<void>(
            future: _checkLogin(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && loaded && !error) {
                return Stack(
                  children: [
                    ImageGridWidget(playlists: playlists, receivedCall: receivedCall, user: user),
                    if (!user.subscribed)
                      Ads().setupAds(context, user)
                  ],
                );
              }
              else if(refresh) {
                  return Stack(
                    children: [
                      const Center(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(strokeWidth: 6),
                              Text(
                                'Syncing Playlists',
                                textScaler: TextScaler.linear(2)
                              ),
                            ]
                        )
                      ),
                      if (!user.subscribed)
                        Ads().setupAds(context, user),
                    ],
                  ) ;
                }
              else if(error && loaded){
                return Stack(
                  children: [
                    const Center(
                      child: Text(
                        'Error retreiving Playlists from Spotify. Check connection and Refresh page.',
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.linear(2),
                      ),
                    ),
                    if (!user.subscribed)
                      Ads().setupAds(context, user),
                  ],
                );
              }
              else{
                  return Stack(
                    children: [
                      const Center(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(strokeWidth: 6,),
                            Text(
                              'Loading Playlists',
                              textScaler: TextScaler.linear(2)
                            ),
                          ]
                        )
                      ),
                      if (!user.subscribed)
                        Ads().setupAds(context, user)
                    ],
                  );
                }
            },
          ),
        )
      );
  }//build

  AppBar homeAppbar(){
    return AppBar(
        //Refresh Icon under Appbar
        bottom: Tab( 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    color: Colors.black,
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      if (loaded){
                        await refreshPage();
                      }
                    },
                  ),
                  InkWell(
                    onTap: () async{
                      if (loaded){
                        await refreshPage();
                      }
                    },
                    child: const Text('Sync Playlists'),
                  ),
                ],
              )
            ),

        //The Options Menu containing other navigation options
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu), 
            onPressed: ()  {
              Scaffold.of(context).openDrawer();
            },
          )
        ),

        centerTitle: true,
        automaticallyImplyLeading: false, //Prevents back arrow
        backgroundColor: spotHelperGreen,

        title: const Text(
          'Music Mover',
          textAlign: TextAlign.center,
        ),

        actions: [
          //Search Button
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                if (loaded){
                  //Gets search result to user selected playlist
                  final result = await showSearch(
                      context: context,
                      delegate: PlaylistSearchDelegate(playlists));

                  //Checks if user selected a playlist before search closed
                  if (result != null) {
                    navigateToTracks(result);
                  }
                }
              }
          ),
        ],
      );
  }//homeAppbar

}//HomeViewState