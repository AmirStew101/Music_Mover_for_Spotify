import 'package:flutter/material.dart';

const String status = 'status';
const String success = 'Success';
const String failed = 'Failed';
const String statusMessage = 'message';

const String assetLikedSongs = 'assets/images/spotify_liked_songs.jpg';
const String assetNoImage = 'assets/images/no_image.png';
const String unlikeHeart = 'assets/images/unlike_heart-64.png';

Color spotHelperGreen = const Color.fromARGB(255, 3, 153, 8);
Color failedRed = const Color.fromARGB(255, 219, 26, 12);
Color errorMessageRed = const Color.fromARGB(255, 143, 12, 2);

Color linkBlue = const Color.fromARGB(255, 17, 134, 230);
Color snackBarGrey = const Color.fromARGB(255, 65, 64, 64);

class SpotifyIcons{
  final String blackCMYK = 'assets/images/Spotify_Icon_CMYK_Black.png';
  final String greenCMYK = 'assets/images/Spotify_Icon_CMYK_Green.png';
  final String whiteCMYK = 'assets/images/Spotify_Icon_CMYK_White.png';

  final String blackRGB = 'assets/images/Spotify_Icon_RGB_Black.png';
  final String greenRGB = 'assets/images/Spotify_Icon_RGB_Green.png';
  final String whiteRGB = 'assets/images/Spotify_Icon_RGB_White.png';

  String get iconBlackCMYK{
    return blackCMYK;
  }

  String get iconGreenCMYK{
    return greenCMYK;
  }

  String get iconWhiteCMYK{
    return whiteCMYK;
  }

  String get iconBlackRGB{
    return blackRGB;
  }

  String get iconGreenRGB{
    return greenRGB;
  }

  String get iconWhiteRGB{
    return whiteRGB;
  }

}

class SpotifyLogos{
  final String blackCMYK = 'assets/images/Spotify_Logo_CMYK_Black.png';
  final String greenCMYK = 'assets/images/Spotify_Logo_CMYK_Green.png';
  final String whiteCMYK = 'assets/images/Spotify_Logo_CMYK_White.png';

  final String blackRGB = 'assets/images/Spotify_Logo_RGB_Black.png';
  final String greenRGB = 'assets/images/Spotify_Logo_RGB_Green.png';
  final String whiteRGB = 'assets/images/Spotify_Logo_RGB_White.png';

  String get logoBlackCMYK{
    return blackCMYK;
  }

  String get logoGreenCMYK{
    return greenCMYK;
  }

  String get logoWhiteCMYK{
    return whiteCMYK;
  }

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
