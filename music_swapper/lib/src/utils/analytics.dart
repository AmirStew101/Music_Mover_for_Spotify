import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';

final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: analytics);
final FirebaseAnalyticsAndroid android = FirebaseAnalyticsAndroid();
final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

///Controls the Analytics for the app.
class AppAnalytics{

  ///Track a user logging into Spotify.
  Future<void> trackSpotifyLogin(UserModel user) async{
    await analytics.logEvent(
      name: 'spotify_login',
      parameters: <String, Object?>{
        'user': user.spotifyId,
        'subscribed': user.subscribed.toString(),
        'tier': user.tier
      },
    )
    .onError((Object? error, StackTrace stack) => _crashlytics.recordError(error, stack, reason: 'Failed to Log Spotify Login Event'));
  }

  ///Track saving a new user to the database.
  Future<void> trackSavedLogin(UserModel user) async{
    await analytics.logEvent(
      name: 'saved_login',
      parameters: <String, Object?>{
        'user': user.spotifyId,
        'subscribed': user.subscribed.toString(),
        'tier': user.tier
      },
    )
    .onError((Object? error, StackTrace stack) => _crashlytics.recordError(error, stack, reason: 'Failed to Log Saved Login Event'));
  }

}