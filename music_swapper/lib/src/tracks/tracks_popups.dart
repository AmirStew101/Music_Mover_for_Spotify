
import 'dart:async';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';

class TracksViewPopups{

  ///Failed message to alert user of needed track selection to proceed.
  Future<bool> noTracks(BuildContext context) async{
      Flushbar(
        isDismissible: true,
        backgroundColor: snackBarGrey,
        titleColor: failedRed,
        title: 'Failed Message',
        duration: const Duration(seconds: 2),
        flushbarPosition: FlushbarPosition.TOP,
        message: 'No tracks selected',
      ).show(context);
    
      await Future.delayed(const Duration(seconds: 2));
      return false;
  }
  
  ///Successfully deleted tracks.
  Future<bool> deletedTracks(BuildContext context, int numDeleted, String from) async{
    Flushbar(
      backgroundColor: snackBarGrey,
      titleColor: spotHelperGreen,
      title: 'Success Message',
      duration: const Duration(seconds: 3),
      flushbarPosition: FlushbarPosition.TOP,
      message: 'Deleted $numDeleted track(s) from $from',
    ).show(context);
  
    await Future.delayed(const Duration(seconds: 2));
    return false;
  } 

}