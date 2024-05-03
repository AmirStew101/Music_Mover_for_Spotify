// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/select_playlists/select_view.dart';
import 'package:spotify_music_helper/src/utils/ads.dart';
import 'package:spotify_music_helper/src/tracks/tracks_popups.dart';
import 'package:spotify_music_helper/src/utils/class%20models/custom_sort.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/spotify_requests.dart';
import 'package:spotify_music_helper/src/tracks/tracks_search.dart';
import 'package:spotify_music_helper/src/utils/global_classes/options_menu.dart';
import 'package:spotify_music_helper/src/utils/class%20models/playlist_model.dart';
import 'package:spotify_music_helper/src/utils/class%20models/track_model.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';
import 'package:url_launcher/url_launcher.dart';

const String _fileName = 'tracks_view.dart';

class TracksView extends StatefulWidget {
  const TracksView({super.key});

  @override
  State<TracksView> createState() => TracksViewState();
}

class _UiText{
  final String loading = 'Loading Tracks';
  final String syncing = 'Syncing Tracks';
  final String empty = 'No tracks in Playlist.';
  final String error = 'Error retreiving Tracks. \nCheck connection and Refresh page.';
}

class TracksViewState extends State<TracksView> with SingleTickerProviderStateMixin{
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  late SpotifyRequests _spotifyRequests;

  late PlaylistModel currentPlaylist;
  late UserModel user;

  /// All of the selected tracks.
  /// 
  /// key: Track ID
  /// 
  /// values: TrackModel {Id, Track Title, Artist, Image Url, PreviewUrl}
  RxList<TrackModel> selectedTracksList = <TrackModel>[].obs;

  final ValueNotifier loaded = ValueNotifier(false);

  bool refresh = false;
  bool error = false;
  bool removing = false;
  
  late TabController tabController;

  RxString sortType = Sort().title.obs;

  @override
  void initState(){
    super.initState();
    try{
      _spotifyRequests = SpotifyRequests.instance;
      currentPlaylist = _spotifyRequests.currentPlaylist;
      print('Init Playlists: ${currentPlaylist.title}');
      print('Init Tracks: ${currentPlaylist.tracks}');
    }
    catch (e){
      print('Error Tracks go Back $e');
      Get.back(result: false);
    }

    user = _spotifyRequests.user;
    tabController = TabController(length: 2, vsync: this);
    _checkTracks();
  }

  @override
  void dispose(){
    tabController.dispose();
    super.dispose();
  }

  /// Updates how the tracks are sorted.
  void sortUpdate() {
    print('Sort: ${currentPlaylist.title} Requests Tracks ${_spotifyRequests.playlistTracks.length}');

    // Sorts the tracks based on the current sort type.
    if(sortType == Sort().addedAt){
      _spotifyRequests.sortTracks(sortType.value, addedAt: true);
    }
    else if(sortType == Sort().artist){
      _spotifyRequests.sortTracks(sortType.value, artist: true);
    }
    else if(sortType == Sort().type){
      _spotifyRequests.sortTracks(sortType.value, type: true);
    }
    // Default title sort
    else{
      _spotifyRequests.sortTracks(sortType.value);
    }

    print('Sorted: ${currentPlaylist.title} Tracks ${_spotifyRequests.playlistTracks.length}');
  }

  ///Page state setup Function to setup the page.
  Future<void> _checkTracks() async{

    // Keeps from repeating functions
    if(!loaded.value){
      try{
        if (mounted && (currentPlaylist.tracks.isEmpty || refresh)){
          print('Playlist empty: ${currentPlaylist.tracks}');
          await fetchSpotifyTracks();
        }
        else if(mounted){
          print('Tracks Loaded');
          loaded.value = true;
        }
      }
      catch (e, stack){
        print('Error Loading tracks');
        error = true;
        loaded.value = true;
        _crashlytics.recordError(e, stack, reason: 'Failed while Fetching Spotify Tracks', fatal: true);
      }
    }
  }//checkLogin

