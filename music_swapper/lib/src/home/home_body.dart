
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/spotify_requests.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/class%20models/playlist_model.dart';

class ImageGridWidget extends StatefulWidget{
  ///Playlists View.
  const ImageGridWidget({required this.playlists, required this.spotifyRequests,super.key});
  final List<PlaylistModel> playlists;
  final SpotifyRequests spotifyRequests;
  
  @override
  State<ImageGridWidget> createState() => ImageGridState();
}

///State view for the users Playlists showing each playlists image with its name under it.
class ImageGridState extends State<ImageGridWidget> {
  late final SpotifyRequests _spotifyRequests;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  @override
  void initState(){
    super.initState();
    _spotifyRequests = widget.spotifyRequests;
  }

  /// Text under a playlists image giving its state.
  String imageText(String id, String playlistName){
    if(_spotifyRequests.loadedIds.contains(id)){
      return playlistName;
    }
    else if(!_spotifyRequests.loadedIds.contains(id) && _spotifyRequests.loading.value){
      return 'Loading $playlistName';
    }
    else{
      return 'Error Loading $playlistName';
    }
  }


  @override
  Widget build(BuildContext context) {
    //Builds the Grid of Images with Playlist Names
    return Obx(() => GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, //Number of Col in the grid
            crossAxisSpacing: 8, //Spacing between Col
            mainAxisSpacing: 10, //Spacing between rows
          ),
          itemCount: _spotifyRequests.allPlaylists.length,
          itemBuilder: (_, int index) {

              //Gets the Map items by index with the extra item in mind
              final PlaylistModel currPlaylist = _spotifyRequests.allPlaylists[index];
              final String imageName = currPlaylist.title;
              String imageUrl = currPlaylist.imageUrl;
              
              return Obx(() => Column(
                children: <Widget>[
                  // Displays Images that can be clicked
                  InkWell(
                    onTap: () async {
                      if(_spotifyRequests.loadedIds.contains(currPlaylist.id) && !_spotifyRequests.loading.value){

                        _spotifyRequests.currentPlaylist = currPlaylist;
                        _crashlytics.log('Navigate to Playlist Tracks');
                        bool? success = await Get.to(const TracksView(), arguments: _spotifyRequests);

                        if(success != null && !success){
                          _crashlytics.log('Home Body Request Tracks: TracksView returned false');
                          _spotifyRequests.loadedIds.remove(currPlaylist.id);
                          _spotifyRequests.requestTracks(currPlaylist.id);
                        }
                      }
                    },
                    // Aligns the image over its title
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[

                          // Error loading playlist Tracks
                          if(!currPlaylist.loaded && !_spotifyRequests.loading.value)
                          ...<Widget>[
                            InkWell(
                              onTap: () async{
                                _crashlytics.log('Refresh Playlist in Error Ids');
                                await _spotifyRequests.requestTracks(currPlaylist.id);
                              },
                              child: 
                                const SizedBox(
                                  height: 154,
                                  width: 155,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.refresh),
                                      Text('retry')
                                    ],
                                  )
                                  
                                )
                            ),
                          ],

                          if(!currPlaylist.loaded && _spotifyRequests.loading.value && _spotifyRequests.currentPlaylist.id == currPlaylist.id)
                          ... <Widget>[
                            const SizedBox(
                              height: 154,
                              width: 155,
                              child: Center(child: CircularProgressIndicator.adaptive()),
                            )
                          ],

                          // Successfully loaded Playlist Tracks
                          if(currPlaylist.loaded)
                          imageUrl.contains('asset')
                              //Playlist doesn't have an image from Spotify
                          ?  Image(
                              image: AssetImage(imageUrl),
                              fit: BoxFit.cover,
                              height: 154,
                              width: 155,
                            )
                          
                          // Playlist has an image from Spotify.
                          // Grey image when not loaded
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              height: 154,
                              width: 155,

                              // Error connecting to the images URL
                              // Use the No image asset
                              errorBuilder: (_, __, ___) => const Image(
                                image: AssetImage(assetNoImage),
                                fit: BoxFit.cover,
                                height: 154,
                                width: 155,
                              ),
                            ),
                          
                          // Playlist Name
                          Text(
                            imageText(currPlaylist.id, imageName),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis, //Displays (...) when oveflowed
                          ),
                        ],
                      ),
                  ),
                
                  //Playlist Divider underlining the Name
                  const Divider(
                    height: 1,
                    color: Colors.grey,
                  ),
                ]
              ));
            }
        ));
  }// build Widget

}// ImageGridState
