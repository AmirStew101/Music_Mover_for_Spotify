// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/spotify_requests.dart';
import 'package:spotify_music_helper/src/utils/global_classes/database_classes.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';

String allOption = 'all';
String tracksOption = 'tracks';
String playlistsOption = 'playlists';

Color errorMessageRed = const Color.fromARGB(255, 143, 12, 2);

///Controls background syncing for Playlists and Tracks.
class SpotifySync{
  bool isSyncing = false;
  bool updateDatabase = true;

  ///Starts an animation for a sync Icon
  AnimatedBuilder startSyncIconsAnimation(AnimationController controller, ScaffoldMessengerState scaffoldMessengerState){
    return _syncIcons(controller, scaffoldMessengerState);
  }

  ///Start to Sync Spotify Playlists.
  Future<SyncGroupingModel> startPlaylistsSync(UserModel user, CallbackModel callback, ScaffoldMessengerState scaffoldMessengerState) async{
    isSyncing = true;
    final playlistsSync = await _syncAllPlaylists(user, callback, scaffoldMessengerState);
    isSyncing = false;
    return playlistsSync;
  }

  ///Start to Sync Spotify Tracks.
  Future<void> startSyncAllTracks(ScaffoldMessengerState scaffoldMessengerState, {bool showNotifications = false}) async{
    isSyncing = true;
    if (showNotifications) await _syncAllTracks(scaffoldMessengerState);
    isSyncing = false;
  }

  ///Start Syncing Tracks for a Playlist.
  Future<SyncGroupingModel> startPlaylistsTracksSync(UserModel user, CallbackModel callback, PlaylistModel playlist, ScaffoldMessengerState scaffoldMessengerState, {bool showNotifications = false}) async{
    isSyncing = true;
    final tracksSync = await _syncPlaylistsTracks(user, callback, playlist, scaffoldMessengerState);
    isSyncing = false;
    return tracksSync;
  }

  ///Start to update a Playlist after modifying it.
  Future<void> startUpdatePlaylistsTracks(UserModel user, CallbackModel callback, List<String> playlistIds, ScaffoldMessengerState scaffoldMessengerState) async{
    isSyncing = true;
    for (var id in playlistIds){
      await _syncUpdatePlaylistTracks(user, callback, id, scaffoldMessengerState);
    }
    isSyncing = false;
  }

  ///Stops Syncing
  void stop(){
    isSyncing = false;
  }
  

  //Private functions for animating the sync icon in settings and for Syncing Spotify Playlists and the Tracks within.

