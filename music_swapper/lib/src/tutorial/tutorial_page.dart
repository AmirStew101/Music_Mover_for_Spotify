
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';

class TutorialWidget extends StatelessWidget{

  final RxList<String> _tutorialImages = <String>[SpotifyLogos().greenRGB].obs;
  int index = 0;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Row(
          children: [

            if(index > 0)
            IconButton(
              onPressed: () {
                print('Move to previous image.');
                index--;
              }, 
              icon: const Icon(Icons.arrow_back_ios_rounded)
            ),

            Obx(() => Image(
              image: AssetImage(_tutorialImages[index])
            )),

            if(index < _tutorialImages.length)
            IconButton(
              onPressed: () {
                print('Move to next image.');
                index++;
              }, 
              icon: const Icon(Icons.arrow_forward_ios_rounded)
            )
          ],
        ),
      ),
    );
  }

}