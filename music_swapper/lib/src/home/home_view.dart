// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/home/home_appbar.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/utils/analytics.dart';
import 'package:spotify_music_helper/src/utils/ads.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/playlists_requests.dart';
import 'package:spotify_music_helper/src/home/home_body.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/src/utils/global_classes/database_class.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';

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
  CallbackModel receivedCall = CallbackModel(); //required passed callback variable
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

  Future<void> checkLogin() async {
    final refreshResponse = await PlaylistsRequests().checkRefresh(receivedCall, false);

    if (!checkedLogin || refreshResponse == null){
      checkedLogin = true;
      
      //Make a function that returns a bool to check
      CallbackModel? secureCall = await SecureStorage().getTokens();
      UserModel? secureUser = await SecureStorage().getUser();
      bool initial = widget.initial;

      if (secureCall == null || secureUser == null){
        checkedLogin = false;
        bool reLogin = false;

        Navigator.of(context).pushReplacementNamed(StartViewWidget.routeName, arguments: reLogin);

        if (!initial){
          storageCheck(context, secureCall, secureUser);
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
    if (mounted && !loaded && checkedLogin){
      if (!refresh){
        await fetchDatabasePlaylists()
        .catchError((e) {
          error = true;
          throw Exception('home_view.dart line: ${getCurrentLine(offset: 3)} Caught Error $e');
        });
      }
      
      if (mounted){
        await fetchSpotifyPlaylists()
        .catchError((e) {
          error = true;
          throw Exception('home_view.dart line: ${getCurrentLine(offset: 3)} Caught Error $e');
        });
      }
    }
  }//checkLogin

  Future<void> fetchDatabasePlaylists() async{
    playlists = await DatabaseStorage().getDatabasePlaylists(user.spotifyId);

    //More than just the Liked Songs playlist & not Refreshing the page
    if (playlists.length > 1 && !refresh){
      loaded = true;
    }
    else if (mounted){
      await fetchSpotifyPlaylists()
      .catchError((e) {
          error = true;
          throw Exception('home_view.dart line: ${getCurrentLine(offset: 3)} Caught Error $e');
      });
    }

  }//fetchDatabasePlaylists

  //Gets all the Users Playlists and platform specific images
  Future<void> fetchSpotifyPlaylists() async {
    try{
      bool forceRefresh = false;
      //Checks to make sure Tokens are up to date before making a Spotify request
      CallbackModel? result = await PlaylistsRequests().checkRefresh(receivedCall, forceRefresh);

      if (result == null){
        checkedLogin = false;
        error = true;
        throw Exception('home_view.dart line: ${getCurrentLine(offset: 5)} Failed to get Refresh Tokens');
      }
      receivedCall = result;

      playlists = await  PlaylistsRequests().getPlaylists(receivedCall.expiresAt, receivedCall.accessToken, user.spotifyId);

      //Checks all playlists if they are in database
      await DatabaseStorage().syncPlaylists(playlists, user.spotifyId);
      
    }
    catch (e){
      error = true;
      throw Exception('home_view.dart Caught Error in fetchSpotifyPLaylists: $e');
    }
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

        body: FutureBuilder<void>(
          future: checkLogin(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && loaded && !error) {
              return Stack(
                children: [
                  ImageGridWidget(playlists: playlists, receivedCall: receivedCall, user: user),
                  homeAdRow(context, user)
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
                    homeAdRow(context, user),
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
                  homeAdRow(context, user),
                ],
              );
            }
            else{
                return const Stack(
                  children: [
                    Center(
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
                  ],
                );
              }
          },
        ),
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