import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/about/about.dart';
import 'package:spotify_music_helper/src/home/home_appbar.dart';
import 'package:spotify_music_helper/src/login/spot_login_view.dart';
import 'package:spotify_music_helper/src/settings/settings_view.dart';
import 'package:spotify_music_helper/utils/playlists_requests.dart';
import 'package:spotify_music_helper/src/home/home_body.dart';
import 'package:spotify_music_helper/src/tracks/tracks_view.dart';
import 'package:spotify_music_helper/utils/universal_widgets.dart';

//Creates the state for the home screen to view/edit playlists
class HomeView extends StatefulWidget {
  static const routeName = '/Home';

  //Class definition with the required callback data needed from Spotify
  const HomeView({super.key, required this.multiArgs});
  final Map<String, dynamic> multiArgs;

  @override
  State<HomeView> createState() => HomeViewState();
}

//State widget for the Home screen
class HomeViewState extends State<HomeView> {
  Map<String, dynamic> receivedCall = {}; //required passed callback variable
  Map<String, dynamic> user = {};

  Map<String, dynamic> playlists = {}; //all the users playlists
  bool loaded = false;
  bool error = false;
  bool refresh = false;

  Future<void> fetchDatabasePlaylists() async{
    loaded = false;
    final Map<String, dynamic> multiArgs = widget.multiArgs;
    receivedCall = multiArgs['callback'];
    user = multiArgs['user'];
    debugPrint('User: $user Callback: $receivedCall');

    if (!refresh){
      debugPrint('Fetching Database Playlists');
      playlists = await getDatabasePlaylists(user['id']);
    }

    if (playlists.isNotEmpty && playlists.length > 1 && !refresh){
      loaded = true;
    }
    else{
      await fetchSpotifyPlaylists();
    }
  }

  //Gets all the Users Playlists and platform specific images
  Future<void> fetchSpotifyPlaylists() async {
    loaded = false;
    debugPrint('\nNeeded Spotify\n');
    try{
      bool forceRefresh = false;
      //Checks to make sure Tokens are up to date before making a Spotify request
      receivedCall = await checkRefresh(receivedCall, forceRefresh);

      playlists = await getSpotifyPlaylists(receivedCall['expiresAt'], receivedCall['accessToken'], user['id']);

      //Checks all playlists if they are in database
      await syncPlaylists(playlists, user['id']);
    }
    catch (e){
      debugPrint('Caught an Error in Home fetchSpotifyPlaylists: $e');
      error = true;
    }

    refresh = false;
    loaded = true; //Future methods have complete
  }

  Future<void> refreshPage() async{
    if (error){
      SpotLogin().initiateLogin(context);
    }
    setState(() {
      loaded = false;
      error = false;
      refresh = true;
    });
  }

  //The main Widget for the page
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

        //Refresh Icon under Appbar
        bottom: Tab(
          child: IconButton(
            color: Colors.black,
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await refreshPage();
            },
          )
        ),

        //The Options Menu containing other navigation options
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu), 
            onPressed: ()  {
              Scaffold.of(context).openDrawer();
            },
          )
        ),

        centerTitle: true,
        automaticallyImplyLeading: false, //Prevents back arrow
        backgroundColor: const Color.fromARGB(255, 6, 163, 11),

        title: const Text(
          'Spotify Helper',
          textAlign: TextAlign.center,
        ),

        actions: [
          //Search Button
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                //Gets search result to user selected playlist
                final result = await showSearch(
                    context: context,
                    delegate: PlaylistSearchDelegate(playlists));

                //Checks if user selected a playlist before search closed
                if (result != null) {
                  tracksNavigate(result);
                }
              }
          ),
        ],
      ),

      drawer: homeOptionsMenu(),

      body: FutureBuilder<void>(
        future: fetchDatabasePlaylists(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && loaded && !error) {
            return ImageGridWidget(receivedCall: receivedCall, playlists: playlists, user: user,);
          }
          else if(refresh) {
              return const Center(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 6),
                        Text(
                          'Syncing Playlists',
                          textScaler: TextScaler.linear(2)
                        ),
                      ]
                  )
              );
            }
          else if(error && loaded){
            return const Center(child: Text(
              'Error retreiving Playlists from Spotify. Check connection and Refresh page.',
              textAlign: TextAlign.center,
              textScaler: TextScaler.linear(2),
              ),
            );
          }
          else{
              return const Center(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 6,),
                        Text(
                          'Loading Playlists',
                          textScaler: TextScaler.linear(2)
                        ),
                      ]
                  )
              );
            }
        },
      ),
    );
  }

  //Navigate to Tracks page for chosen Playlist
  void tracksNavigate(String playlistName){
    MapEntry<String, dynamic> currEntry = playlists.entries.firstWhere((element) => element.value['title'] == playlistName);
    Map<String, dynamic> currentPlaylist = {currEntry.key: currEntry.value};
    Map<String, dynamic> homeArgs = {
                    'currentPlaylist': currentPlaylist,
                    'callback': receivedCall,
                    'user': user,
    };
    Navigator.restorablePushNamed(context, TracksView.routeName, arguments: homeArgs);
  }

  Drawer homeOptionsMenu(){
    return Drawer(
      elevation: 16,
      width: 200,
      child: Container(
        alignment: Alignment.bottomLeft,
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color.fromARGB(255, 6, 163, 11)),
              child: Text(
                'Sidebar',
                style: TextStyle(fontSize: 18),
              )
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Playlists'),
              onTap: () {
                Map<String, dynamic> multiArgs = {
                'callback': receivedCall,
                'user': user,
                };

                Navigator.restorablePushNamed(context, HomeView.routeName, arguments: multiArgs);
              },
            ),
            ListTile(
              leading: const Icon(Icons.question_mark),
              title: const Text('About'),
              onTap: () {
                Map<String, dynamic> multiArgs = {
                'callback': receivedCall,
                'user': user,
                };
                
                Navigator.restorablePushNamed(context, AboutView.routeName, arguments: multiArgs);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.restorablePushNamed(context, SettingsView.routeName);
              },
            ),
            ListTile(
              title: const Text('Sign Out'),
              onTap: () {
                debugPrint('Sign Out Selected');
              },
            ),
          ],
        ),
      )
    );
  }

}

class HomeOptionsMenu extends Drawer {
  const HomeOptionsMenu({required this.callback, required this.user, super.key});
  final Map<String, dynamic> callback;
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 16,
      width: 200,
      child: Container(
        alignment: Alignment.bottomLeft,
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color.fromARGB(255, 6, 163, 11)),
              child: Text(
                'Sidebar',
                style: TextStyle(fontSize: 18),
              )
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Playlists'),
              onTap: () {
                Map<String, dynamic> multiArgs = {
                'callback': callback,
                'user': user,
                };
                debugPrint('Drawer Sending - User: $user Callback: $callback');
                Navigator.restorablePushNamed(context, HomeView.routeName, arguments: multiArgs);
              },
            ),
            ListTile(
              leading: const Icon(Icons.question_mark),
              title: const Text('About'),
              onTap: () {
                Map<String, dynamic> multiArgs = {
                'callback': callback,
                'user': user,
                };
                
                debugPrint('Drawer Sending - User: $user Callback: $callback');
                Navigator.restorablePushNamed(context, AboutView.routeName, arguments: multiArgs);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.restorablePushNamed(context, SettingsView.routeName);
              },
            ),
            ListTile(
              title: const Text('Sign Out'),
              onTap: () {
                debugPrint('Sign Out Selected');
              },
            ),
          ],
        ),
      )
    );
  
  }
}