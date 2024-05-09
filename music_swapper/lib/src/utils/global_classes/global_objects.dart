import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:music_mover/src/utils/backend_calls/spotify_requests.dart';
import 'package:music_mover/src/utils/class%20models/track_model.dart';
import 'package:music_mover/src/utils/exceptions.dart';
import 'package:music_mover/src/utils/globals.dart';

/// Checks if the map has the neccessary keys.
void mapKeysCheck(List<String> keys, Map<String, dynamic> mapCheck, String functionName){
  for(String key in keys){
    if(!keys.contains(key)){
      throw CustomException(fatal: false, stack: StackTrace.current, functionName: functionName, error: 'Map is missing the required key \'$key\'.');
    }
  }
}

/// Removes the modified underscore and duplicate number from a track
/// ```dart
/// final response = getTrackId("9s8fs8sd98_1"); //response = "9s8fs8sd98"
/// ```
String getTrackId(String trackId){
  int underScoreIndex = trackId.indexOf('_');
  String result = trackId;

  if (underScoreIndex != -1){
    result = trackId.substring(0, underScoreIndex);
  }

  return result;
}// getTrackId

/// Modifies the users input to remove any potentially problomatic charachters.
String modifyBadQuery(String query){
  List<String> badInput = <String>['\\', ';', '\'', '"', '@', '|'];
  String newQuery = '';
  for (String char in query.characters){
    if (!badInput.contains(char)){
      newQuery = newQuery + char;
    }
  }
  return newQuery;
}//modifyBadQuery

// /Standard grey divider
Divider customDivider(){
  return const Divider(
    color: Colors.grey,
  );
}

///Model for app TrackArguments object. Used to pass tracks between pages.
class TrackArguments{
  final List<TrackModel> selectedTracks;
  final String option;
  final SpotifyRequests spotifyRequests;

  ///Model for app TrackArguments object. Used to pass tracks between pages.
  TrackArguments({
    required this.selectedTracks,
    required this.option,
    required this.spotifyRequests,
  });

}


/// Timer to check if Refresh has been pressed to many times.
class RefreshTimer{
  int _refeshTimes = 0;
  static const int refreshLimit = 10;
  bool _timerStart = false;

  /// Checks if the user has clicked refresh too many times.
  bool shouldRefresh(bool loaded, bool loading, bool refresh){
    if(!loaded || loading || refresh){
      return false;
    }
    else if(_refeshTimes == refreshLimit && !_timerStart){
      Get.snackbar(
        'Reached Refresh Limit',
        'Refreshed too many times to quickly. Must wait before refreshing again.',
        backgroundColor: snackBarGrey
      );
      _timerStart = true;
      
      Timer.periodic(const Duration(seconds: 5), (timer) {
        _refeshTimes--;
        if(_refeshTimes == 0){
          _timerStart = false;
          timer.cancel();
        }
      });
      return false;
    }
    else if(_refeshTimes == refreshLimit && _timerStart){
      Get.snackbar(
        'Reached Refresh Limit',
        'Refreshed too many times to quickly. Must wait before refreshing again',
        backgroundColor: snackBarGrey
      );
      return false;
    }
    else{
      _refeshTimes++;
      return true;
    }
  }
}