
import 'package:spotify_music_helper/src/utils/class%20models/playlist_model.dart';
import 'package:spotify_music_helper/src/utils/class%20models/track_model.dart';
import 'package:spotify_music_helper/src/utils/exceptions.dart';

/// Sort Playlists and Tracks based on title's and Tracks by artists, types, and date added to playlist.
class Sort{

  final String title = 'title';
  final String artist = 'artist';
  final String type = 'type';
  final String addedAt = 'addedAt';


  /// Sorts a Map or List of playlists in ascending or descending order based on their Title.
  /// Trows an error if no Map or List is given.
  List<PlaylistModel> playlistsListSort(List<PlaylistModel> playlistsList,{bool ascending = true}){

    if(ascending){
      playlistsList.sort((PlaylistModel a, PlaylistModel b) => a.title.compareTo(b.title));
    }
    else{
      playlistsList.sort((PlaylistModel a, PlaylistModel b) => a.title.compareTo(b.title) * -1);
    }

    return playlistsList;
  }

  /// Sort a Map of tracks from a given playlist.
  /// 
  /// Sorts based on four types [title], [artist], [type], [addedAt]. Defaults to title as true but if another type is set to true it will override the [title] type.
  /// 
  /// [title] - The title of the Track,
  /// [artist] - The artists name,
  /// [type] - The type of track it is between 'track' and 'episode',
  /// [addedAt] - The time the track was added to the playlist
  /// 
  /// Tracks can be sorted in ascending or descending order based on the value of [ascending]. Defaults to true.
  List<TrackModel> tracksListSort({PlaylistModel? playlist, List<TrackModel>? tracksList, bool artist = false, bool type = false, bool addedAt = false, bool id = false, bool ascending = true}){
    List<TrackModel> tracks;

    if(playlist != null){
      tracks = playlist.tracks;
    }
    else if(tracksList != null){
      tracks = tracksList;
    }
    else{
      throw CustomException(error: 'Missing PlaylistModel or List of TrackModels');
    }


    if(artist){
      if(ascending){
        tracks.sort((TrackModel a, TrackModel b) => a.artistNames[0].compareTo(b.artistNames[0]));
      }
      else{
        tracks.sort((TrackModel a, TrackModel b) => a.artistNames[0].compareTo(b.artistNames[0]) * -1);
      }
    }
    else if(type){
      if (ascending){
        tracks.sort((TrackModel a, TrackModel b) => a.type.compareTo(b.type));
      }
      else{
        tracks.sort((TrackModel a, TrackModel b) => a.type.compareTo(b.type) * -1);
      }
    }
    else if(addedAt){
      if (ascending){
        tracks.sort((TrackModel a, TrackModel b) => a.addedAt.compareTo(b.addedAt));
      }
      else{
        tracks.sort((TrackModel a, TrackModel b) => a.addedAt.compareTo(b.addedAt) * -1);
      }
    }
    else if(id){
      if (ascending){
        tracks.sort((TrackModel a, TrackModel b) => a.id.compareTo(b.id));
      }
      else{
        tracks.sort((TrackModel a, TrackModel b) => a.id.compareTo(b.id) * -1);
      }
    }
    else{
      if(ascending){
        tracks.sort((TrackModel a, TrackModel b) => a.title.compareTo(b.title));
      }
      else{
        tracks.sort((TrackModel a, TrackModel b) => a.title.compareTo(b.title) * -1);
      }
    }

    return tracks;
  }

}