import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PasswordResetHandler extends StatefulWidget {
  const PasswordResetHandler({super.key});

  @override
  State<PasswordResetHandler> createState() => _PasswordResetHandlerState();
}

class _PasswordResetHandlerState extends State<PasswordResetHandler> {
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  // Strict Validation Flags
  bool _hasEight = false;
  bool _hasCap = false;
  bool _hasSmall = false;
  bool _hasNum = false;
  bool _hasSym = false;

  // Extracts the secure oobCode from the browser URL
  String get _oobCode => Uri.base.queryParameters['oobCode'] ?? '';

  void _validate(String v) {
    setState(() {
      _hasEight = v.length >= 8;
      _hasCap = v.contains(RegExp(r'[A-Z]'));
      _hasSmall = v.contains(RegExp(r'[a-z]'));
      _hasNum = v.contains(RegExp(r'[0-9]'));
      _hasSym = v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _isValid => _hasEight && _hasCap && _hasSmall && _hasNum && _hasSym && 
                       _passController.text == _confirmController.text;

  Future<void> _handleSave() async {
    if (_oobCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid or expired link.")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: _oobCode,
        newPassword: _passController.text.trim(),
      );
      
      if (mounted) {
        // SUCCESS STATE: Show message ONLY. Removed the Button and Navigation logic.
        showDialog(
          context: context,
          barrierDismissible: false, 
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 60),
                SizedBox(height: 10),
                Text("Success", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              "Your password has been updated successfully!\n\n"
              "Please close this window and return to the login screen manually to sign in with your new credentials.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            // Actions property removed entirely to hide the button.
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString().contains('expired-action-code') ? 'Link expired or already used.' : e.toString()}"))
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], 
      body: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_reset, size: 50, color: Colors.indigo),
                const SizedBox(height: 10),
                const Text("Secure Password Reset", 
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
                const SizedBox(height: 20),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  onChanged: _validate,
                  decoration: const InputDecoration(
                    labelText: "New Password", 
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _confirmController,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: "Confirm Password", 
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_clock_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                
                _reqRow("8+ Characters", _hasEight),
                _reqRow("Uppercase & Lowercase", _hasCap && _hasSmall),
                _reqRow("Number & Special Symbol", _hasNum && _hasSym),
                _reqRow("Passwords Match", _passController.text == _confirmController.text && _passController.text.isNotEmpty),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isValid && !_isLoading ? _handleSave : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text("UPDATE PASSWORD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reqRow(String t, bool m) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.0),
    child: Row(children: [
      Icon(m ? Icons.check_circle : Icons.cancel, color: m ? Colors.green : Colors.grey, size: 18),
      const SizedBox(width: 8),
      Text(t, style: TextStyle(color: m ? Colors.green : Colors.black54, fontSize: 13)),
    ]),
  );
}