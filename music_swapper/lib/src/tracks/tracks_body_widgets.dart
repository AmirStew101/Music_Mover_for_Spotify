import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:music_swapper/utils/database/database_model.dart';
import 'package:music_swapper/utils/playlists_requests.dart';
import 'package:music_swapper/utils/tracks_requests.dart';
import 'package:music_swapper/utils/universal_widgets.dart';

//Creates the state to update tracks the user selected
//Receives all the users tracks for the selected playlist
class TrackListWidget extends StatefulWidget {
  const TrackListWidget({
    required this.allTracks, 
    required this.selectedTracksMap,
    required this.sendTracks,
    required this.receivedCall,
    required this.playlistId,
    required this.user,
    super.key
  });

  final Map<String, dynamic> allTracks;
  final Map<String, dynamic> selectedTracksMap;
  final Map<String, dynamic> receivedCall;
  final String playlistId;
  final Map<String, dynamic> user;
  final void Function(List<MapEntry<String, dynamic>>) sendTracks;

  @override
  State<TrackListWidget> createState() => TrackListState();
}

//Main functionality for displaying, updating, and listening to previews of tracks
class TrackListState extends State<TrackListWidget> {

  //Map of the track with key = 'Track ID' and value = {images:, previewUrl:, artist:, title:}
  Map<String, dynamic> allTracks = {};
  Map<String, dynamic> receivedCall = {};
  Map<String, dynamic> user = {};

  final audioPlayer = AudioPlayer(); //Used to play previewUrl

  //Key: Track ID & values: if 'chosen' bool & Title
  late List<MapEntry<String, dynamic>> selectedTracks = [];
  late List<MapEntry<String, dynamic>> playingList = []; //User selected song to preview

  //Function to send selected tracks to main body
  late void Function(List<MapEntry<String, dynamic>>) sendTracks;

  bool selectAll = false;
  String playlistId = '';

  //Creates lists for comparing if tracks are selected or if a track is playing
  //Fills the tracks Map with the users tracks fromthe widget
  @override
  void initState() {
    super.initState();
    user = widget.user;
    playlistId = widget.playlistId;
    sendTracks = widget.sendTracks;
    allTracks = widget.allTracks;
    receivedCall = widget.receivedCall;

    initialSelect();
  }

  void initialSelect(){
    if (allTracks.isNotEmpty) {
      Map<String, dynamic> chosenTracks = widget.selectedTracksMap;

      //Initializes the selected playlists
      selectedTracks = List.generate(allTracks.length, (index) {
        MapEntry currTrack = allTracks.entries.elementAt(index);

        String trackTitle = currTrack.value['title'];
        String trackId = currTrack.key;
        bool selected = false;

        //If the track is already selected from past widget
        if (chosenTracks.containsKey(trackId)){
          selected = true;
        }

        Map<String, dynamic> selectMap = {'chosen': selected, 'title': trackTitle};

        return MapEntry(trackId, selectMap);
      });

      //Initializes the playing list
      playingList = List.generate(allTracks.length, (index) {
        String trackTitle = allTracks.entries.elementAt(index).value['title'];
        String trackId = allTracks.entries.elementAt(index).key;
        String playUrl = allTracks.entries.elementAt(index).value['preview_url'] ?? '';

        Map<String, dynamic> playMap = {'playing': false, 'title': trackTitle, 'playUrl': playUrl};

        return MapEntry(trackId, playMap);
      });

    }
  }


