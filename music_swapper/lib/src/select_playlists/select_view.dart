// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/home/home_view.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/playlists_requests.dart';
import 'package:spotify_music_helper/src/select_playlists/select_search.dart';
import 'package:spotify_music_helper/src/utils/global_classes/database_class.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';
import 'package:spotify_music_helper/src/utils/global_classes/sync_services.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/tracks_requests.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';

class SelectPlaylistsViewWidget extends StatefulWidget {
  static const routeName = '/SelectPlaylists';
  const SelectPlaylistsViewWidget({super.key, required this.trackArgs});
  final Map<String, dynamic> trackArgs;

  @override
  State<SelectPlaylistsViewWidget> createState() => SelectPlaylistsViewState();
}

class SelectPlaylistsViewState extends State<SelectPlaylistsViewWidget> {
  late ScaffoldMessengerState scaffoldMessengerState;

  //Passed variables
  Map<String, TrackModel> selectedTracksMap = {};
  PlaylistModel currentPlaylist = const PlaylistModel();
  String option = '';
  Map<String, TrackModel> allTracks = {};

  //Variables in storage
  UserModel user = UserModel.defaultUser();
  CallbackModel receivedCall = CallbackModel();

  //Playlist Variables
  Map<String, PlaylistModel> allPlaylists = {};
  Map<String, PlaylistModel> selectedPlaylistsMap = {};
  List<MapEntry<String, dynamic>> selectedPlaylistsList = []; //Stores [Key: playlist ID, Values: Title, bool of if 'chosen', image]
  List<String> playlistIds = [];
  bool selectAll = false;

  //Page View state variables
  bool loaded = false;
  bool adding = false;
  bool error = false;
  bool refresh = false;
  bool selectUpdating = false;

