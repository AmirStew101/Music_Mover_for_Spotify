
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/src/utils/analytics.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/spotify_requests.dart';
import 'package:spotify_music_helper/src/utils/class%20models/custom_sort.dart';
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
  List<PlaylistModel> playlists = <PlaylistModel>[];
  late final SpotifyRequests _spotifyRequests;

  @override
  void initState(){
    super.initState();
    _spotifyRequests = widget.spotifyRequests;
    playlists = widget.playlists;
  }

  /// Text under a playlists image giving its state.
  String imageText(String id, String playlistName){
    if(_spotifyRequests.loadedIds.contains(id)){
      return playlistName;
    }
    else if(!_spotifyRequests.errorIds.contains(id) && _spotifyRequests.loading.value){
      return 'Loading $playlistName';
    }
    else{
      return 'Error Loading $playlistName';
    }
  }


  @override
  Widget build(BuildContext context) {
    //Builds the Grid of Images with Playlist Names
    return Stack(
      children: <Widget>[
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, //Number of Col in the grid
            crossAxisSpacing: 8, //Spacing between Col
            mainAxisSpacing: 10, //Spacing between rows
          ),
          itemCount: playlists.length+1,
          itemBuilder: (_, int index) {
            
            if(index >= playlists.length){
              return const SizedBox(
                height: 10,
              );
            }
            else{
              //Gets the Map items by index with the extra item in mind
              final PlaylistModel currPlaylist = playlists[index];
              final String imageName = currPlaylist.title;
              String imageUrl = currPlaylist.imageUrl;
              
              return Obx(() => Column(
                children: <Widget>[
                  // Displays Images that can be clicked
                  InkWell(
                    onTap: () async {
                      if(_spotifyRequests.loadedIds.contains(currPlaylist.id)){
                        if (currPlaylist.title == 'Liked_Songs'){
                          await AppAnalytics().trackLikedSongs();
                        }

                        _spotifyRequests.currentPlaylist = currPlaylist;
                        bool? success = await Get.to(const TracksView());

                        if(success != null && !success){
                          _spotifyRequests.requestTracks(currPlaylist.id);
                        }
                      }
                    },
                    // Aligns the image over its title
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          if(_spotifyRequests.errorIds.contains(currPlaylist.id) && !_spotifyRequests.loading.value)
                          ...<Widget>[
                            SizedBox(
                              height: 154,
                              width: 155,
                              child: IconButton(
                                onPressed: () async{
                                  await _spotifyRequests.requestTracks(currPlaylist.id);
                                }, 
                                icon: const Icon(Icons.refresh)
                              )
                            ),
                            const Text('Retry')
                          ],

                          if(!_spotifyRequests.errorIds.contains(currPlaylist.id) || _spotifyRequests.loading.value)
                          ColorFiltered(
                              colorFilter: _spotifyRequests.loadedIds.contains(currPlaylist.id)
                              ? const ColorFilter.mode(Colors.transparent, BlendMode.srcOver)
                              : const ColorFilter.mode(Colors.grey, BlendMode.saturation),

                              child: imageUrl.contains('asset')
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
          }
        ),
      ],
    );
  }// build Widget

}// ImageGridState