  //Gets Tracks from Spotify to update database
  Future<void> refreshTracks() async{
    debugPrint('Refresh Tracks');

    receivedCall = await checkRefresh(receivedCall, false);
    final totalTracks = await getSpotifyTracksTotal(playlistId, receivedCall['expiresAt'], receivedCall['accessToken']);

    if (totalTracks > 0) {
      //gets user tracks for playlist
      allTracks = await getSpotifyPlaylistTracks(
          playlistId,
          receivedCall['expiresAt'],
          receivedCall['accessToken'],
          totalTracks);

      //Keeps tracks that are already selected
      if (selectedTracks.isNotEmpty){
        debugPrint('Selected $selectedTracks');
        List<MapEntry<String, dynamic>> newSelected = [];

        //Refereshes the slected list
        for (var track in allTracks.entries){
          String trackId = track.key;
          String trackTitle = track.value['title'];

          final Map<String, dynamic> trackMap = {'chosen': true, 'title': trackTitle};
          final Map<String, dynamic> selectedMap = {'chosen': false, 'title': trackTitle};

          final selected = selectedTracks.firstWhere((element) => element.key == trackId);

          if (selected.value['chosen']){
            debugPrint('Selected $trackTitle');
            newSelected.add(MapEntry(trackId, trackMap));
          }
          else{
            debugPrint('Not Selected $trackTitle');
            newSelected.add(MapEntry(trackId, selectedMap));
          }
        }
        selectedTracks = newSelected;
      }
      //There are no already selected songs
      else{
        for (var track in allTracks.entries){
          String trackId = track.key;
          String trackTitle = track.value['title'];
          Map<String, dynamic> selectedMap = {'chosen': false, 'title': trackTitle};

          selectedTracks.add(MapEntry(trackId, selectedMap));
        }
      }
    }
    //Playlist has no songs
    else{
      allTracks = {};
      selectedTracks = [];
    }

    //Adds tracks to database for faster retreival later
    await syncPlaylistTracksData(user['id'], allTracks, playlistId);

    setState(() {
      //refreshes tracks
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return RefreshIndicator(
      onRefresh: refreshTracks,

      //Stack for the hovering select all button & tracks view
      child: Stack(
        children: [ ListView.builder(
            itemCount: allTracks.length,
            itemBuilder: (context, index) {
              final trackMap = allTracks.entries.elementAt(index);

              //Used for displaying track information
              final trackTitle = trackMap.value['title'];
              final trackImage = trackMap.value['imageUrl'];
              final trackPrevUrl = trackMap.value?['previewUrl'] ?? '';
              final trackArtist = trackMap.value['artist'];

              //Used to update Selected Tracks
              final chosen = selectedTracks[index].value['chosen'];
              final trackId = selectedTracks[index].key;
              final selectMap = {'chosen': !chosen, 'title': trackTitle};

              //Alligns the songs as a Column
              return Column(children: [
                //Lets the entire left section with checkbox and Title be selected
                InkWell(
                    onTap: () {
                      debugPrint('Track Id: ${trackMap.key}\n Selected Id: $trackId');
                      debugPrint('Track Name: $trackTitle\n Selected Id: ${selectMap.values.last}');
                      debugPrint('Selected Index before: ${selectedTracks[index]}');
                      setState(() {
                        selectedTracks[index] = MapEntry(trackId, selectMap);
                        debugPrint('Selected Index after: ${selectedTracks[index]}');
                        sendTracks(selectedTracks);
                      });
                    },
                    //Container puts the Tracks image in the background
                    child: Container(
                        decoration: BoxDecoration(
                            image: DecorationImage(
                              alignment: Alignment.topRight,
                              image: NetworkImage(
                                trackImage,
                                scale: 0.9),
                              fit: BoxFit.fitHeight,
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
                
              ]);
            }),

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

                      //Selects all the check boxes
                      if (selectAll) {
                        for (int i = 0; i < selectedTracks.length; i++) {
                          String trackTitle = selectedTracks[i].value['title'];
                          String trackId = selectedTracks[i].key;

                          Map<String, dynamic> selectMap = {'chosen': true, 'title': trackTitle};

                          selectedTracks[i] = MapEntry(trackId, selectMap);
                        }
                        sendTracks(selectedTracks);
                      } 
                      else {
                        //Deselects all check boxes
                        for (int i = 0; i < selectedTracks.length; i++) {
                          String trackTitle = selectedTracks[i].value['title'];
                          String trackId = selectedTracks[i].key;

                          Map<String, dynamic> selectMap = {'chosen': false, 'title': trackTitle};

                          selectedTracks[i] = MapEntry(trackId, selectMap);
                        }
                        sendTracks(selectedTracks);
                      }
                    });
                  },
                ))
    ])
    );
  }

  //Creates the State for each Tracks Row
  Widget trackRows(int index, String trackTitle, String trackArtist){
        return Row(children: [
      //Design & Functinoality for the checkbox button when selected and not
      Checkbox(
        value: selectedTracks[index].value['chosen'],
        onChanged: (value) {
          setState(() {
            bool chosen = selectedTracks[index].value['chosen'];
            String trackId = selectedTracks[index].key;
            Map<String, dynamic> selectMap = {'chosen': !chosen, 'title': trackTitle};
            
            selectedTracks[index] = MapEntry(trackId, selectMap);
            sendTracks(selectedTracks);
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
            trackTitle,
            textScaler: const TextScaler.linear(1.2),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color.fromARGB(255, 6, 163, 11)),
          ),
          //Name of track Artist show to user
          Text(
            'By: $trackArtist',
            textScaler: const TextScaler.linear(0.8),
          ),
      ]),
    ]);
  }
}
