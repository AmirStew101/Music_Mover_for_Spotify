import 'package:flutter/material.dart';
import 'package:music_swapper/src/select_playlists/select_body.dart';
import 'package:music_swapper/src/select_playlists/select_bottom.dart';
import 'package:music_swapper/utils/playlists_requests.dart';
import 'package:music_swapper/src/select_playlists/select_appbar.dart';
import 'package:music_swapper/utils/universal_widgets.dart';

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
  
  //Stores Key: playlist ID w/ Values: Title & bool of if 'chosen'
  List<MapEntry<String, dynamic>> selectedPlaylists = [];

  @override
  void initState() {
    super.initState();
    final multiArgs = widget.multiArgs;
    receivedCall = multiArgs['callback'];
    chosenTracks = multiArgs['tracks'];
    currentPlaylist = multiArgs['currentPlaylist'];
    option = multiArgs['option'];
    userId = multiArgs['user'];
  }

  Future<void> fetchDatabasePlaylists() async{
    final Map<String, dynamic> multiArgs = widget.multiArgs;
    receivedCall = multiArgs['callback'];
    userId = multiArgs['user'];

    playlists = await getDatabasePlaylists(userId);

    if (playlists.isEmpty){
      await fetchSpotifyPlaylists();
    }
  }

  Future<void> fetchSpotifyPlaylists() async {
    bool forceRefresh = false;
    receivedCall = await checkRefresh(receivedCall, forceRefresh);

    playlists = await getSpotifyPlaylists(receivedCall['expiresAt'], receivedCall['accessToken']);

    //Checks all playlists if they are in database
    checkPlaylists(playlists, userId);
  }

  //Updates the list of Playlists the user selected
  void receiveSelected(List<MapEntry<String, dynamic>> playlistsSelected) {
    selectedPlaylists = playlistsSelected;
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
                List<MapEntry<String, dynamic>> result = await showSearch(
                    context: context,
                    delegate: SelectPlaylistSearchDelegate(playlists, selectedPlaylists)
                );
                selectedPlaylists = result;
                setState(() {
                  debugPrint('Selected $selectedPlaylists');
                  //Update Selected Playlists
                });
              }),
        ],
      ),
      body: FutureBuilder<void>(
        future: fetchDatabasePlaylists(),
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
          receivedCall: receivedCall,
          userId: userId),
    );
  }
}

