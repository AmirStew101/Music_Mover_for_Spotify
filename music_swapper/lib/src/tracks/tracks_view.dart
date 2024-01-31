import 'package:flutter/material.dart';
import 'package:music_swapper/utils/database/database_model.dart';
import 'package:music_swapper/utils/playlists_requests.dart';
import 'package:music_swapper/src/tracks/tracks_body_widgets.dart';
import 'package:music_swapper/src/tracks/tracks_bottom_widgets.dart';
import 'package:music_swapper/utils/tracks_requests.dart';
import 'package:music_swapper/src/tracks/tracks_appbar_widgets.dart';
import 'package:music_swapper/utils/universal_widgets.dart';

class TracksView extends StatefulWidget {
  static const routeName = '/tracksView';

  const TracksView({super.key, required this.multiArgs});

  final Map<String, dynamic> multiArgs;

  @override
  State<TracksView> createState() => TracksViewState();
}

class TracksViewState extends State<TracksView> {
  //Passed arguments
  Map<String, dynamic> currentPlaylist = {};
  Map<String, dynamic> receivedCall = {}; //Received Spotify callback arguments as Map
  String userId = '';
  String playlistId = '';

  Map<String, dynamic> allTracks = {}; //Tracks for the chosen playlist
  //All of the selected tracks 
  //key: Track ID
  //values: 'Chosen' as bool & Track Title
  Map<String, dynamic> selectedTracks = {}; 
  String playlistName = '';

  int totalTracks = -1;
  bool loaded = false; //Tracks loaded status
  bool selectAll = false;

  Future<void> fetchDatabaseTracks() async{
    debugPrint('\nCalling Database');
    //Seperates the arguments passed to this page
    Map<String, dynamic> widgetArgs = widget.multiArgs;
    currentPlaylist = widgetArgs['currentPlaylist'];
    receivedCall = widgetArgs['callback'];
    userId = widgetArgs['user'];

    if (currentPlaylist['Liked Songs'] != null) {
      playlistId = 'Liked Songs';
      playlistName = 'Liked Songs';
    } 
    else {
      playlistId = currentPlaylist.entries.single.key;
      playlistName = currentPlaylist.entries.single.value['title'];
    }

    //Fills Users tracks from the Database
    allTracks = await getPlaylistTracksData(userId, playlistId);

    if (allTracks.isNotEmpty){
      totalTracks = allTracks.length;
      loaded = true;
      debugPrint('\nLoaded');
    }
    else{
      await fetchSpotifyTracks();
    }

  }

  //Gets the users tracks for the selected Playlist
  Future<void> fetchSpotifyTracks() async {
    if (allTracks.isEmpty){
      try{
        debugPrint('\nCalling Spot');
        //Checks if Token needs to be refreshed
        receivedCall = await checkRefresh(receivedCall, false); 
        totalTracks = await getSpotifyTracksTotal(playlistId, receivedCall['expiresAt'], receivedCall['accessToken']);

        if (totalTracks > 0) {
          allTracks = await getSpotifyPlaylistTracks(
              playlistId,
              receivedCall['expiresAt'],
              receivedCall['accessToken'],
              totalTracks); //gets user tracks for playlist

            //Adds tracks to database for faster retreival later
            for (var track in allTracks.entries){
              await checkUserTrackData(userId, track, playlistId);
            }
        }
      }
      catch (e){
        debugPrint('Caught Error while trying to fetch tracks in tracks view \n$e');
      }
    }

    loaded = true; //Tracks if the tracks are loaded to be shown
  }

  //Updates the chosen tracks function argument for TrackListWidget
  void receiveValue(List<MapEntry<String, dynamic>> chosenTracks) {
    for (var element in chosenTracks) {
      String trackTitle = element.value['title'];
      bool trackState = element.value['chosen'];
      String trackId = element.key;

      Map<String, dynamic> selectMap = {'chosen': trackState, 'title': trackTitle};

      //Track is in Searched Tracks but it was unchecked in Widget
      //Track is removed from Searched tracks
      if (selectedTracks.containsKey(trackId) && trackState == false) {
        selectedTracks.removeWhere((key, value) => key == trackId);
      }
      //Track is not in Searched Tracks but it was checked in Widget
      //Adds the Track to Searched Tracks
      if (!selectedTracks.containsKey(trackId) && trackState == true) {
        selectedTracks[trackId] = selectMap;
      }
    }
  }

  void deleteRefresh(Map<String, dynamic> chosenTracks) {
    //Get all the tracks the user chose to be deleted
    List<String> tracksRemove = [];
    for (var track in chosenTracks.entries){
      tracksRemove.add(track.key);
    }

    //deleteTracksData(String userId, List<Strings> trackIds);
    
    for (var trackId in tracksRemove) {
      allTracks.remove(trackId);
      selectedTracks.removeWhere((key, value) => key == trackId);
      totalTracks--;
    }
    setState(() {});
  }

  //Gets Tracks from Spotify to update database
  Future<void> refreshTracks() async{
    debugPrint('Refresh Tracks');

    receivedCall = await checkRefresh(receivedCall, false);
    totalTracks = await getSpotifyTracksTotal(playlistId, receivedCall['expiresAt'], receivedCall['accessToken']);

    if (totalTracks > 0) {
      //gets user tracks for playlist
      allTracks = await getSpotifyPlaylistTracks(
          playlistId,
          receivedCall['expiresAt'],
          receivedCall['accessToken'],
          totalTracks);

      //Adds tracks to database for faster retreival later
      for (var track in allTracks.entries){
        await checkUserTrackData(userId, track, playlistId);
      }
    }
    setState(() {
      //Update Playlists
    });
  }


  //Main body of the page
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: OptionsMenu(callback: receivedCall, userId: userId),
          backgroundColor: const Color.fromARGB(255, 6, 163, 11),
          title: Text(
            playlistName, //Playlist Name
            textAlign: TextAlign.center,
          ),
          actions: [
            //Search Button
            IconButton(
                icon: const Icon(Icons.search),

                onPressed: () async {
                  List<MapEntry<String, dynamic>> queryResult = await showSearch(
                      context: context,
                      delegate: TracksSearchDelegate(allTracks, selectedTracks));

                  for (var result in queryResult){
                    if (result.value['chosen']){
                      selectedTracks[result.key] = result.value;
                    }
                  }
                  setState(() {

                  });
                }),
          ],
        ),
        //Loads the users tracks and its associated images after fetching them for user viewing
        body: FutureBuilder<void>(
          future: fetchDatabaseTracks(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && loaded && totalTracks > 0) {
              return TrackListWidget(
                playlistId: playlistId,
                receivedCall: receivedCall,
                allTracks: allTracks,
                selectedTracks: selectedTracks,
                sendTracks: receiveValue,
                refreshTracks: refreshTracks,
              );
            } 
            else if (loaded && totalTracks <= 0) {
              return const Center(
                  child: Text(
                'Playlist is empty no Tracks to Show',
                textScaler: TextScaler.linear(2),
                textAlign: TextAlign.center,
              ));
            } 
            else {
              return const Center(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    CircularProgressIndicator(),
                    Text('Loading tracks')
                  ]));
            }
          },
        ),
        bottomNavigationBar: TracksBottomBar(
          currentPlaylist: currentPlaylist,
          tracks: selectedTracks,
          receivedCall: receivedCall,
          userId: userId,
          refreshTracks: deleteRefresh,
        ));
  }
}
