
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/class%20models/custom_sort.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/class%20models/playlist_model.dart';

class SelectPlaylistSearchDelegate extends SearchDelegate {
  List<PlaylistModel> selectedList = [];
  List<PlaylistModel> allPlaylists = [];

  Rx<bool> selectAll = false.obs;

  //Search Constructor setting the search results to the Playlist names
  SelectPlaylistSearchDelegate(List<PlaylistModel> playlists, List<PlaylistModel> selectedPlaylistsMap) {
    allPlaylists = playlists;
    allPlaylists = Sort().playlistsListSort(playlistsList: playlists);
    selectedList = selectedPlaylistsMap;

    if (selectedList.length == playlists.length) selectAll.value = true;

  }

  // What Icons on the Left side of the Search Bar
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.cancel),
        onPressed: () {
          if (query.isEmpty) {
            close(context, selectedList);
          } 
          else {
            query = '';
          }
        },
  );

  // Icons on the Right side of the Search Bar
  @override
  List<Widget>? buildActions(BuildContext context) => 
  <Widget>[
    Obx(() => FilterChip(
      backgroundColor: Colors.grey,
      label: const Text('Select All'),

      selected: selectAll.value,
      selectedColor: spotHelperGreen,

      onSelected: (bool value) {
        selectAll.value = !selectAll.value;
        if(selectAll.value){
          selectedList = allPlaylists;
        }
        else{
          selectedList.clear();
        }
      },
    )),
  ];

  //What happens after a query is selected
  @override
  Widget buildResults(BuildContext context) {

    query = modifyBadQuery(query);
    bool searchHas = allPlaylists.any((PlaylistModel element) => element.title == query);
    
    if (searchHas) {
      close(context, selectedList);
    }
    return const Center(
      child: Text(
        'No Matching Results', 
        textScaler: TextScaler.linear(2)
      )
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    //Creates a list of suggestions based on users Playlist names
    //& compares it to the users input
    List<PlaylistModel> suggestions = allPlaylists.where((PlaylistModel searchResult) {
      final String result = searchResult.title.toLowerCase();
      final String input = modifyBadQuery(query).toLowerCase();

      return result.contains(input);
    }).toList();

    if (suggestions.isEmpty) {
      return const Align(
        alignment: Alignment.topCenter,
        child: Text('No Matching Results', textScaler: TextScaler.linear(1.2))
      );
    }

    //Creates the list of Suggestions for the user
    return ListView.builder(
            itemCount: suggestions.length,
            itemBuilder: (BuildContext context, int index) {
              final PlaylistModel suggestion = suggestions[index];
              String playImage = suggestion.imageUrl;

              Rx<bool> chosen = selectedList.contains(suggestion).obs;
              
              return ListTile(
                leading: Obx(() => Checkbox(
                  value: chosen.value,
                  onChanged: (_) {
                    chosen.value = !chosen.value;

                    if(chosen.value){
                      selectedList.add(suggestion);
                    }
                  },
                )),

                title: Text(
                  suggestion.title, 
                  textScaler: const TextScaler.linear(1.2)
                ),

                trailing: playImage.contains('asset')
                ?Image.asset(playImage)
                :Image.network(playImage),

                onTap: () {
                  chosen.value = !chosen.value;

                  if(chosen.value){
                    selectedList.add(suggestion);
                  }
                },
              );
            },
    );
  }
}
