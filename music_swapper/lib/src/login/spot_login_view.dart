// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/home/home_view.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/utils/analytics.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/global_classes/database_class.dart';
import 'package:spotify_music_helper/src/utils/global_classes/secure_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

class SpotLoginWidget extends StatefulWidget {
  const SpotLoginWidget({super.key, required this.reLogin});
  final bool reLogin;

  static const routeName = '/SpotLogin';

  @override
  State<SpotLoginWidget> createState() => SpotLoginState();
}

class SpotLoginState extends State<SpotLoginWidget> {
  bool reLogin = false;

  @override
  void initState(){
    super.initState();
    reLogin = widget.reLogin;
  }

  //Spotify Login view
  Future<WebViewController> initiateLogin(BuildContext context, bool reLogin) async {
    late final String loginURL;

    if (reLogin){
      loginURL = '$hosted/get-auth-url-dialog';
    }
    else{
      loginURL = '$hosted/get-auth-url-no-dialog';
    }

    late final dynamic responseDecode;

    try{
      final response = await http.get(Uri.parse(loginURL));
      if (response.statusCode != 200){
        loginIssue();
      }
      responseDecode = json.decode(response.body);
    }
    catch (e){
      debugPrint('Caught Error in spot_login_view.dart in function initialLogin trying to get authUrl $e');
      loginIssue();
    }

    final authUrl = responseDecode['data']; //The authorization url to get Spotify access

    // Makes a Web controller to login to Spotify and redirect back to app
    if (responseDecode['status'] == 'Success') {
      final authUri = Uri.parse(authUrl);

      Map callback = {'accessToken': '', 'refreshToken': '', 'expiresAt': ''};

      //Sets up parameters for the Web controller
      PlatformWebViewControllerCreationParams params = const PlatformWebViewControllerCreationParams();

      //Creates controller to direct where the url goes and where the /callback from
      //Spotify takes the user when using a mobile app
      final controller = WebViewController.fromPlatformCreationParams(params);
      
      try{
        //Sets up the controller settings and what the user sees 
        controller
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(NavigationDelegate(
            onPageStarted: (String url) {
            },
            onProgress: (int progress) {
              debugPrint('Spotify Login Loading (progress: $progress%)');
            },
            onNavigationRequest: (NavigationRequest request) async {
              //Spotify sent the callback tokens
              if (request.url.startsWith('$hosted/callback')) {
                callback = await getCallback(request.url);
                
                //No errors in getting the callback
                if (callback.isNotEmpty){
                  final UserModel? syncedUser = await DatabaseStorage().syncUserData(callback['expiresAt'], callback['accessToken']);

                  if (syncedUser != null){
                    final CallbackModel callbackModel = CallbackModel(expiresAt: callback['expiresAt'], accessToken: callback['accessToken'], refreshToken: callback['refreshToken']);

                    await SecureStorage().saveTokens(callbackModel);
                    await SecureStorage().saveUser(syncedUser);

                    await AppAnalytics().trackSpotifyLogin(syncedUser);
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
              return NavigationDecision.navigate;
            },
          ))
          ..loadRequest(authUri, method: LoadRequestMethod.get);
      }
      catch (e){
        debugPrint('Caught Error while trying to login to Spotify $e');
      }

      return controller;
    }
    throw Error();
  }

//Function to decide what to do when /callback is called
Future<Map> getCallback(String callRequest) async {

  final response = await http.get(Uri.parse(callRequest));

  if (response.statusCode == 200){
    final Map<String, dynamic> responseDecode = jsonDecode(response.body);
  
    if (responseDecode.containsKey('status') && responseDecode['status'] == 'Success'){
      final Map<String, dynamic> info = responseDecode['data']; //This is a Map

      return info;
    }

  }
  else {
    debugPrint('Response: ${response.body.toString()}');
  }

  return {};
}

Future<void> loginIssue({bool loginReset = true, bool hasUser = false}) async{
  Flushbar(
    title: 'Error',
    message: 'Problem with connecting to Spotify redirecting back to Start page',
    backgroundColor: Colors.red,
    duration: const Duration(seconds: 3),
  ).show(context);

  await Future.delayed(const Duration(seconds: 3));
  bool reLogin = loginReset;
  Navigator.pushNamedAndRemoveUntil(context, StartViewWidget.routeName, (route) => false, arguments: reLogin);

}

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WebViewController>(
      future: initiateLogin(context, reLogin),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            // Handle error
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Extract WebViewController
          final WebViewController controller = snapshot.data!;

          return Scaffold(
            appBar: AppBar(title: const Text('Spotify Login')),
            body: WebViewWidget(controller: controller),
          );
        } 
        else {
          return Scaffold(
            appBar: AppBar(title: const Text('Spotify Login Loading')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}
