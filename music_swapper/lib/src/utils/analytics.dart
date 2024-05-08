import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:music_mover/src/utils/class%20models/user_model.dart';

final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: _analytics);
final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

///Controls the Analytics for the app.
class AppAnalytics{

  /// Track a user logging into Spotify.
  Future<void> trackSpotifyLogin(UserModel user) async{
    await _analytics.logLogin(
      parameters: <String, Object?>{
        'user': user.spotifyId.substring(0,5),
        'subscribed': user.subscribed.toString(),
        'tier': user.tier,
        'expiration': user.expiration.toString()
      },
    ).onError((Object? error, StackTrace stack) => _crashlytics.recordError(error, stack, reason: 'Failed to Log Spotify Login Event'));
  }

  /// Track saving a new user to the database.
  Future<void> trackNewUser(UserModel user) async{
    await _analytics.logEvent(
      name: 'new_user',
      parameters: <String, Object?>{
        'subscribed': user.subscribed.toString(),
        'tier': user.tier,
        'expiration': user.expiration.toString()
      },
    ).onError((Object? error, StackTrace stack) => _crashlytics.recordError(error, stack, reason: 'Failed to Log Saved Login Event'));
  }

  Future<void> trackHelpMenu() async{
    await FirebaseAnalytics.instance.logScreenView(
      screenName: 'help_screen',
    );
  }

}