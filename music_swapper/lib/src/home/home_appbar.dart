
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:music_swapper/utils/universal_widgets.dart';

class PlaylistSearchDelegate extends SearchDelegate {
  List<String> searchResults = [];

  //Search Constructor setting the search results to the Playlist image names and
  //setting playlistImages variable
  PlaylistSearchDelegate(Map<String, dynamic> playlists) {
    playlists.forEach((key, value) {
      searchResults.add(value['title']);
    });
  }

  //What Icons on the Left side of the Search Bar
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          close(context, null);
        },
      );

  //Icons on the Right side of the Search Bar
  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: () {
              if (query.isEmpty) {
                close(context, null);
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
      close(context, query);
    }
    return const Center(
        child: Text('No Matching Results', textScaler: TextScaler.linear(2)));
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

    //User searched for a Playlist they don't have
    if (suggestions.isEmpty) {
      return const Align(
          alignment: Alignment.topCenter,
          child:
              Text('No Matching Results', textScaler: TextScaler.linear(1.2)));
    }

    //Creates the list of Suggestions for the user
    return ListView.builder(
      itemCount: min(8, suggestions.length), //Shows a max of 6 suggestions
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];

        return ListTile(
          title: Text(suggestion, textScaler: const TextScaler.linear(1.2)),
          onTap: () {
            close(context, suggestion);
          },
        );
      },
    );
  }
}
