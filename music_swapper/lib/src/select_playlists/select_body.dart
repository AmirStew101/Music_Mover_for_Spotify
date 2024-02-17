// ignore: must_be_immutable
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/playlists_requests.dart';
import 'package:spotify_music_helper/src/utils/universal_widgets.dart';

class SelectBodyWidget extends StatefulWidget {
  const SelectBodyWidget(
      {super.key,
      required this.currentPlaylist,
      required this.selectedPlaylistsMap,
      required this.playlists,
      required this.receivedCall,
      required this.sendSelected,
      required this.user,
      }
  );

  final Map<String, PlaylistModel> selectedPlaylistsMap;
  final PlaylistModel currentPlaylist;
  final Map<String, PlaylistModel> playlists;
  final CallbackModel receivedCall;
  final void Function(List<MapEntry<String, dynamic>>) sendSelected;
  final UserModel user;

  @override
  State<SelectBodyWidget> createState() => SelectBodyState();
}

//Users Playlists to move selected songs to
class SelectBodyState extends State<SelectBodyWidget> {
  //Recived values
  Map<String, PlaylistModel> playlists = {};
  PlaylistModel currentPlaylist = const PlaylistModel();
  CallbackModel receivedCall = CallbackModel();
  UserModel user = UserModel.defaultUser();
  late final void Function(List<MapEntry<String, dynamic>>) sendSelected;

  List<MapEntry<String, dynamic>> selectedPlaylists = [];
  String currentId = '';
  bool selectAll = false;
  bool error = false;

  @override
  void initState() {
    super.initState();
    playlists = widget.playlists;
    sendSelected = widget.sendSelected;
    currentPlaylist = widget.currentPlaylist;
    receivedCall = widget.receivedCall;
    currentId = currentPlaylist.id;
    user = widget.user;

    Map<String, PlaylistModel> receivedSelected = widget.selectedPlaylistsMap;

    selectedPlaylists = List.generate(playlists.length, (index) {
        MapEntry<String, PlaylistModel> currPlaylist = playlists.entries.elementAt(index);

        String playlistTitle = currPlaylist.value.title;
        String playlistId = currPlaylist.key;
        bool selected = false;

        if (receivedSelected.containsKey(playlistId)){
          selected = true;
        }

        Map<String, dynamic> selectMap = {'chosen': selected, 'title': playlistTitle};

        return MapEntry(playlistId, selectMap);
    });

  }

  Future<void> refreshPlaylists() async {
    try{
    bool forceRefresh = false;
    //Checks to make sure Tokens are up to date before making a Spotify request
    final result = await checkRefresh(receivedCall, forceRefresh);

    //Ignore the error
    if (result != null){
      receivedCall = result;
    }
    

    playlists = await getSpotifyPlaylists(receivedCall.expiresAt, receivedCall.accessToken, user.spotifyId);

    bool updateDatabase = false;
    //Checks all playlists if they are in database
    await DatabaseStorage().syncPlaylists(playlists, user.spotifyId, updateDatabase);

    playlists.forEach((key, value) {
      //Gets the current 'chosen' value by checking if selectedList has the playlist
      //And if it is marked as true
      //returns true when playlist 'chosen' is true and false in any other case
      bool chosen = selectedPlaylists.contains(MapEntry(key, {'chosen': true, 'title': value.title}));

      Map<String, dynamic> selectMap = {'chosen': chosen, 'title': value.title};

      selectedPlaylists.add(MapEntry(key, selectMap));
    });
    }
    catch (e){
      debugPrint('Caught Error will trying to refresh playlists in select_body \n $e');
    }
    setState(() {
      
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return RefreshIndicator(
        onRefresh: refreshPlaylists,
        child: Stack(
          children: [

            //Creates the list of user playlists
            ListView.builder(
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                MapEntry<String, PlaylistModel> playEntry = playlists.entries.elementAt(index);
                String playTitle = playEntry.value.title;
                String playId = playEntry.key;
                bool chosen = selectedPlaylists[index].value['chosen'];
                Map<String, dynamic> selectMap = {'chosen': !chosen, 'title': playTitle};

                if (currentId == playId){
                  return Container();
                }
                else{
                  return InkWell(
                      onTap: () {
                        setState(() {
                          selectedPlaylists[index] = MapEntry(playId, selectMap);
                        });
                        sendSelected(selectedPlaylists);
                      },
                      child: ListTile(
                        leading: Checkbox(
                          value: chosen,
                          onChanged: (value) {
                            setState(() {
                              selectedPlaylists[index] = MapEntry(playId, selectMap);
                            });
                            sendSelected(selectedPlaylists);
                          },
                        ),
                        title: Text(playTitle),
                      ),
                    );
                }
              },
            ),
            // Hovering "Select All" button
            Positioned(
                top: screenHeight * 0.02,
                right: screenWidth * 0.05,
                child: FilterChip(
                  backgroundColor: selectAll
                      ? const Color.fromARGB(255, 6, 163, 11)
                      : Colors.grey,
                  label: selectAll
                      ? const Text('Deselect All')
                      : const Text('Select All'),
                  padding: const EdgeInsets.all(10.0),
                  onSelected: (value) {
                    setState(() {
                      selectAll = !selectAll;
                    });
                      //Selects all the check boxes
                      if (selectAll) {
                        selectedPlaylists.clear();
                        playlists.forEach((key, value) {
                          Map<String, dynamic> selectMap = {'chosen': true, 'title': value.title};
                          selectedPlaylists.add(MapEntry(key, selectMap));
                        },);
                        
                        sendSelected(selectedPlaylists);
                      } 
                      else {
                        //Deselects all check boxes
                        selectedPlaylists.clear();
                        playlists.forEach((key, value) {
                          Map<String, dynamic> selectMap = {'chosen': false, 'title': value.title};
                          selectedPlaylists.add(MapEntry(key, selectMap));
                        },);
                        
                        sendSelected(selectedPlaylists);
                      }
                  },
                ))
          ],
        ));
  }
}