  /// Gets the users tracks for the selected Playlist
  Future<void> fetchSpotifyTracks() async {
    try{
      await _spotifyRequests.requestTracks(currentPlaylist.id);
      currentPlaylist = _spotifyRequests.currentPlaylist;
      sortUpdate();

      if (mounted) {
        loaded.value = true;
        refresh = false;
        error = false;
      }
    }
    catch (e){
      throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'fetchSpotifyTracks',  error: e);
    }
  }

  void handleSelectAll(){
    print('Select All');
    if (selectedTracksList.length != currentPlaylist.tracks.length){
      selectedTracksList.clear();
      selectedTracksList.addAll(currentPlaylist.tracks);
    }
    else{
      selectedTracksList.clear();
    }
  }


  ///Refreshes the page with function constraints to skip unnecessary steps on page refresh after deleteing tracks.
  ///
  ///Clears the selected tracks to realign the view.
  Future<void> handleDeleteRefresh() async{
    print('Delete Refresh');
    loaded.value = false;
    error = false;
    removing = false;
    refresh = true;

    selectedTracksList.clear();
    _checkTracks();
  }

  ///Refreshes the page with function constraints to skip unnecessary steps on page refresh.
  Future<void> handleRefresh() async{
    print('Refresh');
    refresh = true;
    loaded.value = false;
    error = false;

    selectedTracksList.clear();
    _checkTracks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: tracksAppBar(),

        drawer: optionsMenu(context),

        // Loads the users tracks and its associated images after fetching them for user viewing
        body: PopScope(
          child: ValueListenableBuilder<dynamic>(
            valueListenable: loaded, 
            builder: (_, __, ___) {
              if (!loaded.value && !error){
                return Center(
                    child: CircularProgressIndicator(color: spotHelperGreen,)
                );
              }
              // Playlist has tracks and Tracks finished loading
              else if (loaded.value && currentPlaylist.tracks.isNotEmpty) {
                return Stack(
                  children: <Widget>[
                    tracksViewBody(),
                    Ads().setupAds(context, user)
                  ],
                );
              }
              else {
                return Stack(
                  children: <Widget>[
                    Center(
                      child: Text(
                        error ? _UiText().error : _UiText().empty,
                        textScaler: const TextScaler.linear(2),
                        textAlign: TextAlign.center,
                      )
                    ),
                    Ads().setupAds(context, user)
                  ],
                );
              }
            },
          )
        ),

        bottomNavigationBar: tracksBottomBar(),
      );
  }

  AppBar tracksAppBar(){
     return AppBar(
      leading: Builder(
        builder: (BuildContext context) => IconButton(
          icon: const Icon(Icons.menu), 
          onPressed: ()  {
            Scaffold.of(context).openDrawer();
          },
        )
      ),

      title: Text(
        //Playlist Name
        currentPlaylist.title,
        textAlign: TextAlign.center,
      ),
      centerTitle: true,

      backgroundColor: spotHelperGreen,

      actions: <Widget>[

        // Filter button
        IconButton(
          onPressed: (){
            Get.dialog(
              AlertDialog.adaptive(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filters:',
                      textAlign: TextAlign.center,
                    ),
                    Obx(() => IconButton(
                      onPressed: () {
                        _spotifyRequests.tracksAsc = !_spotifyRequests.tracksAsc;
                        sortUpdate();
                      }, 
                      icon: _spotifyRequests.tracksAsc
                      ? const Icon(
                        Icons.arrow_upward_sharp,
                        color: Colors.green,
                      )
                      : const Icon(Icons.arrow_downward_sharp,
                        color: Colors.green,
                      )
                    )),
                  ]
                ),
                actions: [
                  Obx(() => SwitchListTile.adaptive(
                    title: const Text('Title'),
                    value: sortType == Sort().title,
                    onChanged: (_) {
                      print('Title Switch');
                      sortType.value = Sort().title;
                      sortUpdate();
                    },
                  )),

                  Obx(() => SwitchListTile.adaptive(
                    title: const Text('Artist'),

                    value: sortType == Sort().artist,
                    onChanged: (_) {
                      print('Artist Switch');
                      sortType.value = Sort().artist;
                      sortUpdate();
                    },
                  )),

                  Obx(() => SwitchListTile.adaptive(
                    title: const Text('Added At'),

                    value: sortType == Sort().addedAt,
                    onChanged: (_) {
                      print('Added At Switch');
                      sortType.value = Sort().addedAt;
                      sortUpdate();
                    },
                  )),

                  Obx(() => SwitchListTile.adaptive(
                    title: const Text('Type'),
                    value: sortType == Sort().type,
                    onChanged: (_) {
                      print('Type Switch');
                      sortType.value = Sort().type;
                      sortUpdate();
                    },
                  )),
                ],
              )
            );
          }, 
          icon: const Icon(Icons.filter_alt_rounded)
        ),

        //Search Button
        IconButton(
          icon: const Icon(Icons.search),

          onPressed: () async {
            if (loaded.value){
              final queryResult = await showSearch(
                  context: context,
                  delegate: TracksSearchDelegate(currentPlaylist, selectedTracksList)
              );
              
              if (queryResult != null){
                selectedTracksList = queryResult;
              }
            }
          }
        ),
      ],

      bottom: TabBar(
        tabAlignment: TabAlignment.center,
        indicatorColor:spotHelperGreen,
        controller: tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.grey,
        tabs: <Widget>[
          //Refresh tracks for the current Paylist
          Tab(
            child: InkWell(
              onTap: () async{
                handleRefresh();
              },
              child: Row(
                children: <Widget>[ 
                  IconButton(
                    icon: const Icon(Icons.sync_sharp),
                    onPressed: () async{
                      handleRefresh();
                    },
                  ),
                  const Text('Refresh'),
                ],
              ),
            )
          ),
          
          //Select All checkbox.
          Tab(
            child: InkWell(
              onTap: () {
                handleSelectAll();
              },
              child: Row(
                children: <Widget>[
                   Obx(() => Checkbox(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    value: selectedTracksList.length == currentPlaylist.tracks.length && loaded.value,
                    onChanged: (_) {
                      handleSelectAll();
                    },
                  )),
                  const Text('Select All'),
                ],
              ),
            )
          ),
        ]),
    );
  }

  Widget tracksViewBody(){
    //Stack for the hovering select all button & tracks view
    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            Expanded(
              child: 
              Obx(() => ListView.builder(
                itemCount: _spotifyRequests.playlistTracks.length,
                itemBuilder: (_, int index) {
                  final TrackModel currTrack = _spotifyRequests.playlistTracks[index];

                  //Alligns the songs as a Column
                  return Column(
                    children: <Widget>[
                      //Lets the entire left section with checkbox and Title be selected
                      InkWell(
                        onTap: () {
                          if (!selectedTracksList.contains(currTrack)){
                            selectedTracksList.add(currTrack);
                          }
                          else{
                            selectedTracksList.remove(currTrack);
                          }
                        },
                        //Container puts the Tracks image in the background
                        child: Container(
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            // Album Image for Track
                            image: DecorationImage(
                              alignment: Alignment.centerRight,
                              image: NetworkImage(currTrack.imageUrl),
                              fit: BoxFit.contain,
                            ),
                            shape: BoxShape.rectangle
                          ),

                          //Aligns the Track Name, Checkbox, Artist Name, Preview Button as a Row
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            mainAxisSize: MainAxisSize.max,
                            children: <Widget>[
                              trackRows(index, currTrack),

                              // The Liked Songs icon and Track link
                              Row(
                                children: <Widget>[
                                  if(currTrack.liked)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Image.asset(
                                      unlikeHeart,
                                      width: 21.0,
                                      height: 21.0,
                                      color: Colors.green,
                                      fit: BoxFit.cover,
                                    ),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.only(right: 60),
                                    child: InkWell(
                                      onTap: () async{
                                        try{
                                          final bool response = await launchUrl(Uri.parse(currTrack.albumLink));

                                          if(!response) TracksViewPopups().errorLink('Track');
                                        }
                                        catch (e){
                                          TracksViewPopups().errorLink('Track');
                                        }
                                      },
                                      child: const Icon(
                                        Icons.link,
                                        color: Colors.blue,
                                      ),
                                    )
                                  ),
                                ],
                              ),
                            ],
                          )
                        )
                      ),
                    
                      //The grey divider line between each Row to look nice
                      const Divider(
                        height: 1,
                        color: Colors.grey,
                      ),

                      //Makes space so last item isn't behind ad
                      if (index == _spotifyRequests.playlistTracks.length-1)
                        const SizedBox(
                          height: 90,
                        ),
                    ]
                  );
                }
              )),
              
            ),
          ],
        )
    ] );
  }

  /// Creates the State for each Tracks Row
  Widget trackRows(int index, TrackModel track) {
    String artistText = '';

    if(track.artists.length > 1){
      artistText = 'By: ${track.artistNames[0]}...';
    }
    else{
      artistText = 'By: ${track.artistNames[0]}';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        //Design & Functinoality for the checkbox button when selected and not
        Obx(() => Checkbox(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          value: selectedTracksList.contains(track),
          onChanged: (_) {
            if (!selectedTracksList.contains(track)){
              selectedTracksList.add(track);
            }
            else{
              selectedTracksList.remove(track);
            }
          },
        )),

        //Track Names & Artist Names design and Functionality
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          //Name of the Track shown to user
          children: <Widget>[
            Text(
              track.title.length > 20
              ? '${track.title.substring(0, 20)}...'
              : track.title,
              textScaler: const TextScaler.linear(1.2),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: spotHelperGreen),
            ),
            //Name of track Artist show to user
            InkWell(
              onTap: () {
                Get.bottomSheet(
                  backgroundColor: Get.theme.canvasColor,
                  ListView.builder(
                    itemCount: track.artists.length+1,
                    itemBuilder: (_, int index) {
                      if(index == 0){
                        return Column(
                          children: [
                            const Text(
                              'Artists Links',
                              textScaler: TextScaler.linear(1.2),
                            ),
                            customDivider()
                          ]
                        );
                      }
                      return Column(
                        children: <Widget>[
                          TextButton(
                            onPressed: () async{
                              try{
                                final bool response = await launchUrl(Uri.parse(track.artistLinks[index-1]));

                                if(!response) TracksViewPopups().errorLink('Artists');
                              }
                              catch (e){
                                TracksViewPopups().errorLink('Artists');
                              }
                            }, 
                            child: Text(
                              track.artistNames[index-1],
                              style: TextStyle(
                                color: linkBlue,
                              ),
                            ),
                          ),
                          customDivider()
                        ],
                      );
                    },
                  ),
                );
              },
              child: Text(
                artistText,
                textScaler: const TextScaler.linear(0.8),
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
            ),
            
          ]
        ),

      ]
    );
  }

  Widget tracksBottomBar(){
      return BottomNavigationBar(
        backgroundColor: spotHelperGreen,
        items: const <BottomNavigationBarItem>[
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
        onTap: (int value) async {
          // Move to playlist(s) Index
          if (value == 0 && selectedTracksList.isNotEmpty && loaded.value) {
            TrackArguments trackArgs = TrackArguments(selectedTracks: selectedTracksList, option: 'move');

            await Get.to(const SelectPlaylistsViewWidget(), arguments: trackArgs);
            await handleDeleteRefresh();
          }
          // Add to playlist(s) index
          else if (value == 1 && selectedTracksList.isNotEmpty && loaded.value) {
            TrackArguments trackArgs = TrackArguments(selectedTracks: selectedTracksList, option: 'add');

            await Get.to(const SelectPlaylistsViewWidget(), arguments: trackArgs);
            await handleRefresh();
          } 
          //Removes track(s) from current playlist
          else if (value == 2 && selectedTracksList.isNotEmpty && loaded.value){
            bool confirmed = false;

            await showDialog(
              context: context, 
              builder: (BuildContext context) {
                return AlertDialog.adaptive(
                  title: const Text(
                    'Sure you want to delete these Tracks?',
                    textAlign: TextAlign.center,
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        //Close Popup
                        Get.back();
                      }, 
                      child: const Text('Cancel')
                    ),
                    TextButton(
                      onPressed: () {
                        confirmed = true;
                        //Close Popup
                        Get.back();
                      },
                      child: const Text('Confirm'),
                    ),
                  ],
                );
              },
            );

            if (confirmed){
              removing = true;

              int tracksDeleted = selectedTracksList.length;
              loaded.value = false;
              await _spotifyRequests.removeTracks(selectedTracksList, currentPlaylist, currentPlaylist.snapshotId);
              await handleDeleteRefresh();

              Get.closeAllSnackbars();
              TracksViewPopups().deletedTracks(tracksDeleted, currentPlaylist.title);
            }// User Confirmed Deletion

          }
          // User Hasn't selected a Track
          else {
            Get.closeAllSnackbars();
            TracksViewPopups().noTracks();
          }
        },
      );
  }
}
