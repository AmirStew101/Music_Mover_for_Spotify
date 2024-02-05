import 'dart:math';

import 'package:flutter/material.dart';
import 'package:music_swapper/src/tracks/tracks_view.dart';
import 'package:music_swapper/utils/database/database_model.dart';
import 'package:music_swapper/utils/playlists_requests.dart';
import 'package:music_swapper/utils/universal_widgets.dart';

class ImageGridWidget extends StatefulWidget{
  const ImageGridWidget({required this.receivedCall, required this.playlists, required this.user, super.key});
  final Map<String, dynamic> receivedCall;
  final Map<String, dynamic> playlists;
  final Map<String, dynamic> user;

  @override
  State<ImageGridWidget> createState() => ImageGridState();
}

//Class for the Playlist Images with their Names under them
class ImageGridState extends State<ImageGridWidget> {
  Map<String, dynamic> receivedCall = {};
  Map<String, dynamic> playlists = {};
  Map<String, dynamic> user = {};

  @override
  void initState(){
    super.initState();
    receivedCall = widget.receivedCall;
    playlists = widget.playlists;
    user = widget.user;
  }

  Future<void> refreshPlaylists() async {
    bool forceRefresh = false;

    //Checks to make sure Tokens are up to date before making a Spotify request
    receivedCall = await checkRefresh(receivedCall, forceRefresh);

    playlists = await getSpotifyPlaylists(receivedCall['expiresAt'], receivedCall['accessToken'], user['username']);

    await syncPlaylists(playlists, user['id']);

    setState(() {
      //Update Playlists
    });
  }

  @override
  Widget build(BuildContext context) {
    
    //Builds the Grid of Images with Playlist Names
    return RefreshIndicator(
      onRefresh: refreshPlaylists, 
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, //Number of Col in the grid
          crossAxisSpacing: 8, //Spacing between Col
          mainAxisSpacing: 8, //Spacing between rows
        ),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          //Gets the Map items by index with the extra item in mind
          final item = playlists.entries.elementAt(index);
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
                  'user': user,
                };
                Navigator.restorablePushNamed(context, TracksView.routeName, arguments: homeArgs);
              },
              //Aligns the image over its title
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  //Playlist has an image url to display
                  if (!imageUrl.contains('asset'))
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
                  if (imageUrl.contains('asset'))
                    Align(
                      //Aligns the Image
                      alignment: Alignment.topCenter,
                      child: Image(
                        image: AssetImage(imageUrl),
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
                      key: const Key('assetImage'),
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
        })
        );
  }

}
