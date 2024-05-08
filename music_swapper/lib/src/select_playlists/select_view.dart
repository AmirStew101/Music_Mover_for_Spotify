// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:music_mover/src/select_playlists/select_popups.dart';
import 'package:music_mover/src/utils/exceptions.dart';
import 'package:music_mover/src/utils/global_classes/global_objects.dart';
import 'package:music_mover/src/utils/globals.dart';
import 'package:music_mover/src/utils/backend_calls/spotify_requests.dart';
import 'package:music_mover/src/utils/class%20models/playlist_model.dart';
import 'package:music_mover/src/utils/class%20models/track_model.dart';

class SelectPlaylistsViewWidget extends StatefulWidget {
  static const String routeName = '/SelectPlaylists';
  const SelectPlaylistsViewWidget({super.key});

  @override
  State<SelectPlaylistsViewWidget> createState() => SelectPlaylistsViewState();
}

class SelectPlaylistsViewState extends State<SelectPlaylistsViewWidget> {
  late SpotifyRequests _spotifyRequests ;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Passed variables
  List<TrackModel> selectedTracksList = <TrackModel>[];
  String option = '';
  static const move = 'move';
  static const add = 'add';

  RxList<PlaylistModel> selectedPlaylistList = <PlaylistModel>[].obs;

  /// Page View state variables
  ValueNotifier loaded = ValueNotifier(false);
  bool error = false;

  bool refresh = false;

  @override
  void initState() {
    super.initState();
    _crashlytics.log('Init Select View Page');

    final TrackArguments? trackArgs = Get.arguments;
    if(trackArgs == null){
      _crashlytics.recordError('Missing Track Arguments in Select View', StackTrace.current, reason: 'Missiing state argumentes');
      Get.back();
    }
    else{
      _spotifyRequests = trackArgs.spotifyRequests;
      selectedTracksList = trackArgs.selectedTracks;
      option = trackArgs.option;
      _checkPlaylists();
    }
  }

  /// Check if the playlists were passed correctly.
  Future<void> _checkPlaylists() async{
    try{
      loaded.value = false;

      if(mounted && (_spotifyRequests.allPlaylists.isEmpty || refresh)){
        _crashlytics.log('Select View: Request Playlists');
        await _spotifyRequests.requestPlaylists();
        selectedPlaylistList.clear();
      }
    }
    on CustomException catch (ee, stack){
      error = true;
      _crashlytics.recordError(ee.error, stack, reason: ee.reason, fatal: ee.fatal);
    }
    catch (ee, stack){
      error = true;
      _crashlytics.recordError(ee, stack, reason: 'Failed to Request playlists from Spotify', fatal: true);
    }

    loaded.value = true;

  }

  /// Handles what to do when the user selects the Move/Add Tracks button
  Future<bool> handleOptionSelect() async {
    List<PlaylistModel> selectedList = selectedPlaylistList;
    //Move tracks to Playlists
    if (option == 'move') {
      try{
        //Add tracks to selected playlists
        bool response = await _spotifyRequests.addTracks(selectedList, selectedTracksList);
        if(!response){
          error = true;
          loaded.value = true;
          Get.closeAllSnackbars();
          SelectPopups.failedAdd();
          return false;
        }

        //Remove tracks from current playlist
        response = await _spotifyRequests.removeTracks(selectedTracksList, _spotifyRequests.currentPlaylist.snapshotId);
        if(!response){
          error = true;
          loaded.value = true;
          Get.closeAllSnackbars();
          SelectPopups.failedRemove();
          return false;
        }
      }
      catch (ee, stack){
        error = true;
        loaded.value = true;
        _crashlytics.recordError(ee, stack, reason: 'handleOptionSelect Failed to edit Tracks');
        return false;
      }
    }
    //Adds tracks to Playlists
    else {
      try{
        //Update Spotify with the added tracks
        bool response = await _spotifyRequests.addTracks(selectedList, selectedTracksList);
        if(!response){
          error = true;
          loaded.value = true;
          Get.closeAllSnackbars();
          SelectPopups.failedAdd();
          return false;
        }
      }
      catch (ee, stack){
        error = true;
        loaded.value = true;
        _crashlytics.recordError(ee, stack, reason: 'handleOptionSelect Failed to edit Tracks');
        return false;
      }
    }

    loaded.value = true;
    return true;
  }

