
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';

class TracksViewPopups{
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Failed message to alert user of needed track selection to proceed.
  void noTracks(){
    _crashlytics.log('No Tracks message');

    Get.snackbar(
      'Failed', 
      'No tracks selected',
      isDismissible: true,
      backgroundColor: snackBarGrey,
      colorText: failedRed,
      duration: const Duration(seconds: 2),
      snackPosition: SnackPosition.TOP
    );
  }
  
  /// Successfully deleted tracks.
  void deletedTracks(int numDeleted, String from){
    _crashlytics.log('Deleted Tracks message');

    Get.snackbar(
      'Success', 
      'Deleted $numDeleted track(s) from $from',
      isDismissible: true,
      backgroundColor: snackBarGrey,
      colorText: spotHelperGreen,
      duration: const Duration(seconds: 2),
      snackPosition: SnackPosition.TOP
    );
  }

  /// Error notification for if the link failed to alert the user.
  void errorLink(String type){
    _crashlytics.log('Error Spotify Link message');

    Get.snackbar(
      'Error', 
      'Failed to open $type link.',
      backgroundColor: snackBarGrey,
      isDismissible: true,
      colorText: failedRed
    );
  }

}