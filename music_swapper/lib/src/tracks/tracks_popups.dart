
import 'dart:async';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';

class TracksViewPopups{

  Future<bool> noTracks(BuildContext context) async{
      Flushbar(
        isDismissible: true,
        backgroundColor:failedRed,
        title: 'Failed Message',
        duration: const Duration(seconds: 2),
        flushbarPosition: FlushbarPosition.TOP,
        message: 'No tracks selected',
      ).show(context);
    
      await Future.delayed(const Duration(seconds: 2));
      return false;
  }

   Future<bool> deletedTracks(BuildContext context, int numDeleted, String from) async{
      Flushbar(
        backgroundColor: spotHelperGreen,
        title: 'Success Message',
        duration: const Duration(seconds: 3),
        flushbarPosition: FlushbarPosition.TOP,
        message: 'Deleted $numDeleted tracks from $from',
      ).show(context);
    
      await Future.delayed(const Duration(seconds: 2));
      return false;
  } 

}