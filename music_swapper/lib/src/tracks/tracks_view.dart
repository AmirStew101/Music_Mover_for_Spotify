// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/select_playlists/select_view.dart';
import 'package:spotify_music_helper/src/utils/ads.dart';
import 'package:spotify_music_helper/src/tracks/tracks_popups.dart';
import 'package:spotify_music_helper/src/utils/dev_global.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/playlists_requests.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/tracks_requests.dart';
import 'package:spotify_music_helper/src/tracks/tracks_search.dart';
import 'package:spotify_music_helper/src/utils/global_classes/database_class.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';

class TracksView extends StatefulWidget {
  static const routeName = '/tracksView';

  const TracksView({super.key, required this.currentPLaylist});

  final Map<String, dynamic> currentPLaylist;

  @override
  State<TracksView> createState() => TracksViewState();
}

class TracksViewState extends State<TracksView> with SingleTickerProviderStateMixin{
  //Passed argument
  PlaylistModel currentPlaylist = const PlaylistModel();

  CallbackModel receivedCall = CallbackModel();
  UserModel user = UserModel.defaultUser();

  Map<String, TrackModel> allTracks = {}; //Tracks for the chosen playlist
  List<TrackModel> allTracksList = [];

  //All of the selected tracks 
  //key: Track ID
  //values: TrackModel {Id, Track Title, Artist, Image Url, PreviewUrl}
  Map<String, TrackModel> selectedTracksMap = {};

  //List of all tracks with Key: ID and Value: if Chosen & Title
  List<MapEntry<String, dynamic>> selectedTracksList = [];
  //List<MapEntry<String, dynamic>> playingList = [];

  int totalTracks = -1;
  bool refresh = false;
  bool loaded = false; //Tracks loaded status
  bool selectAll = false;
  bool selectingAll = false;
  bool error = false;
  bool homeTimer = false;
  bool removing = false;
  
  late TabController tabController;

  //Users Smart Sync text
  final List<String> smartSyncTexts = ['Syncing Tracks.', 'Syncing a lot of Tracks may take a minute.', 'Someone has a lot of Tracks to Sync, over 1000?'];

  final List<String> loadTexts = ['Loading Tracks.', 'First time Loading a lot of Tracks may take awhile.', 'Someone has a lot of Tracks to Load, over 1000?'];
  int loadingIndex = 0;

  bool checkedLogin = false;

  bool showing = false;


  @override
  void initState(){
    super.initState();
    currentPlaylist = const PlaylistModel().toPlaylistModel(widget.currentPLaylist);
    tabController = TabController(length: devMode ? 3 : 2, vsync: this);
  }

  @override
  void dispose(){
    tabController.dispose();
    super.dispose();
  }

  ///Creates a new [selectedTracksList] out of the old list
  void selectListUpdate() {
    //Sorts the tracks by their title
    allTracksList = List.generate(allTracks.length, (index) => allTracks.entries.elementAt(index).value);
    allTracksList.sort((a, b) => a.title.compareTo(b.title));

    //Initializes the selected playlists
    selectedTracksList = List.generate(allTracksList.length, (index) {
      TrackModel currTrack = allTracksList[index];
      //MapEntry<String, dynamic>? prevTrack = prevMap[currTrack.key];

      String trackTitle = currTrack.title;
      String trackId = currTrack.id;
      bool selected = false;

      //If the track is already selected from past widget
      if (selectedTracksMap.containsKey(trackId) || selectAll) {
        selected = true;
      }

      Map<String, dynamic> selectMap = {
        'chosen': selected,
        'title': trackTitle
      };

      return MapEntry(trackId, selectMap);
    });

    selectingAll = false;
  }

  void startSyncTimer(){
    if (homeTimer && mounted){
      Timer.periodic(const Duration(seconds: 20), (timer) {
        if(mounted){
          setState(() {
            loadingIndex = (loadingIndex + 1) % smartSyncTexts.length;
          });
        }
        else{
          loadingIndex = 0;
          timer.cancel();
        }
        if(loaded && mounted){
          loadingIndex = 0;
          timer.cancel();
          setState(() {
            //Stops the timer and resets messages
          });
        }
      });
     }
  }

