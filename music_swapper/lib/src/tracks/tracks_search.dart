import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/track_model.dart';

class TracksSearchDelegate extends SearchDelegate {
  ///Will have a key: track name & value: Artist & ID
  List<MapEntry<String, dynamic>> searchResults = <MapEntry<String, dynamic>>[];

  Rx<bool> artistFilter = false.obs;
  Rx<bool> selectAll = false.obs;
  
  ///Tracks user has selected in Search or Body.
  ///
  ///Key: Track Title, Value: {ID & bool if 'chosen'}.
  List<MapEntry<String, dynamic>> chosenTracksList = <MapEntry<String, dynamic>>[];
  int numSelected = 0;

  late Map<String, TrackModel> tracks;

  ///Gets all the tracks for the playlist from tracks, and
  ///gets all the selected Tracks from previous widget.
  TracksSearchDelegate(Map<String, TrackModel> allTracks, Map<String, TrackModel> tracksSelectedMap) {
    tracks = allTracks;
    
    allTracks.forEach((String key, TrackModel value) {
      String trackTitle = value.title;

      String artists = '';

      value.artists.forEach((String artist, _) => artists += artist);

      Map<String, dynamic> searchMap = <String, dynamic>{'artist': artists, 'title': trackTitle};
      searchResults.add(MapEntry<String, Map<String, dynamic>>(key, searchMap));

      bool chosen = tracksSelectedMap.containsKey(key);
      if (chosen) numSelected++;

      Map<String, dynamic> selectedMap = <String, dynamic>{'chosen': chosen, 'title': trackTitle};
      chosenTracksList.add(MapEntry<String, Map<String, dynamic>>(key, selectedMap));
    });

    searchResults.sort((MapEntry<String, dynamic> a, MapEntry<String, dynamic> b) => a.value['title'].compareTo(b.value['title']));
    chosenTracksList.sort((MapEntry<String, dynamic> a, MapEntry<String, dynamic> b) => a.value['title'].compareTo(b.value['title']));

    if (numSelected == allTracks.length) selectAll.value = true;
  }
  
  @override
  Widget? buildLeading(BuildContext context) {
    //Close Search bar
    return IconButton(
      icon: const Icon(Icons.cancel),
      onPressed: () {
        if (query.isEmpty) {
          close(context, chosenTracksList);
        } 
        else {
          query = '';
        }
      },
    );
  }

  //Filter button and Clear/Close Search bar
  @override
  List<Widget>? buildActions(BuildContext context) {
    return <Widget>[
      Obx(() => Row(
        children: <Widget>[
          FilterChip(
            backgroundColor: Colors.grey,
            label: const Text('By Artist'),

            selected: artistFilter.value,
            selectedColor: spotHelperGreen,

            onSelected: (_) {
              artistFilter.value = !artistFilter.value;
            },
          ),
          const SizedBox(width: 5,),

          FilterChip(
            backgroundColor: Colors.grey,
            label: const Text('All'),

            selected: selectAll.value,
            selectedColor: spotHelperGreen,

            onSelected: (bool selected) {
              for (MapEntry<String, dynamic> element in chosenTracksList) { 
                element.value['chosen'] = selected;
              }
              selectAll.value = !selectAll.value;
            },
          ),

        ],
      ))
    ];
  }

