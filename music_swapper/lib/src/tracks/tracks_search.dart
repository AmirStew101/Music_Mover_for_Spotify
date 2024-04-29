import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/class%20models/custom_sort.dart';
import 'package:spotify_music_helper/src/utils/class%20models/playlist_model.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/class%20models/track_model.dart';

class TracksSearchDelegate extends SearchDelegate {
  ///Will have a key: track name & value: Artist & ID
  List<TrackModel> searchResults = <TrackModel>[];

  ///Tracks user has selected in Search or Body.
  ///
  ///Key: Track Title, Value: {ID & bool if 'chosen'}.
  RxMap<String, TrackModel> chosenTracksMap = <String, TrackModel>{}.obs;

  Rx<bool> artistFilter = false.obs;
  Rx<bool> selectAll = false.obs;
  
  late PlaylistModel playlist;

  String sortType = Sort().title;
  bool ascending = true;

  ///Gets all the tracks for the playlist from tracks, and
  ///gets all the selected Tracks from previous widget.
  TracksSearchDelegate(PlaylistModel currentPlaylist, Map<String, TrackModel> tracksSelectedMap) {
    playlist = currentPlaylist;
    searchResults = Sort().tracksListSort(playlist, ascending: ascending);

    chosenTracksMap.addAll(tracksSelectedMap);

    if (chosenTracksMap.length == playlist.tracksDupes.length) selectAll.value = true;
  }
  
  @override
  Widget? buildLeading(BuildContext context) {
    //Close Search bar
    return IconButton(
      icon: const Icon(Icons.cancel),
      onPressed: () {
        if (query.isEmpty) {
          close(context, chosenTracksMap);
        } 
        else {
          query = '';
        }
      },
    );
  }

  //Filter button and Clear/Close Search bar
  @override
  List<Widget>? buildActions(BuildContext context) {
    return <Widget>[
      Obx(() => Row(
        children: <Widget>[

          // Artist filter button
          FilterChip(
            backgroundColor: Colors.grey,
            label: const Text('By Artist'),

            selected: artistFilter.value,
            selectedColor: spotHelperGreen,

            onSelected: (_) {
              artistFilter.value = !artistFilter.value;
            },
          ),
          const SizedBox(width: 5,),

          // Select all button
          FilterChip(
            backgroundColor: Colors.grey,
            label: const Text('All'),

            selected: selectAll.value,
            selectedColor: spotHelperGreen,

            onSelected: (_) {
              selectAll.value = !selectAll.value;
              if(selectAll.value){
                chosenTracksMap.addAll(playlist.tracksDupes);
              }
              else{
                chosenTracksMap.clear();
              }
            },
          ),

        ],
      ))
    ];
  }

  @override
  Widget buildResults(BuildContext context) {
    close(context, chosenTracksMap);
    return const Center(child: Text('No Matching Results', textScaler: TextScaler.linear(2)));
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    //Creates a list of suggestions based on users Playlist names
    //& compares it to the users input
    List<TrackModel> trackSuggestions = searchResults
    .where((TrackModel searchResult) {
      final String result;

      if(sortType == Sort().artist){
        result = searchResult.artistNames[0].toLowerCase();
      }
      else{
        result = searchResult.title.toLowerCase();
      }
       
      final String input = modifyBadQuery(query).toLowerCase();

      return result.contains(input);
    }).toList();

    //No suggestions when Filter box isn't checked
    if (trackSuggestions.isEmpty) {
      return const Align(
          alignment: Alignment.topCenter,
          child: Text(
            'No Matching Results', 
            textScaler: TextScaler.linear(1.2))
      );
    }

    String _getArtistText(TrackModel track){
      String artistText = '';

      if(track.artists.length > 1){
        artistText = 'By: ${track.artistNames[0]}...';
      }
      else{
        artistText = 'By: ${track.artistNames[0]}';
      }

      return artistText;
    }

    //Shows suggestions based on the Track Name
    return StatefulBuilder(
      builder: (_, setState) {

        //List of suggested tracks
        return ListView.builder(
            itemCount: trackSuggestions.length,
            itemBuilder: (_, int index) {
              //Suggestion has key: Id Title & Values: Artist, Track title
              final TrackModel suggestion = trackSuggestions[index];
              String trackImage = suggestion.imageUrl;

              return ListTile(
                onTap: () {
                  setState(() {
                    if(!chosenTracksMap.containsKey(suggestion.dupeId)){
                      chosenTracksMap.putIfAbsent(suggestion.dupeId, () => suggestion);
                    }
                    else{
                      chosenTracksMap.remove(suggestion.dupeId);
                    }
                  });
                },

                //Checkbox for users Track
                leading: Obx(() => Checkbox(
                  value: chosenTracksMap.containsKey(suggestion.dupeId),
                  //Keeps track of tracks user selects
                  onChanged: (bool? value) {
                    setState(() {
                      if(!chosenTracksMap.containsKey(suggestion.dupeId)){
                        chosenTracksMap.putIfAbsent(suggestion.dupeId, () => suggestion);
                      }
                      else{
                        chosenTracksMap.remove(suggestion.dupeId);
                      }
                      
                    });
                  },
                )),

                //Track name and Artist
                title: Text(
                  suggestion.title, 
                  textScaler: const TextScaler.linear(1.2)
                ),

                subtitle: Text(_getArtistText(suggestion),
                    textScaler: const TextScaler.linear(0.8)
                ),
                
                trailing: Image.network(trackImage),
              );
            },
          );
      },
    );
  
  }
}