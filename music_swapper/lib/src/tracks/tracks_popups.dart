
import 'dart:async';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';

class TracksViewPopups{

  /// Failed message to alert user of needed track selection to proceed.
  void noTracks(){
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
    Get.snackbar(
      'Error', 
      'Failed to open $type link.',
      backgroundColor: snackBarGrey,
      isDismissible: true,
      colorText: failedRed
    );
  }

}