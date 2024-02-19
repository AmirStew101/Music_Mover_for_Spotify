import 'package:flutter/material.dart';

const String hosted = 'https://amirstew.pythonanywhere.com';
const String ngrok = 'https://5a6f-173-66-70-24.ngrok-free.app';

const homeBannerAd = "ca-app-pub-6435368838932310/9378566458";
const playlistsBannerAd = "ca-app-pub-6435368838932310/1615626502";
const settingsNativeAd = "ca-app-pub-6435368838932310/6322185940";

const assetLikedSongs = 'assets/images/spotify_liked_songs.jpg';
const assetNoImage = 'assets/images/no_image.png';

const unlikeHeart = 'assets/images/unlike_heart-64.png';

Color spotHelperGrey = const Color.fromRGBO(25, 20, 20, 1);
Color spotHelperGreen = const Color.fromARGB(255, 6, 163, 11);

class SpotifyIcons{
  final blackCMYK = 'assets/images/Spotify_icons/Spotify_Icon_CMYK_Black.png';
  final greenCMYK = 'assets/images/Spotify_icons/Spotify_Icon_CMYK_Green.png';
  final whiteCMYK = 'assets/images/Spotify_icons/Spotify_Icon_CMYK_White.png';

  final blackRGB = 'assets/images/Spotify_icons/Spotify_Icon_RGB_Black.png';
  final greenRGB = 'assets/images/Spotify_icons/Spotify_Icon_RGB_Green.png';
  final whiteRGB = 'assets/images/Spotify_icons/Spotify_Icon_RGB_White.png';

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
  final blackCMYK = 'assets/images/Spotify_logos/Spotify_Logo_CMYK_Black.png';
  final greenCMYK = 'assets/images/Spotify_logos/Spotify_Logo_CMYK_Green.png';
  final whiteCMYK = 'assets/images/Spotify_logos/Spotify_Logo_CMYK_White.png';

  final blackRGB = 'assets/images/Spotify_logos/Spotify_Logo_RGB_Black.png';
  final greenRGB = 'assets/images/Spotify_logos/Spotify_Logo_RGB_Green.png';
  final whiteRGB = 'assets/images/Spotify_logos/Spotify_Logo_RGB_White.png';

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
