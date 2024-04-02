import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';

final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: analytics);
final FirebaseAnalyticsAndroid android = FirebaseAnalyticsAndroid();

///Controls the Analytics for the app.
class AppAnalytics{

  ///Track a user logging into Spotify.
  Future<void> trackSpotifyLogin(UserModel user) async{
    await analytics.logEvent(
      name: 'spotify_login',
      parameters: {
        'user': user.spotifyId,
        'subscribed': user.subscribed.toString(),
        'tier': user.tier
      },
    )
    .whenComplete(() => debugPrint('Spotify Login Event Logged\n'))
    .onError((error, stackTrace) => debugPrint('Failed to Log Login Event: $error\n'));
  }

  ///Track saving a new user to the database.
  Future<void> trackSavedLogin(UserModel user) async{
    await analytics.logEvent(
      name: 'saved_login',
      parameters: {
        'user': user.spotifyId,
        'subscribed': user.subscribed.toString(),
        'tier': user.tier
      },
    )
    .whenComplete(() => debugPrint('Saved Login Event Logged\n'))
    .onError((error, stackTrace) => debugPrint('Failed to Log Login Event: $error\n'));
  }

  ///Track going to the liked Songs page.
  Future<void> trackLikedSongs() async{
    analytics.setAnalyticsCollectionEnabled(true);
    
    await analytics
    .logEvent(
      name: 'liked_songs_viewed',
    );
  }

}