  @override
  Widget buildResults(BuildContext context) {
    close(context, chosenTracksList);
    return const Center(child: Text('No Matching Results', textScaler: TextScaler.linear(2)));
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    //Creates a list of suggestions based on users Playlist names
    //& compares it to the users input
    List<MapEntry<String, dynamic>> trackSuggestions = searchResults
    .where((MapEntry<String, dynamic> searchResult) {
      final String result = searchResult.value['title'].toLowerCase() as String;
      query = modifyBadQuery(query);
      final String input = query.toLowerCase();

      return result.contains(input);
    }).toList();

    List<MapEntry<String, dynamic>> artistSuggestions = searchResults
    .where((MapEntry<String, dynamic> searchResult) {
      final String result = searchResult.value['artist'].toLowerCase() as String;
      query = modifyBadQuery(query);
      final String input = query.toLowerCase();

      return result.contains(input);
    }).toList();

    //No suggestions when Filter box isn't checked
    if (!artistFilter.value && trackSuggestions.isEmpty) {
      return const Align(
          alignment: Alignment.topCenter,
          child: Text(
            'No Matching Results', 
            textScaler: TextScaler.linear(1.2))
      );
    }
    //No suggestions when Filter box is checked
    if (artistFilter.value && artistSuggestions.isEmpty) {
      return const Align(
          alignment: Alignment.topCenter,
          child: Text(
            'No Matching Results', 
            textScaler: TextScaler.linear(1.2))
      );
    }

    //Shows suggestions based on the Track Name
    if (!artistFilter.value) {

      //Provides the setState function to update selections
      return StatefulBuilder(
        builder: (_, setState) {

          //List of suggested tracks
          return Obx(() => ListView.builder(
              itemCount: trackSuggestions.length,
              itemBuilder: (_, int index) {
                //Suggestion has key: Id Title & Values: Artist, Track title
                final MapEntry<String, dynamic> suggestion = trackSuggestions[index];
                String trackId = suggestion.key;
                String trackImage = tracks[trackId]!.imageUrl;

                //Get the data and location of track that matches suggestion
                MapEntry<String, dynamic> chosenTrack = chosenTracksList.firstWhere((MapEntry<String, dynamic> track) => track.key == trackId);
                int chosenIndex = chosenTracksList.indexWhere((MapEntry<String, dynamic> track) => track.key == trackId);

                bool isSelected = chosenTrack.value['chosen'];
                String trackTitle = suggestion.value['title'];

                Map<String, dynamic> chosenMap = <String, dynamic>{'chosen': !isSelected, 'title': trackTitle};

                return ListTile(

                  //Checkbox for users Track
                  leading: Checkbox(
                  value: isSelected,
                  //Keeps track of tracks user selects
                  onChanged: (bool? value) {
                    setState(() {
                      //Changes track that matches the suggestion
                      chosenTracksList[chosenIndex] = MapEntry(trackId, chosenMap);
                    });
                  },),

                  //Track name and Artist
                  title: Text(
                    suggestion.value['title'], 
                    textScaler: const TextScaler.linear(1.2)
                  ),

                  subtitle: Text('By: ${suggestion.value['artist']}',
                      textScaler: const TextScaler.linear(0.8)
                  ),
                  
                  trailing: Image.network(trackImage),

                  //Keeps track of tracks user selected
                  onTap: () {
                    setState(() {
                      chosenTracksList[chosenIndex] = MapEntry(trackId, chosenMap);
                    });
                  },
                );
              },
            ));
        },
      );
    } 
    //Shows suggestions based on the Artist
    else {
      return StatefulBuilder(builder: (BuildContext context, setState) {

        return ListView.builder(
          itemCount: artistSuggestions.length, //Shows a max of 6 suggestions
          itemBuilder: (BuildContext context, int index) {
            final MapEntry<String, dynamic> suggestion = artistSuggestions[index];
            String trackId = suggestion.key;
            String trackImage = tracks[trackId]!.imageUrl;

            MapEntry<String, dynamic> chosenTrack = chosenTracksList.firstWhere((MapEntry<String, dynamic> track) => track.key == trackId);
            int chosenIndex = chosenTracksList.indexWhere((MapEntry<String, dynamic> track) => track.key == trackId);

            bool isSelected = chosenTrack.value['chosen'];
            String trackTitle = suggestion.value['title'];

            Map<String, dynamic> chosenMap = <String, dynamic>{'chosen': !isSelected, 'title': trackTitle};

            return ListTile(
              leading: Checkbox(
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    chosenTracksList[chosenIndex] = MapEntry(trackId, chosenMap);
                  });
                },
              ),

              title: Text(
                suggestion.value['title'],
                textScaler: const TextScaler.linear(1.2)
              ),

              subtitle: Text(
                'By: ${suggestion.value['artist']}',
                textScaler: const TextScaler.linear(0.8)
              ),

              trailing: Image.network(trackImage),

              onTap: () {
                setState((){
                  chosenTracksList[chosenIndex] = MapEntry(trackId, chosenMap);
                });
              },
            );
          },
        );
      });
    }
  }
}