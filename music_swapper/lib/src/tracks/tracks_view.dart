// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:music_mover/src/select_playlists/select_view.dart';
import 'package:music_mover/src/utils/ads.dart';
import 'package:music_mover/src/tracks/tracks_popups.dart';
import 'package:music_mover/src/utils/class%20models/custom_sort.dart';
import 'package:music_mover/src/utils/exceptions.dart';
import 'package:music_mover/src/utils/global_classes/global_objects.dart';
import 'package:music_mover/src/utils/globals.dart';
import 'package:music_mover/src/utils/backend_calls/spotify_requests.dart';
import 'package:music_mover/src/utils/global_classes/options_menu.dart';
import 'package:music_mover/src/utils/class%20models/track_model.dart';
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

  @override
  void initState(){
    super.initState();
    _crashlytics.log('Init Tracks View Page');

    try{
      _spotifyRequests = Get.arguments ?? SpotifyRequests.instance;
    }
    catch (e){
      _crashlytics.log('Error Tracks go Back');
      Get.back(result: false);
    }

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
    _crashlytics.log('Sort Tracks Update');

    // Sorts the tracks based on the current sort type.
    if(_spotifyRequests.tracksSortType == Sort().addedAt){
      _spotifyRequests.sortTracks( addedAt: true);
    }
    else if(_spotifyRequests.tracksSortType == Sort().artist){
      _spotifyRequests.sortTracks(artist: true);
    }
    else if(_spotifyRequests.tracksSortType == Sort().type){
      _spotifyRequests.sortTracks(type: true);
    }
    // Default title sort
    else{
      _spotifyRequests.sortTracks();
    }

    setState(() {});
  }

  ///Page state setup Function to setup the page.
  Future<void> _checkTracks() async{

    // Keeps from repeating functions
    if(!loaded.value){
      try{
        if (mounted && (_spotifyRequests.currentPlaylist.tracks.isEmpty || refresh)){
          await fetchSpotifyTracks();
        }
        else if(mounted){
          loaded.value = true;
        }
      }
      on CustomException catch (ee, stack){
        error = true;
        loaded.value = true;
        throw CustomException(stack: stack, fileName: ee.fileName, functionName: ee.functionName, reason: ee.reason, error: ee.error);
      }
      catch (ee, stack){
        error = true;
        loaded.value = true;
        _crashlytics.recordError(ee, stack, reason: 'Failed while Fetching Spotify Tracks', fatal: true);
      }
    }
  }// checkLogin

  /// Gets the users tracks for the selected Playlist
  Future<void> fetchSpotifyTracks() async {
    _crashlytics.log('fetchSpotifyTracks function');
    try{
      await _spotifyRequests.requestTracks(_spotifyRequests.currentPlaylist.id);

      if (mounted) {
        loaded.value = true;
        refresh = false;
        error = false;
      }
    }
    on CustomException catch (error){
      throw CustomException(stack: error.stack, fileName: error.fileName, functionName: error.functionName, reason: error.reason, error: error.error);
    }
    catch (ee, stack){
      throw CustomException(stack: stack, fileName: _fileName, functionName: 'fetchSpotifyTracks', reason: 'Failed to Fetch Spotify Tracks',  error: ee);
    }
  }

  void handleSelectAll(){
    _crashlytics.log('Select All');
    if (selectedTracksList.length != _spotifyRequests.currentPlaylist.tracks.length){
      selectedTracksList.clear();
      selectedTracksList.addAll(_spotifyRequests.currentPlaylist.tracks);
    }
    else{
      selectedTracksList.clear();
    }
  }


  ///Refreshes the page with function constraints to skip unnecessary steps on page refresh after deleteing tracks.
  ///
  ///Clears the selected tracks to realign the view.
  Future<void> handleDeleteRefresh() async{
    _crashlytics.log('Delete Refresh');
    loaded.value = false;
    error = false;
    removing = false;

    selectedTracksList.clear();
    _checkTracks();
  }

  /// Refreshes the page with function constraints to skip unnecessary steps on page refresh.
  Future<void> handleRefresh() async{
    if (_spotifyRequests.shouldRefresh(loaded.value, refresh)){
      _crashlytics.log('Refresh');
      refresh = true;
      loaded.value = false;
      error = false;

      selectedTracksList.clear();
      _checkTracks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: tracksAppBar(),

        drawer: optionsMenu(context, _spotifyRequests.user),

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
              else if (loaded.value && _spotifyRequests.currentPlaylist.tracks.isNotEmpty) {
                return Stack(
                  children: <Widget>[
                    tracksViewBody(),
                    if(!_spotifyRequests.user.subscribed)
                    Ads().setupAds(context, _spotifyRequests.user)
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
                    if(!_spotifyRequests.user.subscribed)
                    Ads().setupAds(context, _spotifyRequests.user)
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
        _spotifyRequests.currentPlaylist.title,
        textAlign: TextAlign.center,
      ),
      centerTitle: true,

      backgroundColor: spotHelperGreen,

      actions: <Widget>[

        // Filter button
        IconButton(
          onPressed: (){
            if(loaded.value && !_spotifyRequests.loading.value){
              Get.dialog(
                AlertDialog.adaptive(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters:',
                        textAlign: TextAlign.center,
                      ),

                      // Ascending Button
                      Obx(() => IconButton(
                        onPressed: () {
                          _spotifyRequests.tracksAsc = !_spotifyRequests.tracksAsc;
                          sortUpdate();
                        }, 
                        icon: _spotifyRequests.tracksAsc
                        ? const Icon(
                          Icons.arrow_upward_sharp,
                          color: Colors.green,
                          size: 35,
                        )
                        : const Icon(Icons.arrow_downward_sharp,
                          color: Colors.green,
                          size: 35,
                        )
                      )),
                    ]
                  ),
                  actions: [
                    Obx(() => SwitchListTile.adaptive(
                      title: const Text('Title'),

                      value: _spotifyRequests.tracksSortType == Sort().title,
                      onChanged: (_) {
                        _crashlytics.log('Sort by Title');
                        _spotifyRequests.tracksSortType = Sort().title;
                        sortUpdate();
                      },
                    )),

                    Obx(() => SwitchListTile.adaptive(
                      title: const Text('Artist'),

                      value: _spotifyRequests.tracksSortType == Sort().artist,
                      onChanged: (_) {
                        _crashlytics.log('Sort by Artist');
                        _spotifyRequests.tracksSortType = Sort().artist;
                        sortUpdate();
                      },
                    )),

                    Obx(() => SwitchListTile.adaptive(
                      title: const Text('Added At'),

                      value: _spotifyRequests.tracksSortType == Sort().addedAt,
                      onChanged: (_) {
                        _crashlytics.log('Sort by Added At time');
                        _spotifyRequests.tracksSortType = Sort().addedAt;
                        sortUpdate();
                      },
                    )),

                    Obx(() => SwitchListTile.adaptive(
                      title: const Text('Type'),
                      subtitle: const Text('Track or Episode'),

                      value: _spotifyRequests.tracksSortType == Sort().type,
                      onChanged: (_) {
                        _crashlytics.log('Sort by Type');
                        _spotifyRequests.tracksSortType = Sort().type;
                        sortUpdate();
                      },
                    )),
                  ],
                )
              );
            }
          }, 
          icon: const Icon(Icons.filter_alt_rounded)
        ),

        //Search Button
        IconButton(
          icon: const Icon(Icons.search),

          onPressed: () async {
            if (loaded.value && !_spotifyRequests.loading.value){
              _crashlytics.log('Search Tracks');
              RxList<TrackModel> searchedTracks = _spotifyRequests.currentPlaylist.tracks.obs;
              String searchType = Sort().title;
              Rx<bool> artistFilter = false.obs;

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
                            searchedTracks.value = _spotifyRequests.currentPlaylist.tracks.where((track){
                              final String result;

                              if(searchType == Sort().artist){
                                result = track.artistNames[0].toLowerCase();
                              }
                              else{
                                result = track.title.toLowerCase();
                              }
                              
                              final String input = modifyBadQuery(query).toLowerCase();

                              return result.contains(input);
                            }).toList();
                          },
                        )
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Obx(() => FilterChip(
                            backgroundColor: Colors.grey,
                            label: const Text('Search Artists'),

                            selected: artistFilter.value,
                            selectedColor: spotHelperGreen,

                            onSelected: (_) {
                              artistFilter.value = !artistFilter.value;
                              if(artistFilter.value){
                                searchType = Sort().artist;
                              }
                              else{
                                searchType = Sort().title;
                              }
                            },
                          )),
                          const SizedBox(width: 5,),

                          // Select all button
                          Obx(() => FilterChip(
                            backgroundColor: Colors.grey,
                            label: const Text('Select All'),

                            selected: selectedTracksList.length == _spotifyRequests.currentPlaylist.tracks.length,
                            selectedColor: spotHelperGreen,

                            onSelected: (_) {
                              if(selectedTracksList.length != searchedTracks.length){
                                selectedTracksList.clear();
                                selectedTracksList.addAll(_spotifyRequests.currentPlaylist.tracks);
                              }
                              else{
                                selectedTracksList.clear();
                              }
                            },
                          )),
                        ],
                      ),

                      Expanded(
                        child: Obx(() => ListView.builder(
                          itemCount: searchedTracks.length,
                          itemBuilder: (context, index) {
                            TrackModel currTrack = searchedTracks[index];

                            String getArtistText(){
                              String artistText = '';

                              if(currTrack.artists.length > 1){
                                artistText = 'By: ${currTrack.artistNames[0]}...';
                              }
                              else{
                                artistText = 'By: ${currTrack.artistNames[0]}';
                              }

                              return artistText;
                            }

                            return ListTile(
                              onTap: () {
                                setState(() {
                                  if(!selectedTracksList.contains(currTrack)){
                                    selectedTracksList.add(currTrack);
                                  }
                                  else{
                                    selectedTracksList.remove(currTrack);
                                  }
                                });
                              },

                              leading: Obx(() => Checkbox(
                                value: selectedTracksList.contains(currTrack), 
                                onChanged: (_) {
                                  if(!selectedTracksList.contains(currTrack)){
                                    selectedTracksList.add(currTrack);
                                  }
                                  else{
                                    selectedTracksList.remove(currTrack);
                                  }
                                }
                              )),

                              //Track name and Artist
                              title: Text(
                                currTrack.title, 
                                textScaler: const TextScaler.linear(1.2)
                              ),

                              subtitle: Text(getArtistText(),
                                  textScaler: const TextScaler.linear(0.8)
                              ),
                              
                              trailing: Image.network(currTrack.imageUrl),
                            );
                          }
                        ))
                      )
                    ],
                  ),
                )
              );
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
              onTap: () => handleRefresh(),
              child: Row(
                children: <Widget>[ 
                  IconButton(
                    icon: const Icon(Icons.sync_sharp),
                    onPressed: () => handleRefresh(),
                  ),
                  const Text('Refresh'),
                ],
              ),
            )
          ),
          
          //Select All checkbox.
          Tab(
            child: InkWell(
              onTap: () => handleSelectAll(),
              child: Row(
                children: <Widget>[
                   Obx(() => Checkbox(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    value: selectedTracksList.length == _spotifyRequests.currentPlaylist.tracks.length && loaded.value,
                    onChanged: (_) => handleSelectAll(),
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
              ListView.builder(
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
                                    padding: const EdgeInsets.only(right: 60),
                                    child: Image.asset(
                                      unlikeHeart,
                                      width: 21.0,
                                      height: 21.0,
                                      color: Colors.green,
                                      fit: BoxFit.cover,
                                    ),
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
              ),
              
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
    if(track.artistNames[0].length > 25){
      artistText = 'By: ${track.artistNames[0].substring(0, 25)}...';
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
            _crashlytics.log('Select track');
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
              track.title.length > 23
              ? '${track.title.substring(0, 23)}...'
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
                            TextButton(
                              onPressed: () async{
                                try{
                                  final bool response = await launchUrl(Uri.parse(track.albumLink));

                                  if(!response) TracksViewPopups().errorLink('Track');
                                }
                                catch (ee, stack){
                                  TracksViewPopups().errorLink('Track');
                                  _crashlytics.recordError(ee, stack, reason: 'Failed to open Track Link');
                                }
                              },
                              child: Text(
                                track.title,
                                textScaler: const TextScaler.linear(1.4),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Color.fromARGB(255, 146, 211, 236)
                                ),
                              )
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
                              catch (ee, stack){
                                TracksViewPopups().errorLink('Artists');
                                _crashlytics.recordError(ee, stack, reason: 'Failed to open Artists Link');
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
            icon: Icon(Icons.drive_file_move_outlined),
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
          bool? changes;

          // Move to playlist(s)
          if (value == 0 && selectedTracksList.isNotEmpty && loaded.value) {
            _crashlytics.log('Move Tracks');

            TrackArguments trackArgs = TrackArguments(selectedTracks: selectedTracksList, option: 'move', spotifyRequests: _spotifyRequests);

            changes = await Get.to(const SelectPlaylistsViewWidget(), arguments: trackArgs);

            if(changes != null && changes) await handleDeleteRefresh();
          }
          // Add to playlist(s)
          else if (value == 1 && selectedTracksList.isNotEmpty && loaded.value) {
            _crashlytics.log('Add Tracks');

            TrackArguments trackArgs = TrackArguments(selectedTracks: selectedTracksList, option: 'add', spotifyRequests: _spotifyRequests);

            changes = await Get.to(const SelectPlaylistsViewWidget(), arguments: trackArgs);
            if(changes != null && changes) await handleRefresh();
          } 
          //Removes track(s) from current playlist
          else if (value == 2 && selectedTracksList.isNotEmpty && loaded.value){
            _crashlytics.log('Remove Tracks');

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
                        _crashlytics.log('Cancel Remove Tracks');
                        //Close Popup
                        Get.back();
                      }, 
                      child: const Text('Cancel')
                    ),
                    TextButton(
                      onPressed: () {
                        confirmed = true;
                        _crashlytics.log('Confirm Remove Tracks');
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

              loaded.value = false;
              await _spotifyRequests.removeTracks(selectedTracksList, _spotifyRequests.currentPlaylist.snapshotId);
              await handleDeleteRefresh();

              Get.closeAllSnackbars();
              TracksViewPopups().deletedTracks(selectedTracksList.length, _spotifyRequests.currentPlaylist.title);
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
