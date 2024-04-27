// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/select_playlists/select_popups.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/select_playlists/select_search.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/spotify_requests.dart';
import 'package:spotify_music_helper/src/utils/playlist_model.dart';
import 'package:spotify_music_helper/src/utils/track_model.dart';
import 'package:spotify_music_helper/src/utils/user_model.dart';

const String _fileName = 'select_view.dart';

class SelectPlaylistsViewWidget extends StatefulWidget {
  static const String routeName = '/SelectPlaylists';
  const SelectPlaylistsViewWidget({super.key});

  @override
  State<SelectPlaylistsViewWidget> createState() => SelectPlaylistsViewState();
}

class SelectPlaylistsViewState extends State<SelectPlaylistsViewWidget> {
  late ScaffoldMessengerState scaffoldMessengerState;
  late SpotifyRequests _spotifyRequests ;

  /// Passed variables
  Map<String, TrackModel> selectedTracksMap = <String, TrackModel>{};
  PlaylistModel currentPlaylist = PlaylistModel();
  String option = '';

  /// Variables in storage
  late UserModel user;

  /// Playlist Variables
  List<PlaylistModel> allPlaylistsList = <PlaylistModel>[];

  RxMap<String, PlaylistModel> selectedPlaylistsMap = <String, PlaylistModel>{}.obs;

  /// Stores [Key: playlist ID, Values: Title, bool of if 'chosen', image]
  List<MapEntry<String, dynamic>> selectedPlaylistsList = <MapEntry<String, dynamic>>[];
  List<String> playlistIds = <String>[];
  bool selectAll = false;

  /// Page View state variables
  bool loaded = false;
  bool adding = false;
  bool error = false;
  bool refresh = false;
  bool selectUpdating = false;
  bool popup = false;

