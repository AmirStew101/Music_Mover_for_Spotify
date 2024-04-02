// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/home/home_view.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/utils/analytics.dart';
import 'package:spotify_music_helper/src/utils/auth.dart';
import 'package:spotify_music_helper/src/utils/backend_calls/spotify_requests.dart';
import 'package:spotify_music_helper/src/utils/dev_global.dart';
import 'package:spotify_music_helper/src/utils/global_classes/global_objects.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/global_classes/database_classes.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;


///Handles Logging into a users Spotify Account and saving their info to the database.
class SpotLoginWidget extends StatefulWidget {
  const SpotLoginWidget({super.key, required this.reLogin});
  final bool reLogin;

  static const routeName = '/SpotLogin';

  @override
  State<SpotLoginWidget> createState() => SpotLoginState();
}

///Implements Logging into a users Spotify Account and saving their info to the database.
class SpotLoginState extends State<SpotLoginWidget> {
  bool reLogin = false;
  late ScaffoldMessengerState _scaffoldMessengerState;

  @override
  void initState(){
    super.initState();
    reLogin = widget.reLogin;
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
      final response = await http.get(Uri.parse(loginURL));
      
      if (response.statusCode != 200){
        await loginIssue();
      }
      responseDecode = json.decode(response.body);
    }
    catch (e){
      await loginIssue();
    }

    //The authorization url to get Spotify access.
    final authUrl = responseDecode['data'];

    // Makes a Web controller to login to Spotify and redirect back to app.
    if (responseDecode['status'] == 'Success') {
      final authUri = Uri.parse(authUrl);

      //Stores the users callback tokens and expiration {'accessToken': '', 'refreshToken': '', 'expiresAt': ''}.
      Map<String, dynamic> callback;

      //Sets up parameters for the Web controller.
      PlatformWebViewControllerCreationParams params = const PlatformWebViewControllerCreationParams();

      //Creates controller to direct where the url's redirect requests Navigate the user.
      final controller = WebViewController.fromPlatformCreationParams(params);
      
      //Tries to Login a user through Spotify.
      try{
        //Sets up the controller settings and what the user sees.
        controller
          ..setJavaScriptMode(JavaScriptMode.unrestricted) //Allows Spotify JavaScript
          ..setNavigationDelegate(NavigationDelegate(
            onNavigationRequest: (NavigationRequest request) async {
              //Spotify sent the callback tokens.
              if (request.url.startsWith('$hosted/callback')) {
                callback = await getTokens(request.url);
                
                //No errors in getting the callback
                if (callback.isNotEmpty){
                  UserModel? spotifyUser = await SpotifyRequests().getUser(callback['expiresAt'], callback['accessToken']);

                  if (spotifyUser != null){
                    final getCustomTokenUrl = '$hosted/get-custom-token/${spotifyUser.spotifyId}';
                    final customResponse = await http.get(Uri.parse(getCustomTokenUrl));

                    if (customResponse.statusCode != 200){
                      throw Exception( exceptionText('spot_login_view.dart', 'initiateLogin', customResponse.body, offset: 3));
                    }

                    await UserAuth().signInUser(customResponse.body);
                    spotifyUser = await DatabaseStorage().syncUserData(spotifyUser);
                    
                    final CallbackModel callbackModel = CallbackModel(expiresAt: callback['expiresAt'], accessToken: callback['accessToken'], refreshToken: callback['refreshToken']);

                    await SecureStorage().saveTokens(callbackModel);
                    await SecureStorage().saveUser(spotifyUser);

                    await AppAnalytics().trackSpotifyLogin(spotifyUser);
                    Navigator.pushNamedAndRemoveUntil(context, HomeView.routeName, (route) => false);
                  }
                  else{
                    await loginIssue();
                  }
                }
                //Spotify was unable to send the callback
                else{
                  await loginIssue();
                }

                return NavigationDecision.prevent;
              }
              else{
                //Facebook does not support in app sign-in.
                if(request.url.contains('facebook')){
                  loginIssue(facebook: true);
                  return NavigationDecision.prevent;
                }
                //Users Spotify account does not exist with Google sign-in.
                else if(request.url.contains('error')){
                  loginIssue(missingAccount: true);
                  return NavigationDecision.prevent;
                }
              }

              //Navigate to Third-party sign-in options (Google, Facebook, Apple).
              return NavigationDecision.navigate;
            },
          ))
          ..loadRequest(authUri, method: LoadRequestMethod.get);
      }
      catch (e){
        throw Exception('Caught Error while trying to login to Spotify $e');
      }

      return controller;
    }
    throw Error();
  }

///Decides what to do when /callback is called.
Future<Map<String, dynamic>> getTokens(String callRequest) async {

  final response = await http.get(Uri.parse(callRequest));

  if (response.statusCode == 200){
    final Map<String, dynamic> responseDecode = jsonDecode(response.body);
  
    if (responseDecode.containsKey('status') && responseDecode['status'] == 'Success'){
      final Map<String, dynamic> info = responseDecode['data']; //This is a Map

      return info;
    }

  }
  else {
    throw Exception('Response: ${response.body.toString()}');
  }

  return {};
}

///Creates an error Notification for the User and Returns to the Start Screen.
Future<void> loginIssue({bool loginReset = true, bool missingAccount = false, bool facebook = false}) async{
  if (!facebook && !missingAccount) Navigator.pushNamedAndRemoveUntil(context, StartViewWidget.routeName, (route) => false, arguments: loginReset);

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
        children: [
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
      builder: (context, snapshot) {
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
