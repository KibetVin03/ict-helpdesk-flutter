import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

// Page imports
import 'password_reset_handler.dart'; 
import 'create_ticket_page.dart'; 
import 'signup_page.dart'; 
import 'login_page.dart';
import 'admin_dashboard.dart';
import 'technician_portal.dart';
import 'splash_screen.dart';
import 'student_dashboard.dart';
import 'theme_provider.dart'; 
import 'faq_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await supabase.Supabase.initialize(
    url: 'https://rlrwtfzlntegjrbnwxpq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJscnd0ZnpsbnRlZ2pyYm53eHBxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MTk2OTksImV4cCI6MjA4OTQ5NTY5OX0.pQY7s0_GouWXln7JxS1RfdP9fe8YlJqCiKRjaj4qOgM', 
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const ICTHelpdeskApp(),
    ),
  );
}

class ICTHelpdeskApp extends StatelessWidget {
  const ICTHelpdeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Consumer used to react to theme changes from the toggle
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ICT Helpdesk Hybrid',
          themeMode: themeProvider.themeMode,
          initialRoute: '/splash',

          // Fixes for the "weird" Flutter 3.x UI look
          theme: ThemeData(
            useMaterial3: false, 
            primaryColor: const Color(0xFF1A237E),
            primarySwatch: Colors.indigo,
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1A237E),
              elevation: 8,
              centerTitle: false,
            ),
          ),

          darkTheme: ThemeData(
            useMaterial3: false,
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF1A237E),
            scaffoldBackgroundColor: const Color(0xFF0A0A0E), 
            cardColor: const Color(0xFF16161E),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1A237E),
              elevation: 4,
            ),
            colorScheme: const ColorScheme.dark(
              primary: Colors.indigoAccent,
              secondary: Colors.amber, 
              surface: Color(0xFF16161E),
            ),
          ),

          onGenerateRoute: (settings) {
            if (settings.name != null && (settings.name!.contains('/reset') || settings.name!.contains('oobCode'))) {
              return MaterialPageRoute(
                builder: (context) => const PasswordResetHandler(),
              );
            }
            return null; 
          },

          routes: {
            '/splash': (context) => const SplashScreen(), 
            '/': (context) => const AuthGateway(), 
            '/login': (context) => const LoginPage(),
            '/studentDashboard': (context) => const StudentDashboard(), 
            '/faq': (context) => const FAQPage(), // Add this line
            '/createTicket': (context) => const CreateTicketPage(),
            '/signup': (context) => const SignupPage(),
            '/adminDashboard': (context) => const AdminDashboard(),
            '/technicianPortal': (context) => const TechnicianPortal(),
            '/techDashboard': (context) => const TechnicianPortal(),
            '/reset': (context) => const PasswordResetHandler(),
          },
        );
      },
    );
  }
}

class AuthGateway extends StatelessWidget {
  const AuthGateway({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // USER NOT LOGGED IN: Landing View
        if (!snapshot.hasData) {
          return Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/uok_logo.png', // Ensure this exists in pubspec.yaml
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: Container(color: Colors.black.withOpacity(0.5)),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "UoK ICT Helpdesk",
                            style: TextStyle(
                              fontSize: 28, 
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A237E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pushNamed(context, '/login'),
                              child: const Text("SIGN IN", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(context, '/signup'),
                            child: const Text(
                              "Create New Account",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // USER LOGGED IN: Role-based routing
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
              return FutureBuilder<String?>(
                future: _getSavedRoleLocally(),
                builder: (context, localSnapshot) {
                  return _getDashboardByRole(localSnapshot.data ?? 'student');
                },
              );
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final String userRole = (userData['role'] ?? 'student').toString().trim().toLowerCase();
            _saveRoleLocally(userRole);

            return _getDashboardByRole(userRole);
          },
        );
      },
    );
  }

  // PERSISTENCE HELPERS
  Future<void> _saveRoleLocally(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }

  Future<String?> _getSavedRoleLocally() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  Widget _getDashboardByRole(String role) {
    if (role == 'admin') return const AdminDashboard();
    if (role == 'technician' || role == 'tech') return const TechnicianPortal();
    return const StudentDashboard();
  }
}