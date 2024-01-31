
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:music_swapper/src/tracks/tracks_view.dart';
import 'package:music_swapper/utils/playlists_requests.dart';
import 'package:music_swapper/utils/tracks_requests.dart';

class SelectBottom extends StatelessWidget {
  const SelectBottom(
      {required this.chosenSongs,
      required this.selectedPlaylists,
      required this.currentPlaylist,
      required this.option,
      required this.receivedCall,
      required this.userId,
      super.key});

  final String option;
  final Map<String, dynamic> currentPlaylist;
  final List<MapEntry<String, dynamic>> selectedPlaylists; //Name and ID of selected playlist
  final Map<String, dynamic> chosenSongs;
  final Map<String, dynamic> receivedCall;
  final String userId;

  //Moves or Adds the selected tracks to the desired playlists
  Future<void> handleOptionSelect(Map<String, dynamic> callback) async {
    String currentId = currentPlaylist.entries.single.value['id'];
    String currentSnapId = currentPlaylist.entries.single.value['snapshotId'];

    //Get Ids for selected tracks
    List<String> trackIds = [];
    for (var track in chosenSongs.entries) {
      trackIds.add(track.value['id']);
    }

    //Get Ids for selected Ids
    List<String> selectedIds = [];
    for (var entries in selectedPlaylists) {
      selectedIds.add(entries.value);
    }

    //Move tracks to Playlists
    if (option == 'move') {
      callback = await checkRefresh(callback, false);
      moveTracksRequest(trackIds, currentId, currentSnapId, selectedIds, callback['expiresAt'], callback['accessToken']);
    }
    //Adds tracks to Playlists
    else {
      callback = await checkRefresh(callback, false);
      addTracksRequest(trackIds, selectedIds, callback['expiresAt'],
          callback['accessToken']);
    }
  }

  //FUnction to exit playlists select menu
  void navigateToTracks(BuildContext context, Map<String, dynamic> callback){
    Map<String, dynamic> multiArgs = {
      'currentPlaylist': currentPlaylist,
      'callback': callback,
      'user': userId,
      };
      Navigator.popAndPushNamed(context, TracksView.routeName, arguments: multiArgs);
  }

  @override
  Widget build(BuildContext context) {
    Icon optionIcon = const Icon(Icons.arrow_forward);
    String optionText = 'Move Songs to Playlist(s)';

    int totalChosen = chosenSongs.length;
    int totalPlaylists = 0;

    //Sets variables for User Notification
    totalPlaylists = selectedPlaylists.length;

    List chosenPLaylists = [];
    for (var element in selectedPlaylists) { 
      chosenPLaylists.add(element.value['title']);
    }

     //Message to display to the user
    String optionMsg = (option == 'move')
          ? 'Successfully moved $totalChosen songs to $chosenPLaylists playlists'
          : 'Successfully added $totalChosen songs to $chosenPLaylists playlists';

    if (option == 'add') {
      optionIcon = const Icon(Icons.add);
      optionText = 'Add Songs to Playlist(s)';
    }

    return BottomAppBar(
      child: InkWell(
        onTap: () async {
          handleOptionSelect(receivedCall);
          navigateToTracks(context, receivedCall);

          //Notification for the User alerting them to the result
          Flushbar(
            title: 'Success Message',
            duration: const Duration(seconds: 5),
            flushbarPosition: FlushbarPosition.TOP,
            message: optionMsg,
          ).show(context);
        },

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
          //Text & Icon dependent on what page the user chose to go
          //Move or Add
          Text(optionText),
          IconButton(
            icon: optionIcon,
            onPressed: () {

              if (option == 'move') {
                handleOptionSelect(receivedCall);
                navigateToTracks(context, receivedCall);

                Flushbar(
                  title: 'Success Message',
                  duration: const Duration(seconds: 5),
                  flushbarPosition: FlushbarPosition.TOP,
                  message: optionMsg,
                ).show(context);
              }
              //Option was Add
              else {
                handleOptionSelect(receivedCall);
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