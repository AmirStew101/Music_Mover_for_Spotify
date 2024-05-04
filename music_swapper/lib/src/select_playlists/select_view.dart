// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/select_playlists/select_popups.dart';
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
  ValueNotifier loaded = ValueNotifier(false);
  bool adding = false;
  bool error = false;
  bool refresh = false;
  bool popup = false;

  @override
  void initState() {
    super.initState();
    _crashlytics.log('Init Select View Page');
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

    _checkPlaylists();
  }

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    scaffoldMessengerState = ScaffoldMessenger.of(context);
  }


  /// Check if the playlists were passed correctly.
  Future<void> _checkPlaylists() async{
    try{
      loaded.value = false;

      if(mounted && !loaded.value && (_spotifyRequests.allPlaylists.isEmpty || refresh)){
        _crashlytics.log('Select View: Request Playlists');
        await _spotifyRequests.requestPlaylists();
        selectedPlaylistList.clear();
        loaded.value = true;
      }
      
      if (mounted && !loaded.value){
        loaded.value = true;
      }
    }
    catch (e, stack){
      error = true;
      loaded.value = true;
      _crashlytics.recordError(e, stack, reason: 'Failed to Request playlists from Spotify', fatal: true);
    }

  }

  /// Handles what to do when the user selects the Move/Add Tracks button
  Future<void> handleOptionSelect() async {

    List<PlaylistModel> selectedList = selectedPlaylistList;
    loaded.value = false;
    adding = true;
    //Move tracks to Playlists
    if (option == 'move') {
      try{
        //Add tracks to selected playlists
        await _spotifyRequests.addTracks(selectedList, selectedTracksList);

        //Remove tracks from current playlist
        await _spotifyRequests.removeTracks(selectedTracksList, currentPlaylist.snapshotId);
      }
      catch (ee, stack){
        adding = false;
        error = true;
        loaded.value = true;
        _crashlytics.recordError(ee, stack, reason: 'handleOptionSelect Failed to edit Tracks');
      }

    }
    //Adds tracks to Playlists
    else {
      try{
        //Update Spotify with the added tracks
        await _spotifyRequests.addTracks(selectedList, selectedTracksList);

        //Finished adding tracks to 
        adding = false;
      }
      catch (ee, stack){
        adding = false;
        error = true;
        loaded.value = true;
        _crashlytics.recordError(ee, stack, reason: 'handleOptionSelect Failed to edit Tracks');
      }
    }

    adding = false;
    loaded.value = true;
  }

  Future<void> refreshPlaylists() async{
    _crashlytics.log('Refresh Playlists');
    loaded.value = false;
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
                onPressed: (){
                  if (!_spotifyRequests.loading.value){
                    refreshPlaylists();
                  }
                }, 
                icon: const Icon(Icons.refresh)
              ),
              InkWell(
                onTap: () {
                  if (!_spotifyRequests.loading.value){
                    refreshPlaylists();
                  }
                },
                child: const Text('Refresh'),
              )
            ],),
        ),
        actions: <Widget>[

          // Search Button
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                if (loaded.value){
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
    int totalChosen = selectedTracksList.length;

    /// Sets variables for User Notification
    int totalPlaylists = selectedPlaylistList.length;

    Icon optionIcon = const Icon(Icons.drive_file_move_outlined);
    String optionText = option == add ? 'Add Tracks' : 'Move Tracks';

    //Message to display to the user
    String optionMsg = option == move
    ? 'Successfully moved $totalChosen songs to $totalPlaylists playlists'
    : 'Successfully added $totalChosen songs to $totalPlaylists playlists';

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
                  if (!adding){
                    adding = true;

                    await handleOptionSelect();
                    _crashlytics.log('Playlists edited Go back');
                    Get.back(result: true);

                    //Notification for the User alerting them to the result
                    if(!popup){
                      popup = true;
                      popup = await SelectPopups().success(context, optionMsg);
                    }

                    if(!error){
                      for(PlaylistModel playlist in selectedPlaylistList){
                        _spotifyRequests.requestTracks(playlist.id);
                      }
                    }
                  }
                }
                else{
                  Get.snackbar(
                    '',
                    '',
                    titleText: const Text(
                      'No Tracks Selected',
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.linear(1.2),
                    ),
                    backgroundColor: snackBarGrey,
                    isDismissible: true,
                    snackPosition: SnackPosition.TOP,
                  );
                }
              },

              // Icon dependent on what page the user chose to go either 'Move' or 'Add' Icon
              leading: IconButton(
                icon: optionIcon,
                onPressed: () async {
                  if (selectedTracksList.isNotEmpty && selectedPlaylistList.isNotEmpty){
                    adding = true;
                    loaded.value = false;

                    await handleOptionSelect();
                    _crashlytics.log('Playlists edited Go back');
                    Get.back(result: true);

                    if(!popup){
                      popup = true;
                      popup = await SelectPopups().success(context, optionMsg);
                    }
                  }
                  else{
                    Get.snackbar(
                      'No Tracks Selected', 
                      '',
                      backgroundColor: snackBarGrey,
                      isDismissible: true,
                      snackPosition: SnackPosition.TOP
                    );
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
                value: selectedPlaylistList.length == _spotifyRequests.allPlaylists.length,
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


