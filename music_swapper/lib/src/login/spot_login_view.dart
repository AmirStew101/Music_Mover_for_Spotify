import 'package:flutter/material.dart';
import 'package:music_swapper/src/login/spot_login_.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SpotViewContainer extends StatefulWidget {
  const SpotViewContainer({super.key});
  static const routeName = '/SpotLogin';

  @override
  State<SpotViewContainer> createState() => SpotLogin();
}

class SpotLogin extends State<SpotViewContainer> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WebViewController>(
      future: initiateLogin(context),
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
