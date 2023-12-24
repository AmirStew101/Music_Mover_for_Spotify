// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:music_swapper/src/settings/settings_view.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  static const routeName = '/';

  Future<void> initiateLogin(BuildContext context) async {
    const serverUrl = 'https://6995-173-66-70-24.ngrok-free.app/login';

    try {
      final response = await http.get(Uri.parse(serverUrl));

      // Handle the response, you might want to check for success or handle errors
      //print('Response status: ${response.statusCode}');
      //print('Response body: ${response.body}');

      // Open a WebView to show the redirect URL
      if (response.statusCode == 200) {
        supportsCloseForLaunchMode(LaunchMode.inAppWebView);
        print('URL Launched result: ${await launchUrl(Uri.parse(response.body), mode:LaunchMode.inAppBrowserView) }');
      }
    } catch (error) {
      // Handle the error
      print('Error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login with Spotify'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to the settings page. If the user leaves and returns
              // to the app after it has been killed while running in the
              // background, the navigation stack is restored.
              Navigator.restorablePushNamed(context, SettingsView.routeName);
            },
          ),
        ],
      ),
      body: Center(
        child: IconButton(
          iconSize: 100,
          icon: const Icon(
            Icons.circle,
            color: Color.fromARGB(255, 20, 245, 136),
          ),
          onPressed: () async {
            initiateLogin(context);
            closeInAppWebView();
          },
        ),
      ),
    );
  }
}
