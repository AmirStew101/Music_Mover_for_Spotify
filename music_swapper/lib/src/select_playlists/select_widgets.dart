// ignore: must_be_immutable
import 'package:flutter/material.dart';
import 'package:music_swapper/src/tracks/tracks_view.dart';
import 'package:music_swapper/utils/playlists_requests.dart';
import 'package:music_swapper/utils/tracks_requests.dart';
import 'package:another_flushbar/flushbar.dart';



class SelectBodyWidget extends StatefulWidget {
  const SelectBodyWidget(
      {super.key,
      required this.currentPlaylist,
      required this.selectedPlaylists,
      required this.playlists,
      required this.receivedCall,
      required this.sendSelected,
      required this.userId,
      }
  );
  final List<MapEntry<String, String>> selectedPlaylists; //Name & ID of selected playlists
  final Map<String, dynamic> currentPlaylist;
  final Map<String, dynamic> playlists;
  final Map<String, dynamic> receivedCall;
  final void Function(List<MapEntry<String, bool>>) sendSelected;
  final String userId;

  @override
  State<SelectBodyWidget> createState() => SelectBodyState();
}

//Users Playlists to move selected songs to
class SelectBodyState extends State<SelectBodyWidget> {
  Map<String, dynamic> playlists = {};
  late final void Function(List<MapEntry<String, bool>>) sendSelected;
  Map<String, dynamic> currentPlaylist = {};
  Map<String, dynamic> receivedCall = {};

  List<MapEntry<String, bool>> selectedPlaylists = []; //Will store the playlist Name and ID
  String currentName = '';
  bool selectAll = false;

  @override
  void initState() {
    super.initState();
    playlists = widget.playlists;
    sendSelected = widget.sendSelected;
    currentPlaylist = widget.currentPlaylist;
    receivedCall = widget.receivedCall;
    final List<MapEntry<String, String>> prassedSelect = widget.selectedPlaylists;

    currentName = currentPlaylist.entries.single.key;

    bool isPassed = false;
    playlists.forEach((key, value) {
      isPassed = false;
      for (var item in prassedSelect){
        if (key == item.key){
          isPassed = true;
        }
      }
      if (isPassed){
        selectedPlaylists.add(MapEntry(key, true));
      }
      else{
        selectedPlaylists.add(MapEntry(key, false));
      }
      
    });
  }

  Future<void> refreshPlaylists() async {
    bool forceRefresh = false;
    //Checks to make sure Tokens are up to date before making a Spotify request
    receivedCall = await checkRefresh(receivedCall, forceRefresh);

    final responsePLaylists = await getSpotifyPlaylists(
        receivedCall['expiresAt'], receivedCall['accessToken']);

    if (responsePLaylists['status'] == 'Success') {
      playlists = responsePLaylists['data'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return RefreshIndicator(
        onRefresh: refreshPlaylists,
        child: Stack(
          children: [
            ListView.builder(
              itemCount: playlists.length - 1,
              itemBuilder: (context, index) {
                MapEntry<String, dynamic> playEntry =
                    playlists.entries.elementAt(index);
                String playName = playEntry.key;

                if (playName == currentName) {
                  //Skip current playlist
                  return Container();
                } else {
                  return InkWell(
                      onTap: () {
                        setState(() {
                          bool currState = selectedPlaylists[index].value;
                          selectedPlaylists[index] = MapEntry(playName, !currState);
                        });
                        sendSelected(selectedPlaylists);
                      },
                      child: ListTile(
                          leading: Checkbox(
                            value: selectedPlaylists[index].value,
                            onChanged: (value) {
                              setState(() {
                                bool currState = selectedPlaylists[index].value;
                                selectedPlaylists[index] = MapEntry(playName, !currState);
                              });
                              sendSelected(selectedPlaylists);
                            },
                          ),
                          title: Text(playName)));
                }
              },
            ),
            // Hovering "Select All" button
            Positioned(
                top: screenHeight * 0.02,
                right: screenWidth * 0.05,
                child: FilterChip(
                  backgroundColor: selectAll
                      ? const Color.fromARGB(255, 6, 163, 11)
                      : Colors.grey,
                  label: selectAll
                      ? const Text('Deselect All')
                      : const Text('Select All'),
                  padding: const EdgeInsets.all(10.0),
                  onSelected: (value) {
                    setState(() {
                      selectAll = !selectAll;
                    });
                      //Selects all the check boxes
                      if (selectAll) {
                        for (int i = 0; i < playlists.length; i++) {
                          MapEntry<String, dynamic> playEntry =
                              playlists.entries.elementAt(i);
                          String playName = playEntry.key;
                          selectedPlaylists[i] = MapEntry(playName, true);
                        }
                        sendSelected(selectedPlaylists);
                      } else {
                        //Deselects all check boxes
                        for (int i = 0; i < playlists.length; i++) {
                          MapEntry<String, dynamic> playEntry =
                              playlists.entries.elementAt(i);
                          String playName = playEntry.key;
                          selectedPlaylists[i] = MapEntry(playName, false);
                        }
                        sendSelected(selectedPlaylists);
                      }
                  },
                ))
          ],
        ));
  }
}

class SelectBottom extends StatelessWidget {
  SelectBottom(
      {required this.chosenSongs,
      required this.selectedPlaylists,
      required this.currentPlaylist,
      required this.option,
      required this.callback,
      required this.userId,
      super.key});

  final String option;
  final Map<String, dynamic> currentPlaylist;
  final List<MapEntry<String, dynamic>> selectedPlaylists; //Name and ID of selected playlist
  final Map<String, dynamic> chosenSongs;
  Map<String, dynamic> callback;
  String userId;

  //Moves or Adds the selected tracks to the desired playlists
  Future<void> handleOptionSelect() async {

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
  void navigateToTracks(context){
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

    int trackTotal = chosenSongs.length;
    int totalPlaylists = 0;

    String optionMsg = ''; //Message to display to the user

    if (option == 'add') {
      optionIcon = const Icon(Icons.add);
      optionText = 'Add Songs to Playlist(s)';
    }

    return BottomAppBar(
      child: InkWell(
        onTap: () async {
          //Sets variables for User Notification
          totalPlaylists = selectedPlaylists.length;
          optionMsg = (option == 'move')
          ? 'Successfully moved $trackTotal songs to $totalPlaylists playlists'
          : 'Successfully added $trackTotal songs to $totalPlaylists playlists';

          handleOptionSelect();
          navigateToTracks(context);

          //Notification for the User alerting them to the result
          Flushbar(
            title: 'Success Message',
            duration: const Duration(seconds: 5),
            flushbarPosition: FlushbarPosition.TOP,
            message: optionMsg,
          ).show(context);
        },
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(optionText),
          IconButton(
            icon: optionIcon,
            onPressed: () {
              if (option == 'move') {
                //Sets variables for User Notification
                totalPlaylists = selectedPlaylists.length;
                optionMsg = 'Successfully Moved $trackTotal songs to $totalPlaylists playlists';

                handleOptionSelect();
                navigateToTracks(context);

                Flushbar(
                  title: 'Success Message',
                  duration: const Duration(seconds: 5),
                  flushbarPosition: FlushbarPosition.TOP,
                  message: optionMsg,
                ).show(context);
              } else {
                //Sets variables for User Notification
                totalPlaylists = selectedPlaylists.length;
                optionMsg = 'Successfully Added $trackTotal songs to $totalPlaylists playlists';

                handleOptionSelect();
                navigateToTracks(context);

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
