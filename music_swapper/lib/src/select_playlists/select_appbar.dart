
import 'package:flutter/material.dart';
import 'package:music_swapper/utils/universal_widgets.dart';

class SelectPlaylistSearchDelegate extends SearchDelegate {
  List<MapEntry<String, dynamic>> searchResults = []; //Names of each playlist
  List<MapEntry<String, dynamic>> selectedList = [];

  //Search Constructor setting the search results to the Playlist names
  SelectPlaylistSearchDelegate(Map<String, dynamic> playlists, Map<String, dynamic> selectedPlaylistsMap) {
    if (selectedPlaylistsMap.isNotEmpty){
      playlists.forEach((key, value) {
        searchResults.add(MapEntry(key, value['title']));

        bool chosen = false;
        String playlistTitle = value['title'];

        Map<String, dynamic> selectMap = {'chosen': chosen, 'title': playlistTitle};

        if (selectedPlaylistsMap.containsKey(key)){
          chosen = true;
        }

        selectedList.add(MapEntry(key, selectMap));
      });
    }
    else{
      playlists.forEach((key, value) {
        searchResults.add(MapEntry(key, value['title']));

        Map<String, dynamic> selectMap = {'chosen': false, 'title': value['title']};
        selectedList.add(MapEntry(key, selectMap));
      });
    }
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
    List<MapEntry<String, dynamic>> suggestions = searchResults.where((searchResult) {
      final result = searchResult.value.toLowerCase();
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
            String playTitle = suggestion.value;
            bool chosen = selectedList[index].value['chosen'];
            String playId = suggestion.key;

            Map<String, dynamic> playMap = {'chosen': !chosen, 'title': playTitle};

            return ListTile(
              leading: Checkbox(
                  onChanged: (value) {
                    setState((){
                      debugPrint('Checkbox clicked: $playTitle');
                      selectedList[index] = MapEntry(playId, playMap);
                    });
                  },

                  value: chosen,
              ),

              title: Text(playTitle, textScaler: const TextScaler.linear(1.2)),

              onTap: () {
                setState((){
                  debugPrint('Box clicked: $playTitle');
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
