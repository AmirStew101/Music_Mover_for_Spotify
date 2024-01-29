import 'package:flutter/material.dart';
import 'package:music_swapper/src/select_playlists/select_widgets.dart';
import 'package:music_swapper/utils/playlists_requests.dart';
import 'package:music_swapper/src/select_playlists/select_appbar.dart';

class SelectPlaylistsWidget extends StatefulWidget {
  static const routeName = '/SelectPlaylists';
  const SelectPlaylistsWidget({super.key, required this.multiArgs});
  final Map<String, dynamic> multiArgs;

  @override
  State<SelectPlaylistsWidget> createState() => SelectPlaylistsState();
}

class SelectPlaylistsState extends State<SelectPlaylistsWidget> {
  //Passed variables
  Map<String, dynamic> receivedCall = {};
  Map<String, dynamic> chosenTracks = {};
  Map<String, dynamic> currentPlaylist = {};
  String option = '';
  String userId = '';

  bool selectAll = false;
  Map<String, dynamic> playlists = {};
  
  List<MapEntry<String, String>> selectedPlaylists = []; //Stores the Name and ID of the selected playlists

  @override
  void initState() {
    super.initState();
    final multiArgs = widget.multiArgs;
    receivedCall = multiArgs['callback'];
    chosenTracks = multiArgs['tracks'];
    currentPlaylist = multiArgs['currentPlaylist'];
    option = multiArgs['option'];
    userId = multiArgs['user'];

    fetchPlaylists();
  }

  Future<void> fetchPlaylists() async {
    bool forceRefresh = false;
    receivedCall = await checkRefresh(receivedCall, forceRefresh);

    final response = await getSpotifyPlaylists(
        receivedCall['expiresAt'] as double, receivedCall['accessToken']);

    if (response['status'] == 'Success') {
      playlists = response['data'];
    }
  }

  //Updates the list of Playlists the user selected
  void receiveSelected(List<MapEntry<String, bool>> playlistsSelected) {
    selectedPlaylists.clear();
    for (var item in playlistsSelected) {
      String playId = playlists[item.key]['id'];
      String playName = item.key;
      bool selected = item.value;

      //Playlist is selected and not in selected Playlist List
      if (selected && !selectedPlaylists.contains(MapEntry(playName, playId))) {
        selectedPlaylists.add(MapEntry(playName, playId));
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
                final List<MapEntry<String, dynamic>> result = await showSearch(
                    context: context,
                    delegate: SelectPlaylistSearchDelegate(playlists, selectedPlaylists)
                );
                selectedPlaylists.clear();
                  for (var item in result){
                      if (item.value){
                        selectedPlaylists.add(MapEntry(item.key ,playlists[item.key]['id']) );
                      }
                  }
                setState(() {
                  debugPrint('Selected $selectedPlaylists');
                  //Update Selected Playlists
                });
              }),
        ],
      ),
      body: FutureBuilder<void>(
        future: fetchPlaylists(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return SelectBodyWidget(
              sendSelected: receiveSelected,
              selectedPlaylists: selectedPlaylists,
              playlists: playlists,
              currentPlaylist: currentPlaylist,
              receivedCall: receivedCall,
              userId: userId);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      bottomNavigationBar: SelectBottom(
          option: option,
          selectedPlaylists: selectedPlaylists,
          currentPlaylist: currentPlaylist,
          chosenSongs: chosenTracks,
          callback: receivedCall,
          userId: userId),
    );
  }
}

