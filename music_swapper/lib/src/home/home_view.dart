import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/home/home_appbar.dart';
import 'package:spotify_music_helper/utils/playlists_requests.dart';
import 'package:spotify_music_helper/src/home/home_body.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/utils/universal_widgets.dart';

//Creates the state for the home screen to view/edit playlists
class HomeView extends StatefulWidget {
  static const routeName = '/Home';

  //Class definition with the required callback data needed from Spotify
  const HomeView({super.key, required this.multiArgs});
  final Map<String, dynamic> multiArgs;

  @override
  State<HomeView> createState() => HomeViewState();
}

//State widget for the Home screen
class HomeViewState extends State<HomeView> {
  Map<String, dynamic> receivedCall = {}; //required passed callback variable
  Map<String, dynamic> user = {};

  Map<String, dynamic> playlists = {}; //all the users playlists
  bool loaded = false;
  bool error = false;

  Future<void> fetchDatabasePlaylists() async{
    final Map<String, dynamic> multiArgs = widget.multiArgs;
    receivedCall = multiArgs['callback'];
    user = multiArgs['user'];

    playlists = await getDatabasePlaylists(user['id']);

    if (playlists.isNotEmpty && playlists.length > 1){
      loaded = true;
    }
    else{
      await fetchSpotifyPlaylists();
    }
  }

  //Gets all the Users Playlists and platform specific images
  Future<void> fetchSpotifyPlaylists() async {
    debugPrint('\nNeeded Spotify\n');
    try{
      bool forceRefresh = false;
      //Checks to make sure Tokens are up to date before making a Spotify request
      receivedCall = await checkRefresh(receivedCall, forceRefresh);

      playlists = await getSpotifyPlaylists(receivedCall['expiresAt'], receivedCall['accessToken'], user['id']);

      //Checks all playlists if they are in database
      await syncPlaylists(playlists, user['id']);
    }
    catch (e){
      debugPrint('Caught an Error in Home fetchSpotifyPlaylists: $e');
      error = true;
    }
    loaded = true; //Future methods have complete
  }

  Future<void> refreshPage() async{
    setState(() {
      loaded = false;
      error = false;
    });
    await fetchSpotifyPlaylists();
  }

  //The main Widget for the page
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        bottom: Tab(
          child: IconButton(
          color: Colors.black,
          icon: const Icon(Icons.refresh),
          onPressed: () async {
            await refreshPage();
          },)),
        //The Options Menu containing other navigation options
        leading:  OptionsMenu(callback: receivedCall, user: user),
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
                  tracksNavigate(result);
                }
              }),
        ],
      ),
      body: FutureBuilder<void>(
        future: fetchDatabasePlaylists(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && loaded && !error) {
            return ImageGridWidget(receivedCall: receivedCall, playlists: playlists, user: user,);
          }
          else if(error && loaded){
            return const Center(child: Text(
              'Error retreiving Playlists from Spotify. Check connection and Refresh page.',
              textAlign: TextAlign.center,
              textScaler: TextScaler.linear(2),
              ),
            );
          }
          else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  //Navigate to Tracks page for chosen Playlist
  void tracksNavigate(String playlistName){
    MapEntry<String, dynamic> currEntry = playlists.entries.firstWhere((element) => element.value['title'] == playlistName);
    Map<String, dynamic> currentPlaylist = {currEntry.key: currEntry.value};
    Map<String, dynamic> homeArgs = {
                    'currentPlaylist': currentPlaylist,
                    'callback': receivedCall,
                    'user': user,
    };
    Navigator.restorablePushNamed(context, TracksView.routeName, arguments: homeArgs);
  }
}