// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:spotify_music_helper/src/home/home_view.dart';
import 'package:spotify_music_helper/src/login/start_screen.dart';
import 'package:spotify_music_helper/src/utils/object_models.dart';
import 'package:spotify_music_helper/src/utils/globals.dart';
import 'package:spotify_music_helper/src/utils/universal_widgets.dart';
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
    debugPrint('Spot Login Relogin value: $reLogin');
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
      responseDecode = json.decode(response.body);
    }
    catch (e){
      debugPrint('Caught Error in spot_login_view.dart in function initialLogin trying to get authUrl $e');
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
              debugPrint('Page started loading:');
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

                    SecureStorage().saveTokens(callbackModel);
                    SecureStorage().saveUser(syncedUser);

                    Navigator.pushNamedAndRemoveUntil(context, HomeView.routeName, (route) => false);
                  }
                  else{
                    Map<String, dynamic> startArgs = {'relogin': false, 'gotUser': true};
                    Navigator.pushNamedAndRemoveUntil(context, StartViewWidget.routeName, (route) => false, arguments: startArgs);
                  }
                }
                //Spotify was unable to send the callback
                else{
                  const Center(
                    child: Text(
                      'Problem with connecting to Spotify redirecting back to Start page',
                      textScaler: TextScaler.linear(1.5),),
                  );
                  Future.delayed(const Duration(seconds: 3));
                  Navigator.pushNamedAndRemoveUntil(context, StartViewWidget.routeName, (route) => false);
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
Future<Map> getCallback(callRequest) async {
  final response = await http.get(Uri.parse(callRequest));
  final responseDecode = jsonDecode(response.body);

  if (responseDecode['status'] == 'Success'){
    final Map<String, dynamic> info = responseDecode['data']; //This is a Map

    return info;
  }

  return {};
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
