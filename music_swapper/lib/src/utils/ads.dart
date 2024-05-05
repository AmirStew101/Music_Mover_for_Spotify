
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spotify_music_helper/src/utils/dev_global.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';

/// Controls the Ad view for users.
class Ads{

  /// Setup the type of ad to be displayed depending on the page route name received.
  Widget setupAds(BuildContext context, UserModel user, {bool home = false}){
    if(user.subscribed){
      return Container();
    }
    else{
      late final String adUnit;

      if (Platform.isAndroid){
        adUnit = androidBannerAd;
      }
      else if (Platform.isIOS){
        adUnit = iosBannerAd;
      }
      else{
        return Container();
      }

      if(home){
        return _bannerAdRow(context, adUnit);
      }

      return _positionedbannerAdRow(context, adUnit);
    }
    
  }
  
  /// Banner Ad setup
  Widget _positionedbannerAdRow(BuildContext context, String adUnit){
    final double width = MediaQuery.of(context).size.width;

    final BannerAd bannerAd = BannerAd(
      size: AdSize.banner, 
      adUnitId: adUnit, 
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) => debugPrint('Ad Loaded\n'),
        onAdClicked: (Ad ad) => debugPrint('Ad Clicked\n'),), 
      request: const AdRequest(),
    );

    bannerAd.load();
    
    return Positioned(
      bottom: 5,
      child: SizedBox(
        width: width,
        height: 70,
        //Creates the ad banner
        child: Center(
          child: AdWidget(
            ad: bannerAd,
          ),
        )
      )
    );
  }

    /// Banner Ad setup
  Widget _bannerAdRow(BuildContext context, String adUnit){
    final double width = MediaQuery.of(context).size.width;

    final BannerAd bannerAd = BannerAd(
      size: AdSize.banner, 
      adUnitId: adUnit, 
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) => debugPrint('Ad Loaded\n'),
        onAdClicked: (Ad ad) => debugPrint('Ad Clicked\n'),), 
      request: const AdRequest(),
    );

    bannerAd.load();
    
    return SizedBox(
      width: width,
      height: 70,
      //Creates the ad banner
      child: Center(
        child: AdWidget(
          ad: bannerAd,
        ),
      )
    );
  }


}