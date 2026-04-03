import 'package:flutter/material.dart';

// GLOBAL INSTANCE
final themeProvider = ThemeProvider();

class ThemeProvider extends ChangeNotifier {
  // Start with system to be adaptive
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  // Helper to check if we are currently in Dark Mode
  bool isDarkMode(BuildContext context) {
    // This looks at the actual brightness of the app right now
    return Theme.of(context).brightness == Brightness.dark;
  }

  void toggleTheme(BuildContext context) {
    // If it's dark now, make it light. If it's light now, make it dark.
    if (isDarkMode(context)) {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    
    notifyListeners(); // This triggers the ListenableBuilder in main.dart
  }
}