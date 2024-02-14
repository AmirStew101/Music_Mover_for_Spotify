// ignore_for_file: use_build_context_synchronously

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/login/login_Screen.dart';
import 'package:spotify_music_helper/src/select_playlists/select_body.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/utils/object_models.dart';
import 'package:spotify_music_helper/utils/playlists_requests.dart';
import 'package:spotify_music_helper/src/select_playlists/select_appbar.dart';
import 'package:spotify_music_helper/utils/tracks_requests.dart';
import 'package:spotify_music_helper/utils/universal_widgets.dart';

class SelectPlaylistsViewWidget extends StatefulWidget {
  static const routeName = '/SelectPlaylists';
  const SelectPlaylistsViewWidget({super.key, required this.multiArgs});
  final Map<String, dynamic> multiArgs;

  @override
  State<SelectPlaylistsViewWidget> createState() => SelectPlaylistsViewState();
}

class SelectPlaylistsViewState extends State<SelectPlaylistsViewWidget> {
  //Passed variables
  CallbackModel receivedCall = CallbackModel();
  Map<String, dynamic> selectedTracksMap = {};
  Map<String, dynamic> currentPlaylist = {};
  String option = '';
  UserModel user = UserModel();

  bool selectAll = false;
  Map<String, dynamic> allPlaylists = {};
  String playlistId = '';
  
  //Stores Key: playlist ID w/ Values: Title & bool of if 'chosen'
  Map<String, dynamic> selectedPlaylistsMap = {};

  @override
  void initState() {
    super.initState();
    final multiArgs = widget.multiArgs;
    selectedTracksMap = multiArgs['selectedTracks'];
    currentPlaylist = multiArgs['currentPlaylist'];
    option = multiArgs['option'];

    playlistId = currentPlaylist.keys.single;
  }

  Future<void> checkLogin() async{
    CallbackModel? secureCall = await SecureStorage().getTokens();
    UserModel? secureUser = await SecureStorage().getUser();

    if (secureCall == null || secureUser == null){
      Navigator.of(context).pushReplacementNamed(StartView.routeName);
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
      await fetchSpotifyPlaylists();
    }
    String currentId = currentPlaylist.entries.single.key;
    allPlaylists.remove(currentId);
  }

  Future<void> fetchSpotifyPlaylists() async {
    bool forceRefresh = false;
    receivedCall = await checkRefresh(receivedCall, forceRefresh);

    allPlaylists = await getSpotifyPlaylists(receivedCall.expiresAt, receivedCall.accessToken, user.spotifyId);

    //Checks all playlists if they are in database
    await DatabaseStorage().syncPlaylists(allPlaylists, user.spotifyId);

    String currentId = currentPlaylist.entries.single.key;
    allPlaylists.remove(currentId);
  }

  //Updates the list of Playlists the user selected
  void receiveSelected(List<MapEntry<String, dynamic>> playlistsSelected) {
    selectedPlaylistsMap.clear();
    
    for (var playlist in playlistsSelected){
      String playlistId = playlist.key;

      if (playlist.value['chosen']){
        selectedPlaylistsMap[playlistId] = allPlaylists[playlistId];
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
          if (snapshot.connectionState == ConnectionState.done) {
            return SelectBodyWidget(
              sendSelected: receiveSelected,
              selectedPlaylistsMap: selectedPlaylistsMap,
              playlists: allPlaylists,
              currentPlaylist: currentPlaylist,
              receivedCall: receivedCall,
              user: user);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      bottomNavigationBar: selectBottomBar()
      );
  }


  Widget selectBottomBar(){
    List<String> trackIds = List.generate(selectedTracksMap.length, (index) {
      final currTrack = selectedTracksMap.entries.elementAt(index);
      return currTrack.key;
    });

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
            int totalChosen = selectedTracksMap.length;
            
            //Sets variables for User Notification
            int totalPlaylists = selectedPlaylistsMap.length;

            //Message to display to the user
            String optionMsg = (option == 'move')
                  ? 'Successfully moved $totalChosen songs to $totalPlaylists playlists'
                  : 'Successfully added $totalChosen songs to $totalPlaylists playlists';

            await handleOptionSelect();
            await DatabaseStorage().removeDatabaseTracks(user.spotifyId, trackIds, playlistId);
            navigateToTracks();

            //Notification for the User alerting them to the result
            Flushbar(
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
                int totalChosen = selectedTracksMap.length;
            
                //Sets variables for User Notification
                int totalPlaylists = selectedPlaylistsMap.length;

                //Message to display to the user
                String optionMsg = (option == 'move')
                      ? 'Successfully moved $totalChosen songs to $totalPlaylists playlists'
                      : 'Successfully added $totalChosen songs to $totalPlaylists playlists';

                await handleOptionSelect();
                navigateToTracks();

                Flushbar(
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
    String currentId = currentPlaylist.entries.single.key;
    String currentSnapId = currentPlaylist.entries.single.value['snapshotId'];

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
      await moveTracksRequest(trackIds, currentId, currentSnapId, playlistIds, receivedCall.expiresAt, receivedCall.accessToken);
      await DatabaseStorage().removeDatabaseTracks(user.spotifyId, trackIds, playlistId);
    }
    //Adds tracks to Playlists
    else {
      debugPrint('Add Option');

      receivedCall = await checkRefresh(receivedCall, false);
      await addTracksRequest(trackIds, playlistIds, receivedCall.expiresAt, receivedCall.accessToken);
    }
  }

  //FUnction to exit playlists select menu
  void navigateToTracks(){
    debugPrint('Navigate');
    Map<String, dynamic> multiArgs = {
      'currentPlaylist': currentPlaylist,
      'callback': receivedCall,
      'user': user,
      };
      Navigator.popAndPushNamed(context, TracksView.routeName, arguments: multiArgs);
  }

}


