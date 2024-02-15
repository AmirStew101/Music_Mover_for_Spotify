// ignore_for_file: use_build_context_synchronously

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/home/home_appbar.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/playlists_requests.dart';
import 'package:spotify_music_helper/src/home/home_body.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/src/utils/universal_widgets.dart';

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
class HomeViewState extends State<HomeView> {
  CallbackModel receivedCall = CallbackModel(); //required passed callback variable
  UserModel user = UserModel();

  Map<String, PlaylistModel> playlists = {}; //all the users playlists
  bool loaded = false;
  bool error = false;
  bool refresh = false;

  Future<void> checkLogin() async {
    CallbackModel? secureCall = await SecureStorage().getTokens();
    UserModel? secureUser = await SecureStorage().getUser();

    if (secureCall == null || secureUser == null){
      bool initial = widget.initial;
      StartArguments startArgs = const StartArguments(reLogin: false, hasUser: true);

      Navigator.of(context).pushReplacementNamed(StartViewWidget.routeName, arguments: startArgs);

      if (!initial){
        storageCheck(context, secureCall, secureUser);
      }
    }
    else{
      receivedCall = secureCall;
      user = secureUser;
      await fetchDatabasePlaylists();
    }
  }

  Future<void> fetchDatabasePlaylists() async{
    loaded = false;
    if (!refresh){
      debugPrint('Fetching Database Playlists');
      playlists = await DatabaseStorage().getDatabasePlaylists(user.spotifyId);
    }

    if (playlists.isNotEmpty && playlists.length > 1 && !refresh){
      debugPrint('Loaded');
      loaded = true;
    }
    else{
      await fetchSpotifyPlaylists();
    }
  }

  //Gets all the Users Playlists and platform specific images
  Future<void> fetchSpotifyPlaylists() async {
    loaded = false;
    debugPrint('\nNeeded Spotify\n');
    try{
      bool forceRefresh = false;
      //Checks to make sure Tokens are up to date before making a Spotify request
      receivedCall = await checkRefresh(receivedCall, forceRefresh);

      playlists = await getSpotifyPlaylists(receivedCall.expiresAt, receivedCall.accessToken, user.spotifyId);

      //Checks all playlists if they are in database
      await DatabaseStorage().syncPlaylists(playlists, user.spotifyId);
    }
    catch (e){
      debugPrint('Caught an Error in Home fetchSpotifyPlaylists: $e');
      error = true;
    }

    refresh = false;
    loaded = true; //Future methods have complete
  }

  Future<void> refreshPage() async{
    setState(() {
      loaded = false;
      error = false;
      refresh = true;
    });
  }

  //The main Widget for the page
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

        //Refresh Icon under Appbar
        bottom: Tab(
          child: IconButton(
            color: Colors.black,
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await refreshPage();
            },
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
        backgroundColor: const Color.fromARGB(255, 6, 163, 11),

        title: const Text(
          'Spotify Helper',
          textAlign: TextAlign.center,
        ),

        actions: [
          //Search Button
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                //Gets search result to user selected playlist
                final result = await showSearch(
                    context: context,
                    delegate: PlaylistSearchDelegate(playlists));

                //Checks if user selected a playlist before search closed
                if (result != null) {
                  navigateToTracks(result);
                }
              }
          ),
        ],
      ),

      drawer: optionsMenu(context),

      body: FutureBuilder<void>(
        future: checkLogin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && loaded && !error) {
            return ImageGridWidget(playlists: playlists, receivedCall: receivedCall, user: user);
          }
          else if(refresh) {
              return const Center(
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
              );
            }
          else if(error && loaded){
            return const Center(child: Text(
              'Error retreiving Playlists from Spotify. Check connection and Refresh page.',
              textAlign: TextAlign.center,
              textScaler: TextScaler.linear(2),
              ),
            );
          }
          else{
              return const Center(
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
              );
            }
        },
      ),
    );
  }

  //Navigate to Tracks page for chosen Playlist
  void navigateToTracks(String playlistName){
    try{
      MapEntry<String, PlaylistModel> currEntry = playlists.entries.firstWhere((element) => element.value.title == playlistName);
      Map<String, dynamic> currPlaylist = currEntry.value.toJson();

      Navigator.restorablePushNamed(context, TracksView.routeName, arguments: currPlaylist);
    }
    catch (e){
      debugPrint('Found it');
    }
  }

}