  @override
  void initState() {
    super.initState();
    final trackArgs = const TrackArguments().toTrackArgs(widget.trackArgs);
    selectedTracksMap = trackArgs.selectedTracks;
    currentPlaylist = trackArgs.currentPlaylist;
    option = trackArgs.option;
    allTracks = trackArgs.allTracks;
  }

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    scaffoldMessengerState = ScaffoldMessenger.of(context);
  }

  void selectListUpdate(){
    debugPrint('Updating select');
    selectedPlaylistsList = List.generate(allPlaylists.length, (index) {
        MapEntry<String, PlaylistModel> currPlaylist = allPlaylists.entries.elementAt(index);

        String playlistTitle = currPlaylist.value.title;
        String playlistId = currPlaylist.key;
        String imageUrl = currPlaylist.value.imageUrl;
        bool selected = false;

        if (selectedPlaylistsMap.containsKey(playlistId)){
          selected = true;
        }

        Map<String, dynamic> selectMap = {'chosen': selected, 'title': playlistTitle, 'imageUrl': imageUrl};

        return MapEntry(playlistId, selectMap);
    });
    
    selectUpdating = false;
  }

  handleSelectAll(){
    selectUpdating = true;

    if (selectAll){
      selectedPlaylistsMap.addAll(allPlaylists);
    }
    else{
      selectedPlaylistsMap.clear();
    }

    selectListUpdate();
    setState(() {
      //Select All playlists
    });
  }

  Future<void> checkLogin() async{
    if (mounted && !loaded && !refresh){
      debugPrint('Checking Login');
      CallbackModel? secureCall = await SecureStorage().getTokens();
      UserModel? secureUser = await SecureStorage().getUser();
      
      if (secureCall == null || secureUser == null){
        bool reLogin = false;
        Navigator.of(context).pushReplacementNamed(StartViewWidget.routeName, arguments: reLogin);
        storageCheck(context, secureCall, secureUser);
      }
      else if(mounted && !loaded && !selectUpdating){
        receivedCall = secureCall;
        user = secureUser;
        await fetchDatabasePlaylists();
      }
    }
    else if (mounted && refresh && !loaded){
      await fetchSpotifyPlaylists()
      .catchError((e) {
        error = true;
        debugPrint('Caught error in select_view.dart line: ${getCurrentLine(offset: 3)} error: $e');
      });
    }

  }

  Future<void> fetchDatabasePlaylists() async{
    try{
      if (mounted && !loaded){
        debugPrint('Fetching Database');
        allPlaylists = await DatabaseStorage().getDatabasePlaylists(user.spotifyId)
        .catchError((e) {
          selectViewError(e, getCurrentLine(offset: 2));
          return Future.value({'': const PlaylistModel()});
        });
      }

      //Checks if only the Liked_Songs playlist is the only playlist
      if (mounted && allPlaylists.length > 1){
        selectUpdating = true;
        selectListUpdate();
        loaded = true;
      }
      else if(mounted && !selectUpdating){
        await fetchSpotifyPlaylists();
      }
    }
    catch (e){
      selectViewError(e, getCurrentLine(offset: 17));
    }

  }

  Future<void> fetchSpotifyPlaylists() async {
    try{
      if (!loaded && !selectUpdating){
        debugPrint('Fetching Spotify');
        bool forceRefresh = false;
        final result = await checkRefresh(receivedCall, forceRefresh);

        if (result != null){
          receivedCall = result;
        }

        allPlaylists = await getSpotifyPlaylists(receivedCall.expiresAt, receivedCall.accessToken, user.spotifyId);

        selectUpdating = true;
        selectListUpdate();

        //Checks all playlists if they are in database
        await DatabaseStorage().smartSyncPlaylists(allPlaylists, user.spotifyId);

        loaded = true;
      }
    }
    catch (e){
      selectViewError(e, getCurrentLine(offset: 17));
    }

  }

  //Updates the list of Playlists the user selected from Search
  // void receiveSelected(List<MapEntry<String, dynamic>> playlistsSelected) {
  //   selectedPlaylistsMap.clear();
  //
  //   for (var playlist in playlistsSelected){
  //     String playlistId = playlist.key;
  //
  //     if (playlist.value['chosen']){
  //       selectedPlaylistsMap[playlistId] = allPlaylists[playlistId]!;
  //     }
  //   }
  // }


  //Handles what to do when the user selects the Move/Add Tracks button
  Future<void> handleOptionSelect() async {
    //Get Ids for selected tracks
    List<String> trackIds = [];
    for (var track in selectedTracksMap.entries) {
      trackIds.add(track.key);
    }

    //Get Ids for selected Ids
    for (var playlist in selectedPlaylistsMap.entries) {
      playlistIds.add(playlist.key);
    }

    //Move tracks to Playlists
    if (option == 'move') {
      
      final result = await checkRefresh(receivedCall, false);
      if(result != null){
        receivedCall = result;
      }
      await addTracksRequest(trackIds, playlistIds, receivedCall.expiresAt, receivedCall.accessToken);
      await DatabaseStorage().removeTracks(receivedCall, currentPlaylist, selectedTracksMap, allTracks, user);

    }
    //Adds tracks to Playlists
    else {

      final result = await checkRefresh(receivedCall, false);

      if (result != null){
        receivedCall = result;
      }
      await addTracksRequest(trackIds, playlistIds, receivedCall.expiresAt, receivedCall.accessToken);
      
    }
  }

  
  //FUnction to exit playlists select menu
  void navigateToTracks(){
      Map<String, dynamic> sendPlaylist = currentPlaylist.toJson();
      //Removes the Stacked Pages until the Home page is the only one Left
      Navigator.popUntil(context, ModalRoute.withName(HomeView.routeName) );
      //Adds the New Tracks Page to Stack
      Navigator.restorablePushNamed(context, TracksView.routeName, arguments: sendPlaylist);
  }


  Future<void> refreshPlaylists() async{
    debugPrint('Refresh');
    loaded = false;
    refresh = true;
    setState(() {
      //Refresh page
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 6, 163, 11),
        title: const Text(
          'Playlist(s) Select',
          textAlign: TextAlign.center,
        ),

        //Refresh Button
        bottom: Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () async{
                  if (loaded && !selectUpdating){
                    refreshPlaylists();
                  }
                }, 
                icon: const Icon(Icons.refresh)
              ),
              InkWell(
                onTap: () {
                  if (loaded && !selectUpdating){
                    refreshPlaylists();
                  }
                },
                child: const Text('Refresh'),
              )
            ],),
        ),
        actions: [

          //Search Button
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                if (loaded && !selectUpdating){
                  final result = await showSearch(
                      context: context,
                      delegate: SelectPlaylistSearchDelegate(allPlaylists, selectedPlaylistsMap)
                  );
                  if(result != null){
                    selectedPlaylistsList = result;
                    //receiveSelected(result);
                  }

                  setState(() {
                    //Update Selected Playlists
                  });
                }
              }),
        ],
      ),
      body: selectBody(),

      bottomNavigationBar: selectBottomBar()
      );
  }

  FutureBuilder selectBody(){
    return FutureBuilder<void>(
        future: checkLogin(),
        builder: (context, snapshot) {
          if (error){
            return const Center(
              child: Column(
                children: [
                  Center(
                    child: CircularProgressIndicator.adaptive(),
                  ),
                  Center(
                    child: Text(
                      'Connection Error',
                      textScaler: TextScaler.linear(1.3),
                    )
                  ),
                ]),
            );
          }
          else if (adding){
            return const Center(
              child: Column(
                children: [
                  CircularProgressIndicator.adaptive(),
                  Text(
                    'Adding Tracks to Playlists',
                    textScaler: TextScaler.linear(1.3),
                  )
                ]),
            );
          }
          else if (loaded) {
            return selectBodyView();
          } 
          else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      );
  }

  Widget selectBodyView(){
    //Creates the list of user playlists
    return ListView.builder(
              itemCount: allPlaylists.length,
              itemBuilder: (context, index) {
                MapEntry<String, PlaylistModel> playEntry = allPlaylists.entries.elementAt(index);
                String playTitle = playEntry.value.title;
                String playId = playEntry.key;
                String imageUrl = playEntry.value.imageUrl;

                bool chosen = selectedPlaylistsList[index].value['chosen'];
                Map<String, dynamic> selectMap = {'chosen': !chosen, 'title': playTitle, 'imageUrl': imageUrl};

                return Column(
                  children: [
                    InkWell(
                      onTap: () {
                        selectedPlaylistsMap[playId] = allPlaylists[playId]!;
                        selectedPlaylistsList[index] = MapEntry(playId, selectMap);
                        setState(() {

                        });
                      },
                      child: ListTile(
                        trailing: imageUrl.contains('asset')
                        ? Image.asset(imageUrl)
                        :Image.network(imageUrl),
                        
                        leading: Checkbox(
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          value: chosen,
                          onChanged: (value) {
                            selectedPlaylistsMap[playId] = allPlaylists[playId]!;
                            selectedPlaylistsList[index] = MapEntry(playId, selectMap);
                            setState(() {

                            });
                          },
                        ),
                        title: Text(
                          playTitle,
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ),

                    const Divider(color: Colors.grey,)
                  ],
                );
              },
            );
  }

  Widget selectBottomBar(){

    Icon optionIcon = const Icon(Icons.arrow_forward);
    String optionText = 'Move Track(s)';

    if (option == 'add') {
      optionIcon = const Icon(Icons.add);
      optionText = 'Add Track(s)';
    }

    return BottomAppBar(
      color: const Color.fromRGBO(25, 20, 20, 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // Move/Add button to add tracks to Playlist(s)
          Expanded(
            child: InkWell(
              onTap: () async {
                if (selectedTracksMap.isNotEmpty){
                  adding = true;
                  int totalChosen = selectedTracksMap.length;
                  
                  //Sets variables for User Notification
                  int totalPlaylists = selectedPlaylistsMap.length;

                  //Message to display to the user
                  String optionMsg = (option == 'move')
                        ? 'Successfully moved $totalChosen songs to $totalPlaylists playlists'
                        : 'Successfully added $totalChosen songs to $totalPlaylists playlists';

                  setState(() {
                    //Updates adding
                  });

                  await handleOptionSelect()
                  .catchError((e){
                    debugPrint('Caught Error in select_playlists_view.dart at line ${getCurrentLine(offset: 2)} $e');
                  });
                  navigateToTracks();


                  //Notification for the User alerting them to the result
                  Flushbar(
                    backgroundColor: const Color.fromARGB(255, 10, 182, 16),
                    title: 'Success Message',
                    duration: const Duration(seconds: 5),
                    flushbarPosition: FlushbarPosition.TOP,
                    message: optionMsg,
                  ).show(context);

                  await SpotifySync().startUpdate(playlistIds, scaffoldMessengerState);
                }
              },

              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                //Text & Icon dependent on what page the user chose to go
                //Move or Add
                IconButton(
                  icon: optionIcon,
                  onPressed: () async {
                    if (selectedTracksMap.isNotEmpty){
                      adding = true;
                      int totalChosen = selectedTracksMap.length;
                  
                      //Sets variables for User Notification
                      int totalPlaylists = selectedPlaylistsMap.length;

                      //Message to display to the user
                      String optionMsg = (option == 'move')
                            ? 'Successfully moved $totalChosen songs to $totalPlaylists playlists'
                            : 'Successfully added $totalChosen songs to $totalPlaylists playlists';

                      setState(() {
                        //Updates adding
                      });

                      await handleOptionSelect()
                      .catchError((e){
                        debugPrint('Caught Error in select_playlists_view.dart at line ${getCurrentLine(offset: 2)} $e');
                      });
                      navigateToTracks();

                      Flushbar(
                        backgroundColor: const Color.fromARGB(255, 2, 155, 7),
                        title: 'Success Message',
                        duration: const Duration(seconds: 5),
                        flushbarPosition: FlushbarPosition.TOP,
                        message: optionMsg,
                      ).show(context);
                    }
                  },
                ),
                Text(optionText),

              ]),
            ),
          ),

          const VerticalDivider(
            color: Colors.grey,
          ),

          // Select All button
          Expanded(
            child:
            InkWell(
              onTap: () {
                selectAll = !selectAll;
                handleSelectAll();
                setState(() {
                  //Check
                });
              },
              child: Row(
                children: [
                  Checkbox(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    value: selectAll, 
                    onChanged: (value) {
                      selectAll = !selectAll;
                      handleSelectAll();
                      setState(() {
                        //Check
                      });
                    },
                  ),
                  const Text('Select All'),
                ],
              ),
            )
          ),
      
        ],
      )
    );
  }

}


