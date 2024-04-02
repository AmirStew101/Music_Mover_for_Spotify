// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/select_playlists/select_popups.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/select_playlists/select_search.dart';
import 'package:spotify_music_helper/src/utils/global_classes/database_classes.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';
import 'package:spotify_music_helper/src/utils/global_classes/sync_services.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/spotify_requests.dart';
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
  bool checkedLogin = false;

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

  ///Updates the List of selected playlists.
  void selectPlaylistsListUpdate(){
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

  ///Selects all of the playlists.
  void handleSelectAll(){
    selectUpdating = true;

    if (selectAll){
      selectedPlaylistsMap.addAll(allPlaylists);
    }
    else{
      selectedPlaylistsMap.clear();
    }

    selectPlaylistsListUpdate();
    setState(() {
      //Select All playlists
    });
  }

  Future<void> checkLogin() async{
    if (mounted && !checkedLogin){
      CallbackModel? secureCall = await SecureStorage().getTokens();
      UserModel? secureUser = await SecureStorage().getUser();
      
      if (secureCall == null || secureUser == null){
        bool reLogin = false;
        Navigator.of(context).pushReplacementNamed(StartViewWidget.routeName, arguments: reLogin);
        SecureStorage().errorCheck(secureCall, secureUser, context: context);
      }
      else{
        receivedCall = secureCall;
        user = secureUser;
      }
    }

    if(mounted && !loaded && !refresh && !selectUpdating){
      await fetchDatabasePlaylists()
        .onError((error, stackTrace) {
        error = true;
        throw Exception( exceptionText('select_playlists_view.dart', 'checkLogin', error, offset: 3) );
      });
    }
    else if (mounted && refresh && !loaded && !selectUpdating){
      await fetchSpotifyPlaylists()
      .onError((error, stackTrace) {
        error = true;
        throw Exception( exceptionText('select_playlists_view.dart', 'checkLogin', error, offset: 3) );
      });
    }

  }

  Future<void> fetchDatabasePlaylists() async{
    try{
      if (mounted && !loaded){
        Map<String, PlaylistModel>? databasePlaylists = await DatabaseStorage().getDatabasePlaylists(user.spotifyId);

        if (databasePlaylists != null){
          allPlaylists = databasePlaylists;
        }
        else{
          allPlaylists = {};
        }
      }

      //Checks if only the Liked_Songs playlist is the only playlist
      if (mounted && allPlaylists.length > 1){
        selectUpdating = true;
        selectPlaylistsListUpdate();
        loaded = true;
      }
      else if(mounted && !selectUpdating){
        await fetchSpotifyPlaylists();
      }
    }
    catch (e){
      throw Exception( exceptionText('select_playlists_view.dart', 'fetchDatabasePlaylists', error) );
    }

  }

  Future<void> fetchSpotifyPlaylists() async {

    final playlistsSync = await SpotifySync().startPlaylistsSync(user, receivedCall, scaffoldMessengerState)
      .onError((error, stackTrace) {
        checkedLogin = false;
        throw Exception( exceptionText('home_view.dart', 'fetchSpotifyPLaylists', error) );
      });

      if (playlistsSync.callback == null){
        checkedLogin = false;
        throw Exception( exceptionText('home_view.dart', 'fetchSpotifyPLaylists', error, offset: 8) );
      }

      allPlaylists = playlistsSync.playlists;
      receivedCall = playlistsSync.callback!;

      selectUpdating = true;
      selectPlaylistsListUpdate();

      loaded = true;
  }

  //Handles what to do when the user selects the Move/Add Tracks button
  Future<void> handleOptionSelect() async {
    //Get Ids for selected tracks
    List<String> addIds = SpotifyRequests().getUnmodifiedIds(selectedTracksMap);

    //Get Ids for selected Ids
    for (var playlist in selectedPlaylistsMap.entries) {
      playlistIds.add(playlist.key);
    }

    //Move tracks to Playlists
    if (option == 'move') {
      List<String> removeIds = addIds;
      List<String> addBackIds = SpotifyRequests().getAddBackIds(selectedTracksMap);
      
      final result = await SpotifyRequests().checkRefresh(receivedCall);
      if(result != null){
        receivedCall = result;
      }

      try{
        //Add tracks to selected playlists
        await SpotifyRequests().addTracks(addIds, playlistIds, receivedCall.expiresAt, receivedCall.accessToken);

        //Remove tracks from current playlist
        await SpotifyRequests().removeTracks(removeIds, currentPlaylist.id, currentPlaylist.snapshotId, receivedCall.expiresAt, receivedCall.accessToken);

        if (addBackIds.isNotEmpty){
          //Add back the Duplicate tracks
          await SpotifyRequests().addTracks(addBackIds, [currentPlaylist.id], receivedCall.expiresAt, receivedCall.accessToken);
        }
      
      
        await DatabaseStorage().removeTracks(user.spotifyId, currentPlaylist.id, removeIds);

        //Finished moving tracks for the playlist
        adding = false;

        await DatabaseStorage().addTracks(user.spotifyId, selectedTracksMap, playlistIds);

      }
      catch (e){
        error = true;
        throw Exception( exceptionText('select_playlists_view.dart', 'handleOptionSelect', error) );
      }

    }
    //Adds tracks to Playlists
    else {
      final result = await SpotifyRequests().checkRefresh(receivedCall);

      if (result != null){
        receivedCall = result;
      }

      //Update Spotify with the added tracks
      await SpotifyRequests().addTracks(addIds, playlistIds, receivedCall.expiresAt, receivedCall.accessToken)
      .onError((error, stackTrace) {
        error = true;
        throw Exception( exceptionText('select_playlists_view.dart', 'addTracks', error, offset: 3) );
      });

      //Finished adding tracks to 
      adding = false;

      debugPrint('Adding $selectedTracksMap to $playlistIds');
      //Update the database to add the tracks
      await DatabaseStorage().addTracks(user.spotifyId, selectedTracksMap, playlistIds)
      .onError((error, stackTrace) {
        throw Exception( exceptionText('select_playlists_view.dart', 'addTracks', error, offset: 2) );
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
                      id = playEntry.key;
                      if (playEntry.value['chosen']){
                        selectedPlaylistsMap.putIfAbsent(id, () => allPlaylists[id]!);
                      }
                      else{
                        selectedPlaylistsMap.remove(id);
                      }
                    }
                  }

                  if (selectedPlaylistsMap.length == allPlaylists.length) selectAll = true;
                  if (selectedPlaylistsMap.isEmpty) selectAll = false;

                  //Update Selected Playlists
                  setState(() {});
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
                    .onError((error, stackTrace){
                      error = true;
                      throw Exception( exceptionText('select_playlists_view.dart', 'handleOptionSelect', error, offset: 2) );
                    });
                    navigateToTracks();

                    if (!error){
                      //Notification for the User alerting them to the result
                      if(!popup){
                        popup = true;
                        popup = await SelectPopups().success(context, optionMsg);
                      }

                      await SpotifySync().startUpdatePlaylistsTracks(user, receivedCall , playlistIds, scaffoldMessengerState);
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
                      .onError((error, stackTrace){
                        throw Exception( exceptionText('select_playlists_view.dart', 'handleOptionSelect', error, offset: 2));
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


