import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme_provider.dart'; // Import to access the theme switcher

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // .trim() handles accidental spaces often found on web copy-paste
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ); 
      if (mounted) {
        // Redirect to root where AuthGateway handles dashboard routing
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      // Specific error handling for more helpful feedback
      String errorMessage = "Login Failed";
      if (e.code == 'user-not-found') {
        errorMessage = "No account found for this email.";
      } else if (e.code == 'wrong-password') errorMessage = "Incorrect password.";
      else if (e.code == 'network-request-failed') errorMessage = "Check your internet connection.";
      else errorMessage = e.message ?? "An unexpected error occurred.";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An error occurred. Please try again.")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email first")),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password reset link sent to your email!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

@override
  Widget build(BuildContext context) {
    final bool isDark = themeProvider.isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Login"),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeProvider.toggleTheme(context);
            },
          ),
        ],
      ),
      // Use a Stack to layer the background image behind your content
      body: Stack(
        children: [
          // LAYER 1: Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/uok_logo.png', // Exact path as confirmed
              fit: BoxFit.cover,
            ),
          ),
          // LAYER 2: Semi-transparent overlay for readability
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
          // LAYER 3: Your original Login UI
          Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400), 
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_person, 
                        size: 80, 
                        color: isDark ? Colors.indigoAccent : Colors.indigo
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white), // Ensures text is visible
                        decoration: const InputDecoration(
                          labelText: "Email", 
                          labelStyle: TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white38),
                          ),
                          prefixIcon: Icon(Icons.email, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _passwordController,
                        // Change from 'true' to use the variable
                        obscureText: !_isPasswordVisible, 
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Password",
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: const OutlineInputBorder(),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white38),
                          ),
                          prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                          // Add the toggle button here
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _resetPassword,
                          child: const Text(
                            "Forgot Password?", 
                            style: TextStyle(color: Colors.redAccent)
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _isLoading 
                        ? const CircularProgressIndicator()
                        : SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo, 
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)
                                )
                              ),
                              onPressed: _handleLogin,
                              child: const Text("LOGIN"),
                            ),
                          ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account?", 
                            style: TextStyle(color: Colors.white70)
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(context, '/signup'),
                            child: const Text(
                              "Create Account",
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: Colors.indigoAccent
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}