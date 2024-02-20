
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/src/utils/analytics.dart';
import 'package:spotify_music_helper/src/utils/ads.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';

class ImageGridWidget extends StatefulWidget{
  const ImageGridWidget({required this.receivedCall, required this.playlists, required this.user, super.key});
  final CallbackModel receivedCall;
  final Map<String, PlaylistModel> playlists;
  final UserModel user;

  @override
  State<ImageGridWidget> createState() => ImageGridState();
}

//Class for the Playlist Images with their Names under them
class ImageGridState extends State<ImageGridWidget> {
  CallbackModel receivedCall = CallbackModel();
  Map<String, PlaylistModel> playlists = {};
  UserModel user = UserModel.defaultUser();
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  void initState(){
    super.initState();
    receivedCall = widget.receivedCall;
    playlists = widget.playlists;
    user = widget.user;
  }


  @override
  Widget build(BuildContext context) {
    //Builds the Grid of Images with Playlist Names
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, //Number of Col in the grid
                  crossAxisSpacing: 8, //Spacing between Col
                  mainAxisSpacing: 10, //Spacing between rows
                ),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    //Gets the Map items by index with the extra item in mind
                    final item = playlists.entries.elementAt(index);
                    final String imageName = item.value.title;
                    String imageUrl = item.value.imageUrl;

                    return Column(
                      children: [
                        //Displays Images that can be clicked
                        InkWell(
                          onTap: () async {
                            Map<String, dynamic> currPlaylist = item.value.toJson();

                            if (item.value.title == 'Liked_Songs'){
                              await AppAnalytics().trackLikedSongs();
                            }

                            // ignore: use_build_context_synchronously
                            Navigator.restorablePushNamed(context, TracksView.routeName, arguments: currPlaylist);
                          },
                          //Aligns the image over its title
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                imageUrl.contains('asset')
                                //Playlist doesn't have an image from Spotify
                                ? Image(
                                    image: AssetImage(imageUrl),
                                    fit: BoxFit.cover,
                                    height: 154,
                                    width: 155,
                                )
                                //Playlist has an image from Spotify
                                : Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    height: 154,
                                    width: 155,
                                    //Error connecting to the images URL
                                    //Use the No image asset
                                    errorBuilder: (context, error, stackTrace) => const Image(
                                      image: AssetImage(assetNoImage),
                                      fit: BoxFit.cover,
                                      height: 154,
                                      width: 155,
                                    ),
                                ),

                                //Playlist Name
                                Text(
                                  imageName,
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
                    );

                  }
              ),
            ),
            if (!user.subscribed || !devMode)
              //Space for Ad
              const SizedBox(
                height: 70,
              )
          ],
        ),

        homeAdRow(context, user),
      ],
    );
  }

}
