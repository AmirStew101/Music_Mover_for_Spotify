
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';


final db = FirebaseFirestore.instance;

class UserRepository extends GetxController {
  static UserRepository get instance => Get.find();
  
  final usersRef = db.collection('Users');
  final playlistColl  = 'Playlists';//Collection name for Users Playlists
  final tracksColl = 'PlaylistTracks'; //Collection name for Users Tracks

  final CacheManager cacheManager = DefaultCacheManager();

  Future<bool> hasUser(UserModel user) async{
    try{
      final DocumentSnapshot<Map<String, dynamic>> userExists = await usersRef.doc(user.spotifyId).get();

      if (userExists.exists) {
        return true;
      }
      return false;
    }
    catch (e){
        throw Exception('Caught Error in database_calls.dart line: ${getCurrentLine()} Function hasUser $e');
    }
  }
  
  Future<void> createUser(UserModel user) async{
    await usersRef.doc(user.spotifyId).set(user.toJson())
    .catchError((e) {
      throw Exception('Error trying to create user in databse_calls.dart line ${getCurrentLine(offset: 2)}: $e');
      }
    );
  }

  Future<void> removeUser(UserModel user) async{
    await usersRef.doc(user.spotifyId).delete()
    .catchError((e) => throw Exception('database_calls.dart line: ${getCurrentLine()} Caught Error: $e'));
  }

  Future<UserModel?> getUser(UserModel user) async{
    final userRef = usersRef.doc(user.spotifyId);
    final databaseUser = await userRef.get();
    
    if (databaseUser.exists){
      UserModel retreivedUser = UserModel(
        spotifyId: databaseUser.id,
        subscribed: databaseUser.data()?['subscribed'],
        tier: databaseUser.data()?['tier'],
        uri: databaseUser.data()?['uri'],
        username: databaseUser.data()?['username'],
        expiration: databaseUser.data()?['expiration']
      );

      return retreivedUser;
    }

    return null;
  }

  Future<void> updateUser(UserModel user) async{
    final userRef = usersRef.doc(user.spotifyId);
    final databaseUser = await userRef.get();

    if (databaseUser.exists){
      await userRef.update({'Subscribed': user.subscribed, 'Tier': user.tier, 'Username': user.username, 'Expiration': DateTime.now()})
      .catchError((e) {
        throw Exception('Caught error in database_calls.dart line: line ${getCurrentLine(offset: 2)} error: $e');
      });
    }
  }


  //Check if Playlist is in collections
  Future<void> syncUserPlaylists(String userId, Map<String, PlaylistModel> spotifyPlaylists) async{
    try{
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final playlistDocs = await playlistRef.get();
      final batch = db.batch();

      await db.runTransaction((transaction) async{
        //Removes playlists from database that are not in Spotify
        for (var playlistDoc in playlistDocs.docs){
          final playlistId = playlistDoc.id;

          if (!spotifyPlaylists.containsKey(playlistId)){
            transaction.delete(playlistRef.doc(playlistDoc.id));
            //batch.delete(playlistRef.doc(playlistDoc.id));
          }
        }
      });

      //Adds playlists that Database is missing or Updates existing
      List<PlaylistModel> newPlaylists = [];

      for (var playlist in spotifyPlaylists.entries){
        String playlistId = playlist.key;
        final databasePlaylist = await playlistRef.doc(playlistId).get();

        PlaylistModel newPlaylist = playlist.value;

        if (!databasePlaylist.exists){
          newPlaylists.add(newPlaylist);
        }
        else{
          batch.update(playlistRef.doc(playlistId), newPlaylist.toJsonFirestore());
        }
      }

      await batch.commit();

      if (newPlaylists.isNotEmpty){
        await createPlaylists(userId, newPlaylists);
      }

    }
    catch (e){
      throw Exception('In database_calls.dart line ${getCurrentLine()} $e');
    }
  }//syncUserPlaylists

