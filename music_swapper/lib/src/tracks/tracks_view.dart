// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/select_playlists/select_view.dart';
import 'package:spotify_music_helper/src/utils/ads.dart';
import 'package:spotify_music_helper/src/tracks/tracks_popups.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/spotify_requests.dart';
import 'package:spotify_music_helper/src/tracks/tracks_search.dart';
import 'package:spotify_music_helper/src/utils/global_classes/options_menu.dart';
import 'package:spotify_music_helper/src/utils/playlist_model.dart';
import 'package:spotify_music_helper/src/utils/track_model.dart';
import 'package:spotify_music_helper/src/utils/user_model.dart';
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
  final String empty = 'Playlist is empty.';
  final String error = 'Error retreiving Tracks. \nCheck connection and Refresh page.';
}

class TracksViewState extends State<TracksView> with SingleTickerProviderStateMixin{
  //late DatabaseStorage _databaseStorage = DatabaseStorage.instance;
  late SpotifyRequests _spotifyRequests = SpotifyRequests.instance;
  //late SpotifySync _spotifySync = SpotifySync.instance;

  late PlaylistModel currentPlaylist;
  late UserModel user;

  /// All of a playlists tracks as a list that can be sorted to have different views.
  List<TrackModel> allTracksList = <TrackModel>[];

  /// All of the selected tracks.
  /// 
  /// key: Track ID
  /// 
  /// values: TrackModel {Id, Track Title, Artist, Image Url, PreviewUrl}
  Map<String, TrackModel> selectedTracksMap = <String, TrackModel>{};

  /// List of all tracks with 
  /// 
  /// Key: ID 
  /// 
  /// Value: if Chosen & Title
  List<MapEntry<String, dynamic>> selectedTracksList = <MapEntry<String, dynamic>>[];

  final ValueNotifier _tracksNotifier = ValueNotifier({});

  bool refresh = false;
  bool loaded = false; //Tracks loaded status
  bool selectAll = false;
  bool selectingAll = false;
  bool error = false;
  bool removing = false;
  
  late TabController tabController;

  bool showing = false;


