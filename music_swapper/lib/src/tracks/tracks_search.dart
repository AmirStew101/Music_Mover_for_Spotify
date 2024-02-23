import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';

class TracksSearchDelegate extends SearchDelegate {
  //Will have a key: track name & value: Artist & ID
  List<MapEntry<String, dynamic>> searchResults = [];

  bool artistFilter = false;
  
  //Tracks user has selected in Search or Body
  //Key: Track Title, Value: {ID & bool if 'chosen'}
  List<MapEntry<String, dynamic>> chosenTracksList = [];

  //Gets all the tracks for the playlist from tracks
  //Gets all the selected Tracks from previous widget
  TracksSearchDelegate(Map<String, TrackModel> allTracks, Map<String, TrackModel> tracksSelectedMap) {

    allTracks.forEach((key, value) {
      String trackTitle = value.title;

      Map<String, dynamic> searchMap = {'artist': value.artist, 'title': trackTitle};
      searchResults.add(MapEntry(key, searchMap));

      bool chosen = tracksSelectedMap.containsKey(key);

      Map<String, dynamic> selectedMap = {'chosen': chosen, 'title': trackTitle};
      chosenTracksList.add(MapEntry(key, selectedMap));
    });

    searchResults.sort((a, b) => a.value['title'].compareTo(b.value['title']));
    chosenTracksList.sort((a, b) => a.value['title'].compareTo(b.value['title']));
  }
  
  @override
  Widget? buildLeading(BuildContext context) {
    //Close Search bar
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, chosenTracksList);
      },
    );
  }

  //Filter button and Clear/Close Search bar
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      StatefulBuilder(
        builder: (context, setState) {
          //Artist Filter checkbox functionality
          return Column(
            children: [
              FilterChip(
                backgroundColor: artistFilter
                    ? spotHelperGreen
                    : Colors.grey,
                label: const Text('Artist Filter'),
                onSelected: (value) {
                  setState(() {
                    artistFilter = !artistFilter;
                  });
                },
              ),
            ],
          );
        },
      ),
      StatefulBuilder(builder: (context, setState) => 
        //Cancel Button functionality
        IconButton(
          icon: const Icon(Icons.cancel),
          onPressed: () {
            if (query.isEmpty) {
              close(context, chosenTracksList);
            } else {
              query = '';
            }
          },
        )
      )
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
    .where((searchResult) {
      final result = searchResult.value['title'].toLowerCase() as String;
      query = modifyBadQuery(query);
      final input = query.toLowerCase();

      return result.contains(input);
    }).toList();

    List<MapEntry<String, dynamic>> artistSuggestions = searchResults
    .where((searchResult) {
      final result = searchResult.value['artist'].toLowerCase() as String;
      query = modifyBadQuery(query);
      final input = query.toLowerCase();

      return result.contains(input);
    }).toList();

    //No suggestions when Filter box isn't checked
    if (!artistFilter && trackSuggestions.isEmpty) {
      return const Align(
          alignment: Alignment.topCenter,
          child: Text(
            'No Matching Results', 
            textScaler: TextScaler.linear(1.2))
      );
    }
    //No suggestions when Filter box is checked
    if (artistFilter && artistSuggestions.isEmpty) {
      return const Align(
          alignment: Alignment.topCenter,
          child: Text(
            'No Matching Results', 
            textScaler: TextScaler.linear(1.2))
      );
    }

    //Shows suggestions based on the Track Name
    if (!artistFilter) {

      //Provides the setState function to update selections
      return StatefulBuilder(
        builder: (context, setState) {

          //List of suggested tracks
          return ListView.builder(
            itemCount: trackSuggestions.length,
            itemBuilder: (context, index) {
              //Suggestion has key: Id Title & Values: Artist, Track title
              final suggestion = trackSuggestions[index];
              String trackId = suggestion.key;

              //Get the data and location of track that matches suggestion
              MapEntry<String, dynamic> chosenTrack = chosenTracksList.firstWhere((track) => track.key == trackId);
              int chosenIndex = chosenTracksList.indexWhere((track) => track.key == trackId);

              bool isSelected = chosenTrack.value['chosen'];
              String trackTitle = suggestion.value['title'];

              Map<String, dynamic> chosenMap = {'chosen': !isSelected, 'Title': trackTitle};

              return ListTile(

                //Checkbox for users Track
                leading: Checkbox(
                value: isSelected,
                //Keeps track of tracks user selects
                onChanged: (value) {
                  setState(() {
                    //Changes track that matches the suggestion
                    chosenTracksList[chosenIndex] = MapEntry(trackId, chosenMap);
                  });
                },),

                //Track name and Artist
                title: Text(
                  suggestion.value['title'], 
                  textScaler: const TextScaler.linear(1.2)),

                subtitle: Text('By: ${suggestion.value['artist']}',
                    textScaler: const TextScaler.linear(0.8)),
                //Keeps track of tracks user selected
                onTap: () {
                  setState(() {
                    chosenTracksList[chosenIndex] = MapEntry(trackId, chosenMap);
                  });
                },
              );
            },
          );
        },
      );
    } 
    //Shows suggestions based on the Artist
    else {
      return StatefulBuilder(builder: (context, setState) {

        return ListView.builder(
          itemCount: artistSuggestions.length, //Shows a max of 6 suggestions
          itemBuilder: (context, index) {
            final suggestion = artistSuggestions[index];
            String trackId = suggestion.key;

            MapEntry<String, dynamic> chosenTrack = chosenTracksList.firstWhere((track) => track.key == trackId);
            int chosenIndex = chosenTracksList.indexWhere((track) => track.key == trackId);

            bool isSelected = chosenTrack.value['chosen'];
            String trackTitle = suggestion.value['title'];

            Map<String, dynamic> chosenMap = {'chosen': !isSelected, 'title': trackTitle};

            return ListTile(
              leading: Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    chosenTracksList[chosenIndex] = MapEntry(trackId, chosenMap);
                  });
                },
              ),
              title: Text(
                suggestion.value['title'],
                textScaler: const TextScaler.linear(1.2)),

              subtitle: Text(
                'By: ${suggestion.value['artist']}',
                textScaler: const TextScaler.linear(0.8)),

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