import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service that stores and retrieves user settings locally using the shared_preferences package.
class SettingsService {
  /// Loads the User's preferred ThemeMode from persistent storage.
  Future<ThemeMode> themeMode() async {
    //Get the persistent storage
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    //Get the saved theme from storage
    final String? savedTheme = prefs.getString('theme');

    //Stores a new theme to storage
    if (savedTheme == null){
      await updateThemeMode(ThemeMode.system);
      return ThemeMode.system;
    }

    //Sets the stored theme to application
    if(savedTheme == 'system'){
      return ThemeMode.system;
    }
    else if(savedTheme == 'dark'){
      return ThemeMode.dark;
    }
    else{
      return ThemeMode.light;
    }
  }

  /// Persists the user's preferred ThemeMode to local or remote storage.
  Future<void> updateThemeMode(ThemeMode theme) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('theme', theme.name);
  }
}
