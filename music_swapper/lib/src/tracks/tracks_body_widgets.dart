import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:music_swapper/utils/database/database_model.dart';
import 'package:music_swapper/utils/playlists_requests.dart';
import 'package:music_swapper/utils/tracks_requests.dart';

//Creates the state to update tracks the user selected
//Receives all the users tracks for the selected playlist
class TrackListWidget extends StatefulWidget {
  final Map<String, dynamic> tracks;
  final Map<String, dynamic> selectedTracks;
  final void Function(List<MapEntry<String, bool>>) sendTracks;
  final Map<String, dynamic> receivedCall;
  final String playlistId;
  final Future<void> Function() refreshTracks;
  
  const TrackListWidget({
    required this.tracks, 
    required this.selectedTracks,
    required this.sendTracks,
    required this.receivedCall,
    required this.playlistId,
    required this.refreshTracks, 
    super.key});

  @override
  State<TrackListWidget> createState() => TrackListState();
}

//Main functionality for displaying, updating, and listening to previews of tracks
class TrackListState extends State<TrackListWidget> {
  //Map of the track with key = 'track name' and value = {images:, previewUrl:, artist:}
  Map<String, dynamic> tracks = {};
  Map<String, dynamic> receivedCall = {};
  late Future<void> Function() refreshTracks;

  final audioPlayer = AudioPlayer(); //Used to play previewUrl

  late List<MapEntry<String, bool>> selectedList = []; //Stores Track Name & if its Selected
  late List<MapEntry<String, bool>> playingList = []; //User selected song to preview

  //Function to send selected tracks to main body
  late void Function(List<MapEntry<String, bool>>) sendTracks;

  bool selectAll = false;

  //Creates lists for comparing if tracks are selected or if a track is playing
  //Fills the tracks Map with the users tracks fromthe widget
  @override
  void initState() {
    super.initState();
    sendTracks = widget.sendTracks;
    refreshTracks = widget.refreshTracks;
    tracks = widget.tracks;
    Map<String, dynamic> searchedTracks = widget.selectedTracks;

    if (tracks.isNotEmpty) {
      selectedList = List.generate(tracks.length, (index) {
        String name = tracks.entries.elementAt(index).key;
        bool state = searchedTracks[name] != null;
        return MapEntry(name, state);
      });

      playingList = List.generate(tracks.length, (index) {
        String name = tracks.entries.elementAt(index).key;
        bool state = false;
        return MapEntry(name, state);
      });
    }
  }

  void updateSelected(covariant TrackListWidget oldWidget){
    super.didUpdateWidget(oldWidget);
    setState(() {
    for (int i = 0; i < selectedList.length; i++){
      MapEntry<String, bool> item = selectedList[i];
      bool trackSelected = widget.selectedTracks.containsKey(item.key);
      if (trackSelected){
        selectedList[i] = MapEntry(item.key, true);
      }
    }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    

    return RefreshIndicator(
      onRefresh: refreshTracks, 
      child: Stack(children: [
      ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final trackMap = tracks.entries.elementAt(index);
              final trackName = trackMap.value['title'];
              final trackImage = trackMap.value?['imageUrl'] ?? '';
              final trackPrevUrl = trackMap.value?['previewUrl'] ?? '';
              final trackArtist = trackMap.value?['artist'] ?? '';

              //Alligns the songs as a Column
              return Column(children: [
                //Lets the entire left section with checkbox and Title be selected
                InkWell(
                    //Functionality for entire section that isn't the preview button or checkbox
                    //Has same functionality as the checkbox button
                    onTap: () {
                      setState(() {
                        bool currState = selectedList[index].value;
                        selectedList[index] = MapEntry(trackName, !currState);
                        sendTracks(selectedList);
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
                        child: TrackRowsWidget(selectedList, index, trackName,
                            trackArtist, playingList, trackPrevUrl, sendTracks: sendTracks))),
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
                        for (int i = 0; i < tracks.length; i++) {
                          MapEntry<String, dynamic> trackEntry = tracks.entries.elementAt(i);
                          selectedList[i] = MapEntry(trackEntry.key, true);
                        }
                        sendTracks(selectedList);
                      } else {
                        //Deselects all check boxes
                        for (int i = 0; i < tracks.length; i++) {
                          MapEntry<String, dynamic> trackEntry = tracks.entries.elementAt(i);
                          selectedList[i] = MapEntry(trackEntry.key, false);
                        }
                        sendTracks(selectedList);
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
  const TrackRowsWidget(this.selectedList, this.index, this.trackName,
      this.trackArtist, this.playingList, this.trackPrevUrl,
      {required this.sendTracks , super.key});

  final List<MapEntry<String, bool>> selectedList;
  final int index;
  final String trackName;
  final String trackArtist;
  final List<MapEntry<String, bool>> playingList;
  final String trackPrevUrl;
  final void Function(List<MapEntry<String, bool>>) sendTracks;

  @override
  State<TrackRowsWidget> createState() => TrackRows();
}

//Functionality for each row item
class TrackRows extends State<TrackRowsWidget> {
  List<MapEntry<String, bool>> selectedList = [];
  int index = 0;
  String trackName = '';
  String trackArtist = '';
  List<MapEntry<String, bool>> playingList = [];
  String trackPrevUrl = '';
  late void Function(List<MapEntry<String, bool>>) sendTracks;

  //Assigns the sent variables
  @override
  void initState() {
    super.initState();
    selectedList = widget.selectedList;
    index = widget.index;
    trackName = widget.trackName;
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
        value: selectedList[index].value,
        onChanged: (value) {
          setState(() {
            bool currState = selectedList[index].value;
            selectedList[index] = MapEntry(trackName, !currState);
            sendTracks(selectedList);
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
              trackName,
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
