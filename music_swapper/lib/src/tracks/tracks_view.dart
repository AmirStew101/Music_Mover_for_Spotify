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

  Map<String, dynamic> tracks = {}; //Tracks for the chosen playlist
  Map<String, dynamic> searchedTracks = {};
  String playlistName = '';

  int totalTracks = -1;
  bool loaded = false; //Tracks loaded status
  bool selectAll = false;

  @override
  void initState() {
    super.initState();
    fetchTracks(); //Future function since initState as Future makes errors
  }

  //Gets the users tracks for the selected Playlist
  Future<void> fetchTracks() async {
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

    //Checks if Token needs to be refreshed
    receivedCall = await checkRefresh(receivedCall, false); 
    final responseTotal = await getSpotifyTracksTotal(playlistId, receivedCall['expiresAt'], receivedCall['accessToken']);

    if (responseTotal['status'] == 'Success') {
      totalTracks = responseTotal['totalTracks'];
    } 
    else {
      throw Exception('Failed to get Tracks total');
    }

    if (totalTracks > 0) {
      final responseTracks = await getSpotifyPlaylistTracks(
          playlistId,
          receivedCall['expiresAt'],
          receivedCall['accessToken'],
          totalTracks); //gets user tracks for playlist
      if (responseTracks['status'] == 'Success') {
        tracks = responseTracks['data'];
      }

      tracks = getPlatformTrackImages(tracks); //Gets the images for the current platform
    }
    loaded = true; //Tracks if the tracks are loaded to be shown
  }

  //Updates the chosen tracks function argument for TrackListWidget
  void receiveValue(List<MapEntry<String, bool>> chosenTracks) {
    for (var element in chosenTracks) {
      String trackName = element.key;
      bool trackState = element.value;

      //Track is in Searched Tracks but it was unchecked in Widget
      //Track is removed from Searched tracks
      if (searchedTracks.containsKey(trackName) && trackState == false) {
        searchedTracks.remove(element.key);
      }
      //Track is not in Searched Tracks but it was checked in Widget
      //Adds the Track to Searched Tracks
      if (!searchedTracks.containsKey(trackName) && trackState == true) {
        searchedTracks.putIfAbsent(element.key, () => tracks[element.key]);
      }
    }
    searchedTracks = searchedTracks;
  }

  void deleteRefresh(Map<String, dynamic> chosenTracks) {
    List<String> tracksRemove = chosenTracks.keys.toList();
    for (var track in tracksRemove) {
      tracks.remove(track);
      searchedTracks.remove(track);
      totalTracks--;
    }
    setState(() {});
  }

  Future<void> refreshTracks() async{
    debugPrint('Refresh Tracks');

    receivedCall = await checkRefresh(receivedCall, false);
    final responseTotal = await getSpotifyTracksTotal(playlistId, receivedCall['expiresAt'], receivedCall['accessToken']);

    if (responseTotal['status'] == 'Success') {
      totalTracks = responseTotal['totalTracks'];
    } 
    else {
      throw Exception('Failed to get Tracks total');
    }

    if (totalTracks > 0) {
      //gets user tracks for playlist
      final responseTracks = await getSpotifyPlaylistTracks(
          playlistId,
          receivedCall['expiresAt'],
          receivedCall['accessToken'],
          totalTracks);

      if (responseTracks['status'] == 'Success') {
        tracks = responseTracks['data'];
      }

      tracks = getPlatformTrackImages(tracks); //Gets the images for the current platform
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
                  searchedTracks = await showSearch(
                      context: context,
                      delegate: TracksSearchDelegate(tracks, searchedTracks));
                  setState(() {
                    searchedTracks = searchedTracks;
                  });
                }),
          ],
        ),
        //Loads the users tracks and its associated images after fetching them for user viewing
        body: FutureBuilder<void>(
          future: fetchTracks(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                loaded &&
                totalTracks > 0) {
              return TrackListWidget(
                playlistId: playlistId,
                receivedCall: receivedCall,
                tracks: tracks,
                searchedTracks: searchedTracks,
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
          tracks: searchedTracks,
          receivedCall: receivedCall,
          userId: userId,
          refreshTracks: deleteRefresh,
        ));
  }
}