  ///Animates a sync Icon and starts syncing the corresponding Sync option.
  AnimatedBuilder _syncIcons(AnimationController controller, ScaffoldMessengerState scaffoldMessengerState){
      return AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: controller.value * 2 * 3.14, //Rate of rotation
            child: IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () async {

                if (isSyncing){
                  //Start animation
                  controller.repeat();
                }

                updateDatabase = true;
                await SpotifySync().startSyncAllTracks(scaffoldMessengerState);

                if (!isSyncing){
                  // Stop animation Finished Syncing
                  controller.reset();
                }
              },
            ),
          );
        },
      );
    }//Custom AnimatedBuilder

  ///Syncs all of a users Spotify Playlists and can notify the user for each retreived playlist.
  ///
  ///Returns the retreived Playlists. 
  Future<SyncGroupingModel> _syncAllPlaylists(UserModel user, CallbackModel callback, ScaffoldMessengerState scaffoldMessengerState, {bool showNotifications = false}) async{
      Map<String, PlaylistModel> playlists = {};

      if (isSyncing){
        if (showNotifications && isSyncing) _startMessage(scaffoldMessengerState, 'Playlists');

        try{
          final result = await SpotifyRequests().checkRefresh(callback); 

          if (result != null){
            callback = result;
            await SecureStorage().saveTokens(result);
          }
          else{
            SyncGroupingModel playlistsSync = SyncGroupingModel(callback: result, playlists: playlists);
            return playlistsSync;
          }

          if (isSyncing) playlists = await SpotifyRequests().getPlaylists(callback.expiresAt, callback.accessToken, user.spotifyId);

          if (isSyncing) await DatabaseStorage().syncPlaylists(playlists, user.spotifyId);
        }
        catch (e){
          _errorMessage(scaffoldMessengerState);
          throw Exception( exceptionText('sync_services.dart', '_syncAllPlaylists', e));
        }

        //Update User on What playlists have been Synced.
        if (showNotifications && isSyncing){
          String mesg = '';
          for (var playlist in playlists.entries){

            if (playlist.key != playlists.entries.last.key){
              mesg += '${playlist.value.title}, ';
            }
            else{
              mesg += playlist.value.title;
            }

          }
          scaffoldMessengerState.showSnackBar(
            SnackBar(
              content: Text('Synced: $mesg'),
              duration: const Duration(seconds: 6),
              backgroundColor: spotHelperGreen,

            )
          );
        }

        SyncGroupingModel playlistsSync = SyncGroupingModel(callback: callback, playlists: playlists);
        return playlistsSync;
      }

      SecureStorage().errorCheck(callback, user, scaffoldMessengerState: scaffoldMessengerState);
      Object error = "Failed to Sync Playlists";
      throw Exception( exceptionText('sync_services.dart', '_syncAllPlaylists', error) );
    }//syncAllPlaylists


  ///Used to update a Playlist given its id after adding songs to it.
  Future<void> _syncUpdatePlaylistTracks(UserModel user, CallbackModel callback, String playlistId, ScaffoldMessengerState scaffoldMessengerState) async{

      if (isSyncing){
        //Tries to update the Playlist's tracks if syncing.
        try{
          final result = await SpotifyRequests().checkRefresh(callback); 

          if (result != null){
            callback = result;
          }

          late int tracksTotal;
          if (isSyncing) tracksTotal = await SpotifyRequests().getTracksTotal(playlistId, callback.expiresAt, callback.accessToken);

          late Map<String, TrackModel> tracks;
          if (isSyncing) tracks = await SpotifyRequests().getPlaylistTracks(playlistId, callback.expiresAt, callback.accessToken, tracksTotal);
          
          if (isSyncing) await DatabaseStorage().syncTracks(user.spotifyId, tracks, playlistId);
          return;
        }
        catch (e){
          _errorMessage(scaffoldMessengerState);
        }
      }

      SecureStorage().errorCheck(callback, user, scaffoldMessengerState: scaffoldMessengerState);
      Object error = "Failed to Sync Playlists";
      throw Exception( exceptionText('sync_services.dart', '_syncUpdatePlaylistTracks', error) );
    }

  ///Sync all of a users Tracks for each of their Playlists.
  Future<void> _syncAllTracks(ScaffoldMessengerState scaffoldMessengerState, {bool showNotifications = false}) async{
      final callback = await SecureStorage().getTokens();
      final user = await SecureStorage().getUser();

      if (user != null && callback != null && isSyncing){

        if (showNotifications) _startMessage(scaffoldMessengerState, 'Tracks');

        CallbackModel receivedCall = callback;

        final result = await SpotifyRequests().checkRefresh(receivedCall); 

        if (result != null){
          receivedCall = result;
        }

        late Map<String, PlaylistModel> playlists;
        if (isSyncing) playlists = await SpotifyRequests().getPlaylists(receivedCall.expiresAt, receivedCall.accessToken, user.spotifyId);
        
        if (isSyncing){
          //Gets every Playlist's Tracks and syncs Tracks to database
          for (var playlist in playlists.entries){
            String total = '';
            try{
              
              final result = await SpotifyRequests().checkRefresh(receivedCall); 

              if (result != null){
                receivedCall = result;
              }

              late int tracksTotal;
              if (isSyncing) tracksTotal = await SpotifyRequests().getTracksTotal(playlist.value.id, receivedCall.expiresAt, receivedCall.accessToken);
              total = '$tracksTotal';

              late Map<String, TrackModel> tracks;
              if (isSyncing) tracks = await SpotifyRequests().getPlaylistTracks(playlist.value.id, receivedCall.expiresAt, receivedCall.accessToken, tracksTotal);

              if (isSyncing) await DatabaseStorage().syncTracks(user.spotifyId, tracks, playlist.value.id);

            }
            catch (e){
              _errorMessage(scaffoldMessengerState);
            }

            //Shows Tracks sync status for user if true.
            if (showNotifications){
              //Removes old notification
              scaffoldMessengerState.hideCurrentSnackBar();

              //Update user on Progress
              String mesg = playlist.value.title;

              scaffoldMessengerState.showSnackBar(
                SnackBar(
                  content: Text('Synced: $total tracks for $mesg'),
                  duration: const Duration(seconds: 8),
                  backgroundColor: spotHelperGreen,
                )
              );
            }
          }
        }
      }
    }//syncAllTracks

  ///Sync tracks for a playlist for a user.
  Future<SyncGroupingModel> _syncPlaylistsTracks(UserModel user, CallbackModel callback, PlaylistModel playlist, ScaffoldMessengerState scaffoldMessengerState, {bool showNotifications = false}) async{
      Map<String, TrackModel> tracks = {};

      if (isSyncing && showNotifications) _startMessage(scaffoldMessengerState, 'Tracks');

      if (isSyncing){
        
        try{
          final result = await SpotifyRequests().checkRefresh(callback); 

          if (result != null){
            callback = result;
          }
          else{
            return SyncGroupingModel(callback: callback, tracks: tracks);
          }

          late int tracksTotal;
          if (isSyncing) tracksTotal = await SpotifyRequests().getTracksTotal(playlist.id, callback.expiresAt, callback.accessToken);

          if (isSyncing) tracks = await SpotifyRequests().getPlaylistTracks(playlist.id, callback.expiresAt, callback.accessToken, tracksTotal);

          if (isSyncing) await DatabaseStorage().syncTracks(user.spotifyId, tracks, playlist.id);

        }
        catch (e){
          _errorMessage(scaffoldMessengerState);
        }

        //Shows Tracks sync status for user if true.
        if (showNotifications){
          //Removes old notification
          scaffoldMessengerState.hideCurrentSnackBar();
          
          scaffoldMessengerState.showSnackBar(
            SnackBar(
              content: Text('Synced tracks for ${playlist.title}'),
              duration: const Duration(seconds: 8),
              backgroundColor: spotHelperGreen,
            )
          );
        }

        return SyncGroupingModel(callback: callback, tracks: tracks);
      }
      //Syncing Stoped Return empty values.
      else{
        return const SyncGroupingModel(callback: null, tracks: {});
      }
    }//syncPlaylistTracks


  //Private functions for sending messages to the User. 

  ///Alerts the user that Syncing has started.
  void _startMessage(ScaffoldMessengerState scaffoldMessengerState, String message){
      scaffoldMessengerState.showSnackBar(
          SnackBar(
            action: SnackBarAction(
              label: "hide", 
              onPressed: () => scaffoldMessengerState.hideCurrentSnackBar(),
            ),
            content: Column(
              children: [
                Text('Started Syncing $message'),
                const Text('Will sync in the background')
              ],
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: spotHelperGreen,

          )
        );
    }

  ///Alerts the user that an error has occured.
  void _errorMessage(ScaffoldMessengerState scaffoldMessengerState){
    scaffoldMessengerState.hideCurrentSnackBar();

    scaffoldMessengerState.showSnackBar(
      SnackBar(
        action: SnackBarAction(
          label: "hide", 
          onPressed: () => scaffoldMessengerState.hideCurrentSnackBar(),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Sync Error',
                textScaler: const TextScaler.linear(1.2),
                style: TextStyle(color: failedRed),
            ),
            const Text(
              'Failed to connect with Spotify',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: snackBarGrey,
      ));
  }

}