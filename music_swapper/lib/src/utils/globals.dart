
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String status = 'status';
const String success = 'Success';
const String failed = 'Failed';
const String statusMessage = 'message';
const String likedSongs = 'Liked_Songs';

const String assetLikedSongs = 'assets/images/spotify_liked_songs.jpg';
const String assetNoImage = 'assets/images/no_image.png';
const String assetUnlikeHeart = 'assets/images/unlike_heart-64.png';

Color spotHelperGreen = const Color.fromARGB(255, 3, 153, 8);
Color failedRed = const Color.fromARGB(255, 219, 26, 12);
Color errorMessageRed = const Color.fromARGB(255, 143, 12, 2);

Color linkBlue = const Color.fromARGB(255, 17, 134, 230);
Color snackBarGrey = const Color.fromARGB(255, 65, 64, 64);

class SpotifyLogos{
  final String blackRGB = 'assets/images/Spotify_Logo_RGB_Black.png';
  final String greenRGB = 'assets/images/Spotify_Logo_RGB_Green.png';
  final String whiteRGB = 'assets/images/Spotify_Logo_RGB_White.png';

  String get logoBlackRGB{
    return blackRGB;
  }

  String get logoGreenRGB{
    return greenRGB;
  }

  String get logoWhiteRGB{
    return whiteRGB;
  }

}