  @override
  void initState() {
    super.initState();
    try{
      _spotifyRequests = SpotifyRequests.instance;
    }
    catch (e){
      _spotifyRequests = Get.put(SpotifyRequests());
    }
    final TrackArguments trackArgs = Get.arguments;
    selectedTracksMap = trackArgs.selectedTracks;
    currentPlaylist = trackArgs.currentPlaylist;
    option = trackArgs.option;
    user = _spotifyRequests.user;
  }

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    scaffoldMessengerState = ScaffoldMessenger.of(context);
  }

  ///Updates the List of selected playlists.
  void selectPlaylistsListUpdate(){
    allPlaylistsList = List.generate(_spotifyRequests.allPlaylists.length, (int index) => _spotifyRequests.allPlaylists.entries.elementAt(index).value);
    allPlaylistsList.sort((PlaylistModel a, PlaylistModel b) => a.title.compareTo(b.title));

    selectedPlaylistsList = List.generate(allPlaylistsList.length, (int index) {
        PlaylistModel currPlaylist = allPlaylistsList[index];

        String playlistTitle = currPlaylist.title;
        String playlistId = currPlaylist.id;
        String imageUrl = currPlaylist.imageUrl;
        bool selected = false;

        if (selectedPlaylistsMap.containsKey(playlistId)){
          selected = true;
        }

        Map<String, dynamic> selectMap = <String, dynamic>{'chosen': selected, 'title': playlistTitle, 'imageUrl': imageUrl};

        return MapEntry(playlistId, selectMap);
    });
    
    selectUpdating = false;
  }

  /// Selects all of the playlists.
  void handleSelectAll(){
    selectUpdating = true;

    if (selectAll){
      selectedPlaylistsMap.addAll(_spotifyRequests.allPlaylists);
    }
    else{
      selectedPlaylistsMap.clear();
    }

    selectPlaylistsListUpdate();
    //Select All playlists
    //if(mounted) setState(() {});
  }

  /// Check if the playlists were passed correctly.
  Future<void> _checkPlaylists() async{
    try{
      if(mounted && !loaded && !selectUpdating && (_spotifyRequests.allPlaylists.isEmpty || refresh)){
        await _spotifyRequests.requestPlaylists(refresh: refresh);
        selectUpdating = true;

        selectPlaylistsListUpdate();

        loaded = true;
      }
      else if (mounted && !loaded){
        selectUpdating = true;
        selectPlaylistsListUpdate();

        loaded = true;
      }
    }
    catch (e, stack){
      error = true;
      FileErrors.logError(error, stack);
    }

  }

  /// Handles what to do when the user selects the Move/Add Tracks button
  Future<void> handleOptionSelect() async {

    //Get Ids for selected Ids
    for (MapEntry<String, PlaylistModel> playlist in selectedPlaylistsMap.entries) {
      playlistIds.add(playlist.key);
    }

    //Move tracks to Playlists
    if (option == 'move') {

      try{
        //Add tracks to selected playlists
        await _spotifyRequests.addTracks(playlistIds, tracksMap: selectedTracksMap);

        //Remove tracks from current playlist
        await _spotifyRequests.removeTracks(selectedTracksMap, currentPlaylist.id, currentPlaylist.snapshotId);

        //Finished moving tracks for the playlist
        adding = false;
      }
      catch (e, stack){
        error = true;
        throw CustomException(stack: stack, fileName: _fileName, functionName: 'handleOptionSelect', error: error);
      }

    }
    //Adds tracks to Playlists
    else {
      try{
        //Update Spotify with the added tracks
        await _spotifyRequests.addTracks(playlistIds, tracksMap: selectedTracksMap);

        //Finished adding tracks to 
        adding = false;

        debugPrint('Adding $selectedTracksMap to $playlistIds');
        //Update the database to add the tracks
        //await _spotifyRequests.addTracks(selectedTracksMap, playlistIds);
      }
      catch (e, stack){
        error = true;
        throw CustomException(stack: stack, fileName: _fileName, functionName: 'handleOptionSelect', error: error);
      }

    }
  }

  Future<void> refreshPlaylists() async{
    loaded = false;
    refresh = true;
    selectedPlaylistsMap.clear();
    _checkPlaylists();
    // setState(() {
    //   //Refresh page
    // });
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
        centerTitle: true,

        //Refresh Button
        bottom: Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
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
        actions: <Widget>[

          //Search Button
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                if (loaded && !selectUpdating){
                  final result = await showSearch(
                      context: context,
                      delegate: SelectPlaylistSearchDelegate(_spotifyRequests.allPlaylists, selectedPlaylistsMap)
                  );
                  if(result != null){
                    selectedPlaylistsList = result;
                    String id;
                    for (MapEntry<String, dynamic> playEntry in result as List<MapEntry<String, dynamic>>){
                      id = playEntry.key;
                      if (playEntry.value['chosen']){
                        selectedPlaylistsMap.putIfAbsent(id, () => _spotifyRequests.allPlaylists[id]!);
                      }
                      else{
                        selectedPlaylistsMap.remove(id);
                      }
                    }
                  }

                  if (selectedPlaylistsMap.length == _spotifyRequests.allPlaylists.length) selectAll = true;
                  if (selectedPlaylistsMap.isEmpty) selectAll = false;

                  //Update Selected Playlists
                  setState(() {});
                }
              }),
        ],
      ),
      body: FutureBuilder(
        future: _checkPlaylists(), 
        builder: (_, __) {
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
      itemCount: _spotifyRequests.allPlaylists.length,
      itemBuilder: (_, int index) {
        PlaylistModel playModel = allPlaylistsList[index];
        String playTitle = playModel.title;
        String playId = playModel.id;
        String imageUrl = playModel.imageUrl;

        bool chosen = selectedPlaylistsList[index].value['chosen'];
        Map<String, dynamic> selectMap = <String,dynamic >{'chosen': !chosen, 'title': playTitle, 'imageUrl': imageUrl};

        if (option == 'move' && currentPlaylist.title == playTitle){
          return Container();
        }

        return Column(
          children: <Widget>[
            Obx(() => InkWell(
              onTap: () {
                if(selectedPlaylistsMap[playId] == null){
                  selectedPlaylistsMap[playId] = _spotifyRequests.allPlaylists[playId]!;
                  selectedPlaylistsList[index] = MapEntry(playId, selectMap);
                }
                else{
                  selectedPlaylistsMap.remove(playId);
                  selectedPlaylistsList.removeAt(index);
                }
              },
              child: ListTile(
                leading: Checkbox(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  value: selectedPlaylistsMap[playId] != null,
                  onChanged: (_) {
                    if(selectedPlaylistsMap[playId] == null){
                      selectedPlaylistsMap[playId] = _spotifyRequests.allPlaylists[playId]!;
                      selectedPlaylistsList[index] = MapEntry(playId, selectMap);
                    }
                    else{
                      selectedPlaylistsMap.remove(playId);
                      selectedPlaylistsList.removeAt(index);
                    }
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
            )),

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

    int totalChosen = selectedTracksMap.length;
                  
    /// Sets variables for User Notification
    int totalPlaylists = selectedPlaylistsMap.length;

    //Message to display to the user
    String optionMsg = (option == 'move')
    ? 'Successfully moved $totalChosen songs to $totalPlaylists playlists'
    : 'Successfully added $totalChosen songs to $totalPlaylists playlists';

    return BottomAppBar(
      color: spotHelperGreen,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[

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

                    await handleOptionSelect();
                    Get.back();

                    if (!error){
                      //Notification for the User alerting them to the result
                      if(!popup){
                        popup = true;
                        popup = await SelectPopups().success(context, optionMsg);
                      }
                      for(MapEntry<String, PlaylistModel> playlist in selectedPlaylistsMap.entries){
                        _spotifyRequests.requestTracks(playlist.value.id);
                      }
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
                children: <Widget>[
                //Text & Icon dependent on what page the user chose to go
                //Move or Add
                IconButton(
                  icon: optionIcon,
                  onPressed: () async {
                    if (selectedTracksMap.isNotEmpty){
                      adding = true;

                      setState(() {
                        //Updates adding
                      });

                      await handleOptionSelect();
                      Get.back();

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
                children: <Widget>[
                  Checkbox(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    value: selectAll, 
                    onChanged: (bool? value) {
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


