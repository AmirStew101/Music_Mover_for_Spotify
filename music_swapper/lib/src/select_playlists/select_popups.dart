
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';

class SelectPopups{
  ///Moved or Added tracks Successfully
  Future<bool> success(BuildContext context, String message) async{
    Flushbar(
      isDismissible: true,
      backgroundColor: snackBarGrey,
      titleColor: spotHelperGreen,
      title: 'Success Message',
      duration: const Duration(seconds: 5),
      flushbarPosition: FlushbarPosition.TOP,
      message: message,
    ).show(context);
    
    await Future.delayed(const Duration(seconds: 5));
    return false;
  }

  ///Failed to Moved or Added tracks
  Future<bool> fail(BuildContext context) async{
    Flushbar(
      isDismissible: true,
      backgroundColor: snackBarGrey,
      titleColor: failedRed,
      title: 'Fail Message',
      duration: const Duration(seconds: 5),
      flushbarPosition: FlushbarPosition.TOP,
      message: 'Connection Error with Spotify',
    ).show(context);

    await Future.delayed(const Duration(seconds: 5));
    return false;
  }
}