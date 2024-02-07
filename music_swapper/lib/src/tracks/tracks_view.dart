import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/select_playlists/select_playlists_view.dart';
import 'package:spotify_music_helper/utils/playlists_requests.dart';
import 'package:spotify_music_helper/src/tracks/tracks_body_widgets.dart';
import 'package:spotify_music_helper/utils/tracks_requests.dart';
import 'package:spotify_music_helper/src/tracks/tracks_appbar_widgets.dart';
import 'package:spotify_music_helper/utils/universal_widgets.dart';

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
  Map<String, dynamic> user = {};
  String playlistId = '';

  Map<String, dynamic> allTracks = {}; //Tracks for the chosen playlist
  //All of the selected tracks 
  //key: Track ID
  //values: Track Title, Artist, Image Url, PreviewUrl
  Map<String, dynamic> selectedTracksMap = {}; 
  String playlistName = '';

  int totalTracks = -1;
  bool loaded = false; //Tracks loaded status
  bool selectAll = false;

  @override
  void initState(){
    super.initState();
    //Seperates the arguments passed to this page
    Map<String, dynamic> widgetArgs = widget.multiArgs;
    currentPlaylist = widgetArgs['currentPlaylist'];
    receivedCall = widgetArgs['callback'];
    user = widgetArgs['user'];

    if (currentPlaylist['Liked Songs'] != null) {
      playlistId = 'Liked Songs';
      playlistName = 'Liked Songs';
    } 
    else {
      playlistId = currentPlaylist.entries.single.key;
      playlistName = currentPlaylist.entries.single.value['title'];
    }

  }

  Future<void> fetchDatabaseTracks() async{
    debugPrint('\nCalling Database');

    //Fills Users tracks from the Database
    allTracks = await getDatabaseTracks(user['id'], playlistId);

    if (allTracks.isNotEmpty){
      totalTracks = allTracks.length;
      loaded = true;
      debugPrint('\nLoaded');
    }
    else{
      //await fetchSpotifyTracks();
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
            //await syncPlaylistTracksData(user['id'], allTracks, playlistId);
        }
      }
      catch (e){
        debugPrint('Caught Error while trying to fetch tracks in tracks view \n$e');
      }
    }
    debugPrint('Total Spotify Tracks: $totalTracks');
    loaded = true; //Tracks if the tracks are loaded to be shown
  }

  //Updates the chosen tracks function argument for TrackListWidget
  void receiveValue(List<MapEntry<String, dynamic>> chosenTracks) {
    for (var element in chosenTracks) {
      bool trackState = element.value['chosen'];
      String trackId = element.key;

      //Track is in Searched Tracks but it was unchecked in Widget
      //Track is removed from Searched tracks
      if (selectedTracksMap.containsKey(trackId) && trackState == false) {
        selectedTracksMap.removeWhere((key, value) => key == allTracks[trackId]);
      }
      //Track is not in Searched Tracks but it was checked in Widget
      //Adds the Track to Searched Tracks
      if (!selectedTracksMap.containsKey(trackId) && trackState == true) {
        selectedTracksMap[trackId] = allTracks[trackId];
      }
    }
  }

  Future<void> deleteRefresh() async{
    debugPrint('Delete Refresh');
    loaded = false;

    selectedTracksMap.clear();

    await fetchDatabaseTracks();

    setState(() {
      //Update Tracks
    });
  }

  Future<void> removeTracks(Map<String, dynamic> callback) async {

  String playlistId = currentPlaylist.entries.single.key;
  String snapId = currentPlaylist.entries.single.value['snapshotId'];
  debugPrint('Selected $selectedTracksMap');

  //Get Ids for selected tracks
  List<String> trackIds = [];
  for (var track in selectedTracksMap.entries) {
    trackIds.add(track.key);
  }

  final updateCallback = await checkRefresh(receivedCall, false);
  setState(() {
    //Refresh callback
    callback = updateCallback;
  });
  await removeTracksRequest(trackIds, playlistId, snapId, updateCallback['expiresAt'], updateCallback['accessToken']);
  await removeDatabaseTracks(user['id'], trackIds, playlistId);
  }

  //Main body of the page
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: OptionsMenu(callback: receivedCall, user: user),
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
                      delegate: TracksSearchDelegate(allTracks, selectedTracksMap));

                  for (var result in queryResult){
                    if (result.value['chosen']){
                      selectedTracksMap[result.key] = result.value;
                    }
                  }
                  setState(() {

                  });
                }),
          ],
        ),
        //Loads the users tracks and its associated images after fetching them for user viewing
        body: FutureBuilder<void>(
          future: fetchSpotifyTracks(),
          builder: (context, snapshot) {
            //Playlist has tracks and Tracks finished loading
            if (snapshot.connectionState == ConnectionState.done && loaded && totalTracks > 0) {
              return TrackListWidget(
                playlistId: playlistId,
                receivedCall: receivedCall,
                allTracks: allTracks,
                selectedTracksMap: selectedTracksMap,
                user: user,
                sendTracks: receiveValue,
              );
            } 
            //Playlist doesn't have Tracks
            else if (loaded && totalTracks <= 0) {
              return const Center(
                  child: Text(
                'Playlist is empty no Tracks to Show',
                textScaler: TextScaler.linear(2),
                textAlign: TextAlign.center,
              ));
            }
            //Tracks are loading
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
        bottomNavigationBar: tracksBottomBar(),
      );
  }


  Widget tracksBottomBar(){
      return BottomNavigationBar(
        backgroundColor: const Color.fromARGB(255, 6, 163, 11),
        items: const [
          //Oth item in List
          BottomNavigationBarItem(
            icon: Icon(Icons.drive_file_move_rtl_rounded),
            label: 'Move to Playlists'),

          //1st item in List
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Add to Playlists',
          ),

          //2nd item in List
          BottomNavigationBarItem(
            icon: Icon(Icons.delete),
            label: 'Remove',
          ),
        ],
        onTap: (value) async {
          //Move to playlist(s) Index
          if (value == 0 && selectedTracksMap.isNotEmpty) {
            debugPrint('Selected: $selectedTracksMap');
            final multiArgs = {
              'callback': receivedCall,
              'selectedTracks': selectedTracksMap,
              'currentPlaylist': currentPlaylist,
              'option': 'move',
              'user': user,
            };
            Navigator.restorablePushNamed(context, SelectPlaylistsViewWidget.routeName, arguments: multiArgs);
          }
          //Add to playlist(s) index
          else if (value == 1 && selectedTracksMap.isNotEmpty) {
            final multiArgs = {
              'callback': receivedCall,
              'selectedTracks': selectedTracksMap,
              'currentPlaylist': currentPlaylist,
              'option': 'add',
              'user': user,
            };
            Navigator.restorablePushNamed(context, SelectPlaylistsViewWidget.routeName, arguments: multiArgs);
          } 
          //Removes track(s) from current playlist
          else if (value == 2 && selectedTracksMap.isNotEmpty){
            int tracksDeleted = selectedTracksMap.length;
            String playlistTitle = currentPlaylist.values.single['title'];

            await removeTracks(receivedCall);
            await deleteRefresh();

            // ignore: use_build_context_synchronously
            Flushbar(
              title: 'Success Message',
              duration: const Duration(seconds: 3),
              flushbarPosition: FlushbarPosition.TOP,
              message: 'Deleted $tracksDeleted tracks from $playlistTitle',
            ).show(context);
          }

          else {
            Flushbar(
              title: 'Failed Message',
              duration: const Duration(seconds: 2),
              flushbarPosition: FlushbarPosition.TOP,
              message: 'No tracks selected',
            ).show(context);
          }
        },
      );
  }

}
