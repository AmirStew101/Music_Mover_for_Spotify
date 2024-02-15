// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:ffi';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/select_playlists/select_view.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/playlists_requests.dart';
import 'package:spotify_music_helper/src/tracks/tracks_body.dart';
import 'package:spotify_music_helper/src/utils/tracks_requests.dart';
import 'package:spotify_music_helper/src/tracks/tracks_search.dart';
import 'package:spotify_music_helper/src/utils/universal_widgets.dart';

class TracksView extends StatefulWidget {
  static const routeName = '/tracksView';

  const TracksView({super.key, required this.currentPLaylist});

  final Map<String, dynamic> currentPLaylist;

  @override
  State<TracksView> createState() => TracksViewState();
}

class TracksViewState extends State<TracksView> with SingleTickerProviderStateMixin{
  //Passed arguments
  CallbackModel receivedCall = CallbackModel(); //Received Spotify callback arguments as Map
  UserModel user = UserModel();
  String playlistId = '';
  PlaylistModel currentPlaylist = const PlaylistModel();

  Map<String, TrackModel> allTracks = {}; //Tracks for the chosen playlist
  //All of the selected tracks 
  //key: Track ID
  //values: Track Title, Artist, Image Url, PreviewUrl
  Map<String, TrackModel> selectedTracksMap = {}; 
  String playlistName = '';

  int totalTracks = -1;
  bool refresh = false;
  bool loaded = false; //Tracks loaded status
  bool selectAll = false;
  bool error = false;
  late TabController tabController;

  //Users Loading text
  final List<String> syncTexts = ['Syncing Tracks', 'First time Syncing a lot of Tracks may take awhile', 'Someone has a lot of Tracks to Sync, over 1000?'];
  int syncIndex = 0;

  final List<String> loadTexts = ['Loading Tracks', 'First time Loading a lot of Tracks may take awhile', 'Someone has a lot of Tracks to Load, over 1000?'];
  int loadIndex = 0;



  @override
  void initState(){
    super.initState();

    currentPlaylist = const PlaylistModel().mapToModel(widget.currentPLaylist);

    playlistId = currentPlaylist.id;
    playlistName = currentPlaylist.title;
    
    tabController = TabController(length: 2, vsync: this);
  }


  Future<void> checkLogin() async{
    CallbackModel? secureCall = await SecureStorage().getTokens();
    UserModel? secureUser = await SecureStorage().getUser();

    if (secureCall == null || secureUser == null){
      bool reLogin = false;
      
      Navigator.of(context).pushReplacementNamed(StartViewWidget.routeName, arguments: reLogin);

      storageCheck(context, secureCall, secureUser);
    }
    else{
      receivedCall = secureCall;
      user = secureUser;
      await fetchDatabaseTracks().catchError((e){
        error = true;
        debugPrint('Error when trying to fetchDatabaseTracks ${getCurrentLine()} $e');
      });
    }
  }

  Future<void> fetchDatabaseTracks() async{
    if (!refresh){
      debugPrint('\nCalling Database');

      //Fills Users tracks from the Database
      allTracks = await DatabaseStorage().getDatabaseTracks(user.spotifyId, playlistId, context);
    }

    if (allTracks.isNotEmpty && !refresh){
      totalTracks = allTracks.length;
      loaded = true;
      debugPrint('\nLoaded Tracks');
    }
    else{
      await fetchSpotifyTracks().catchError((e){
        error = true;
        debugPrint('Error when trying to fetchSpotifyTracks $e');
      });
    }
  }

  //Gets the users tracks for the selected Playlist
  Future<void> fetchSpotifyTracks() async {
    debugPrint('\nCalling Spot');
    //Checks if Token needs to be refreshed
    receivedCall = await checkRefresh(receivedCall, false); 
    totalTracks = await getSpotifyTracksTotal(playlistId, receivedCall.expiresAt, receivedCall.accessToken);
    debugPrint('Total Spotify Tracks: $totalTracks');

    if (totalTracks > 0) {
      allTracks = await getSpotifyPlaylistTracks(
          playlistId,
          receivedCall.expiresAt,
          receivedCall.accessToken,
          totalTracks,
      ); //gets user tracks for playlist

      //Adds tracks to database for faster retreival later
      await DatabaseStorage().syncPlaylistTracksData(user.spotifyId, allTracks, playlistId);
    }

    debugPrint('Loaded Tracks');
    loaded = true; //Tracks if the tracks are loaded to be shown
    refresh = false;
  }


