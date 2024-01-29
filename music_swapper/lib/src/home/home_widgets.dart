import 'dart:math';

import 'package:flutter/material.dart';
import 'package:music_swapper/src/tracks/tracks_view.dart';
import 'package:music_swapper/utils/database/database_model.dart';
import 'package:music_swapper/utils/playlists_requests.dart';
import 'package:music_swapper/utils/universal_widgets.dart';

class ImageGridWidget extends StatefulWidget{
  const ImageGridWidget({required this.receivedCall, required this.playlists, required this.userId, super.key});
  final Map<String, dynamic> receivedCall;
  final Map<String, dynamic> playlists;
  final String userId;

  @override
  State<ImageGridWidget> createState() => ImageGridState();
}

//Class for the Playlist Images with their Names under them
class ImageGridState extends State<ImageGridWidget> {
  Map<String, dynamic> receivedCall = {};
  Map<String, dynamic> playlists = {};
  String userId = '';

  @override
  void initState(){
    super.initState();
    receivedCall = widget.receivedCall;
    playlists = widget.playlists;
    userId = widget.userId;
  }

  Future<void> refreshPlaylists() async {
    bool forceRefresh = false;

    //Checks to make sure Tokens are up to date before making a Spotify request
    receivedCall = await checkRefresh(receivedCall, forceRefresh);

    playlists.addAll(await getSpotifyPlaylists(receivedCall['expiresAt'], receivedCall['accessToken']));

    setState(() {
      //Update Playlists
    });
  }

  @override
  Widget build(BuildContext context) {
    String assetImage = 'assets/images/no_image.png';
    String likedImage = 'assets/images/spotify_liked_songs.jpg';
    
    //Builds the Grid of Images with Playlist Names
    return RefreshIndicator(
      onRefresh: refreshPlaylists, 
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, //Number of Col in the grid
          crossAxisSpacing: 8, //Spacing between Col
          mainAxisSpacing: 8, //Spacing between rows
        ),
        itemCount: playlists.length + 1,
        itemBuilder: (context, index) {
          //Makes the Liked Songs Playlist Grid item for the user
          //Liked songs Playlist can't be automatically added
          if (index == 0) {
            return Column(children: [
              //Interactable Image grid to navigate to Tracks of playlist
              InkWell(
                onTap: () {
                  Map<String, dynamic> homeArgs = {
                    'currentPlaylist': {'Liked Songs': 'Liked Songs'},
                    'callback': receivedCall,
                    'user': userId,
                  };
                  Navigator.restorablePushNamed(context, TracksView.routeName, arguments: homeArgs);
                },
                child: Column(children: [

                  //Playlist Image from assets
                  Align(
                    alignment: Alignment.topCenter,
                    child: Image.asset(
                      likedImage,
                      fit: BoxFit.cover,
                      height: 154,
                      width: 155,
                    ),
                  ),

                  //Playlist Name
                  const Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Liked Songs',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  //Divider line underneath Name
                  const Divider(
                    height: 1,
                    color: Colors.grey,
                  )
                ]),
              )
            ]);
          } 
          //Automatically creates grid elements for the rest of the users Playlists
          else { 
            //Gets the Map items by index with the extra item in mind
            final item = playlists.entries.elementAt(index - 1);
            final String imageName = item.value['title'];
            String imageUrl = item.value['imageUrl'];

            return Column(children: [
              //Displays Images that can be clicked
              InkWell(
                onTap: () {
                  MapEntry<String, dynamic> currEntry = playlists.entries.firstWhere((element) => element.value['title'] == imageName);
                  Map<String, dynamic> currentPlaylist = {currEntry.key: currEntry.value};
                  
                  Map<String, dynamic> homeArgs = {
                    'currentPlaylist': currentPlaylist,
                    'callback': receivedCall,
                    'user': userId,
                  };
                  Navigator.restorablePushNamed(context, TracksView.routeName, arguments: homeArgs);
                },
                //Aligns the image over its title
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    //Playlist has an image url to display
                    if (item.value['imageUrl'] != assetImage || item.value['imageUrl'] != likedImage)
                      //Playlist Image
                      Align(
                        //Aligns the Image
                        alignment: Alignment.topCenter,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          height: 154,
                          width: 155,
                        ),
                      ),
                    //PLaylist doesn't have an image to display or its the Liked Songs playlist
                    if (item.value['imageUrl'] == assetImage || item.value['imageUrl'] == likedImage)
                      Align(
                        //Aligns the Image
                        alignment: Alignment.topCenter,
                        child: Image.asset(
                          imageUrl,
                          fit: BoxFit.cover,
                          height: 154,
                          width: 155,
                        ),
                      ),

                    //Playlist Name
                    Align(
                      //Aligns the Image's Name
                      alignment: Alignment.center,
                      child: Text(
                        imageName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow
                            .ellipsis, //Displays (...) when ovefloed
                      ),
                    )
                  ],
                ),
              ),
              
              //Playlist Divider underlining the Name
              const Divider(
                height: 1,
                color: Colors.grey,
              )
            ]);
          }
        })
        );
  }

}

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
