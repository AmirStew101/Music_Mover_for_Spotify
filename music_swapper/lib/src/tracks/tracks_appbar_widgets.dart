import 'package:flutter/material.dart';
import 'package:music_swapper/utils/universal_widgets.dart';

class TracksSearchDelegate extends SearchDelegate {
  List<MapEntry<String, dynamic>> searchResults = []; //Will have a key: track name & value: artist name
  Map<String, dynamic> chosenTracks = {};
  Map<String, dynamic> userTracks = {};
  bool artistFilter = false;
  List<MapEntry<String, bool>> selectedTracks = [];

  TracksSearchDelegate(Map<String, dynamic> tracks, Map<String, dynamic> searchedTracks) {
    userTracks = tracks;
    tracks.forEach((key, value) {
      searchResults.add(MapEntry(key, value['artist']));
      selectedTracks.add(MapEntry(key, searchedTracks[key] != null));
    });
  }
  
  @override
  Widget? buildLeading(BuildContext context) {
    //Close Search bar
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        for (var item in selectedTracks){
          if (item.value){
            String trackName = item.key;
            chosenTracks.putIfAbsent(trackName, () => userTracks[trackName]);
          }
        }
        debugPrint('\nChosen Tracks $chosenTracks\n');
        close(context, chosenTracks);
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
                    ? const Color.fromARGB(255, 6, 163, 11)
                    : Colors.grey,
                label: const Text('Artist Filter'),
                onSelected: (value) {
                  setState(() {
                    artistFilter = !artistFilter;
                    debugPrint('Filter Tapped');
                  });
                },
              ),
            ],
          );
        },
      ),
      //Cancel Button functionality
      IconButton(
        icon: const Icon(Icons.cancel),
        onPressed: () {
          if (query.isEmpty) {
            for (var item in selectedTracks){
              if (item.value){
                String trackName = item.key;
                chosenTracks.putIfAbsent(trackName, () => userTracks[trackName]);
              }
            }
            debugPrint('\nChosen Tracks $chosenTracks\n');
            close(context, chosenTracks);
          } else {
            query = '';
          }
        },
      )
    ];
  }

  @override
  Widget buildResults(BuildContext context) {
    for (var item in selectedTracks){
      if (item.value){
        String trackName = item.key;
        chosenTracks.putIfAbsent(trackName, () => userTracks[trackName]);
      }
    }
    close(context, chosenTracks);
    return const Center(child: Text('No Matching Results', textScaler: TextScaler.linear(2)));
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    //Creates a list of suggestions based on users Playlist names
    //& compares it to the users input
    List<MapEntry<String, dynamic>> trackSuggestions =
        searchResults.where((searchResult) {
      final result = searchResult.key.toLowerCase();
      query = modifyBadQuery(query);
      final input = query.toLowerCase();

      return result.contains(input);
    }).toList();

    List<MapEntry<String, dynamic>> artistSuggestions =
        searchResults.where((searchResult) {
      final result = searchResult.value.toLowerCase();
      query = modifyBadQuery(query);
      final input = query.toLowerCase();

      return result.contains(input);
    }).toList();

    //No suggestions when Filter box isn't checked
    if (!artistFilter && trackSuggestions.isEmpty) {
      return const Align(
          alignment: Alignment.topCenter,
          child:
              Text('No Matching Results', textScaler: TextScaler.linear(1.2)));
    }
    //No suggestions when Filter box is checked
    if (artistFilter && artistSuggestions.isEmpty) {
      return const Align(
          alignment: Alignment.topCenter,
          child:
              Text('No Matching Results', textScaler: TextScaler.linear(1.2)));
    }

    //Shows suggestions based on the Track Name
    if (!artistFilter) {
      return StatefulBuilder(
        builder: (context, setState) {
          return ListView.builder(
            itemCount: trackSuggestions.length, //Shows a max of 6 suggestions
            itemBuilder: (context, index) {
              final suggestion = trackSuggestions[index];

              return ListTile(
                //Checkbox for users Track
                leading: Checkbox(
                value: selectedTracks[index].value,
                //Keeps track of tracks user selects
                onChanged: (value) {
                  bool isSelected = selectedTracks[index].value;
                  String trackName = suggestion.key;
                  setState(() {
                    selectedTracks[index] = MapEntry(trackName, !isSelected);
                  });
                },
                ),
                //Track name and Artist
                title: Text(suggestion.key,
                    textScaler: const TextScaler.linear(1.2)),
                subtitle: Text('By: ${suggestion.value}',
                    textScaler: const TextScaler.linear(0.8)),
                //Keeps track of tracks user selected
                onTap: () {
                  bool isSelected = selectedTracks[index].value;
                  String trackName = suggestion.key;
                  setState(() {
                    selectedTracks[index] = MapEntry(trackName, !isSelected);
                  });
                },
              );
            },
          );
        },
      );
    } else {//Shows suggestions based on the Artist
      return StatefulBuilder(builder: (context, setState) {

        return ListView.builder(
          itemCount: artistSuggestions.length, //Shows a max of 6 suggestions
          itemBuilder: (context, index) {
            final suggestion = artistSuggestions[index];

            return ListTile(
              leading: Checkbox(
                value: selectedTracks[index].value,
                onChanged: (value) {
                  bool isSelected = selectedTracks[index].value;
                  String trackName = suggestion.key;
                  setState(() {
                    selectedTracks[index] = MapEntry(trackName, !isSelected);
                  });
                },
              ),
              title: Text(suggestion.key,
                  textScaler: const TextScaler.linear(1.2)),
              subtitle: Text('By: ${suggestion.value}',
                  textScaler: const TextScaler.linear(0.8)),
              onTap: () {
                bool isSelected = selectedTracks[index].value;
                String trackName = suggestion.key;
                setState((){
                  selectedTracks[index] = MapEntry(trackName, !isSelected);
                });
              },
            );
          },
        );
      });
    }
  }
}