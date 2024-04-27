
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/playlist_model.dart';

class SelectPlaylistSearchDelegate extends SearchDelegate {
  List<MapEntry<String, dynamic>> searchResults = <MapEntry<String, dynamic>>[];
  List<MapEntry<String, dynamic>> selectedList = <MapEntry<String, dynamic>>[];
  late Map<String, PlaylistModel> allPlaylists;
  ValueNotifier<bool> selectAll = ValueNotifier<bool>(false);
  int numSelected = 0;

  //Search Constructor setting the search results to the Playlist names
  SelectPlaylistSearchDelegate(Map<String, PlaylistModel> playlists, Map<String, PlaylistModel> selectedPlaylistsMap) {
    allPlaylists = playlists;

    playlists.forEach((String key, PlaylistModel value) {
      
        String playlistTitle = value.title;

        searchResults.add(MapEntry(key, playlistTitle));

        bool chosen = selectedPlaylistsMap.containsKey(key);
        if (chosen) numSelected++;
        
        Map<String, dynamic> selectMap = <String, dynamic>{'chosen': chosen, 'title': playlistTitle};

        selectedList.add(MapEntry(key, selectMap));
        
    });

    searchResults.sort((MapEntry<String, dynamic> a, MapEntry<String, dynamic> b) => a.value.compareTo(b.value));
    selectedList.sort((MapEntry<String, dynamic> a, MapEntry<String, dynamic> b) => a.value['title'].compareTo(b.value['title']));

    if (numSelected == playlists.length) selectAll.value = true;

  }

  //What Icons on the Left side of the Search Bar
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.cancel),
        onPressed: () {
          if (query.isEmpty) {
            close(context, selectedList);
          } else {
            query = '';
          }
        },
  );

  //Icons on the Right side of the Search Bar
  @override
  List<Widget>? buildActions(BuildContext context) => 
  <Widget>[
    StatefulBuilder(
      builder: (BuildContext context, setState) => FilterChip(
        backgroundColor: Colors.grey,
        label: const Text('Select All'),

        selected: selectAll.value,
        selectedColor: spotHelperGreen,

        onSelected: (bool value) {
          selectAll.value = !selectAll.value;
          for (MapEntry<String, dynamic> element in selectedList) { 
            element.value['chosen'] = selectAll.value;
          }
          setState(() {});
        },
      ),
    )
  ];

  //What happens after a query is selected
  @override
  Widget buildResults(BuildContext context) {

    query = modifyBadQuery(query);
    bool searchHas = searchResults.any((MapEntry<String, dynamic> element) => element.value['title'] == query);
    
    if (searchHas) {
      close(context, selectedList);
    }
    return const Center(child: Text('No Matching Results', textScaler: TextScaler.linear(2)));
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    //Creates a list of suggestions based on users Playlist names
    //& compares it to the users input
    List<MapEntry<String, dynamic>> suggestions = searchResults.where((MapEntry<String, dynamic> searchResult) {
      final result = searchResult.value.toLowerCase();
      query = modifyBadQuery(query);
      final String input = query.toLowerCase();

      return result.contains(input);
    }).toList();

    if (suggestions.isEmpty) {
      return const Align(
          alignment: Alignment.topCenter,
          child: Text('No Matching Results', textScaler: TextScaler.linear(1.2)));
    }

    //Creates the list of Suggestions for the user
    return StatefulBuilder(
      builder: (BuildContext context, setState) {

        return ValueListenableBuilder(
          valueListenable: selectAll, 
          builder: (BuildContext context, bool value, Widget? child) => ListView.builder(
            itemCount: suggestions.length,
            itemBuilder: (BuildContext context, int index) {
              final MapEntry<String, dynamic> suggestion = suggestions[index];
              String playTitle = suggestion.value;
              String playId = suggestion.key;
              String playImage = allPlaylists[playId]!.imageUrl;

              //Get the data and location of playlist that matches suggestion
              MapEntry<String, dynamic> chosenPlaylist = selectedList.firstWhere((MapEntry<String, dynamic> playlist) => playlist.key == playId);
              int chosenIndex = selectedList.indexWhere((MapEntry<String, dynamic> playlist) => playlist.key == playId);

              bool chosen = chosenPlaylist.value['chosen'];

              Map<String, dynamic> playMap = <String, dynamic>{'chosen': !chosen, 'title': playTitle};

              return ListTile(
                leading: Checkbox(
                  value: chosen,
                  onChanged: (bool? value) {
                    setState((){
                      selectedList[chosenIndex] = MapEntry(playId, playMap);
                    });
                  },
                ),

                title: Text(playTitle, textScaler: const TextScaler.linear(1.2)),

                trailing: playImage.contains('asset')
                ?Image.asset(playImage)
                :Image.network(playImage),

                onTap: () {
                  setState((){
                    selectedList[chosenIndex] = MapEntry(playId, playMap);
                  });
                },
              );
            },
          )
        );
      },
    );
  }
}
