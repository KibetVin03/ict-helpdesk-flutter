import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'theme_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Transition to login
    Timer(const Duration(seconds: 10), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Use the smarter helper from our updated provider
    final bool isDark = themeProvider.isDarkMode(context);

    return Scaffold(
      body: Stack(
        children: [
          // 2. DYNAMIC BACKGROUND (Matches Global Theme)
          Positioned.fill(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),

          // 3. THEME SWITCH BUTTON
          Positioned(
            top: 50, 
            right: 20,
            child: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                // Adaptive icon color
                color: isDark ? Colors.white : Colors.indigo,
              ),
              onPressed: () {
                themeProvider.toggleTheme(context); // Added context
              },
            ),
          ),

          // 4. OVERLAY ANIMATION & TEXT
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/animations/splash.json',
                  width: 300,
                  height: 300,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  "Welcome To \n\nUoK ICT Helpdesk",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    // Indigo for light mode, White for dark mode
                    color: isDark ? Colors.white : Colors.indigo, 
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}