
import 'package:flutter/material.dart';
import 'package:music_swapper/utils/universal_widgets.dart';

class SelectPlaylistSearchDelegate extends SearchDelegate {
  List<String> searchResults = []; //Names of each playlist
  List<MapEntry<String, dynamic>> selectedList = [];

  //Search Constructor setting the search results to the Playlist names
  SelectPlaylistSearchDelegate(Map<String, dynamic> playlists, List<MapEntry<String, dynamic>> selectedPlaylists) {
    if (selectedPlaylists.isNotEmpty){
      selectedList = selectedPlaylists;
      playlists.forEach((key, value) {
        searchResults.add(value['title']);
      });
    }
    else{
      playlists.forEach((key, value) {
        searchResults.add(value['title']);

        Map<String, dynamic> selectMap = {'chosen': false, 'title': value['title']};
        selectedPlaylists.add(MapEntry(key, selectMap));
      });
    }
    
    debugPrint('Selected List: $selectedList\n');
  }

  //What Icons on the Left side of the Search Bar
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          close(context, selectedList);
        },
  );

  //Icons on the Right side of the Search Bar
  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: () {
              if (query.isEmpty) {
                close(context, selectedList);
              } else {
                query = '';
              }
            })
      ];

  //What happens after a query is selected
  @override
  Widget buildResults(BuildContext context) {

    query = modifyBadQuery(query);
    if (searchResults.contains(query)) {
      close(context, selectedList);
    }
    return const Center(child: Text('No Matching Results', textScaler: TextScaler.linear(2)));
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    //Creates a list of suggestions based on users Playlist names
    //& compares it to the users input
    List<String> suggestions = searchResults.where((searchResult) {
      final result = searchResult.toLowerCase();
      query = modifyBadQuery(query);
      final input = query.toLowerCase();

      return result.contains(input);
    }).toList();

    if (suggestions.isEmpty) {
      return const Align(
          alignment: Alignment.topCenter,
          child: Text('No Matching Results', textScaler: TextScaler.linear(1.2)));
    }

    //Creates the list of Suggestions for the user
    return StatefulBuilder(
      builder: (context, setState) {

        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];

            return ListTile(
              leading: Checkbox(
                  onChanged: (value) {
                    String playTitle = selectedList[index].value['title'];
                    bool chosen = selectedList[index].value['chosen'];
                    String playId = selectedList[index].key;

                    Map<String, dynamic> playMap = {'chosen': chosen, 'title': playTitle};

                    setState((){
                    selectedList[index] = MapEntry(playId, playMap);
                    });
                  },
                  value: selectedList[index].value,
              ),
              title: Text(suggestion, textScaler: const TextScaler.linear(1.2)),

              onTap: () {
                String playTitle = selectedList[index].value['title'];
                bool chosen = selectedList[index].value['chosen'];
                String playId = selectedList[index].key;

                Map<String, dynamic> playMap = {'chosen': chosen, 'title': playTitle};

                setState((){
                selectedList[index] = MapEntry(playId, playMap);
                });
              },
            );
          },
        );
      },
    );
  }
}
