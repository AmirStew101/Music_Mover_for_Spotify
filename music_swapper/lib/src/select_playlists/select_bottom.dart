
// ignore_for_file: use_build_context_synchronously

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/utils/playlists_requests.dart';
import 'package:spotify_music_helper/utils/tracks_requests.dart';
import 'package:spotify_music_helper/utils/universal_widgets.dart';

class SelectBottom extends StatelessWidget {
  const SelectBottom(
      {required this.chosenSongs,
      required this.selectedPlaylists,
      required this.currentPlaylist,
      required this.option,
      required this.receivedCall,
      required this.user,
      super.key});

  final String option;
  final Map<String, dynamic> currentPlaylist;
  final List<MapEntry<String, dynamic>> selectedPlaylists; //Name and ID of selected playlist
  final Map<String, dynamic> chosenSongs;
  final Map<String, dynamic> receivedCall;
  final Map<String, dynamic> user;

  //Moves or Adds the selected tracks to the desired playlists
  Future<void> handleOptionSelect(Map<String, dynamic> callback) async {
    String currentId = currentPlaylist.entries.single.key;
    String currentSnapId = currentPlaylist.entries.single.value['snapshotId'];

    //Get Ids for selected tracks
    List<String> trackIds = [];
    for (var track in chosenSongs.entries) {
      trackIds.add(track.key);
    }
    debugPrint('Track ids: $trackIds');

    //Get Ids for selected Ids
    List<String> playlistIds = [];
    for (var playlist in selectedPlaylists) {
      playlistIds.add(playlist.key);
    }
    debugPrint('Selected Playlists: $selectedPlaylists');

    //Move tracks to Playlists
    if (option == 'move') {
      callback = await checkRefresh(callback, false);
      await moveTracksRequest(trackIds, currentId, currentSnapId, playlistIds, callback['expiresAt'], callback['accessToken']);
      await syncPlaylistTracksData(user['id'], chosenSongs, currentId);
    }
    //Adds tracks to Playlists
    else {
      callback = await checkRefresh(callback, false);
      await addTracksRequest(trackIds, playlistIds, callback['expiresAt'], callback['accessToken']);
      await syncPlaylistTracksData(user['id'], chosenSongs, currentId);
    }
  }

  //FUnction to exit playlists select menu
  void navigateToTracks(BuildContext context, Map<String, dynamic> callback){
    Map<String, dynamic> multiArgs = {
      'currentPlaylist': currentPlaylist,
      'callback': callback,
      'user': user,
      };
      Navigator.popAndPushNamed(context, TracksView.routeName, arguments: multiArgs);
  }

  @override
  Widget build(BuildContext context) {
    Icon optionIcon = const Icon(Icons.arrow_forward);
    String optionText = 'Move Songs to Playlist(s)';

    int totalChosen = chosenSongs.length;

    //Sets variables for User Notification
    int totalPlaylists = selectedPlaylists.length;

     //Message to display to the user
    String optionMsg = (option == 'move')
          ? 'Successfully moved $totalChosen songs to $totalPlaylists playlists'
          : 'Successfully added $totalChosen songs to $totalPlaylists playlists';

    if (option == 'add') {
      optionIcon = const Icon(Icons.add);
      optionText = 'Add Songs to Playlist(s)';
    }

    return BottomAppBar(
      child: InkWell(
        onTap: () async {
          if (chosenSongs.isNotEmpty){
            await handleOptionSelect(receivedCall);
            navigateToTracks(context, receivedCall);

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
              if (chosenSongs.isNotEmpty){
                //Option was to Move tracks
                await handleOptionSelect(receivedCall);
                navigateToTracks(context, receivedCall);

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
}