  Future<void> refreshPlaylists() async{
    if(_spotifyRequests.shouldRefresh(loaded.value, refresh)){
      _crashlytics.log('Refresh Playlists');
      loaded.value = false;
      error = false;
      refresh = true;
      selectedPlaylistList.clear();
      _checkPlaylists();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: spotHelperGreen,
        title: const Text(
          'Playlists Select',
          textAlign: TextAlign.center,
        ),
        centerTitle: true,

        //Refresh Button
        bottom: Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                onPressed: () => refreshPlaylists(), 
                icon: const Icon(Icons.refresh)
              ),
              InkWell(
                onTap: () => refreshPlaylists(),
                child: const Text('Refresh'),
              )
            ],),
        ),
        actions: <Widget>[

          // Search Button
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                if (loaded.value && !_spotifyRequests.loading.value){
                  _crashlytics.log('Search Selectable Playlists');
                  RxList<PlaylistModel> searchedPlaylists = _spotifyRequests.allPlaylists.obs;

                  Get.dialog(
                    Dialog.fullscreen(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                height: 50,
                                width: 250,
                                child: TextField(
                                  decoration: InputDecoration(
                                    icon: IconButton(
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
                              const SizedBox(width: 15,),

                              // Select all button
                              Obx(() => FilterChip(
                                backgroundColor: Colors.grey,
                                label: const Text('Select All'),

                                selected: selectedPlaylistList.length == _spotifyRequests.allPlaylists.length,
                                selectedColor: spotHelperGreen,

                                onSelected: (_) {
                                  if(selectedPlaylistList.length != _spotifyRequests.allPlaylists.length){
                                    selectedPlaylistList.clear();
                                    selectedPlaylistList.addAll(_spotifyRequests.allPlaylists);
                                  }
                                  else{
                                    selectedPlaylistList.clear();
                                  }
                                },
                              )),
                            ]
                          ),

                          Expanded(
                            child: Obx(() => ListView.builder(
                              itemCount: searchedPlaylists.length,
                              itemBuilder: (context, index) {
                                PlaylistModel currPlaylist = searchedPlaylists[index];
                                String playImage = currPlaylist.imageUrl;

                                if(option == move && currPlaylist == _spotifyRequests.currentPlaylist){
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
      body: ValueListenableBuilder(
        valueListenable: loaded,
        builder: (_, __, ___) {
          if (error){
            return const Center(
              child: Text(
                'Error retreiving Playlists from Spotify. Check connection and Refresh page.',
                textScaler: TextScaler.linear(2),
                textAlign: TextAlign.center,
              )
            );
          }
          if(!loaded.value){
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

        if (option == move && _spotifyRequests.currentPlaylist.title == playTitle){
          return Container();
        }

        return Column(
          children: <Widget>[
            // Select Playlist
            InkWell(
              onTap: () {
                _crashlytics.log('Select Playlist');
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
                    _crashlytics.log('Select Playlist');
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
    Icon optionIcon = const Icon(Icons.drive_file_move_outlined);
    String optionText = option == add ? 'Add Tracks' : 'Move Tracks';

    /// Message to display to the user.
    late String optionMsg;

    return BottomAppBar(
      color: spotHelperGreen,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[

          // Move/Add button to add tracks to Playlist(s)
          Expanded(
            child: ListTile(
              onTap: () async {
                if (selectedTracksList.isNotEmpty && selectedPlaylistList.isNotEmpty){
                  if (loaded.value){
                    loaded.value = false;

                    optionMsg = option == move
                    ? 'Successfully moved ${selectedTracksList.length} songs to ${selectedPlaylistList.length} playlists'
                    : 'Successfully added ${selectedTracksList.length} songs to ${selectedPlaylistList.length} playlists';

                    bool modified = await handleOptionSelect();
                    _crashlytics.log('Playlists edited Go back');
                    Get.back(result: true);

                    if(modified){
                      //Notification for the User alerting them to the result
                      Get.closeAllSnackbars();
                      SelectPopups.success(optionMsg);
                    }

                    if(!error){
                      for(PlaylistModel playlist in selectedPlaylistList){
                        _spotifyRequests.requestTracks(playlist.id);
                      }
                    }
                  }
                }
                else{
                  Get.closeAllSnackbars();
                  SelectPopups.noPlaylists();
                }
              },

              // Icon dependent on what page the user chose to go either 'Move' or 'Add' Icon
              leading: IconButton(
                icon: optionIcon,
                onPressed: () async {
                  if (selectedTracksList.isNotEmpty && selectedPlaylistList.isNotEmpty){
                    loaded.value = false;

                    optionMsg = option == move
                    ? 'Successfully moved ${selectedTracksList.length} songs to ${selectedPlaylistList.length} playlists'
                    : 'Successfully added ${selectedTracksList.length} songs to ${selectedPlaylistList.length} playlists';

                    bool modified = await handleOptionSelect();
                    _crashlytics.log('Playlists edited Go back');
                    Get.back(result: true);

                    if(modified){
                      //Notification for the User alerting them to the result
                      Get.closeAllSnackbars();
                      SelectPopups.success(optionMsg);
                    }
                  }
                  else{
                    Get.closeAllSnackbars();
                    SelectPopups.noPlaylists();
                  }
                },
              ),

              // Text dependent on what page the user chose to go either 'Move' or 'Add' Text
              title: Text(
                optionText,
                textAlign: TextAlign.center,
              ),
            )
          ),

          const VerticalDivider(
            color: Colors.grey,
          ),

          // Select All button
          Expanded(
            child:
            ListTile(
              onTap: () {
                _crashlytics.log('Select All');
                if (selectedPlaylistList.length != _spotifyRequests.allPlaylists.length){
                  selectedPlaylistList.clear();
                  selectedPlaylistList.addAll(_spotifyRequests.allPlaylists);
                }
                else{
                  selectedPlaylistList.clear();
                }
              },

              leading: Obx(() => Checkbox(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                value: selectedPlaylistList.length == _spotifyRequests.allPlaylists.length && _spotifyRequests.allPlaylists.isNotEmpty,
                onChanged: (_) {
                  _crashlytics.log('Select All');
                  if (selectedPlaylistList.length != _spotifyRequests.allPlaylists.length){
                    selectedPlaylistList.clear();
                    selectedPlaylistList.addAll(_spotifyRequests.allPlaylists);
                  }
                  else{
                    selectedPlaylistList.clear();
                  }
                },
              )),

              title: const Text('Select All'),
            )
          ),
        ],
      )
    );
  }

}


