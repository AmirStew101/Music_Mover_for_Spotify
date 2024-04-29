import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/class%20models/custom_sort.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/class%20models/playlist_model.dart';

class PlaylistSearchDelegate extends SearchDelegate {
  List<PlaylistModel> searchResults = [];
  late List<PlaylistModel> allplaylists;

  ///Search Constructor setting the search results to the Playlist image names and
  ///setting playlistImages variable
  PlaylistSearchDelegate(List<PlaylistModel> playlists) {
    allplaylists = playlists;
    searchResults = Sort().playlistsListSort(playlistsList: playlists);
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
  List<Widget>? buildActions(BuildContext context) => <Widget>[
        IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: () {
              if (query.isEmpty) {
                close(context, null);
              } 
              else {
                query = '';
              }
            })
      ];

  //What happens after a query is selected
  @override
  Widget buildResults(BuildContext context) {
    query = modifyBadQuery(query);
    if (searchResults.any((PlaylistModel element) => element.title == query)) {
      close(context, query);
    }
    return const Center(
        child: Text('No Matching Results', textScaler: TextScaler.linear(2)));
  }

  @override
  Widget buildSuggestions(BuildContext context) {

    /// A list of suggestions based on the users current search text.
    List<PlaylistModel> suggestions = searchResults.where((PlaylistModel searchResult) {
      // Current title of playlist
      String result = searchResult.title.toLowerCase();

      // Lowercase the text the user has searched after ensuring it is safe text.
      String input = modifyBadQuery(query).toLowerCase();

      return result.contains(input);
    }).toList();

    // User searched for a Playlist they don't have
    if (suggestions.isEmpty) {
      return const Align(
        alignment: Alignment.topCenter,
        child: Text(
          'No Matching Results', 
          textScaler: TextScaler.linear(1.2)
        )
      );
    }

    // Creates the list of Suggestions for the user
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (BuildContext context, int index) {
        final PlaylistModel suggestion = suggestions[index];
        String playImage = suggestion.imageUrl;

        return ListTile(
          title: Text(
            suggestion.title, 
            textScaler: const TextScaler.linear(1.2)
          ),
          trailing: playImage.contains('asset')
          ?Image.asset(playImage)
          :Image.network(playImage),

          onTap: () {
            close(context, suggestion);
          },
        );
      },
    );
  }
}
