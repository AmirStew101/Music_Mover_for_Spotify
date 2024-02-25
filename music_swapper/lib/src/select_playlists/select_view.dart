// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/select_playlists/select_popups.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
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
  List<PlaylistModel> allPlaylistsList = [];

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
  bool popup = false;

  @override
  void initState() {
    super.initState();
    final trackArgs = const TrackArguments().toTrackArgs(widget.trackArgs);
    selectedTracksMap = trackArgs.selectedTracks;
    debugPrint('Received Selected = $selectedTracksMap');
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
    allPlaylistsList = List.generate(allPlaylists.length, (index) => allPlaylists.entries.elementAt(index).value);
    allPlaylistsList.sort((a, b) => a.title.compareTo(b.title));

    selectedPlaylistsList = List.generate(allPlaylistsList.length, (index) {
        PlaylistModel currPlaylist = allPlaylistsList[index];

        String playlistTitle = currPlaylist.title;
        String playlistId = currPlaylist.id;
        String imageUrl = currPlaylist.imageUrl;
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
    
    if (mounted && refresh && !loaded){
      await fetchSpotifyPlaylists()
      .catchError((e) {
        error = true;
        throw Exception('Caught error in select_view.dart line: ${getCurrentLine(offset: 3)} error: $e');
      });
    }

  }

  Future<void> fetchDatabasePlaylists() async{
    try{
      if (mounted && !loaded){
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
        bool forceRefresh = false;
        final result = await PlaylistsRequests().checkRefresh(receivedCall, forceRefresh);

        if (result != null){
          receivedCall = result;
        }

        allPlaylists = await PlaylistsRequests().getPlaylists(receivedCall.expiresAt, receivedCall.accessToken, user.spotifyId);

        selectUpdating = true;
        selectListUpdate();

        //Checks all playlists if they are in database
        await DatabaseStorage().syncPlaylists(allPlaylists, user.spotifyId);

        loaded = true;
      }
    }
    catch (e){
      selectViewError(e, getCurrentLine(offset: 17));
    }

  }

  //Handles what to do when the user selects the Move/Add Tracks button
  Future<void> handleOptionSelect() async {
    //Get Ids for selected tracks
    List<String> addIds = TracksRequests().getUnmodifiedIds(selectedTracksMap);

    //Get Ids for selected Ids
    for (var playlist in selectedPlaylistsMap.entries) {
      playlistIds.add(playlist.key);
    }

    //Move tracks to Playlists
    if (option == 'move') {
      List<String> removeIds = addIds;
      List<String> addBackIds = TracksRequests().getAddBackIds(selectedTracksMap);
      
      final result = await PlaylistsRequests().checkRefresh(receivedCall, false);
      if(result != null){
        receivedCall = result;
      }

      try{
        //Add tracks to selected playlists
        await TracksRequests().addTracks(addIds, playlistIds, receivedCall.expiresAt, receivedCall.accessToken)
        .catchError((e) {
          error = true;
          throw Exception('select_view.dart line: ${getCurrentLine(offset:  3)} Caught Error $e');
        });

        //Remove tracks from current playlist
        await TracksRequests().removeTracks(removeIds, currentPlaylist.id, currentPlaylist.snapshotId, receivedCall.expiresAt, receivedCall.accessToken);

        if (addBackIds.isNotEmpty){
          //Add back the Duplicate tracks
          await TracksRequests().addTracks(addBackIds, [currentPlaylist.id], receivedCall.expiresAt, receivedCall.accessToken);
        }
      }
      catch (e){
        error = true;
        throw Exception('select_view.dart line: ${getCurrentLine()} TracksRequests Caught Error: $e');
      }
      
      await DatabaseStorage().removeTracks(currentPlaylist, removeIds, user)
      .catchError((e) {
        throw Exception('select_view.dart line: ${getCurrentLine(offset:  3)} DatabaseStorage Caught Error $e');
      });

      //Finished moving tracks for the playlist
      adding = false;

      await DatabaseStorage().addTracks(user.spotifyId, selectedTracksMap, playlistIds)
      .catchError((e) {
        throw Exception('select_view.dart line: ${getCurrentLine(offset:  3)} DatabaseStorage Caught Error $e');
      });

    }
    //Adds tracks to Playlists
    else {
      final result = await PlaylistsRequests().checkRefresh(receivedCall, false);

      if (result != null){
        receivedCall = result;
      }

      //Update Spotify with the added tracks
      await TracksRequests().addTracks(addIds, playlistIds, receivedCall.expiresAt, receivedCall.accessToken)
      .catchError((e) {
        error = true;
        throw Exception('select_view.dart line: ${getCurrentLine(offset:  3)} Caught Error $e');
      });

      //Finished adding tracks to 
      adding = false;

      debugPrint('Adding $selectedTracksMap to $playlistIds');
      //Update the database to add the tracks
      await DatabaseStorage().addTracks(user.spotifyId, selectedTracksMap, playlistIds)
      .catchError((e) {
        throw Exception('select_view.dart line: ${getCurrentLine(offset:  3)} DatabaseStorage Caught Error $e');
      });

    }
  }
  
  //FUnction to exit playlists select menu
  void navigateToTracks(){
      Map<String, dynamic> sendPlaylist = currentPlaylist.toJson();
      Navigator.pushNamedAndRemoveUntil(context, TracksView.routeName, (route) => route.isFirst, arguments: sendPlaylist);
  }


  Future<void> refreshPlaylists() async{
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
        backgroundColor: spotHelperGreen,
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
                    String id;
                    for (var playEntry in result as List<MapEntry<String, dynamic>>){
                      if (playEntry.value['chosen']){
                        id = playEntry.key;
                        selectedPlaylistsMap.putIfAbsent(id, () => allPlaylists[id]!);
                      }
                    }
                    
                    //receiveSelected(result);
                  }

                  setState(() {
                    //Update Selected Playlists
                  });
                }
              }),
        ],
      ),
      body: FutureBuilder(
        future: checkLogin(), 
        builder: (context, snapshot) {
          if (error){
            return const Center(
              child: Text(
                'Error retreiving Playlists from Spotify. Check connection and Refresh page.',
                textScaler: TextScaler.linear(2),
                textAlign: TextAlign.center,
              )
            );
          }
          else if (loaded && !adding) {
            return selectBodyView();
          } 
          else {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
        },
      ),

      bottomNavigationBar: selectBottomBar()
      );
  }

  Widget selectBodyView(){
    //Creates the list of user playlists
    return ListView.builder(
              itemCount: allPlaylistsList.length,
              itemBuilder: (context, index) {
                PlaylistModel playModel = allPlaylistsList[index];
                String playTitle = playModel.title;
                String playId = playModel.id;
                String imageUrl = playModel.imageUrl;

                bool chosen = selectedPlaylistsList[index].value['chosen'];
                Map<String, dynamic> selectMap = {'chosen': !chosen, 'title': playTitle, 'imageUrl': imageUrl};

                if (option == 'move' && currentPlaylist.title == playTitle){
                  return Container();
                }

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
                        trailing: imageUrl.contains('asset')
                        ? Image.asset(imageUrl)
                        :Image.network(imageUrl),
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
      color: spotHelperGreen,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // Move/Add button to add tracks to Playlist(s)
          Expanded(
            child: InkWell(
              onTap: () async {
                if (selectedTracksMap.isNotEmpty){
                  if (!adding){
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
                      error = true;
                      throw Exception('Caught Error in select_playlists_view.dart at line ${getCurrentLine(offset: 2)} $e');
                    });
                    navigateToTracks();

                    if (!error){
                      //Notification for the User alerting them to the result
                      if(!popup){
                        popup = true;
                        popup = await SelectPopups().success(context, optionMsg);
                      }

                      await SpotifySync().startUpdate(playlistIds, scaffoldMessengerState);
                    }
                    else{
                      //Notification for the User alerting them to the result
                      if(!popup){
                        popup = true;
                        popup = await SelectPopups().success(context, optionMsg);
                      }
                      
                    }
                  }
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
                        throw Exception('Caught Error in select_playlists_view.dart at line ${getCurrentLine(offset: 2)} $e');
                      });
                      navigateToTracks();

                      if(!popup){
                        popup = true;
                        popup = await SelectPopups().success(context, optionMsg);
                      }
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


