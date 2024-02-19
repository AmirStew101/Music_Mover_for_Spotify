// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/playlists_requests.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/tracks_requests.dart';
import 'package:spotify_music_helper/src/utils/global_classes/database_class.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';

String allOption = 'all';
String tracksOption = 'tracks';
String playlistsOption = 'playlists';

class SpotifySync{
  bool isSyncing = false;
  bool updateDatabase = true;

  AnimatedBuilder startIcons(AnimationController controller, String option, ScaffoldMessengerState scaffoldMessengerState){
    return syncIcons(controller, option, scaffoldMessengerState);
  }

  Future<void> startAll(String option, ScaffoldMessengerState scaffoldMessengerState) async{
    isSyncing = true;
    await syncAllPlaylists(option, scaffoldMessengerState);

    if (!isSyncing) return;

    await syncAllTracks(option, scaffoldMessengerState);
    isSyncing = false;
  }

  Future<void> startPlaylists(String option, ScaffoldMessengerState scaffoldMessengerState) async{
    isSyncing = true;
    await syncAllPlaylists(option, scaffoldMessengerState);
    isSyncing = false;
  }

  Future<void> startTracks(String option, ScaffoldMessengerState scaffoldMessengerState) async{
    isSyncing = true;
    await syncAllTracks(option, scaffoldMessengerState);
    isSyncing = false;
  }

  Future<void> startUpdate(List<String> playlistIds, ScaffoldMessengerState scaffoldMessengerState) async{
    isSyncing = true;
    for (var id in playlistIds){
      await syncUpdatePlaylist(id, scaffoldMessengerState);
    }
    isSyncing = false;
  }

  void stop(){
    isSyncing = false;
  }
  
  //Updates a playlist after adding songs to it
  Future<void> syncUpdatePlaylist(String playlistId, ScaffoldMessengerState scaffoldMessengerState) async{
      final callback = await SecureStorage().getTokens();
      final user = await SecureStorage().getUser();

      if (user != null && callback != null && isSyncing){
        CallbackModel receivedCall = callback;

        try{
          final result = await checkRefresh(receivedCall, false); 

          if (result != null){
            receivedCall = result;
          }

          int tracksTotal = await getSpotifyTracksTotal(playlistId, receivedCall.expiresAt, receivedCall.accessToken);
          Map<String, TrackModel> tracks = await getSpotifyPlaylistTracks(playlistId, receivedCall.expiresAt, receivedCall.accessToken, tracksTotal);
          
          await DatabaseStorage().smartSyncTracks(user.spotifyId, tracks, playlistId);
        }
        catch (e){
          errorMessage(scaffoldMessengerState);
        }
      }
    }


  AnimatedBuilder syncIcons(AnimationController controller, String option, ScaffoldMessengerState scaffoldMessengerState){
      return AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: controller.value * 2 * 3.14,
            child: IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () async {

                if (isSyncing){
                  //Start animation
                  controller.repeat();
                }

                if (option == allOption){
                  updateDatabase = true;
                  await SpotifySync().startAll(option, scaffoldMessengerState);
                }
                else if (option == playlistsOption){
                  await SpotifySync().startPlaylists(option, scaffoldMessengerState);
                }
                else if (option == tracksOption){
                  await SpotifySync().startTracks(option, scaffoldMessengerState);
                }

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


  Future<void> syncAllPlaylists(String option, ScaffoldMessengerState scaffoldMessengerState) async{
      final callback = await SecureStorage().getTokens();
      final user = await SecureStorage().getUser();

      if (user != null && callback != null && isSyncing){
        startMessage(scaffoldMessengerState, 'Playlists');

        CallbackModel receivedCall = callback;

        try{
          final result = await checkRefresh(receivedCall, false); 

          if (result != null){
            receivedCall = result;
          }
          final playlists = await getSpotifyPlaylists(receivedCall.expiresAt, receivedCall.accessToken, user.spotifyId);

          if (updateDatabase){
            await DatabaseStorage().deepSynvPlaylists(playlists, user.spotifyId);
          }
          else{
            await DatabaseStorage().smartSyncPlaylists(playlists, user.spotifyId);
          }

          //Update User on What playlists have been Synced
          if (option != allOption){
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
                backgroundColor: const Color.fromARGB(255, 1, 167, 7),

              )
            );
          }
        }
        catch (e){
          errorMessage(scaffoldMessengerState);
        }
      }
      else{

      }
    }//syncAllPlaylists


  Future<void> syncAllTracks(String option, ScaffoldMessengerState scaffoldMessengerState) async{
      final callback = await SecureStorage().getTokens();
      final user = await SecureStorage().getUser();

      if (user != null && callback != null && isSyncing){

        if (option == 'tracks'){
          startMessage(scaffoldMessengerState, 'Tracks');
        }
        else{
          startMessage(scaffoldMessengerState, 'Playlists & Tracks');
        }

        CallbackModel receivedCall = callback;

        final result = await checkRefresh(receivedCall, false); 

        if (result != null){
          receivedCall = result;
        }
        Map<String, PlaylistModel> playlists = await getSpotifyPlaylists(receivedCall.expiresAt, receivedCall.accessToken, user.spotifyId);
        
        //Gets every Playlist's Tracks and syncs Tracks to database
        for (var playlist in playlists.entries){
          try{
            debugPrint('Getting tracks for ${playlist.value.title} ${playlist.key}');
            
            final result = await checkRefresh(receivedCall, false); 

            if (result != null){
              receivedCall = result;
            }

            int tracksTotal = await getSpotifyTracksTotal(playlist.value.id, receivedCall.expiresAt, receivedCall.accessToken);
            Map<String, TrackModel> tracks = await getSpotifyPlaylistTracks(playlist.value.id, receivedCall.expiresAt, receivedCall.accessToken, tracksTotal);

            if (updateDatabase){
              await DatabaseStorage().deepSyncTracks(user.spotifyId, tracks, playlist.value.id);
            }
            else{
              await DatabaseStorage().smartSyncTracks(user.spotifyId, tracks, playlist.value.id);
            }

          }
          catch (e){
            errorMessage(scaffoldMessengerState);
          }

          //Removes old notification
          scaffoldMessengerState.hideCurrentSnackBar();

          //Update user on Progress
          String mesg = playlist.value.title;
          
          scaffoldMessengerState.showSnackBar(
            SnackBar(
              content: Text('Synced: $mesg tracks'),
              duration: const Duration(seconds: 8),
              backgroundColor: const Color.fromARGB(255, 1, 167, 7),

            )
          );
        }
      }
    }//syncAllTracks


  void startMessage(ScaffoldMessengerState scaffoldMessengerState, String message){
      scaffoldMessengerState.showSnackBar(
          SnackBar(
            content: Column(
              children: [
                Text('Started Syncing $message'),
                const Text('Will sync in the background')
              ],
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: const Color.fromARGB(255, 1, 167, 7),

          )
        );
    }

  void errorMessage(ScaffoldMessengerState scaffoldMessengerState){
    scaffoldMessengerState.hideCurrentSnackBar();

    scaffoldMessengerState.showSnackBar(
      const SnackBar(
        content: Column(
          children: [
            Text(
              'Failed to connect with Spotify',
              style: TextStyle(color: Color.fromARGB(255, 209, 28, 15)),
            ),
            Text(
                'Sync Error',
                style: TextStyle(color: Color.fromARGB(255, 209, 28, 15)),
            )
          ],
        ),
        duration: Duration(seconds: 8),
        backgroundColor: Color.fromARGB(255, 143, 12, 2),
      ));
  }

}