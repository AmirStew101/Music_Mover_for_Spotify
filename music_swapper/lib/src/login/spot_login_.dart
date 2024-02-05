import 'dart:convert';
import 'dart:io';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:music_swapper/src/home/home_view.dart';
import 'package:music_swapper/utils/database/database_model.dart';
import 'package:music_swapper/utils/universal_widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:music_swapper/utils/globals.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

Future<WebViewController> initiateLogin(BuildContext context) async {
  const loginURL = '$hosted/get-auth-url';

    final response = await http.get(Uri.parse(loginURL));
    final responseDecode = json.decode(response.body);

    final authUrl = responseDecode['data']; //The authorization url to get Spotify access

    // Makes a Web controller to login to Spotify and redirect back to app
    if (responseDecode['status'] == 'Success') {
      final authUri = Uri.parse(authUrl);

      Map callback = {'accessToken': '', 'refreshToken': '', 'expiresAt': ''};

      //Sets up parameters for the Web controller
      PlatformWebViewControllerCreationParams params = const PlatformWebViewControllerCreationParams();

      if (WebViewPlatform.instance is AndroidWebViewPlatform){
        params = AndroidWebViewControllerCreationParams
        .fromPlatformWebViewControllerCreationParams(params);
      }

      //Creates controller to direct where the url goes and where the /callback from
      //Spotify takes the user when using a mobile app
      final controller = WebViewController.fromPlatformCreationParams(params);
      
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
            if (request.url.startsWith('$hosted/callback') && (Platform.isAndroid || Platform.isIOS)) {
              callback = await getCallback(request.url);
              
              final UserModel userModel = await syncUserData(callback['expiresAt'], callback['accessToken']);
              final Map<String, dynamic> user = {'id': userModel.spotifyId, 'username': userModel.username, 'uri': userModel.uri};

              Map<String, dynamic> multiArgs = {
                'callback': callback,
                'user': user,
              };

              // ignore: use_build_context_synchronously
              Navigator.pushNamed(context, HomeView.routeName, arguments: multiArgs);

              Flushbar(
                title: 'Success',
                message: 'User created',
                duration: const Duration(seconds: 3),
                flushbarPosition: FlushbarPosition.BOTTOM,
                titleColor: const Color.fromARGB(255, 6, 163, 11),
                messageColor: const Color.fromARGB(255, 6, 163, 11),
              );

            }
            return NavigationDecision.prevent;
          },
        ))
        ..loadRequest(authUri, method: LoadRequestMethod.get);

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

  throw Exception('Failed to get callback info');
}
