// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:music_mover/src/utils/analytics.dart';
import 'package:music_mover/src/utils/auth.dart';
import 'package:music_mover/src/utils/backend_calls/spotify_requests.dart';
import 'package:music_mover/src/utils/dev_global.dart';
import 'package:music_mover/src/utils/globals.dart';
import 'package:music_mover/src/utils/backend_calls/database_classes.dart';
import 'package:music_mover/src/utils/backend_calls/storage.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

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
  final SpotifyRequests _spotifyRequests = SpotifyRequests.instance;
  final SecureStorage _secureStorage = SecureStorage.instance;
  final PlaylistsCacheManager _cacheManager = PlaylistsCacheManager.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    //Initializes the page ScaffoldMessenger before the page is loaded in the initial state.
    _scaffoldMessengerState = ScaffoldMessenger.of(context);
  }

  ///In app web view for logging into Spotify.
  Future<WebViewController> initiateLogin(BuildContext context, bool reLogin) async {
    late final String loginURL;
    bool initializing = false;

    _crashlytics.log('Set login Url');
    if (reLogin){
      //Ask user if they are signed into the correct account.
      loginURL = '$hosted/get-auth-url-dialog';
    }
    else{
      //Skip asking user if sign-in is correct.
      loginURL = '$hosted/get-auth-url-no-dialog';
    }

    //The authorization url to get Spotify access.
    late final String authUrl;

    try{
      _crashlytics.log('Request AuthUrl');
      final http.Response response = await http.get(Uri.parse(loginURL));
      
      if (response.statusCode != 200){
        _crashlytics.recordError(response.body, StackTrace.current, reason: 'Failed to retrieve Request Url');
        loginIssue();
      }
      authUrl = json.decode(response.body);
    }
    catch (error, stack){
      _crashlytics.recordError(error, stack, reason: 'Failed to retrieve Request Url');
      loginIssue();
    }

    _crashlytics.log('Set authUri');
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
            if (request.url.startsWith('$hosted/callback') && !initializing) {
              _crashlytics.log('Clear Storage');
              _secureStorage.removeTokens();
              _secureStorage.removeUser();
              await _cacheManager.clearPlaylists();

              _crashlytics.log('Spot Login: Initialize SpotifyRequests');
              await _spotifyRequests.initializeRequests(callRequest: request.url);
              await DatabaseStorage.instance.initializeDatabase(_spotifyRequests.user);
              await _secureStorage.saveUser(DatabaseStorage.instance.user);
              _spotifyRequests.user = DatabaseStorage.instance.user;

              _crashlytics.log('Spot Login: Sign in User');
              await UserAuth().signInUser(_spotifyRequests.user.spotifyId);

              await AppAnalytics().trackSpotifyLogin(_spotifyRequests.user);

              // if(_databaseStorage.newUser){
              //   _crashlytics.log('Go to Turotrial page');
              //   // Navigate to Tutorial screen for new Users and remove previous routes
              //   Get.offAllNamed('/tutorial');
              // }
              // else{
                _crashlytics.log('Go to Home page');
                // Navigate to Home and remove previous routes
                Get.offAllNamed('/');
              //}
              
              return NavigationDecision.prevent;
            }
            else if(!initializing){
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
    _crashlytics.log('Login Issue');
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
