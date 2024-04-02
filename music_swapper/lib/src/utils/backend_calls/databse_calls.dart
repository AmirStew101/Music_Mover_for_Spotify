
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';


final db = FirebaseFirestore.instance;

///Repository for the Users database interaction.
class UserRepository extends GetxController {
  static UserRepository get instance => Get.find();
  
  ///Reference to Users collection.
  final usersRef = db.collection('Users');
  ///Collection name for users Playlists.
  final playlistColl  = 'Playlists';
  ///Collection name for users Tracks.
  final tracksColl = 'PlaylistTracks';

  final CacheManager cacheManager = DefaultCacheManager();

  ///Checks if the user is in the database. 
  ///Returns ture or false.
  Future<bool> hasUser(UserModel user) async{
    try{
      final DocumentSnapshot<Map<String, dynamic>> userExists = await usersRef.doc(user.spotifyId).get();

      if (userExists.exists) {
        return true;
      }
      return false;
    }
    catch (e){
        throw Exception( exceptionText('database_calls.dart', '', e) );
    }
  }//hasUser
  
  ///Create a new user and adds them to the database.
  Future<void> createUser(UserModel user) async{
    await usersRef.doc(user.spotifyId).set(user.toFirestoreJson())
    .onError((error, stackTrace) {
      throw Exception( exceptionText('database_calls.dart', '', error, offset: 2));
      }
    );
  }//createUser

  ///Remove a user and their associated data from the database.
  Future<void> removeUser(UserModel user) async{
    final playlistsRef = usersRef.doc(user.spotifyId).collection(playlistColl);
    final playlistDocs = await playlistsRef.get();

    final batch = db.batch();
    
    //Delete each playlist and their associated Tracks
    for (var playlistDoc in playlistDocs.docs){
        batch.delete(playlistDoc.reference);
    }

    //Delete the User
    batch.delete(usersRef.doc(user.spotifyId));

    await batch.commit()
    .onError((error, stackTrace) => throw Exception( exceptionText('database_calls.dart', '', error, offset: 1)));
  }//removeUser

  ///Get the user from the database and converts to a `UserModel`.
  Future<UserModel?> getUser(UserModel user) async{
    final databaseUser = await usersRef.doc(user.spotifyId).get();
    
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
  }//getUser

  ///Updates the users information.
  Future<void> updateUser(UserModel user) async{
    final databaseUser = await usersRef.doc(user.spotifyId).get();

    if (databaseUser.exists){
      await usersRef.doc(user.spotifyId).update({'Subscribed': user.subscribed, 'Tier': user.tier, 'Username': user.username, 'Expiration': DateTime.now()})
      .onError((error, stackTrace) => throw Exception( exceptionText('database_calls.dart', 'updateUser', error, offset: 2) ));
    }
  }//updateUser


