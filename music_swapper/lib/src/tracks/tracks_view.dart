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

class TracksViewState extends State<TracksView> with SingleTickerProviderStateMixin{
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
  late TabController tabController;

  @override
  void initState(){
    super.initState();
    tabController = TabController(length: 2, vsync: this);

    //Seperates the arguments passed to this page
    Map<String, dynamic> widgetArgs = widget.multiArgs;
    currentPlaylist = widgetArgs['currentPlaylist'];
    receivedCall = widgetArgs['callback'];
    user = widgetArgs['user'];

    playlistId = currentPlaylist.entries.single.key;
    playlistName = currentPlaylist.entries.single.value['title'];
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
      await fetchSpotifyTracks();
    }

  }

  //Gets the users tracks for the selected Playlist
  Future<void> fetchSpotifyTracks() async {
    debugPrint('\nCalling Spot');
      try{
        //Checks if Token needs to be refreshed
        receivedCall = await checkRefresh(receivedCall, false); 
        totalTracks = await getSpotifyTracksTotal(playlistId, receivedCall['expiresAt'], receivedCall['accessToken']);
        debugPrint('Total Spotify Tracks: $totalTracks');

        if (totalTracks > 0) {
          allTracks = await getSpotifyPlaylistTracks(
              playlistId,
              receivedCall['expiresAt'],
              receivedCall['accessToken'],
              totalTracks,
          ); //gets user tracks for playlist

          //Adds tracks to database for faster retreival later
          await syncPlaylistTracksData(user['id'], allTracks, playlistId);
        }
      }
      catch (e){
        debugPrint('Caught Error while trying to fetch tracks in tracks view \n$e');
      }
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

  try{
  callback = await checkRefresh(receivedCall, false);
  await removeTracksRequest(trackIds, playlistId, snapId, callback['expiresAt'], callback['accessToken']);
  await removeDatabaseTracks(user['id'], trackIds, playlistId);
  }
  catch (e){
    debugPrint('Caught error in tracks_view.dart in function removeTracks $e');
  }

  }

  Future<void> refreshTracks() async{
    setState(() {
      loaded = false;
    });
    await fetchSpotifyTracks(); 
  }

  void handleSelectAll(){
    setState(() {
      //Updates checkbox
      selectAll = !selectAll;
    });

    //Selects all the check boxes
    if (selectAll) {
      selectedTracksMap = allTracks;
    }
    else {
      selectedTracksMap.clear();
    }

  }

  //Main body of the page
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            controller: tabController,
            tabs: [
              //Tracks Refresh Button
              Tab(
                child: InkWell(
                  onTap: () async{
                    await refreshTracks();
                  },
                  child: Row(children: [ 
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async{
                      await refreshTracks();
                    },
                  ),
                  const Text('Refresh'),
                ],),
              )
              ),
              //Select All checkbox
              Tab(child: InkWell(
                onTap: () {
                  handleSelectAll();
                },
                child: Row(children: [
                Checkbox(
                  value: selectAll,
                  onChanged: (value) {
                    handleSelectAll();
                  },
                ),
                const Text('Select Al'),
              ],),
              )
              )
            ]),
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
                  final queryResult = await showSearch(
                      context: context,
                      delegate: TracksSearchDelegate(allTracks, selectedTracksMap));

                  if (queryResult != null){
                    for (var result in queryResult){
                      if (result.value['chosen']){
                        String trackId = result.key;
                        selectedTracksMap[trackId] = allTracks[trackId];
                      }
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
            debugPrint('\nSelected to Move: $selectedTracksMap');
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
            debugPrint('Tracks to Delete: $selectedTracksMap');

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
