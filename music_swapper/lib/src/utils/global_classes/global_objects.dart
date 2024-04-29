import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/class%20models/playlist_model.dart';
import 'package:spotify_music_helper/src/utils/class%20models/track_model.dart';

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
  final Map<String, TrackModel> selectedTracks;
  final String option;

  ///Model for app TrackArguments object. Used to pass tracks between pages.
  TrackArguments({
    this.selectedTracks = const <String, TrackModel>{},
    this.option = '',
  });

}