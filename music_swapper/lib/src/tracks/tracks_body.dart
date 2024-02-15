import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';

//Creates the state to update tracks the user selected
//Receives all the users tracks for the selected playlist
class TrackListWidget extends StatefulWidget {
  const TrackListWidget(
      {required this.allTracks,
      required this.selectedTracksMap,
      required this.sendTracks,
      required this.playlistId,
      super.key});

  final Map<String, TrackModel> allTracks;
  final Map<String, TrackModel> selectedTracksMap;
  final String playlistId;
  final void Function(List<MapEntry<String, dynamic>>) sendTracks;

  @override
  State<TrackListWidget> createState() => TrackListState();
}

//Main functionality for displaying, updating, and listening to previews of tracks
class TrackListState extends State<TrackListWidget> {
  //Map of the track with key = 'Track ID' and value = {images:, previewUrl:, artist:, title:}
  Map<String, TrackModel> allTracks = {};

  final audioPlayer = AudioPlayer(); //Used to play previewUrl

  //Key: Track ID & values: if 'chosen' bool & Title
  late List<MapEntry<String, dynamic>> selectedTracks = [];
  //late List<MapEntry<String, dynamic>> playingList = []; //User selected song to preview

  //Function to send selected tracks to main body
  late void Function(List<MapEntry<String, dynamic>>) sendTracks;

  bool selectAll = false;
  String playlistId = '';

  //If user subscribed to remove ads
  bool subscribed = false;

  //Creates lists for comparing if tracks are selected or if a track is playing
  //Fills the tracks Map with the users tracks fromthe widget
  @override
  void initState() {
    super.initState();
    playlistId = widget.playlistId;
    sendTracks = widget.sendTracks;
    allTracks = widget.allTracks;
    
    initialSelect();
  }


  void initialSelect() {
    if (allTracks.isNotEmpty) {
      Map<String, TrackModel> chosenTracks = widget.selectedTracksMap;
      debugPrint('\nChosen Tracks $chosenTracks\n');

      //Initializes the selected playlists
      selectedTracks = List.generate(allTracks.length, (index) {
        MapEntry<String, TrackModel> currTrack = allTracks.entries.elementAt(index);

        String trackTitle = currTrack.value.title;
        String trackId = currTrack.key;
        bool selected = false;

        //If the track is already selected from past widget
        if (chosenTracks.containsKey(trackId)) {
          selected = true;
        }

        Map<String, dynamic> selectMap = {
          'chosen': selected,
          'title': trackTitle
        };

        return MapEntry(trackId, selectMap);
      });

      //Initializes the playing list
      // playingList = List.generate(allTracks.length, (index) {
      //   String trackTitle = allTracks.entries.elementAt(index).value.title;
      //   String trackId = allTracks.entries.elementAt(index).key;
      //   String? playUrl = allTracks.entries.elementAt(index).value.previewUrl;

      //   Map<String, dynamic> playMap = {
      //     'playing': false,
      //     'title': trackTitle,
      //     'playUrl': playUrl ?? ''
      //   };

      //   return MapEntry(trackId, playMap);
      // });
    }
  }

  @override
  Widget build(BuildContext context) {

    //Stack for the hovering select all button & tracks view
    return Stack(children: [
      ListView.builder(
          itemCount: allTracks.length,
          itemBuilder: (context, index) {
            final trackMap = allTracks.entries.elementAt(index);

            //Used for displaying track information
            final trackTitle = trackMap.value.title;
            final trackImage = trackMap.value.imageUrl;
            //final trackPrevUrl = trackMap.value.previewUrl ?? '';
            final trackArtist = trackMap.value.artist;

            //Used to update Selected Tracks
            final chosen = selectedTracks[index].value['chosen'];
            final trackId = selectedTracks[index].key;
            final selectMap = {'chosen': !chosen, 'title': trackTitle};

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
                    clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                          image: DecorationImage(
                            alignment: Alignment.topRight,
                            image: NetworkImage(trackImage),
                            fit: BoxFit.contain,
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
              if (index == allTracks.length-1)
                const SizedBox(
                  height: 90,
                ),
            ]);
          }),
          
      if (subscribed)
        //Shows an ad if user isn't subscribed
        Positioned(
          bottom: 5,
          child: adRow(),
        )
      ],
    );
  }

  //Banner Ad setup
  Widget adRow(){
    final width = MediaQuery.of(context).size.width;

    final BannerAd bannerAd = BannerAd(
      size: AdSize.fluid, 
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', 
      listener: BannerAdListener(
        onAdLoaded: (ad) => debugPrint('Ad Loaded\n'),
        onAdClicked: (ad) => debugPrint('Ad Clicked\n'),), 
      request: const AdRequest(),
    );

    bannerAd.load();
    
    return SizedBox(
      width: width,
      height: 70,
      //Creates the ad banner
      child: AdWidget(
        ad: bannerAd,
      ),
    );
  }

  //Creates the State for each Tracks Row
  Widget trackRows(int index, String trackTitle, String trackArtist) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        //Design & Functinoality for the checkbox button when selected and not
        Checkbox(
          value: selectedTracks[index].value['chosen'],
          onChanged: (value) {
            setState(() {
              bool chosen = selectedTracks[index].value['chosen'];
              String trackId = selectedTracks[index].key;
              Map<String, dynamic> selectMap = {
                'chosen': !chosen,
                'title': trackTitle
              };

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
                  trackTitle.length > 25
                  ? '${trackTitle.substring(0, 25)}...'
                  : trackTitle,
                  textScaler: const TextScaler.linear(1.2),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color.fromARGB(255, 6, 163, 11)),
                ),
                //Name of track Artist show to user
                Text(
                  'By: $trackArtist',
                  textScaler: const TextScaler.linear(0.8),
                ),
              ])
      ]
    );
  }
}
