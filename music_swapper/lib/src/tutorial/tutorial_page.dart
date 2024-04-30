
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/spotify_requests.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/tutorial_calls.dart';

class TutorialWidget extends StatelessWidget{
  final TutorialCalls _tutorialCalls = TutorialCalls();
  final SpotifyRequests _spotifyRequests = SpotifyRequests.instance;

  TutorialWidget({super.key}){
    _tutorialCalls.devInitTests(_spotifyRequests.allPlaylists);
  }
  
  @override
  Widget build(BuildContext context) {
    /// Test user data for viewing.
    String _test_user = '31rzpaxkysira77u2durfkotvtoi';
    
    

    return Scaffold(

    );
  }

}