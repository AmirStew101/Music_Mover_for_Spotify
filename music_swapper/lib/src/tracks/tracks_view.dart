// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/select_playlists/select_view.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/playlists_requests.dart';
import 'package:spotify_music_helper/src/utils/tracks_requests.dart';
import 'package:spotify_music_helper/src/tracks/tracks_search.dart';
import 'package:spotify_music_helper/src/utils/universal_widgets.dart';

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

  String playlistId = '';

  Map<String, TrackModel> allTracks = {}; //Tracks for the chosen playlist
  //All of the selected tracks 
  //key: Track ID
  //values: TrackModel {Id, Track Title, Artist, Image Url, PreviewUrl}
  Map<String, TrackModel> selectedTracksMap = {};
  String playlistName = '';

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
  
  late TabController tabController;

  //Users Smart Sync text
  final List<String> smartSyncTexts = ['Smart Syncing Tracks.', 'First time Syncing a lot of Tracks may take awhile.', 'Someone has a lot of Tracks to Sync, over 1000?'];

  //Users Deep Sync text
  final List<String> deepSyncTexts = ['Deep Syncing Tracks.', 'Deep syncing updates every track so it might take awhile.', 'Someone has a lot of Tracks to Sync, over 1000?'];

  final List<String> loadTexts = ['Loading Tracks.', 'First time Loading a lot of Tracks may take awhile.', 'Someone has a lot of Tracks to Load, over 1000?'];
  int loadingIndex = 0;

  bool deepSync = false;



  @override
  void initState(){
    super.initState();

    currentPlaylist = const PlaylistModel().mapToModel(widget.currentPLaylist);

    playlistId = currentPlaylist.id;
    playlistName = currentPlaylist.title;
    
    tabController = TabController(length: 3, vsync: this);
  }

  void selectListUpdate() {
    debugPrint('Updating Select');
    //Initializes the selected playlists
    selectedTracksList = List.generate(allTracks.length, (index) {
      MapEntry<String, TrackModel> currTrack = allTracks.entries.elementAt(index);
      //MapEntry<String, dynamic>? prevTrack = prevMap[currTrack.key];

      String trackTitle = currTrack.value.title;
      String trackId = currTrack.key;
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

    //Initializes the playing list
    // playingList = List.generate(allTracks.length, (index) {
    //   String trackTitle = allTracks.entries.elementAt(index).value.title;
    //   String trackId = allTracks.entries.elementAt(index).key;
    //   String? playUrl = allTracks.entries.elementAt(index).value.previewUrl;
    //
    //   Map<String, dynamic> playMap = {
    //     'playing': false,
    //     'title': trackTitle,
    //     'playUrl': playUrl ?? ''
    //   };
    //
    //   return MapEntry(trackId, playMap);
    // });

    selectingAll = false;
  }


  void startSyncTimer(){
    if (homeTimer && mounted){
      Timer.periodic(const Duration(seconds: 5), (timer) {
        debugPrint('Sync Timer');
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
          debugPrint('\nCancel Timer!\n');
          setState(() {
            //Stops the timer and resets messages
          });
        }
      });
     }
  }

  void startLoadTimer(){
    if(homeTimer && mounted){
      Timer.periodic(const Duration(seconds: 5), (timer) {
        debugPrint('Load Timer');
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
          debugPrint('\nCancel Timer!\n');
          setState(() {
            //Stops the timer and resets messages
          });
        }
      });
    }
  }

  Future<void> checkLogin() async{
    debugPrint('Check Login');
    CallbackModel? secureCall = await SecureStorage().getTokens();
    UserModel? secureUser = await SecureStorage().getUser();

    if (secureCall == null || secureUser == null){
      bool reLogin = false;
      
      Navigator.of(context).pushReplacementNamed(StartViewWidget.routeName, arguments: reLogin);

      storageCheck(context, secureCall, secureUser);
    }
    else if(!homeTimer && mounted && !loaded && !selectingAll){
      if (!loaded && !refresh){
        homeTimer = true;
        startLoadTimer();
      }
      else if (!loaded && refresh){
        homeTimer = true;
        startSyncTimer();
      }
      receivedCall = secureCall;
      user = secureUser;
      await fetchDatabaseTracks().catchError((e){
        error = true;
        debugPrint('Error when trying to fetchDatabaseTracks ${getCurrentLine()} $e');
      });
    }

  }

  Future<void> fetchDatabaseTracks() async{

    //Gets Tracks from database when not refreshing
    if (!refresh){
      debugPrint('\nCalling Database');

      //Fills Users tracks from the Database
      allTracks = await DatabaseStorage().getDatabaseTracks(user.spotifyId, playlistId, context);
    }
    
    //If not refreshing page and Database has tracks Page is loaded
    if (allTracks.isNotEmpty && !refresh){
      totalTracks = allTracks.length;

      selectListUpdate();

      loaded = true;
      debugPrint('\nLoaded Tracks');
    }
    //Page is refreshing or Database has no tracks
    else{
      await fetchSpotifyTracks().catchError((e){
        error = true;
        debugPrint('Error when trying to fetchSpotifyTracks $e');
      });
    }
  }

  //Gets the users tracks for the selected Playlist
  Future<void> fetchSpotifyTracks() async {
    debugPrint('\nCalling Spot');
    //Checks if Token needs to be refreshed
    receivedCall = await checkRefresh(receivedCall, false); 
    totalTracks = await getSpotifyTracksTotal(playlistId, receivedCall.expiresAt, receivedCall.accessToken);

    if (totalTracks > 0) {
      allTracks = await getSpotifyPlaylistTracks(
          playlistId,
          receivedCall.expiresAt,
          receivedCall.accessToken,
          totalTracks,
      ); //gets user tracks for playlist


      selectListUpdate();      

      //Adds tracks to database for faster retreival later
      await DatabaseStorage().syncPlaylistTracksData(user.spotifyId, allTracks, playlistId, deepSync);
    }

    debugPrint('Loaded Tracks');

    loaded = true; //Tracks if the tracks are loaded to be shown
    refresh = false;
  }


  Future<void> deleteRefresh() async{
    debugPrint('Delete Refresh');
    loaded = false;
    selectAll = false;

    selectedTracksMap.clear();

    setState(() {
      //Update Tracks
    });
  }


  Future<void> refreshTracks(bool syncOption) async{
    deepSync = syncOption;
    selectAll = false;
    refresh = true;
    loaded = false;
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
              controller: tabController,
              tabs: [

                //Smart Sync tracks for PLaylist
                Tab(
                  child: InkWell(
                    onTap: () async{
                      if (!selectingAll){
                        await refreshTracks(false);
                      }
                    },
                    child: Row(children: [ 
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () async{
                        if (!selectingAll){
                          await refreshTracks(false);
                        }
                      },
                    ),
                    const Text('Smart'),
                  ],),
                )
                ),

                //Deep SYnc Tracks for Playlist
                Tab(
                  child: InkWell(
                    onTap: () async{
                      if (!selectingAll){
                        await refreshTracks(true);
                      }
                    },
                    child: Row(children: [ 
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () async{
                        if (!selectingAll){
                          await refreshTracks(true);
                        }
                      },
                    ),
                    const Text('Deep'),
                  ],),
                )
                ),
                
                //Select All checkbox
                Tab(child: InkWell(
                  onTap: () {
                    if (!selectingAll){
                      handleSelectAll();
                    }
                  },
                  child: Row(children: [
                  Checkbox(
                    value: selectAll,
                    onChanged: (value) {
                      if (!selectingAll){
                        handleSelectAll();
                      }
                    },
                  ),
                  const Text('All'),
                ],),
                )
                )
              ]),
            
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu), 
                onPressed: ()  {
                  Scaffold.of(context).openDrawer();
                },
              )
            ),

            backgroundColor: const Color.fromARGB(255, 6, 163, 11),
            title: Text(
              playlistName, //Playlist Name
              textAlign: TextAlign.center,
            ),

            actions: [
              //Search Button
              IconButton(
                  icon: const Icon(Icons.search),

                  onPressed: () async {
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
                  }),
            ],
      );
  }

  Widget tracksBody(){
    return FutureBuilder<void>(
          future: checkLogin().catchError((e) => debugPrint('\nTracks_view.dart line ${getCurrentLine()} error in tracks_view: $e')),
          builder: (context, snapshot) {

            if (selectingAll){
              return const Center(
                  child: CircularProgressIndicator(color: Color.fromARGB(255, 22, 199, 28),)
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
              homeTimer = false;
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
                      if(refresh && !deepSync) 
                        Center(child: 
                          Text(
                            smartSyncTexts[loadingIndex],
                            textScaler: const TextScaler.linear(2),
                            textAlign: TextAlign.center,
                          )
                        )

                      //Deep Sync was pressed
                      else if(refresh && deepSync)
                        Center(child: 
                          Text(
                            deepSyncTexts[loadingIndex],
                            textScaler: const TextScaler.linear(2),
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
          itemCount: allTracks.length,
          itemBuilder: (context, index) {
            final trackMap = allTracks.entries.elementAt(index);

            //Used for displaying track information
            final trackTitle = trackMap.value.title;
            final trackImage = trackMap.value.imageUrl;
            //final trackPrevUrl = trackMap.value.previewUrl ?? '';
            final trackArtist = trackMap.value.artist;

            //Used to update Selected Tracks
            bool chosen = selectedTracksList[index].value['chosen'];
            final trackId = selectedTracksList[index].key;
            final selectMap = {'chosen': !chosen, 'title': trackTitle};

            //Alligns the songs as a Column
            return Column(children: [
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
                            alignment: Alignment.topRight,
                            image: NetworkImage(trackImage),
                            fit: BoxFit.contain,
                          ),
                          shape: BoxShape.rectangle),

                      //Aligns the Track Name, Checkbox, Artist Name, Preview Button as a Row
                      child: trackRows(index, trackTitle, trackArtist),
                  )
              ),
              //The grey divider line between each Row to look nice
              const Divider(
                height: 1,
                color: Colors.grey,
              ),
              if (index == allTracks.length-1)
                const SizedBox(
                  height: 90,
                ),
            ]);
          }),
          
      if (user.subscribed)
        //Shows an ad if user isn't subscribed
        Positioned(
          bottom: 5,
          child: adRow(),
        )
      ],
    );
  }

  //Banner Ad setup
  Widget adRow(){
    final width = MediaQuery.of(context).size.width;

    final BannerAd bannerAd = BannerAd(
      size: AdSize.fluid, 
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', 
      listener: BannerAdListener(
        onAdLoaded: (ad) => debugPrint('Ad Loaded\n'),
        onAdClicked: (ad) => debugPrint('Ad Clicked\n'),), 
      request: const AdRequest(),
    );

    bannerAd.load();
    
    return SizedBox(
      width: width,
      height: 70,
      //Creates the ad banner
      child: AdWidget(
        ad: bannerAd,
      ),
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
                  trackTitle.length > 25
                  ? '${trackTitle.substring(0, 25)}...'
                  : trackTitle,
                  textScaler: const TextScaler.linear(1.2),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color.fromARGB(255, 6, 163, 11)),
                ),
                //Name of track Artist show to user
                Text(
                  'By: $trackArtist',
                  textScaler: const TextScaler.linear(0.8),
                ),
              ])
      ]
    );
  }

  Widget tracksBottomBar(){
      return BottomNavigationBar(
        backgroundColor: const Color.fromARGB(255, 6, 163, 11),
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
          if (value == 0 && selectedTracksMap.isNotEmpty) {
            TrackArguments trackArgs = TrackArguments(selectedTracks: selectedTracksMap, currentPlaylist: currentPlaylist, option: 'move', allTracks: allTracks);

            Navigator.restorablePushNamed(context, SelectPlaylistsViewWidget.routeName, arguments: trackArgs.toJson());
          }
          //Add to playlist(s) index
          else if (value == 1 && selectedTracksMap.isNotEmpty) {

            try{
            TrackArguments trackArgs = TrackArguments(selectedTracks: selectedTracksMap, currentPlaylist: currentPlaylist, option: 'add', allTracks: allTracks);
            Navigator.restorablePushNamed(context, SelectPlaylistsViewWidget.routeName, arguments: trackArgs.toJson());
            }
            catch (e){
              debugPrint('Tracks_view line ${getCurrentLine()} caught error $e');
            }
          } 
          //Removes track(s) from current playlist
          else if (value == 2 && selectedTracksMap.isNotEmpty){
            int tracksDeleted = selectedTracksMap.length;
            String playlistTitle = currentPlaylist.title;
            debugPrint('Tracks to Delete: $selectedTracksMap');

            await DatabaseStorage().removeTracks(receivedCall, currentPlaylist, selectedTracksMap, allTracks, user);
            await deleteRefresh();

            Flushbar(
              backgroundColor: const Color.fromARGB(255, 2, 155, 7),
              title: 'Success Message',
              duration: const Duration(seconds: 3),
              flushbarPosition: FlushbarPosition.TOP,
              message: 'Deleted $tracksDeleted tracks from $playlistTitle',
            ).show(context);
          }

          else {
            Flushbar(
              title: 'Failed Message',
              duration: const Duration(seconds: 2),
              flushbarPosition: FlushbarPosition.TOP,
              message: 'No tracks selected',
            ).show(context);
          }
        },
      );
  }

}
