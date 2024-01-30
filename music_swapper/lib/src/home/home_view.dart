import 'package:flutter/material.dart';
import 'package:music_swapper/utils/database/database_model.dart';
import 'package:music_swapper/utils/playlists_requests.dart';
import 'package:music_swapper/src/home/home_widgets.dart';
import 'package:music_swapper/src/tracks/tracks_view.dart';
import 'package:music_swapper/utils/universal_widgets.dart';

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
  String userId = '';

  Map<String, dynamic> playlists = {}; //all the users playlists
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    fetchPlaylists();
  }

  //Gets all the Users Playlists and platform specific images
  Future<void> fetchPlaylists() async {
    final Map<String, dynamic> multiArgs = widget.multiArgs;
    receivedCall = multiArgs['callback'];
    userId = multiArgs['user'];

    playlists = await getDatabasePlaylists(userId);

    if (playlists.isEmpty){
      debugPrint('\nNeeded Spotify\n');
      try{
        bool forceRefresh = false;
        //Checks to make sure Tokens are up to date before making a Spotify request
        receivedCall = await checkRefresh(receivedCall, forceRefresh);

        playlists = await getSpotifyPlaylists(receivedCall['expiresAt'], receivedCall['accessToken']);

        //Checks all playlists if they are in database
        checkPlaylists(playlists, userId);
      }
      catch (e){
        debugPrint('Caught an exception in Home fetchPlaylists: $e');
      }
    }
    loaded = true; //Future methods have complete

  }

  //The main Widget for the page
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //The Options Menu containing other navigation options
        leading:  OptionsMenu(callback: receivedCall, userId: userId),
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
        future: fetchPlaylists(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && loaded) {
            return ImageGridWidget(receivedCall: receivedCall, playlists: playlists, userId: userId,);
          } else {
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
                    'user': userId,
    };
    Navigator.restorablePushNamed(context, TracksView.routeName, arguments: homeArgs);
  }
}