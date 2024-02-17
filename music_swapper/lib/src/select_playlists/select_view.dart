// ignore_for_file: use_build_context_synchronously

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/home/home_view.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/select_playlists/select_body.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/playlists_requests.dart';
import 'package:spotify_music_helper/src/select_playlists/select_search.dart';
import 'package:spotify_music_helper/src/utils/sync_services.dart';
import 'package:spotify_music_helper/src/utils/tracks_requests.dart';
import 'package:spotify_music_helper/src/utils/universal_widgets.dart';

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
  CallbackModel receivedCall = CallbackModel();
  Map<String, TrackModel> selectedTracksMap = {};
  PlaylistModel currentPlaylist = const PlaylistModel();
  String option = '';
  UserModel user = UserModel.defaultUser();
  Map<String, TrackModel> allTracks = {};

  bool selectAll = false;
  Map<String, PlaylistModel> allPlaylists = {};
  String playlistId = '';
  
  //Stores Key: playlist ID w/ Values: Title & bool of if 'chosen'
  Map<String, PlaylistModel> selectedPlaylistsMap = {};

  bool adding = false;
  bool error = false;

  @override
  void initState() {
    super.initState();
    final trackArgs = const TrackArguments().toTrackArgs(widget.trackArgs);
    selectedTracksMap = trackArgs.selectedTracks;
    currentPlaylist = trackArgs.currentPlaylist;
    option = trackArgs.option;
    allTracks = trackArgs.allTracks;
    
    playlistId = currentPlaylist.id;
  }

    @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    scaffoldMessengerState = ScaffoldMessenger.of(context);
  }

  Future<void> checkLogin() async{
    CallbackModel? secureCall = await SecureStorage().getTokens();
    UserModel? secureUser = await SecureStorage().getUser();

    if (secureCall == null || secureUser == null){
      bool reLogin = false;
      Navigator.of(context).pushReplacementNamed(StartViewWidget.routeName, arguments: reLogin);
      storageCheck(context, secureCall, secureUser);
    }
    else{
      receivedCall = secureCall;
      user = secureUser;
      await fetchDatabasePlaylists();
    }
  }

  Future<void> fetchDatabasePlaylists() async{
    allPlaylists = await DatabaseStorage().getDatabasePlaylists(user.spotifyId);

    //Checks if only the Liked_Songs playlist is the only playlist
    if (allPlaylists.length == 1){
      await fetchSpotifyPlaylists()
      .catchError((e) => error = true);
    }
    String currentId = currentPlaylist.id;
    allPlaylists.remove(currentId);
  }

  Future<void> fetchSpotifyPlaylists() async {
    bool forceRefresh = false;
    receivedCall = await checkRefresh(receivedCall, forceRefresh)
    .catchError((e) {
      error = true;
      return Future.value(CallbackModel());
    });

    allPlaylists = await getSpotifyPlaylists(receivedCall.expiresAt, receivedCall.accessToken, user.spotifyId)
    .catchError((e) {
      error = true;
      return Future.value(<String, PlaylistModel>{});
    });

    bool updateDatabase = false;
    //Checks all playlists if they are in database
    await DatabaseStorage().syncPlaylists(allPlaylists, user.spotifyId, updateDatabase)
    .onError((error, stackTrace) => error = true);

    String currentId = currentPlaylist.id;
    allPlaylists.remove(currentId);
  }

  //Updates the list of Playlists the user selected
  void receiveSelected(List<MapEntry<String, dynamic>> playlistsSelected) {
    selectedPlaylistsMap.clear();
    
    for (var playlist in playlistsSelected){
      String playlistId = playlist.key;

      if (playlist.value['chosen']){
        selectedPlaylistsMap[playlistId] = allPlaylists[playlistId]!;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 6, 163, 11),
        title: const Text(
          'Playlist(s) Select',
          textAlign: TextAlign.center,
        ),
        actions: [

          //Search Button
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                final result = await showSearch(
                    context: context,
                    delegate: SelectPlaylistSearchDelegate(allPlaylists, selectedPlaylistsMap)
                );
                debugPrint('Result');
                if(result != null){
                  receiveSelected(result);
                }

                setState(() {
                  debugPrint('Selected $selectedPlaylistsMap');
                  //Update Selected Playlists
                });
              }),
        ],
      ),
      body: FutureBuilder<void>(
        future: checkLogin(),
        builder: (context, snapshot) {
          if (error){
            return const Center(
              child: Column(
                children: [
                  Center(
                    child: CircularProgressIndicator.adaptive(),
                  ),
                  Center(
                    child: Text(
                      'Connection Error',
                      textScaler: TextScaler.linear(1.3),
                    )
                  ),
                ]),
            );
          }
          else if (adding){
            return const Center(
              child: Column(
                children: [
                  CircularProgressIndicator.adaptive(),
                  Text(
                    'Adding Tracks to Playlists',
                    textScaler: TextScaler.linear(1.3),
                  )
                ]),
            );
          }
          else if (snapshot.connectionState == ConnectionState.done) {
            return SelectBodyWidget(
              sendSelected: receiveSelected,
              selectedPlaylistsMap: selectedPlaylistsMap,
              playlists: allPlaylists,
              currentPlaylist: currentPlaylist,
              receivedCall: receivedCall,
              user: user);
          } 
          else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      bottomNavigationBar: selectBottomBar()
      );
  }


  Widget selectBottomBar(){

    Icon optionIcon = const Icon(Icons.arrow_forward);
    String optionText = 'Move Songs to Playlist(s)';

    if (option == 'add') {
      optionIcon = const Icon(Icons.add);
      optionText = 'Add Songs to Playlist(s)';
    }

    return BottomAppBar(
      child: InkWell(
        onTap: () async {
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
            .catchError((e){
              debugPrint('Caught Error in select_playlists_view.dart at line ${getCurrentLine(offset: 2)} $e');
            });
            navigateToTracks();

            //Notification for the User alerting them to the result
            Flushbar(
              backgroundColor: const Color.fromARGB(255, 10, 182, 16),
              title: 'Success Message',
              duration: const Duration(seconds: 5),
              flushbarPosition: FlushbarPosition.TOP,
              message: optionMsg,
            ).show(context);
          }
        },

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
          //Text & Icon dependent on what page the user chose to go
          //Move or Add
          Text(optionText),
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
                .catchError((e){
                  debugPrint('Caught Error in select_playlists_view.dart at line ${getCurrentLine(offset: 2)} $e');
                });
                navigateToTracks();

                Flushbar(
                  backgroundColor: const Color.fromARGB(255, 2, 155, 7),
                  title: 'Success Message',
                  duration: const Duration(seconds: 5),
                  flushbarPosition: FlushbarPosition.TOP,
                  message: optionMsg,
                ).show(context);
              }
            },
          ),
        ]),
      ),
    );
  }

  Future<void> handleOptionSelect() async {
    //Get Ids for selected tracks
    List<String> trackIds = [];
    for (var track in selectedTracksMap.entries) {
      trackIds.add(track.key);
    }

    //Get Ids for selected Ids
    List<String> playlistIds = [];
    for (var playlist in selectedPlaylistsMap.entries) {
      playlistIds.add(playlist.key);
    }

    //Move tracks to Playlists
    if (option == 'move') {
      debugPrint('Move Option');
      
      receivedCall = await checkRefresh(receivedCall, false);
      await addTracksRequest(trackIds, playlistIds, receivedCall.expiresAt, receivedCall.accessToken);
      await DatabaseStorage().removeTracks(receivedCall, currentPlaylist, selectedTracksMap, allTracks, user);

      await SpotifySync().startUpdate(playlistIds, scaffoldMessengerState);
    }
    //Adds tracks to Playlists
    else {
      debugPrint('Add Option');

      receivedCall = await checkRefresh(receivedCall, false);
      await addTracksRequest(trackIds, playlistIds, receivedCall.expiresAt, receivedCall.accessToken);
      await SpotifySync().startUpdate(playlistIds, scaffoldMessengerState);
    }
  }

  //FUnction to exit playlists select menu
  void navigateToTracks(){
      debugPrint('Navigate');
      Map<String, dynamic> sendPlaylist = currentPlaylist.toJson();
      //Removes the Stacked Pages until the Home page is the only one Left
      Navigator.popUntil(context, ModalRoute.withName(HomeView.routeName) );
      //Adds the New Tracks Page to Stack
      Navigator.restorablePushNamed(context, TracksView.routeName, arguments: sendPlaylist);
  }

}