  @override
  void initState(){
    super.initState();
    try{
      //_databaseStorage = DatabaseStorage.instance;
      _spotifyRequests = SpotifyRequests.instance;
      //_spotifySync = SpotifySync.instance;
      currentPlaylist = Get.arguments;
    }
    catch (e, stack){
      print('Error $e $stack');
      Get.back(result: Get.arguments);
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

  ///Creates a new [selectedTracksList] out of the old list
  void selectListUpdate() {
    //Sorts the tracks by their title
    allTracksList = List.generate(_spotifyRequests.tracksDupes.length, (int index) => _spotifyRequests.tracksDupes.entries.elementAt(index).value);
    allTracksList.sort((TrackModel a, TrackModel b) => a.title.compareTo(b.title));

    //Initializes the selected playlists
    selectedTracksList = List.generate(allTracksList.length, (int index) {
      TrackModel currTrack = allTracksList[index];
      //MapEntry<String, dynamic>? prevTrack = prevMap[currTrack.key];

      String trackTitle = currTrack.title;
      String trackId = currTrack.id;
      bool selected = false;

      //If the track is already selected from past widget
      if (selectedTracksMap.containsKey(trackId) || selectAll) {
        selected = true;
      }

      Map<String, dynamic> selectMap = <String, dynamic>{
        'chosen': selected,
        'title': trackTitle
      };

      return MapEntry(trackId, selectMap);
    });

    selectingAll = false;
  }

  ///Page state setup Function to setup the page.
  Future<void> _checkTracks() async{

    // Keeps from repeating functions
    if(!loaded && !selectingAll){
      try{

        if (mounted && _spotifyRequests.allPlaylists[currentPlaylist.id]!.tracks.isEmpty || refresh){
          await fetchSpotifyTracks();
        }
        else if(mounted){
          _tracksNotifier.value = _spotifyRequests.allPlaylists[currentPlaylist.id]!.tracks;
          loaded = true;
        }
      }
      catch (e, stack){
        error = true;
        _tracksNotifier.value = {};
        await FileErrors.logError(e, stack);
      }
    }
  }//checkLogin

  /// Gets the users tracks for the selected Playlist
  Future<void> fetchSpotifyTracks() async {
    try{
      await _spotifyRequests.requestTracks(currentPlaylist.id);

      if (mounted) selectListUpdate();

      if (mounted) {
        loaded = true; //Tracks if the tracks are loaded to be shown
        refresh = false;
        error = false;
        _tracksNotifier.value = _spotifyRequests.playlistTracks;
      }
    }
    catch (e){
      throw CustomException(stack: StackTrace.current, fileName: _fileName, functionName: 'fetchSpotifyTracks',  error: e);
    }
  }


  ///Refreshes the page with function constraints to skip unnecessary steps on page refresh after deleteing tracks.
  ///
  ///Clears the selected tracks to realign the view.
  Future<void> deleteRefresh() async{
    loaded = false;
    selectingAll = false;
    error = false;
    removing = false;
    selectAll = false;
    refresh = true;

    selectedTracksMap.clear();
    _tracksNotifier.value = {};
    _checkTracks();
  }

  ///Refreshes the page with function constraints to skip unnecessary steps on page refresh.
  Future<void> refreshTracks() async{
    selectingAll = false;
    refresh = true;
    loaded = false;
    error = false;

    selectedTracksMap.clear();
    _tracksNotifier.value = {};
    _checkTracks();
  }


  /// Selects all of the Tracks and updates the users view.
  void handleSelectAll(){
    // Updates checkbox
    selectAll = !selectAll;

    // Prevents Calls to Database and Spotify while selecting all
    selectingAll = true;
  
    // Selects all the check boxes
    if(selectAll) { 
      selectedTracksMap.addAll(_spotifyRequests.tracksDupes); 
    }
    else { 
      selectedTracksMap.clear(); 
    }

    selectListUpdate();
    
    // Updates selected tracks
    if(mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: tracksAppBar(),

        drawer: optionsMenu(context),

        // Loads the users tracks and its associated images after fetching them for user viewing
        body: PopScope(
          child: ValueListenableBuilder<dynamic>(
            valueListenable: _tracksNotifier, 
            builder: (_, __, ___) {
              if (!loaded && !error){
                return Center(
                    child: CircularProgressIndicator(color: spotHelperGreen,)
                );
              }
              // Playlist has tracks and Tracks finished loading
              else if (loaded && _spotifyRequests.tracksTotal > 0) {
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
        //Search Button
        IconButton(
            icon: const Icon(Icons.search),

            onPressed: () async {
              if (loaded){
                final queryResult = await showSearch(
                    context: context,
                    delegate: TracksSearchDelegate(_spotifyRequests.tracksDupes, selectedTracksMap)
                );
                
                if (queryResult != null){
                  for (var result in queryResult){
                    String trackId = result.key;
                    if (result.value['chosen']){
                      selectedTracksMap[trackId] = _spotifyRequests.tracksDupes[trackId]!;
                    }
                    else{
                      selectedTracksMap.remove(trackId);
                    }
                  }
                }

                if (selectedTracksMap.length == _spotifyRequests.tracksDupes.length) selectAll = true;
                if (selectedTracksMap.isEmpty) selectAll = false;

                selectListUpdate();
                if(mounted) setState(() {});
              }
            }),
      ],

      bottom: TabBar(
        tabAlignment: TabAlignment.center,
        indicatorColor:spotHelperGreen,
        controller: tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.grey,
        tabs: <Widget>[
          //Smart Sync tracks for PLaylist
          Tab(
            child: InkWell(
              onTap: () async{
                if (!selectingAll && loaded || error){
                  await refreshTracks();
                }
              },
              child: Row(
                children: <Widget>[ 
                  IconButton(
                    icon: const Icon(Icons.sync_sharp),
                    onPressed: () async{
                      if (!selectingAll && loaded || error){
                        await refreshTracks();
                      }
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
                if (!selectingAll && loaded){
                  handleSelectAll();
                }
              },
              child: Row(
                children: <Widget>[
                  Checkbox(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    value: selectAll,
                    onChanged: (bool? value) {
                      if (!selectingAll&& loaded){
                        handleSelectAll();
                      }
                    },
                  ),
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
                itemCount: allTracksList.length,
                itemBuilder: (_, int index) {
                  final TrackModel trackModel = allTracksList[index];

                  //Used for displaying track information
                  final String trackTitle = trackModel.title;
                  final String trackImage = trackModel.imageUrl;

                  final Map<String, dynamic> artists = trackModel.artists;
                  final bool liked = trackModel.liked;

                  //Used to update Selected Tracks
                  bool chosen = selectedTracksList[index].value['chosen'];
                  final String trackId = selectedTracksList[index].key;
                  final Map<String, dynamic> selectMap = <String, dynamic>{'chosen': !chosen, 'title': trackTitle};

                  //Alligns the songs as a Column
                  return Column(
                    children: <Widget>[
                      //Lets the entire left section with checkbox and Title be selected
                      InkWell(
                        onTap: () {
                          selectedTracksList[index] = MapEntry<String, Map<String, dynamic>>(trackId, selectMap);

                          if (!chosen){
                            selectedTracksMap[trackId] = _spotifyRequests.tracksDupes[trackId]!;
                          }
                          else{
                            selectedTracksMap.remove(trackId);
                          }
                          
                          // Updates selected Tracks List & Map
                          if(mounted) setState(() {});
                        },
                        //Container puts the Tracks image in the background
                        child: Container(
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            // Album Image for Track
                            image: DecorationImage(
                              alignment: Alignment.centerRight,
                              image: NetworkImage(trackImage),
                              fit: BoxFit.contain,
                            ),
                            shape: BoxShape.rectangle
                          ),

                          //Aligns the Track Name, Checkbox, Artist Name, Preview Button as a Row
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            mainAxisSize: MainAxisSize.max,
                            children: <Widget>[
                              trackRows(index, trackModel),

                              // The Liked Songs icon and Track link
                              Row(
                                children: <Widget>[
                                  if(liked)
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
                                          final bool response = await launchUrl(Uri.parse(trackModel.albumLink));

                                          if(!response) _errorLink('Track');
                                        }
                                        catch (e){
                                          _errorLink('Track');
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
                      if (index == allTracksList.length-1)
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

  //Creates the State for each Tracks Row
  Widget trackRows(int index, TrackModel track) {
    String artistText = '';

    if(track.artists.length > 1){
      artistText = 'By: ${track.artistName[0]}...';
    }
    else{
      artistText = 'By: ${track.artistName[0]}';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        //Design & Functinoality for the checkbox button when selected and not
        Checkbox(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          value: selectedTracksList[index].value['chosen'],
          onChanged: (bool? value) {
            
            bool chosen = selectedTracksList[index].value['chosen'];
            String trackId = selectedTracksList[index].key;
            Map<String, dynamic> selectMap = <String, dynamic>{
              'chosen': !chosen,
              'title': track.title
            };

            selectedTracksList[index] = MapEntry(trackId, selectMap);
            if (!chosen){
              selectedTracksMap[trackId] = _spotifyRequests.tracksDupes[trackId]!;
            }
            else{
              selectedTracksMap.remove(trackId);
            }

            // Updates selected track List & Map
            if(mounted) setState(() {});
          },
        ),

        //Track Names & Artist Names design and Functionality
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          //Name of the Track shown to user
          children: <Widget>[
            Text(
              track.title.length > 22
              ? '${track.title.substring(0, 25)}...'
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
                    itemCount: track.artists.length,
                    itemBuilder: (_, int index) {
                      return Column(
                        children: <Widget>[
                          TextButton(
                            onPressed: () async{
                              try{
                                final bool response = await launchUrl(Uri.parse(track.artistLink[index]));

                                if(!response) _errorLink('Artists');
                              }
                              catch (e){
                                _errorLink('Artists');
                              }
                            }, 
                            child: Text(
                              track.artistName[index],
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
          if (value == 0 && selectedTracksMap.isNotEmpty && !selectingAll && loaded) {
            TrackArguments trackArgs = TrackArguments(selectedTracks: selectedTracksMap, currentPlaylist: currentPlaylist, option: 'move', allTracks: _spotifyRequests.tracksDupes);

            await Get.to(const SelectPlaylistsViewWidget(), arguments: trackArgs);
            await deleteRefresh();
          }
          // Add to playlist(s) index
          else if (value == 1 && selectedTracksMap.isNotEmpty && !selectingAll && loaded) {
            TrackArguments trackArgs = TrackArguments(selectedTracks: selectedTracksMap, currentPlaylist: currentPlaylist, option: 'add', allTracks: _spotifyRequests.tracksDupes);

            await Get.to(const SelectPlaylistsViewWidget(), arguments: trackArgs);
            await refreshTracks();
          } 
          //Removes track(s) from current playlist
          else if (value == 2 && selectedTracksMap.isNotEmpty && !selectingAll && loaded){
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
              _tracksNotifier.value = {};

              int tracksDeleted = selectedTracksMap.length;
              await _spotifyRequests.removeTracks(selectedTracksMap, currentPlaylist.id, currentPlaylist.snapshotId);
              await deleteRefresh();

              if (!showing){
                showing = true;
                showing = await TracksViewPopups().deletedTracks(context, tracksDeleted, currentPlaylist.title);
              }
            }// User Confirmed Deletion

          }
          // User Hasn't selected a Track
          else {
            if (!showing){
              showing = true;
              showing = await TracksViewPopups().noTracks(context);
            }
          }
        },
      );
  }

  /// Error notification for if the link failed to alert the user.
  void _errorLink(String type){
    Get.snackbar(
      'Error', 
      'Failed to open $type link.',
      backgroundColor: snackBarGrey,
      isDismissible: true,
      colorText: failedRed
    );
  }

}
