import 'package:firebase_analytics/firebase_analytics.dart';

FirebaseAnalytics analytics = FirebaseAnalytics.instance;

void trackOpen(){
  analytics.logAppOpen();
}


void trackLikedSongs(){
  analytics.logEvent(
    name: 'liked_songs_viewed',
    parameters: {
      'screen_name': 'playlists',
    }
  );
}