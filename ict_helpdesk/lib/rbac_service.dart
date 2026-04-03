import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RBACService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Method to get user role
  static Future<String> getUserRole() async {
    User? user = _auth.currentUser;
    if (user == null) return 'student';

    DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return doc.get('role') ?? 'student';
    }
    return 'student';
  }

  // Method for the global filtered stream
  static Stream<QuerySnapshot> getFilteredTicketsStream(String role) {
    User? user = _auth.currentUser;
    CollectionReference ref = _db.collection('tickets');

    if (role == 'admin') {
      return ref.snapshots();
    } else if (role == 'technician') {
      return ref.where('assigned_to_email', isEqualTo: user?.email).snapshots();
    } else {
      return ref.where('student_email', isEqualTo: user?.email).snapshots();
    }
  }
}