  ///Syncs user with [userId] database playlists with the Spotify playlists.
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
        await updatePlaylists(userId, newPlaylists);
      }

    }
    catch (e){
      throw Exception( exceptionText('database_calls.dart', 'syncUserPlaylists', e));
    }
  }//syncUserPlaylists

  ///Checks if the user with [userId] has a Playlists collection and creates one if none exists.
  Future<bool> hasPlaylistsColl(String userId) async{
    try{
    final playlistRef = usersRef.doc(userId).collection(playlistColl);

    if (playlistRef.isBlank == null){
      await playlistRef.doc().set({});
      return false;
    }

    return true;
    }
    catch (e){
      throw Exception( exceptionText('database_calls.dart', 'hasPlaylistsColl', e,));
    }
  }//hasPlaylistsColl

  ///Retreive the playlists from the database for user with [userId].
  Future<Map<String, PlaylistModel>> getPlaylists(String userId) async{
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
    })
    .onError((error, stackTrace) => throw Exception( exceptionText('database_calls.dart', 'getPlaylists', error, offset: 21) ));

    return allPlaylists;
  }//getPlaylists

  ///Create a playlist for each item in a list of [playlists] for the user with [userId].
  Future<void> updatePlaylists(String userId, List<PlaylistModel> playlists) async{
    try{
      final addBatch = db.batch();

      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      for(var playlist in playlists){
        addBatch.set(playlistRef.doc(playlist.id), playlist.toJsonFirestore());
      }

      await addBatch.commit();
    }
    catch (e){
      throw Exception( exceptionText('database_calls.dart', 'createPlaylists', e) );
    }
  }//createPlaylists

  ///Remove a playlist with [playlistId] from user with [userId].
  Future<void> removePlaylist(String userId, String playlistId) async{
    final playlistRef = usersRef.doc(userId).collection(playlistColl);
    await playlistRef.doc(playlistId).delete()
    .onError((error, stackTrace) => throw Exception( exceptionText('database_calls.dart', 'removePlaylist', error, offset: 1) ));

  }//removePlaylist


  ///Sync database tracks with [spotifyTracks] for the user with [userId] and playlist with [playlistId].
  ///
  ///Given a bool [updateDatabase] to determine between updating every track in a playlist or the missing tracks.
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
          updateBatch.update(tracksRef.doc(trackId), newTrack.toFirestoreJson());
        }

        i++;
      }

      await updateBatch.commit();

      if (createTracks.isNotEmpty){
        await updateTracks(userId, createTracks, playlistId);
      }

    }
    catch (e){
      throw Exception( exceptionText('database_calls.dart', 'syncPlaylistTracks', e) );
    }
  }//syncPlaylistTracks

  ///Get tracks from a playlist matching [playlistId] for the user with [userId].
  Future<Map<String, TrackModel>> getTracks(String userId, String playlistId) async{
    late Map<String, TrackModel> newTracks;

    await db.runTransaction((transaction) async{
      newTracks = {};
      final playlistRef = usersRef.doc(userId).collection(playlistColl);
      final tracksRef = playlistRef.doc(playlistId).collection(tracksColl);
      final playlistTracks = await tracksRef.get();

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
    },
    maxAttempts: 3)
    .onError((error, stackTrace) => throw Exception( exceptionText('database_calls.dart', 'getTracks', error, offset: 27) ));

    return newTracks;
  }//getTracks

  ///Creates new track documents for a user with playlist id matching the given [userId] and [playlistId] respectively.
  ///
  ///Documents are created from the given [trackModels].
  Future<void> updateTracks(String userId, List<TrackModel> trackModels, String playlistId) async{

    final playistRef = usersRef.doc(userId).collection(playlistColl);
    final tracksRef = playistRef.doc(playlistId).collection(tracksColl);
    final batch = db.batch();

    for (var model in trackModels){
      final track = await tracksRef.doc(model.id).get()
      .onError((error, stackTrace) => throw Exception( exceptionText('database_calls.dart', 'addTrackDocs', error, offset: 1) ));

      if (track.exists){
        batch.update(tracksRef.doc(model.id), {'duplicates': model.duplicates});
      }
      else{
        batch.set(tracksRef.doc(model.id), model.toFirestoreJson());
      }
    }

    await batch.commit()
    .onError((error, stackTrace) => throw Exception( exceptionText('database_calls.dart', 'addTrackDocs', error, offset: 1) ));
    
  }//addTrackDocs

  ///Remove tracks for a user with playlist id matching the given [userId] and [playlistId] respectively.
  Future<void> removePlaylistTracks(String userId, List<String> trackIds, String playlistId) async{

    final playlistRef = usersRef.doc(userId).collection(playlistColl);
    final tracksRef = playlistRef.doc(playlistId).collection(tracksColl);
    final playlist = await playlistRef.doc(playlistId).get();

    final batch = db.batch();

    if (!playlist.exists){
      Object error = "Playlist does not exist";
      throw Exception( exceptionText('database_calls.dart', 'removePlaylistTracks', error, offset: 2) );
    }

    Map<String, int> removeTotal = {};

    //Keep track of how many times a track is deleted. This is for deleting duplicates.
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
      final databaseTrack = await tracksRef.doc(removeTrack.key).get()
      .onError((error, stackTrace) => throw Exception( exceptionText('database_calls.dart', 'removePlaylistTracks', error, offset: 1) ));

      int databaseDupes = databaseTrack.data()!['duplicates'];

      int diff = databaseDupes - removeTrack.value;

      //All duplicates of a track are deleted.
      if (diff < 0){
        batch.delete(tracksRef.doc(removeTrack.key));
      }
      //Some of the tracks duplicates are deleted.
      else{
        batch.update(tracksRef.doc(removeTrack.key), {'duplicates': diff});
      }

    }

    //Deletes all batched tracks
    await batch.commit()
    .onError((error, stackTrace) => throw Exception( exceptionText('database_calls.dart', 'removePlaylistTracks', error, offset: 1) ));

  }//removePlaylistTracks

}