  Future<Map<String, PlaylistModel>> getPlaylists(String userId) async{
    try {
      Map<String, PlaylistModel> allPlaylists = {};

      await db.runTransaction((transaction) async {
        //Gets all the Docs in the Playlist Ref
        QuerySnapshot<Map<String, dynamic>> playlistDocs = await usersRef.doc(userId).collection(playlistColl).get();
      
        //For every Doc it adds its fields to the Spotify Id as a Map
        //Ignoring the list of trackIds
        for (var element in playlistDocs.docs) {
          String imageUrl = element.data()['imageUrl'];
          String link = element.data()['link'];
          String snapshotId = element.data()['snapshotId'];
          String title = element.data()['title'];
          String playId = element.id;

          allPlaylists[element.id] = PlaylistModel(
            title: title, 
            id: playId, 
            link: link, 
            imageUrl: imageUrl, 
            snapshotId: snapshotId);
        }
      });

      return allPlaylists;
    }
    catch (e){
      throw Exception('In database_calls.dart line: ${getCurrentLine()} : $e');
    }
  }//getPlaylists

  //Add all Playlists as collections to database
  Future<void> createPlaylists(String userId, List<PlaylistModel> playlists) async{
    try{
      final addBatch = db.batch();

      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      for(var model in playlists){
        addBatch.set(playlistRef.doc(model.id), model.toJsonFirestore());
      }

      await addBatch.commit();
    }
    catch (e){
      throw Exception('In database_calls.dart line: ${getCurrentLine()} : $e');
    }
  }//createPlaylists

  Future<void> removePlaylist(String userId, String playlistId) async{
    try{    
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      await playlistRef.doc(playlistId).delete(); //Removes PLaylist from collection
    }
    catch (e){
      throw Exception('In database_calls.dart line: ${getCurrentLine()} : $e');
    }

  }//removePlaylist

  //Check if Track is in Users Playlist in database
  Future<void> syncPlaylistTracks(String userId, Map<String, TrackModel> spotifyTracks, String playlistId, bool updateDatabase) async{
    try{
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final tracksRef = playlistRef.doc(playlistId).collection(tracksColl);
      
      final playlistTracks = await tracksRef.get();

      int databaseTracks = playlistTracks.docs.length;
      int spotTracks = spotifyTracks.entries.length;

      List<String> removeIds = [];
      final batch = db.batch();
      
      //Removes extra tracks from playlist
      for (var track in playlistTracks.docs){
        final spotTrack = spotifyTracks[track.id];

        if (spotTrack == null){
          databaseTracks--;
          batch.delete(tracksRef.doc(track.id));
        }
        else if (spotTrack.duplicates != track.data()['duplicates']){
          removeIds.add(spotTrack.id);
        }
      }

      if (removeIds.isNotEmpty){
        await removePlaylistTracks(userId, removeIds, playlistId);
      }

      await batch.commit();

      //If Spotify & Database do not have matching tracks it adds
      int i = 0;
      List<TrackModel> createTracks = []; //List of databse missing tracks
      MapEntry<String, TrackModel> spotifyTrack;
      String trackId;
      TrackModel newTrack;
      DocumentSnapshot<Map<String, dynamic>> databaseTrack;
      final updateBatch = db.batch();

      while( (databaseTracks != spotTracks || updateDatabase) && i < spotTracks){
        spotifyTrack = spotifyTracks.entries.elementAt(i);
        trackId = spotifyTrack.key;

        databaseTrack = await tracksRef.doc(trackId).get();
        newTrack = spotifyTrack.value;

        //Track document is not in Database
        if (!databaseTrack.exists){
          databaseTracks++;
          createTracks.add(newTrack);
        }
        else if(updateDatabase){
          updateBatch.update(tracksRef.doc(trackId), newTrack.toJson());
        }

        i++;
      }

      await updateBatch.commit();

      if (createTracks.isNotEmpty){
        await createTrackDocs(userId, createTracks, playlistId);
      }

    }
    catch (e){
      throw Exception('Caught Error in database_calls.dart Function syncPlaylistTracks: $e');
    }
  }//syncPlaylistTracks

