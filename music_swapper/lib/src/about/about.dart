import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/universal_widgets.dart';

class AboutViewWidget extends StatefulWidget{
  const AboutViewWidget({super.key});
  static const routeName = '/About';
  
  @override
  State<AboutViewWidget> createState() => AboutViewState();


}
class AboutViewState extends State<AboutViewWidget> {
  CallbackModel callback = CallbackModel();
  UserModel user = UserModel();


  Future<void> checkLogin() async {
    CallbackModel? secureCall = await SecureStorage().getTokens();
    UserModel? secureUser = await SecureStorage().getUser();

    if (secureCall == null || secureUser == null){
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushReplacementNamed(StartViewWidget.routeName);
    }
    else{
      callback = secureCall;
      user = secureUser;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu), 
            onPressed: ()  {
              Scaffold.of(context).openDrawer();
            },
          )
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 6, 163, 11),
        title: const Text(
          'About Page',
          textAlign: TextAlign.center,
        ),
      ),
      drawer: optionsMenu(context),

      body: FutureBuilder(
        future: checkLogin(), 
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return const Text(
              '''This app is to help organize your Spotify playlist faster. It allows you to select multiple 
              songs by your choice of Artist, Genre, Album, etc. in bulk and move them to another playlist or 
              playlists of your choice. You can also mass delete songs too.
              
              1. If you have over 500 tracks first time syncing from Spotify might take a minute
              2. If a playlist is not showing you will need to go to the playlist click the playlist settings icon and click 'add to other playlist' and create a new playlist and the app should be able to find it now
              ''',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            );
          }
          else{
            return Container();
          }
        },
      )
    );
  }
}