  //Updates the chosen tracks function argument for TrackListWidget
  void receiveValue(List<MapEntry<String, dynamic>> chosenTracks) {
    for (var element in chosenTracks) {
      bool trackState = element.value['chosen'];
      String trackId = element.key;

      //Track is in Searched Tracks but it was unchecked in Widget
      //Track is removed from Searched tracks
      if (selectedTracksMap.containsKey(trackId) && trackState == false) {
        selectedTracksMap.removeWhere((key, value) => key == allTracks[trackId]!.id);
      }
      //Track is not in Searched Tracks but it was checked in Widget
      //Adds the Track to Searched Tracks
      if (!selectedTracksMap.containsKey(trackId) && trackState == true) {
        selectedTracksMap[trackId] = allTracks[trackId]!;
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


  Future<void> refreshTracks() async{
    selectedTracksMap.clear();
    refresh = true;
    loaded = false;
    setState(() {
      //Refreshes the page
    });
  }


  void handleSelectAll(){
    //Updates checkbox
    selectAll = !selectAll;
    loaded = false;
  
    //Selects all the check boxes
    if (selectAll) {
      selectedTracksMap = allTracks;
    }
    else {
      selectedTracksMap.clear();
    }

    setState(() {
      
    });
  }

  //Main body of the page
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: tracksAppBar(),

        drawer: optionsMenu(context),

        //Loads the users tracks and its associated images after fetching them for user viewing
        body: tracksBody(),

        bottomNavigationBar: tracksBottomBar(),
      );
  }

  AppBar tracksAppBar(){
     return AppBar(
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
            
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu), 
                onPressed: ()  {
                  Scaffold.of(context).openDrawer();
                },
              )
            ),

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
                          selectedTracksMap[trackId] = allTracks[trackId]!;
                        }
                      }
                    }
                    setState(() {

                    });
                  }),
            ],
      );
  }

  Widget tracksBody(){
    return FutureBuilder<void>(
          future: checkLogin().catchError((e) => debugPrint('\nTracks_view.dart line ${getCurrentLine()} error in tracks_view: $e')),
          builder: (context, snapshot) {
            
            //Playlist has tracks and Tracks finished loading
            if (loaded && totalTracks > 0) {
              return TrackListWidget(
                playlistId: playlistId,
                allTracks: allTracks,
                selectedTracksMap: selectedTracksMap,
                sendTracks: receiveValue,
              );
            } 
            //Playlist doesn't have Tracks
            else if (loaded && totalTracks <= 0) {
              return const Center(
                  child: Text(
                    'Playlist is empty no Tracks to Show',
                    textScaler: TextScaler.linear(1.7),
                    textAlign: TextAlign.center,
                  )
              );
            }
            else if(error){
              return const Center(
                child: Text(
                  'Error getting tracks',
                  textScaler: TextScaler.linear(2)
                )
              );
            }
            else{
              return Center(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(strokeWidth: 6,),
                      if(refresh) 
                        Center(child: 
                          Text(
                            syncTexts[syncIndex],
                            textScaler: const TextScaler.linear(2)
                          )
                        )
                      
                      else
                        Center(child: 
                          Text(
                            loadTexts[loadIndex],
                            textScaler: const TextScaler.linear(2)
                          )
                        )
                    ]
                )
              );
            }
          },
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
            TrackArguments trackArgs = TrackArguments(selectedTracks: selectedTracksMap, currentPlaylist: currentPlaylist, option: 'move', allTracks: allTracks);

            Navigator.restorablePushNamed(context, SelectPlaylistsViewWidget.routeName, arguments: trackArgs.toJson());
          }
          //Add to playlist(s) index
          else if (value == 1 && selectedTracksMap.isNotEmpty) {

            try{
            TrackArguments trackArgs = TrackArguments(selectedTracks: selectedTracksMap, currentPlaylist: currentPlaylist, option: 'add', allTracks: allTracks);
            Navigator.restorablePushNamed(context, SelectPlaylistsViewWidget.routeName, arguments: trackArgs.toJson());
            }
            catch (e){
              debugPrint('Tracks_view line ${getCurrentLine()} caught error $e');
            }
          } 
          //Removes track(s) from current playlist
          else if (value == 2 && selectedTracksMap.isNotEmpty){
            int tracksDeleted = selectedTracksMap.length;
            String playlistTitle = currentPlaylist.title;
            debugPrint('Tracks to Delete: $selectedTracksMap');

            await removeTracks(receivedCall, currentPlaylist, selectedTracksMap, allTracks, user);
            await deleteRefresh();

            Flushbar(
              backgroundColor: const Color.fromARGB(255, 2, 155, 7),
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