  //Get track names for a given playlist
  Future<Map<String, TrackModel>> getTracks(String userId, String playlistId) async{
    try{
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final tracksRef = playlistRef.doc(playlistId).collection(tracksColl);
      final playlistTracks = await tracksRef.get();
      
      Map<String, TrackModel> newTracks = {};

      for (var track in playlistTracks.docs){
        String id = track.id;
        String artist = track.data()['artist'];
        String imageUrl = track.data()['imageUrl'];
        String previewUrl = track.data()['previewUrl'] ?? '';
        String title = track.data()['title'];
        int duplicates = track.data()['duplicates'];
        bool liked = track.data()['liked'];
        
        newTracks[id] = TrackModel(
          id: id, 
          imageUrl: imageUrl, 
          artist: artist, 
          title: title,
          previewUrl: previewUrl,
          duplicates: duplicates,
          liked: liked,
        );
      }

      return newTracks;
    }
    catch (e){
      throw Exception('In database_calls.dart line ${getCurrentLine()} : $e');
    }
  }//getTracks

  //Add Track to Tracks Collection
  Future<void> createTrackDocs(String userId, List<TrackModel> trackModels, String playlistId) async{
    try{
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final tracksRef = playlistRef.doc(playlistId).collection(tracksColl);
      final batch = db.batch();

      for (var model in trackModels){
        //Creates/Updates the track document with the tracks ID as the key & fills the fields with track data
        batch.set(tracksRef.doc(model.id), model.toJson());
      }

      await batch.commit();
    }
    catch (e){
      throw Exception('Caught Error in database_calls.dart Function creatTrackDoc: $e');
    }
  }//createTrackDocs

  Future<void> addTrackDocs(String userId, List<TrackModel> trackModels, String playlistId) async{

    try{
      final playistRef = usersRef.doc(userId).collection(playlistColl);
      final tracksRef = playistRef.doc(playlistId).collection(tracksColl);
      final batch = db.batch();

      for (var model in trackModels){
        final track = await tracksRef.doc(model.id).get();

        if (track.exists){
          batch.update(tracksRef.doc(model.id), {'duplicates': model.duplicates});
        }
        else{
          batch.set(tracksRef.doc(model.id), model.toJson());
        }
      }

      await batch.commit();
    }
    catch (e){
      throw Exception('database_calls.dart line: ${getCurrentLine()} Caught Error: $e');
    }
    
  }


  //Removes the playlist connection in the database
  Future<void> removePlaylistTracks(String userId, List<String> trackIds, String playlistId) async{
      try{
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final tracksRef = playlistRef.doc(playlistId).collection(tracksColl);
      final playlist = await playlistRef.doc(playlistId).get();

      final batch = db.batch();

      if (!playlist.exists){
        throw Exception('Playlist does not exist');
      }

      Map<String, int> removeTotal = {};

      for (var id in trackIds){
        if (removeTotal[id] != null){
          removeTotal[id] = removeTotal[id]! + 1;
        }
        else{
          removeTotal[id] = 1;
        }
      }

      //Adds all tracks to be deleted to the batch
      for (var removeTrack in removeTotal.entries){
        final databaseTrack = await tracksRef.doc(removeTrack.key).get();
        int databaseDupes = databaseTrack.data()!['duplicates'];

        int diff = databaseDupes - removeTrack.value;

        if (diff < 0){
          batch.delete(tracksRef.doc(removeTrack.key));
        }
        else{
          batch.update(tracksRef.doc(removeTrack.key), {'duplicates': diff});
        }

      }

      //Deletes all batched tracks
      await batch.commit();
    }
    catch (e){
      throw Exception('Caught an Error in database_calls.dart function removePlaylistTracks: $e');
    }

  }//removePlaylistTracks

}