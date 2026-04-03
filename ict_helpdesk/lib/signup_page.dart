import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme_provider.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _hasEightChars = false;
  bool _hasCapital = false;
  bool _hasSmall = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;
  bool _isPasswordVisible = false;

  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(() {
      setState(() {});
    });
  }

  bool get _isPasswordValid => 
    _hasEightChars && _hasCapital && _hasSmall && _hasNumber && _hasSymbol;

  void _onPasswordChanged(String value) {
    setState(() {
      _hasEightChars = value.length >= 8;
      _hasCapital = value.contains(RegExp(r'[A-Z]'));
      _hasSmall = value.contains(RegExp(r'[a-z]'));
      _hasNumber = value.contains(RegExp(r'[0-9]'));
      _hasSymbol = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  // --- STRICT DYNAMIC EMAIL VALIDATION (Feature Fixed) ---
  String? _validateSchoolEmail(String? value) {
    if (value == null || value.isEmpty) return "School email is required";
    
    // RegEx: Exactly 12 alphanumeric chars + @students.kabianga.ac.ke
    final emailRegex = RegExp(r'^[a-zA-Z0-9]{12}@students\.kabianga\.ac\.ke$');
    
    if (!emailRegex.hasMatch(value.trim())) {
      return "Invalid Format. Must be 12 characters prefix\ne.g., comm00192022@students.kabianga.ac.ke";
    }
    return null;
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Save Student Data (Staff handled manually by Admin)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'uid': userCredential.user!.uid,
        'full_name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'student', 
        'is_approved': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        // Navigation Fix: Ensure user moves to dashboard immediately
        Navigator.pushReplacementNamed(context, '/studentDashboard');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created successfully! Welcome.")),
        );
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage = e.message ?? "An error occurred";
      if (e.code == 'email-already-in-use') {
        errorMessage = "This school email is already registered.";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Register Account"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // FULL FEATURE: Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/uok_logo.png', 
              fit: BoxFit.cover,
            ),
          ),
          // FULL FEATURE: Dark Overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.school, size: 80, color: Colors.indigoAccent),
                      const SizedBox(height: 10),
                      const Text(
                        "UoK STUDENT PORTAL",
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 30),
                      
                      // Full Name Field
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration("Full Name", Icons.person),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 15),
                      
                      // Email Field with Strict Validation
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration("School Email", Icons.school),
                        validator: _validateSchoolEmail,
                      ),
                      const SizedBox(height: 15),
                      
                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: !_isPasswordVisible,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration("Password", Icons.lock).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white70,
                            ),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                        ),
                        onChanged: _onPasswordChanged, 
                        validator: (value) => _isPasswordValid ? null : "Requirements not met",
                      ),
                      
                      // FULL FEATURE: Password Requirement Checklist
                      if (_passwordFocusNode.hasFocus && !_isPasswordValid) ...[
                        const SizedBox(height: 12),
                        _buildCheckItem("At least 8 characters", _hasEightChars),
                        _buildCheckItem("Uppercase (A-Z)", _hasCapital),
                        _buildCheckItem("Lowercase (a-z)", _hasSmall),
                        _buildCheckItem("A number (0-9)", _hasNumber),
                        _buildCheckItem("Special symbol (!@#\$)", _hasSymbol),
                      ],

                      const SizedBox(height: 30),

                      // Sign Up Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: (_isPasswordValid && !_isLoading) ? _handleSignup : null, 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("CREATE ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account?", style: TextStyle(color: Colors.white70)),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Login",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigoAccent),
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

  // UI Helpers (Ensuring visual consistency)
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      border: const OutlineInputBorder(),
      prefixIcon: Icon(icon, color: Colors.white70),
      fillColor: Colors.white12,
      filled: true,
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.indigoAccent)),
    );
  }

  Widget _buildCheckItem(String label, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isMet ? Colors.green : Colors.white24,
            size: 16,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: isMet ? Colors.green : Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }
}