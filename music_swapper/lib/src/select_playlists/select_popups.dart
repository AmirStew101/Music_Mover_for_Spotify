
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:music_mover/src/utils/globals.dart';

class SelectPopups{
  ///Moved or Added tracks Successfully
  SelectPopups.success(String message){
    Get.snackbar(
      'Success', 
      message,
      isDismissible: true,
      backgroundColor: snackBarGrey,
      colorText: spotHelperGreen,
      duration: const Duration(seconds: 5),
      snackPosition: SnackPosition.TOP
    );
  }

  /// Failed to Connect to Spotify
  SelectPopups.failConnection(){
    Get.snackbar(
      'Failed', 
      'Connection Error with Spotify',
      isDismissible: true,
      backgroundColor: snackBarGrey,
      colorText: failedRed,
      duration: const Duration(seconds: 5),
      snackPosition: SnackPosition.TOP
    );
  }

  /// Failed to add Tracks
  SelectPopups.failedAdd(){
    Get.snackbar(
      'Failed to Add Tracks', 
      'Connection Error with Spotify',
      isDismissible: true,
      backgroundColor: snackBarGrey,
      colorText: failedRed,
      duration: const Duration(seconds: 5),
      snackPosition: SnackPosition.TOP
    );
  }

  /// Failed to remove Tracks
  SelectPopups.failedRemove(){
    Get.snackbar(
      'Failed to Remove Tracks', 
      'Connection Error with Spotify',
      isDismissible: true,
      backgroundColor: snackBarGrey,
      colorText: failedRed,
      duration: const Duration(seconds: 5),
      snackPosition: SnackPosition.TOP
    );
  }

  SelectPopups.noPlaylists(){
    Get.snackbar(
      '',
      '',
      titleText: const Text(
        'No Playlists Selected',
        textAlign: TextAlign.center,
        textScaler: TextScaler.linear(1.2),
      ),
      backgroundColor: snackBarGrey,
      isDismissible: true,
      snackPosition: SnackPosition.TOP,
    );
  }
}