  void startLoadTimer(){
    if(homeTimer && mounted){
      Timer.periodic(const Duration(seconds: 20), (timer) {
        if(mounted){
          setState(() {
            loadingIndex = (loadingIndex + 1) % loadTexts.length;
          });
        }
        else{
          loadingIndex = 0;
          timer.cancel();
        }
        if(loaded && mounted){
          loadingIndex = 0;
          timer.cancel();
          setState(() {
            //Stops the timer and resets messages
          });
        }
      });
    }
  }


  Future<void> checkLogin() async{
    final response = await PlaylistsRequests().checkRefresh(receivedCall, false);

    if (mounted && !checkedLogin || response == null){
      CallbackModel? secureCall = await SecureStorage().getTokens();
      UserModel? secureUser = await SecureStorage().getUser();

      if (secureCall == null || secureUser == null){
        checkedLogin = false;
        bool reLogin = false;
        
        Navigator.of(context).pushReplacementNamed(StartViewWidget.routeName, arguments: reLogin);

        storageCheck(context, secureCall, secureUser);
      }
      else{
        checkedLogin = true;
        receivedCall = secureCall;
        user = secureUser;
      }
    }

    if (mounted && !loaded && checkedLogin){
      //Timer isn't running, still on the same page, loading the page, & not updating select List
      //Keeps from repeating functions when setState is called
      if(!homeTimer && mounted && !loaded && !selectingAll){

        //Initial load of the page Starts the timer for Loading message change
        if (!refresh){
          homeTimer = true;
          startLoadTimer();

          await fetchDatabaseTracks()
          .catchError((e){
            homeTimer = false;
            debugPrint('Database Failed');
            error = true;
          });
        }
        
        //Sync load of the page Starts the timer for Sync message change
        if (error || refresh){
          error = false;
          homeTimer = true;
          startSyncTimer();

          await fetchSpotifyTracks()
          .catchError((e){
            homeTimer = false;
            error = true;
          });
        }
      }
    }
  }//checkLogin

  Future<void> fetchDatabaseTracks() async{
    if (mounted){
      //Fills Users tracks from the Database
      final allTemp = await DatabaseStorage().getDatabaseTracks(user.spotifyId, currentPlaylist.id, context);
      
      //Database has found tracks so page is done loading
      if (allTemp.isNotEmpty){
        totalTracks = allTemp.length;
        allTracks = TracksRequests().makeDuplicates(allTemp);
      }
      else{
        totalTracks = allTracks.length;
        allTracks = allTemp;
      }

      selectListUpdate();
      loaded = true;
      homeTimer = false;

      //Database has no tracks so check Spotify
      if (mounted && allTracks.isEmpty){
        await fetchSpotifyTracks()
        .catchError((e){
          homeTimer = false;
          error = true;
          throw Exception('Error when trying to fetchSpotifyTracks in tracks_view.dart: $e');
        });
      }
    }

  }

  //Gets the users tracks for the selected Playlist
  Future<void> fetchSpotifyTracks() async {
    //Checks if Token needs to be refreshed
    final result = await PlaylistsRequests().checkRefresh(receivedCall, false); 

    if (result != null){
      receivedCall = result;
    }

    totalTracks = await TracksRequests().getTracksTotal(currentPlaylist.id, receivedCall.expiresAt, receivedCall.accessToken);

    if (mounted) {
      //gets user tracks for playlist
      final allTemp = await TracksRequests().getPlaylistTracks(
          currentPlaylist.id,
          receivedCall.expiresAt,
          receivedCall.accessToken,
          totalTracks,
      );

      if (allTemp.isNotEmpty){
        allTracks = TracksRequests().makeDuplicates(allTemp);
      }
      else{
        allTracks = allTemp;
        allTracksList = [];
      }

      selectListUpdate();
      loaded = true;
      homeTimer = false;

      //Adds tracks to database for faster retreival later
      await DatabaseStorage().syncTracks(user.spotifyId, allTracks, currentPlaylist.id)
      .catchError((e) {
        throw Exception('tracks_view.dart error trying to syncPlaylistTracksData line: ${getCurrentLine(offset: 2)} Caught Error: $e');
      });
    }

    loaded = true; //Tracks if the tracks are loaded to be shown
    homeTimer = false;
    refresh = false;
    error = false;
    setState(() {
      
    });
  }


