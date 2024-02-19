
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';

class SelectPlaylistSearchDelegate extends SearchDelegate {
  List<MapEntry<String, dynamic>> searchResults = []; //Names of each playlist
  List<MapEntry<String, dynamic>> selectedList = [];

  //Search Constructor setting the search results to the Playlist names
  SelectPlaylistSearchDelegate(Map<String, PlaylistModel> playlists, Map<String, PlaylistModel> selectedPlaylistsMap) {
    playlists.forEach((key, value) {
      
        String playlistTitle = value.title;
        bool chosen = false;

        searchResults.add(MapEntry(key, playlistTitle));

        if (selectedPlaylistsMap.containsKey(key)){
          chosen = true;
        }

        Map<String, dynamic> selectMap = {'chosen': chosen, 'title': playlistTitle};

        selectedList.add(MapEntry(key, selectMap));
        
    });

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
    bool searchHas = searchResults.any((element) => element.value['title'] == query);
    
    if (searchHas) {
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
            String playId = suggestion.key;

            //Get the data and location of playlist that matches suggestion
            MapEntry<String, dynamic> chosenPlaylist = selectedList.firstWhere((playlist) => playlist.key == playId);
            int chosenIndex = selectedList.indexWhere((playlist) => playlist.key == playId);

            bool chosen = chosenPlaylist.value['chosen'];

            Map<String, dynamic> playMap = {'chosen': !chosen, 'title': playTitle};

            return ListTile(
              leading: Checkbox(
                value: chosen,
                onChanged: (value) {
                  setState((){
                    selectedList[chosenIndex] = MapEntry(playId, playMap);
                  });
                },
              ),

              title: Text(playTitle, textScaler: const TextScaler.linear(1.2)),

              onTap: () {
                setState((){
                  selectedList[chosenIndex] = MapEntry(playId, playMap);
                });
              },
            );
          },
        );
      },
    );
  }
}
