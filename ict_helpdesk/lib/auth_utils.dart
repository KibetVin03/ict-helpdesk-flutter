import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthUtils {
  static void showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents closing by tapping outside
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  // Removes all previous screens so the user can't go 'Back'
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Logout failed: $e")),
                );
              }
            },
            child: const Text("Yes", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
    static Future<void> recordLog({
    required String ticketId,
    required String action, // e.g., "TICKET_CREATED", "TECH_ASSIGNED", "SOLVED"
    required String details,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final FirebaseFirestore db = FirebaseFirestore.instance;

    await db.collection('logs').add({
      'ticket_id': ticketId,
      'action': action,
      'details': details,
      'performed_by_email': user?.email ?? "System",
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}