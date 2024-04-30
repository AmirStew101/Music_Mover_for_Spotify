// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spotify_music_helper/src/utils/analytics.dart';
import 'package:spotify_music_helper/src/utils/auth.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/spotify_requests.dart';
import 'package:spotify_music_helper/src/utils/dev_global.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/database_classes.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/storage.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

const String _fileName = 'spot_login_view.dart';

///Handles Logging into a users Spotify Account and saving their info to the database.
class SpotLoginWidget extends StatefulWidget {
  const SpotLoginWidget({super.key});

  @override
  State<SpotLoginWidget> createState() => SpotLoginState();
}

///Implements Logging into a users Spotify Account and saving their info to the database.
class SpotLoginState extends State<SpotLoginWidget> {
  bool reLogin = Get.arguments;
  late ScaffoldMessengerState _scaffoldMessengerState;
  late SpotifyRequests _spotifyRequests;
  late DatabaseStorage _databaseStorage;
  late SecureStorage _secureStorage;
  late PlaylistsCacheManager _cacheManager;

  @override
  void initState(){
    super.initState();
    try{
      _secureStorage = SecureStorage.instance;
      _cacheManager = PlaylistsCacheManager.instance;
      _spotifyRequests = SpotifyRequests.instance;
      _databaseStorage = DatabaseStorage.instance;
      
    }
    catch (e){
      _secureStorage = Get.put(SecureStorage());
      _cacheManager = Get.put(PlaylistsCacheManager());
      _spotifyRequests = Get.put(SpotifyRequests());
      _databaseStorage = Get.put(DatabaseStorage());
    }
  }

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    //Initializes the page ScaffoldMessenger before the page is loaded in the initial state.
    _scaffoldMessengerState = ScaffoldMessenger.of(context);
  }

  ///In app web view for logging into Spotify.
  Future<WebViewController> initiateLogin(BuildContext context, bool reLogin) async {
    late final String loginURL;

    if (reLogin){
      //Ask user if they are signed into the correct account.
      loginURL = '$hosted/get-auth-url-dialog';
    }
    else{
      //Skip asking user if sign-in is correct.
      loginURL = '$hosted/get-auth-url-no-dialog';
    }

    late final dynamic responseDecode;

    try{
      final http.Response response = await http.get(Uri.parse(loginURL));
      
      if (response.statusCode != 200){
        loginIssue();
      }
      responseDecode = json.decode(response.body);
    }
    catch (e){
      loginIssue();
    }

    //The authorization url to get Spotify access.
    final String authUrl = responseDecode;

    // Makes a Web controller to login to Spotify and redirect back to app.
    final Uri authUri = Uri.parse(authUrl);

    //Stores the users callback tokens and expiration {'accessToken': '', 'refreshToken': '', 'expiresAt': ''}.
    //Map<String, dynamic> callback;

    //Sets up parameters for the Web controller.
    PlatformWebViewControllerCreationParams params = const PlatformWebViewControllerCreationParams();

    //Creates controller to direct where the url's redirect requests Navigate the user.
    final WebViewController controller = WebViewController.fromPlatformCreationParams(params);
    
    //Tries to Login a user through Spotify.
    try{
      //Sets up the controller settings and what the user sees.
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted) //Allows Spotify JavaScript
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            //Spotify sent the callback tokens.
            if (request.url.startsWith('$hosted/callback')) {
              await _spotifyRequests.initializeRequests(callRequest: request.url);

              await UserAuth().signInUser(_spotifyRequests.user.spotifyId);

              _databaseStorage.initializeDatabase(_spotifyRequests.user);

              await _secureStorage.saveTokens(_spotifyRequests.callback);
              await _secureStorage.saveUser(_spotifyRequests.user);
              await _cacheManager.getCachedPlaylists();

              await AppAnalytics().trackSpotifyLogin(_spotifyRequests.user);

              if(_databaseStorage.newUser){
                // Navigate to Tutorial screen for new Users and remove previous routes
                Get.offAllNamed('/tutorial');
              }
              else{
                // Navigate to Home and remove previous routes
                Get.offAllNamed('/');
              }
              
              return NavigationDecision.prevent;
            }
            else{
              // Facebook does not support in app sign-in.
              if(request.url.contains('facebook')){
                loginIssue(facebook: true);
                return NavigationDecision.prevent;
              }
              // Users Spotify account does not exist with Google sign-in.
              else if(request.url.contains('error')){
                loginIssue(missingAccount: true);
                return NavigationDecision.prevent;
              }
            }

            // Navigate to Third-party sign-in options (Google, Facebook, Apple).
            return NavigationDecision.navigate;
          },
        ))
        ..loadRequest(authUri, method: LoadRequestMethod.get);
    }
    catch (e){
      loginIssue();
    }

    return controller;
  }

  /// Creates an error Notification for the User and Returns to the Start Screen.
  void loginIssue({bool loginReset = true, bool missingAccount = false, bool facebook = false}){
    
    /// Returns to start screen when not a Fascebook or Missing account error.
    if (!facebook && !missingAccount) Get.back();

    late String errorText;

    if (!missingAccount && !facebook){
      errorText = 'Problem with connecting to Spotify redirecting back to Start page.';
    }
    else if (facebook){
      errorText = 'Use the Facebook app to login then try again.';
    }
    else{
      errorText = 'Google Spotify Account does not exist.';
    }
    
    _scaffoldMessengerState.hideCurrentSnackBar();
    _scaffoldMessengerState.showSnackBar(
      SnackBar(
        backgroundColor: snackBarGrey,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Error',
              textScaler: const TextScaler.linear(1.1),
              style: TextStyle(color: failedRed),
              textAlign: TextAlign.center,
            ),
            Text(
              errorText,
              textScaler: const TextScaler.linear(0.9),
              style: const TextStyle(color: Colors.white),
            )
          ],
        )
      )
    );

  }//loginIssue

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WebViewController>(
      future: initiateLogin(context, reLogin),
      builder: (BuildContext context, AsyncSnapshot<WebViewController> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error Connecting to Spotify.'));
          }

          //Extract WebViewController to be viewed by the user.
          final WebViewController controller = snapshot.data!;

          return Scaffold(
            appBar: AppBar(title: const Text('Spotify Login')),
            body: WebViewWidget(controller: controller),
          );
        } 
        else {
          return Scaffold(
            appBar: AppBar(title: const Text('Spotify Login')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}
