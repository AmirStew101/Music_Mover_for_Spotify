import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:spotify_music_helper/src/utils/class%20models/user_model.dart';

final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: analytics);
final FirebaseAnalyticsAndroid android = FirebaseAnalyticsAndroid();
final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

///Controls the Analytics for the app.
class AppAnalytics{

  /// Track a user logging into Spotify.
  Future<void> trackSpotifyLogin(UserModel user) async{
    await analytics.logLogin(
      parameters: <String, Object?>{
        'user': user.spotifyId.substring(0,5),
        'subscribed': user.subscribed.toString(),
        'tier': user.tier,
        'expiration': user.expiration.toString()
      },
    ).onError((Object? error, StackTrace stack) => _crashlytics.recordError(error, stack, reason: 'Failed to Log Spotify Login Event'));
  }

  /// Track saving a new user to the database.
  Future<void> trackSavedLogin(UserModel user) async{
    await analytics.logSignUp(
      signUpMethod: 'spotify',
      parameters: <String, Object?>{
        'user': user.spotifyId.substring(0,5),
        'subscribed': user.subscribed.toString(),
        'tier': user.tier,
        'expiration': user.expiration.toString()
      },
    ).onError((Object? error, StackTrace stack) => _crashlytics.recordError(error, stack, reason: 'Failed to Log Saved Login Event'));
  }

  Future<void> trackHelpMenu() async{
    await analytics.logScreenView(
      screenName: 'help_screen',
    );
  }

}