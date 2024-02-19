import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';


//Banner Ad setup fr Playlist
Widget playlistsAdRow(BuildContext context, UserModel user){
  if (user.subscribed){
    return Container();
  }

  final width = MediaQuery.of(context).size.width;

  final BannerAd bannerAd = BannerAd(
    size: AdSize.fluid, 
    adUnitId: 'ca-app-pub-3940256099942544/6300978111', 
    listener: BannerAdListener(
      onAdLoaded: (ad) => debugPrint('Ad Loaded\n'),
      onAdClicked: (ad) => debugPrint('Ad Clicked\n'),), 
    request: const AdRequest(),
  );

  bannerAd.load();
  
  return Positioned(
    bottom: 5,
    child: SizedBox(
      width: width,
      height: 70,
      //Creates the ad banner
      child: AdWidget(
        ad: bannerAd,
      ),
    )
  );
}

//Banner Ad setup
Widget homeAdRow(BuildContext context, UserModel user){
  if (user.subscribed){
    return Container();
  }

  final width = MediaQuery.of(context).size.width;

  final BannerAd bannerAd = BannerAd(
    size: AdSize.fluid, 
    adUnitId: 'ca-app-pub-3940256099942544/6300978111', 
    listener: BannerAdListener(
      onAdLoaded: (ad) => debugPrint('Ad Loaded\n'),
      onAdClicked: (ad) => debugPrint('Ad Clicked\n'),), 
    request: const AdRequest(),
  );

  bannerAd.load();
  
  return Positioned(
    bottom: 5,
    child: SizedBox(
      width: width,
      height: 70,
      //Creates the ad banner
      child: AdWidget(
        ad: bannerAd,
      ),
    )
  );
}

//Banner Ad setup
Widget settingsAdRow(BuildContext context, UserModel user){
  if (user.subscribed){
    return Container();
  }

  final width = MediaQuery.of(context).size.width;

  final BannerAd bannerAd = BannerAd(
    size: AdSize.fluid, 
    adUnitId: 'ca-app-pub-3940256099942544/6300978111', 
    listener: BannerAdListener(
      onAdLoaded: (ad) => debugPrint('Ad Loaded\n'),
      onAdClicked: (ad) => debugPrint('Ad Clicked\n'),), 
    request: const AdRequest(),
  );

  bannerAd.load();
  
  return Positioned(
    bottom: 5,
    child: SizedBox(
      width: width,
      height: 70,
      //Creates the ad banner
      child: AdWidget(
        ad: bannerAd,
      ),
    )
  );
}