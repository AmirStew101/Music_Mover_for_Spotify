// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/select_playlists/select_popups.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/spotify_requests.dart';
import 'package:spotify_music_helper/src/utils/class%20models/playlist_model.dart';
import 'package:spotify_music_helper/src/utils/class%20models/track_model.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';

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
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Passed variables
  List<TrackModel> selectedTracksList = <TrackModel>[];
  String option = '';
  static const move = 'move';
  static const add = 'add';

  /// Variables in storage
  late UserModel user;
  late PlaylistModel currentPlaylist;

  RxList<PlaylistModel> selectedPlaylistList = <PlaylistModel>[].obs;

  /// Page View state variables
  bool loaded = false;
  bool adding = false;
  bool error = false;
  bool refresh = false;
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

    user = _spotifyRequests.user;
    currentPlaylist = _spotifyRequests.currentPlaylist;
    final TrackArguments trackArgs = Get.arguments;
    selectedTracksList = trackArgs.selectedTracks;
    option = trackArgs.option;
  }

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    scaffoldMessengerState = ScaffoldMessenger.of(context);
  }


  /// Check if the playlists were passed correctly.
  Future<void> _checkPlaylists() async{
    try{
      if(mounted && !loaded && (_spotifyRequests.allPlaylists.isEmpty || refresh)){
        await _spotifyRequests.requestPlaylists(refresh: refresh);
        selectedPlaylistList.clear();
      }
      
      if (mounted && !loaded){
        loaded = true;
      }
    }
    catch (e, stack){
      error = true;
      _crashlytics.recordError(e, stack, reason: 'Failed to Request playlists from Spotify', fatal: true);
    }

  }

  /// Handles what to do when the user selects the Move/Add Tracks button
  Future<void> handleOptionSelect() async {

    List<PlaylistModel> selectedList = selectedPlaylistList;
    
    //Move tracks to Playlists
    if (option == 'move') {
      try{
        //Add tracks to selected playlists
        await _spotifyRequests.addTracks(selectedList, selectedTracksList);

        //Remove tracks from current playlist
        await _spotifyRequests.removeTracks(selectedTracksList, currentPlaylist, currentPlaylist.snapshotId);

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
        adding = true;
        //Update Spotify with the added tracks
        await _spotifyRequests.addTracks(selectedList, selectedTracksList);

        //Finished adding tracks to 
        adding = false;
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
    selectedPlaylistList.clear();
    _checkPlaylists();
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
                onPressed: (){
                  if (loaded){
                    refreshPlaylists();
                  }
                }, 
                icon: const Icon(Icons.refresh)
              ),
              InkWell(
                onTap: () {
                  if (loaded){
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
                if (loaded){
                  RxList<PlaylistModel> searchedPlaylists = _spotifyRequests.allPlaylists.obs;

                  Get.dialog(
                    Dialog.fullscreen(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            child: TextField(
                              decoration: InputDecoration(
                                prefixIcon: IconButton(
                                  onPressed: () => Get.back(), 
                                  icon: const Icon(Icons.arrow_back_sharp)
                                ),
                                hintText: 'Search'
                              ),
                              onChanged: (String query) {
                                searchedPlaylists.value = _spotifyRequests.allPlaylists.where((playlist){
                                  final String result;
                                  result = playlist.title.toLowerCase();
                                  
                                  final String input = modifyBadQuery(query).toLowerCase();

                                  return result.contains(input);
                                }).toList();
                              },
                            )
                          ),

                          Expanded(
                            child: Obx(() => ListView.builder(
                              itemCount: searchedPlaylists.length,
                              itemBuilder: (context, index) {
                                PlaylistModel currPlaylist = searchedPlaylists[index];
                                String playImage = currPlaylist.imageUrl;

                                if(option == move && currPlaylist == currentPlaylist){
                                  return Container();
                                }

                                return ListTile(
                                  onTap: () {
                                    if(!selectedPlaylistList.contains(currPlaylist)){
                                      selectedPlaylistList.add(currPlaylist);
                                    }
                                    else{
                                      selectedPlaylistList.remove(currPlaylist);
                                    }
                                  },

                                  leading: Obx(() => Checkbox(
                                    value: selectedPlaylistList.contains(currPlaylist), 
                                    onChanged: (_) {
                                      if(!selectedPlaylistList.contains(currPlaylist)){
                                        selectedPlaylistList.add(currPlaylist);
                                      }
                                      else{
                                        selectedPlaylistList.remove(currPlaylist);
                                      }
                                    }
                                  )),

                                  // Playlist name and Artist
                                  title: Text(
                                    currPlaylist.title, 
                                    textScaler: const TextScaler.linear(1.2)
                                  ),
                                  
                                  trailing: playImage.contains('asset')
                                  ?Image.asset(playImage)
                                  :Image.network(playImage),
                                );
                              }
                            ))
                          )
                        ],
                      ),
                    )
                  );
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
          if(adding){
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          else{
            return selectBodyView();
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
        PlaylistModel playModel = _spotifyRequests.allPlaylists[index];
        String playTitle = playModel.title;
        String imageUrl = playModel.imageUrl;

        if (option == move && currentPlaylist.title == playTitle){
          return Container();
        }

        return Column(
          children: <Widget>[
            InkWell(
              onTap: () {

                if(!selectedPlaylistList.contains(playModel)){
                  selectedPlaylistList.add(playModel);
                }
                else{
                  selectedPlaylistList.remove(playModel);
                }
              },
              child: ListTile(
                leading: Obx(() => Checkbox(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  value: selectedPlaylistList.contains(playModel),
                  onChanged: (_) {

                    if(!selectedPlaylistList.contains(playModel)){
                      selectedPlaylistList.add(playModel);
                    }
                    else{
                      selectedPlaylistList.remove(playModel);
                    }
                  },
                )),
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

    if (option == add) {
      optionIcon = const Icon(Icons.add);
      optionText = 'Add Track(s)';
    }

    int totalChosen = selectedTracksList.length;
                  
    /// Sets variables for User Notification
    int totalPlaylists = selectedPlaylistList.length;

    //Message to display to the user
    String optionMsg = (option == move)
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
                if (selectedTracksList.isNotEmpty){
                  if (!adding){
                    adding = true;
                    int totalChosen = selectedTracksList.length;
                    
                    //Sets variables for User Notification
                    int totalPlaylists = selectedPlaylistList.length;

                    //Message to display to the user
                    String optionMsg = (option == 'move')
                          ? 'Successfully moved $totalChosen songs to $totalPlaylists playlists'
                          : 'Successfully added $totalChosen songs to $totalPlaylists playlists';

                    setState(() {
                      //Updates adding
                    });

                    await handleOptionSelect();
                    Get.back(result: true);

                    if (!error){
                      //Notification for the User alerting them to the result
                      if(!popup){
                        popup = true;
                        popup = await SelectPopups().success(context, optionMsg);
                      }
                      for(PlaylistModel playlist in selectedPlaylistList){
                        _spotifyRequests.requestTracks(playlist.id);
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
                    if (selectedTracksList.isNotEmpty){
                      adding = true;

                      setState(() {
                        //Updates adding
                      });

                      await handleOptionSelect();
                      Get.back(result: true);

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
                if (selectedPlaylistList.length != _spotifyRequests.allPlaylists.length){
                  selectedPlaylistList.clear();
                  selectedPlaylistList.addAll(_spotifyRequests.allPlaylists);
                }
                else{
                  selectedPlaylistList.clear();
                }
              },
              child: Row(
                children: <Widget>[
                  Obx(() => Checkbox(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    value: selectedPlaylistList.length == _spotifyRequests.allPlaylists.length,
                    onChanged: (_) {
                      if (selectedPlaylistList.length != _spotifyRequests.allPlaylists.length){
                        selectedPlaylistList.clear();
                        selectedPlaylistList.addAll(_spotifyRequests.allPlaylists);
                      }
                      else{
                        selectedPlaylistList.clear();
                      }
                    },
                  )),
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


