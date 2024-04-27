import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/playlist_model.dart';

class PlaylistSearchDelegate extends SearchDelegate {
  List<MapEntry<String, String>> searchResults = <MapEntry<String, String>>[];
  late Map<String, PlaylistModel> allplaylists;


  ///Search Constructor setting the search results to the Playlist image names and
  ///setting playlistImages variable
  PlaylistSearchDelegate(Map<String, PlaylistModel> playlists) {
    allplaylists = playlists;

    playlists.forEach((String key, PlaylistModel value) {
      searchResults.add(MapEntry(key, value.title));
    });
    searchResults.sort((MapEntry<String, String> a, MapEntry<String, String> b) => a.value.compareTo(b.value));
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
    if (searchResults.any((MapEntry<String, String> element) => element.value.contains(query))) {
      close(context, query);
    }
    return const Center(
        child: Text('No Matching Results', textScaler: TextScaler.linear(2)));
  }

  @override
  Widget buildSuggestions(BuildContext context) {

    //Creates a list of suggestions based on users Playlist names
    //& compares it to the users input
    List<MapEntry<String, dynamic>> suggestions = searchResults.where((MapEntry<String, String> searchResult) {
      String result = searchResult.value.toLowerCase();
      query = modifyBadQuery(query);
      String input = query.toLowerCase();

      return result.contains(input);
    }).toList();

    //User searched for a Playlist they don't have
    if (suggestions.isEmpty) {
      return const Align(
          alignment: Alignment.topCenter,
          child: Text('No Matching Results', textScaler: TextScaler.linear(1.2)));
    }

    //Creates the list of Suggestions for the user
    return ListView.builder(
      itemCount: suggestions.length, //Shows a max of 6 suggestions
      itemBuilder: (BuildContext context, int index) {
        final suggestion = suggestions[index].value;
        final String playId = suggestions[index].key;
        String playImage = allplaylists[playId]!.imageUrl;

        return ListTile(
          title: Text(suggestion, textScaler: const TextScaler.linear(1.2)),
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