  Future<void> deleteRefresh() async{
    loaded = false;
    selectingAll = false;
    loadingIndex = 0;
    error = false;
    removing = false;
    selectAll = false;

    selectedTracksMap.clear();

    setState(() {
      //Update Tracks
    });
  }


  Future<void> refreshTracks() async{
    selectingAll = false;
    refresh = true;
    loaded = false;
    loadingIndex = 0;
    error = false;

    setState(() {
      //Refreshes the page
    });
  }


  void handleSelectAll(){
    //Updates checkbox
    selectAll = !selectAll;

    //Prevents Calls to Database and Spotify while selecting all
    selectingAll = true;
  
    //Selects all the check boxes
    if (selectAll) {
      selectedTracksMap.addAll(allTracks);
    }
    else {
      selectedTracksMap.clear();
    }

    selectListUpdate();

    setState(() {
      //Updates selected tracks
    });
  }

  //Main body of the page
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: tracksAppBar(),

        drawer: optionsMenu(context),

        //Loads the users tracks and its associated images after fetching them for user viewing
        body: tracksBody(),

        bottomNavigationBar: tracksBottomBar(),
      );
  }

  AppBar tracksAppBar(){
     return AppBar(
            bottom: TabBar(
              isScrollable: devMode,
              tabAlignment: devMode ? TabAlignment.start :TabAlignment.center,
              indicatorColor:spotHelperGreen,
              controller: tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.grey,
              tabs: [
                //Smart Sync tracks for PLaylist
                Tab(
                  child: InkWell(
                    onTap: () async{
                      if (!selectingAll && loaded || error){
                        await refreshTracks();
                      }
                    },
                    child: Row(
                      children: [ 
                        IconButton(
                          icon: const Icon(Icons.sync_sharp),
                          onPressed: () async{
                            if (!selectingAll && loaded || error){
                              await refreshTracks();
                            }
                          },
                        ),
                        const Text('Sync Tracks'),
                      ],
                    ),
                  )
                ),
                
                //Select All checkbox
                Tab(
                  child: InkWell(
                    onTap: () {
                      if (!selectingAll && loaded){
                        handleSelectAll();
                      }
                    },
                    child: Row(
                      children: [
                        Checkbox(
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          value: selectAll,
                          onChanged: (value) {
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
              
                //Deep Sync Tracks for Playlist
                if (devMode)
                  Tab(
                    child: InkWell(
                      onTap: () async{
                        if (!selectingAll && loaded || error){
                          await refreshTracks();
                        }
                      },
                      child: Row(
                        children: [ 
                          IconButton(
                            icon: const Icon(Icons.cloud_sync_sharp),
                            onPressed: () async{
                              if (!selectingAll && loaded || error){
                                await refreshTracks();
                              }
                            },
                          ),
                          const Text('Deep Sync'),
                        ],
                      ),
                    )
                  ),

              ]),
            
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu), 
                onPressed: ()  {
                  Scaffold.of(context).openDrawer();
                },
              )
            ),

            backgroundColor: spotHelperGreen,

            title: Text(
              currentPlaylist.title, //Playlist Name
              textAlign: TextAlign.center,
            ),

            actions: [
              //Search Button
              IconButton(
                  icon: const Icon(Icons.search),

                  onPressed: () async {
                    if (loaded){
                      final queryResult = await showSearch(
                          context: context,
                          delegate: TracksSearchDelegate(allTracks, selectedTracksMap));

                      if (queryResult != null){
                        for (var result in queryResult){
                          if (result.value['chosen']){
                            String trackId = result.key;
                            selectedTracksMap[trackId] = allTracks[trackId]!;
                          }
                        }
                      }
                      setState(() {

                      });
                    }
                  }),
            ],
      );
  }

  Widget tracksBody(){
    return FutureBuilder<void>(
          future: checkLogin().catchError((e) => throw Exception('\nTracks_view.dart line ${getCurrentLine()} error in tracks_view: $e')),
          builder: (context, snapshot) {

            if (selectingAll || removing){
              return Center(
                  child: CircularProgressIndicator(color: spotHelperGreen,)
              );
            }
            //Playlist doesn't have Tracks
            else if (loaded && totalTracks <= 0) {
              return const Center(
                  child: Text(
                    'Playlist is empty no Tracks to Show',
                    textScaler: TextScaler.linear(1.7),
                    textAlign: TextAlign.center,
                  )
              );
            }
            //Playlist has tracks and Tracks finished loading
            else if (loaded && totalTracks > 0) {
              return tracksViewBody();
            } 
            else if(error){
              return const Center(
                child: Text(
                  'Error getting tracks',
                  textScaler: TextScaler.linear(2),
                  textAlign: TextAlign.center,
                )
              );
            }
            else{
              return Center(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(strokeWidth: 6,),

                      //Smart Sync was pressed
                      if(refresh) 
                        Center(child: 
                          Text(
                            smartSyncTexts[loadingIndex],
                            textScaler: const TextScaler.linear(2),
                            textAlign: TextAlign.center,
                          )
                        )

                      //Deep Sync was pressed
                      else if(refresh)
                        const Center(child: 
                          Text(
                            'Deepe Syncing Tracks',
                            textScaler: TextScaler.linear(2),
                            textAlign: TextAlign.center,
                          )
                        )
                      //Just loaded page
                      else
                        Center(child: 
                          Text(
                            loadTexts[loadingIndex],
                            textScaler: const TextScaler.linear(2),
                            textAlign: TextAlign.center,
                          )
                        )
                    ]
                )
              );
            }
          },
        );
  }

  Widget tracksViewBody(){
    //Stack for the hovering select all button & tracks view
    return Stack(children: [
      ListView.builder(
          itemCount: allTracksList.length,
          itemBuilder: (context, index) {
            final trackModel = allTracksList[index];

            //Used for displaying track information
            final trackTitle = trackModel.title;
            final trackImage = trackModel.imageUrl;
            //final trackPrevUrl = trackMap.value.previewUrl ?? '';
            final trackArtist = trackModel.artist;
            final liked = trackModel.liked;

            //Used to update Selected Tracks
            bool chosen = selectedTracksList[index].value['chosen'];
            final trackId = selectedTracksList[index].key;
            final selectMap = {'chosen': !chosen, 'title': trackTitle};

            //Alligns the songs as a Column
            return Column(
              children: [
                //Lets the entire left section with checkbox and Title be selected
                InkWell(
                    onTap: () {
                      
                      selectedTracksList[index] = MapEntry(trackId, selectMap);

                      if (!chosen){
                        selectedTracksMap[trackId] = allTracks[trackId]!;
                      }
                      else{
                        selectedTracksMap.remove(trackId);
                      }
                      
                      setState(() {
                        //updateds selected Tracks List & Map
                      });
                    },
                    //Container puts the Tracks image in the background
                    child: Container(
                      clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
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
                          children: [
                            trackRows(index, trackTitle, trackArtist),
                            if(liked)
                              Padding(
                                padding: const EdgeInsets.only(right: 60),
                                child:spotifyHeart(),
                              )
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
            ]);
          }),
          
        //Shows an ad if user isn't subscribed
        playlistsAdRow(context, user)
      ],
    );
  }

  //Creates the State for each Tracks Row
  Widget trackRows(int index, String trackTitle, String trackArtist) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        //Design & Functinoality for the checkbox button when selected and not
        Checkbox(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          value: selectedTracksList[index].value['chosen'],
          onChanged: (value) {
            
            bool chosen = selectedTracksList[index].value['chosen'];
            String trackId = selectedTracksList[index].key;
            Map<String, dynamic> selectMap = {
              'chosen': !chosen,
              'title': trackTitle
            };

            selectedTracksList[index] = MapEntry(trackId, selectMap);
            if (!chosen){
              selectedTracksMap[trackId] = allTracks[trackId]!;
            }
            else{
              selectedTracksMap.remove(trackId);
            }

            setState(() {
                //Updates selected track List & Map
            });
          },
        ),

        //Track Names & Artist Names design and Functionality
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          //Name of the Track shown to user
          children: [
            Text(
              trackTitle.length > 22
              ? '${trackTitle.substring(0, 22)}...'
              : trackTitle,
              textScaler: const TextScaler.linear(1.2),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: spotHelperGreen),
            ),
            //Name of track Artist show to user
            Text(
              'By: $trackArtist',
              textScaler: const TextScaler.linear(0.8),
            ),
          ]
        ),

      ]
    );
  }

  Widget tracksBottomBar(){
      return BottomNavigationBar(
        backgroundColor: spotHelperGreen,
        items: const [
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
        onTap: (value) async {
          //Move to playlist(s) Index
          if (value == 0 && selectedTracksMap.isNotEmpty && !selectingAll && loaded) {
            TrackArguments trackArgs = TrackArguments(selectedTracks: selectedTracksMap, currentPlaylist: currentPlaylist, option: 'move', allTracks: allTracks);

            Navigator.restorablePushNamed(context, SelectPlaylistsViewWidget.routeName, arguments: trackArgs.toJson());
          }
          //Add to playlist(s) index
          else if (value == 1 && selectedTracksMap.isNotEmpty && !selectingAll && loaded) {
            TrackArguments trackArgs = TrackArguments(selectedTracks: selectedTracksMap, currentPlaylist: currentPlaylist, option: 'add', allTracks: allTracks);

            Navigator.restorablePushNamed(context, SelectPlaylistsViewWidget.routeName, arguments: trackArgs.toJson());
          } 
          //Removes track(s) from current playlist
          else if (value == 2 && selectedTracksMap.isNotEmpty && !selectingAll && loaded){
            bool confirmed = false;

            await showDialog(
              context: context, 
              builder: (context) {
                return AlertDialog.adaptive(
                  title: const Text('Sure you want to delete these Tracks?'),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    TextButton(
                      onPressed: () {
                        //Close Popup
                        Navigator.of(context).pop();
                      }, 
                      child: const Text('Cancel')
                    ),
                    TextButton(
                      onPressed: () {
                        confirmed = true;
                        //Close Popup
                        Navigator.of(context).pop();
                      },
                      child: const Text('Confirm'),
                    ),
                  ],
                );
              },
            );

            if (confirmed){
              setState(() {
                removing = true;
              });
              int tracksDeleted = selectedTracksMap.length;

              List<String> removeIds = TracksRequests().getUnmodifiedIds(selectedTracksMap);

              List<String> addBackIds = TracksRequests().getAddBackIds(selectedTracksMap);

              final callResponse = await PlaylistsRequests().checkRefresh(receivedCall, false);
              if (callResponse == null){
                error = true;
                throw Exception('tracks_view.dart Callback Refresh Failed line: ${getCurrentLine()}');
              }

              receivedCall = callResponse;
              await TracksRequests().removeTracks(removeIds, currentPlaylist.id, currentPlaylist.snapshotId, receivedCall.expiresAt, receivedCall.accessToken);

              if (addBackIds.isNotEmpty){
                //Add the tracks back to the playlist
                await TracksRequests().addTracks(addBackIds, [currentPlaylist.id], receivedCall.expiresAt, receivedCall.accessToken);
              }
              else if (removeIds.length == totalTracks){
                totalTracks = 0;
              }
              
              await DatabaseStorage().removeTracks(currentPlaylist, removeIds, user);
              await deleteRefresh();

              if (!showing){
                showing = true;
                showing = await TracksViewPopups().deletedTracks(context, tracksDeleted, currentPlaylist.title);
              }
            }//User Confirmed Deltion

          }
          //User Hasn't selected a Track
          else {
            if (!showing){
              showing = true;
              showing = await TracksViewPopups().noTracks(context);
            }
          }
        },
      );
  }

}
