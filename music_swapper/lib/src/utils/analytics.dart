import 'package:firebase_analytics/firebase_analytics.dart';

FirebaseAnalytics analytics = FirebaseAnalytics.instance;

Future<void> trackOpen() async{
  await analytics.logAppOpen();
}


Future<void> trackLikedSongs() async{
  await analytics.logEvent(
    name: 'liked_songs_viewed',
    parameters: {
      'screen_name': 'playlists',
    },
  );
}