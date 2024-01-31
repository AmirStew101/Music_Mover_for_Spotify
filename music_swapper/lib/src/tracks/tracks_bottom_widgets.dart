import 'package:flutter/material.dart';
import 'package:music_swapper/src/select_playlists/select_playlists.dart';
import 'package:music_swapper/utils/database/database_model.dart';
import 'package:music_swapper/utils/playlists_requests.dart';
import 'package:music_swapper/utils/tracks_requests.dart';

class TracksBottomBar extends StatelessWidget {
  TracksBottomBar({
      required this.currentPlaylist,
      required this.tracks,
      required this.receivedCall,
      required this.refreshTracks,
      required this.userId,
      super.key
  });

  final Map<String, dynamic> currentPlaylist;
  final Map<String, dynamic> tracks;
  final String userId;
  final void Function(Map<String, dynamic> chosenTracks) refreshTracks;
  final Map<String, dynamic> receivedCall;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: const Color.fromARGB(255, 6, 163, 11),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.drive_file_move_rtl_rounded),
          label: 'Move to Playlists'),

        BottomNavigationBarItem(
          icon: Icon(Icons.add),
          label: 'Add to Playlists',
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.delete),
          label: 'Remove',
        ),
      ],
      onTap: (value) {

        if (value == 0){

        }
        //Move to playlist(s) Index
        if (value == 0) {
          final multiArgs = {
            'callback': receivedCall,
            'tracks': tracks,
            'currentPlaylist': currentPlaylist,
            'option': 'move',
            'user': userId,
          };
          Navigator.restorablePushNamed(context, SelectPlaylistsWidget.routeName, arguments: multiArgs);
        } 
        //Add to playlist(s) index
        else if (value == 1) {
          final multiArgs = {
            'callback': receivedCall,
            'tracks': tracks,
            'currentPlaylist': currentPlaylist,
            'option': 'add',
            'user': userId,
          };
          Navigator.restorablePushNamed(context, SelectPlaylistsWidget.routeName, arguments: multiArgs);
        } 
        //Remove from current playlist
        else {
          removeTracks(receivedCall);
          refreshTracks(tracks);
        }
      },
    );
  }

  Future<void> removeTracks(Map<String, dynamic> callback) async {

  String currentId = currentPlaylist.entries.single.key;
  String currentSnapId = currentPlaylist.entries.single.value['snapshotId'];
  debugPrint('Current PLaylist: ${currentPlaylist.entries.single.value['snapshotId']}');

  //Get Ids for selected tracks
  List<String> trackIds = [];
  for (var track in tracks.entries) {
    trackIds.add(track.key);
  }

  callback = await checkRefresh(receivedCall, false);
  removeTracksRequest(trackIds, currentId, currentSnapId, receivedCall['expiresAt'], receivedCall['accessToken']);
  }
  
}