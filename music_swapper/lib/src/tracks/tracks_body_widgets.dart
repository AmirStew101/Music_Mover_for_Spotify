import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:music_swapper/utils/database/database_model.dart';
import 'package:music_swapper/utils/playlists_requests.dart';
import 'package:music_swapper/utils/tracks_requests.dart';

//Creates the state to update tracks the user selected
//Receives all the users tracks for the selected playlist
class TrackListWidget extends StatefulWidget {
  const TrackListWidget({
    required this.allTracks, 
    required this.selectedTracks,
    required this.sendTracks,
    required this.receivedCall,
    required this.playlistId,
    required this.refreshTracks, 
    super.key
  });

  final Map<String, dynamic> allTracks;
  final Map<String, dynamic> selectedTracks;
  final Map<String, dynamic> receivedCall;
  final String playlistId;
  final Future<void> Function() refreshTracks;
  final void Function(List<MapEntry<String, dynamic>>) sendTracks;

  @override
  State<TrackListWidget> createState() => TrackListState();
}

//Main functionality for displaying, updating, and listening to previews of tracks
class TrackListState extends State<TrackListWidget> {

  //Map of the track with key = 'Track ID' and value = {images:, previewUrl:, artist:, title:}
  Map<String, dynamic> allTracks = {};
  Map<String, dynamic> receivedCall = {};
  late Future<void> Function() refreshTracks; //Function for updating users tracks

  final audioPlayer = AudioPlayer(); //Used to play previewUrl

  //Key: Track ID & values: if 'chosen' bool & Title
  late List<MapEntry<String, dynamic>> selectedTracks = [];
  late List<MapEntry<String, dynamic>> playingList = []; //User selected song to preview

  //Function to send selected tracks to main body
  late void Function(List<MapEntry<String, dynamic>>) sendTracks;

  bool selectAll = false;

  //Creates lists for comparing if tracks are selected or if a track is playing
  //Fills the tracks Map with the users tracks fromthe widget
  @override
  void initState() {
    super.initState();
    sendTracks = widget.sendTracks;
    refreshTracks = widget.refreshTracks;
    allTracks = widget.allTracks;
    Map<String, dynamic> chosenTracks = widget.selectedTracks;

    if (allTracks.isNotEmpty) {
      selectedTracks = List.generate(allTracks.length, (index) {
        MapEntry currTrack = allTracks.entries.elementAt(index);

        String trackTitle = currTrack.value['title'];
        String trackId = currTrack.key;
        bool selected = false;

        //If the track is already selected from past widget
        if (chosenTracks[trackId] != null){
          selected = true;
        }

        Map<String, dynamic> selectMap = {'chosen': selected, 'title': trackTitle};

        return MapEntry(trackId, selectMap);
      });

      playingList = List.generate(allTracks.length, (index) {
        String trackTitle = allTracks.entries.elementAt(index).value['title'];
        String trackId = allTracks.entries.elementAt(index).key;

        Map<String, dynamic> playMap = {'chosen': false, 'title': trackTitle};

        return MapEntry(trackId, playMap);
      });
    }
  }

  // void updateSelected(covariant TrackListWidget oldWidget){
  //   super.didUpdateWidget(oldWidget);
  //   setState(() {
  //   for (var track in selectedTracks.entries){
  //     String trackId = track.key;
  //     bool trackSelected = widget.selectedTracks.containsKey(trackId);
  //     if (trackSelected){
  //       selectedTracks[trackId]['chosen'] = true;
  //     }
  //   }
  //   });
  // }

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
              bool chosen = selectedTracks[index].value['chosen'];
              String trackId = selectedTracks[index].key;
              Map<String, dynamic> selectMap = {'chosen': !chosen, 'title': trackTitle};

              //Alligns the songs as a Column
              return Column(children: [
                //Lets the entire left section with checkbox and Title be selected
                InkWell(
                    onTap: () {
                      setState(() {
                        selectedTracks[index] = MapEntry(trackId, selectMap);
                        sendTracks(selectedTracks);
                      });
                    },
                    //Container puts the Tracks image in the background
                    child: Container(
                        decoration: BoxDecoration(
                            image: DecorationImage(
                              alignment: Alignment.topRight,
                              image: NetworkImage(trackImage),
                              fit: BoxFit.fitHeight,
                            ),
                            shape: BoxShape.rectangle),

                        //Aligns the Track Name, Checkbox, Artist Name, Preview Button as a Row
                        child: TrackRowsWidget(
                          selectedTracks: selectedTracks, 
                          index: index, 
                          trackTitle: trackTitle,
                          trackArtist: trackArtist, 
                          playingList: playingList, 
                          trackPrevUrl: trackPrevUrl, 
                          sendTracks: sendTracks
                        ),
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
}

//Creates the State for each Tracks Row
class TrackRowsWidget extends StatefulWidget {
  const TrackRowsWidget({
    required this.selectedTracks, 
    required this.index, 
    required this.trackTitle,
    required this.trackArtist, 
    required this.playingList, 
    required this.trackPrevUrl,
    required this.sendTracks, 
    super.key
  });

  final List<MapEntry<String, dynamic>> selectedTracks;
  final int index;
  final String trackTitle;
  final String trackArtist;
  final List<MapEntry<String, dynamic>> playingList;
  final String trackPrevUrl;
  final void Function(List<MapEntry<String, dynamic>>) sendTracks;

  @override
  State<TrackRowsWidget> createState() => TrackRows();
}

//Functionality for each row item
class TrackRows extends State<TrackRowsWidget> {
  List<MapEntry<String, dynamic>> selectedTracks = [];
  int index = 0;
  String trackTitle = '';
  String trackArtist = '';
  List<MapEntry<String, dynamic>> playingList = [];
  String trackPrevUrl = '';
  late void Function(List<MapEntry<String, dynamic>>) sendTracks;

  //Assigns the sent variables
  @override
  void initState() {
    super.initState();
    selectedTracks = widget.selectedTracks;
    index = widget.index;
    trackTitle = widget.trackTitle;
    trackArtist = widget.trackArtist;
    playingList = widget.playingList;
    trackPrevUrl = widget.trackPrevUrl;
    sendTracks = widget.sendTracks;
  }

  @override
  Widget build(BuildContext context) {
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
      Expanded(
          flex: 5,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            //Name of the Track shown to user
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
            )
          ])),
    ]);
  }
}
