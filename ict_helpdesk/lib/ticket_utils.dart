import 'package:cloud_firestore/cloud_firestore.dart';

class TicketUtils {
  static Future<void> autoAssign(String ticketId) async {
    final db = FirebaseFirestore.instance;

    // 1. Find all technicians
    var techQuery = await db.collection('users')
        .where('role', isEqualTo: 'technician')
        .get();

    if (techQuery.docs.isEmpty) return;

    List<Map<String, dynamic>> techStats = [];

    // 2. Count active tickets for each technician
    for (var techDoc in techQuery.docs) {
      var activeTickets = await db.collection('tickets')
          .where('assigned_to', isEqualTo: techDoc.id)
          .where('status', isNotEqualTo: 'solved')
          .get();

      techStats.add({
        'id': techDoc.id,
        'full_name': techDoc.data()['full_name'] ?? "Unknown",
        'email': techDoc.data()['email'] ?? "",
        'count': activeTickets.docs.length,
      });
    }

    // 3. Sort by workload (Least busy first)
    techStats.sort((a, b) => a['count'].compareTo(b['count']));
    var bestTech = techStats.first;

    // 4. Update the ticket immediately
    await db.collection('tickets').doc(ticketId).update({
      'assigned_to': bestTech['id'],
      'assigned_to_email': bestTech['email'],
      'assigned_to_name': bestTech['full_name'],
      'status': 'assigned',
      'assigned_at': FieldValue.serverTimestamp(),
    });
  }
}