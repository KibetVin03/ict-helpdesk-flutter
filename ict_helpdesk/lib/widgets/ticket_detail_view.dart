import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth_utils.dart'; 

class TicketDetailView extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final String ticketId;

  const TicketDetailView({super.key, required this.ticket, required this.ticketId});

  // --- DATABASE LOGIC: ROLE-BASED IDENTITY CAPTURE ---
  Future<void> _handleStatusUpdate(BuildContext context, String newStatus) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch verified user data from Firestore 'users' collection
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      final String actorName = userData?['full_name'] ?? user.email?.split('@')[0] ?? "Staff";
      final String actorRole = (userData?['role'] ?? "staff").toString().toUpperCase(); 
      final String actorEmail = user.email ?? "Unknown Email";

      Map<String, dynamic> updates = {
        'status': newStatus,
        'last_action_by_name': actorName,
        'last_action_by_email': actorEmail,
        'last_action_role': actorRole,
      };

      // Lifecycle-specific data injection
      if (newStatus == 'in_progress') {
        updates['started_at'] = FieldValue.serverTimestamp();
        updates['started_by_name'] = actorName;
        updates['started_by_email'] = actorEmail;
        updates['started_by_role'] = actorRole;
        // Auto-assign the technician who starts the work
        updates['assigned_to_name'] = actorName;
        updates['assigned_to_email'] = actorEmail;
        updates['assigned_to_role'] = actorRole;
      } else if (newStatus == 'solved') {
        updates['resolved_at'] = FieldValue.serverTimestamp();
        updates['resolved_by_name'] = actorName;
        updates['resolved_by_email'] = actorEmail;
        updates['resolved_by_role'] = actorRole;
      }

      await FirebaseFirestore.instance.collection('tickets').doc(ticketId).update(updates);
      // --- TRIGGER AUDIT LOG ---
      await AuthUtils.recordLog(
        ticketId: ticketId,
        action: newStatus == 'solved' ? "COMMIT_RESOLVE" : "EXECUTE_WORK",
        details: "Status transition to ${newStatus.toUpperCase()} by $actorName",
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("System State: ${newStatus.replaceAll('_', ' ').toUpperCase()}")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fault Detected: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (ticket['status'] ?? 'pending').toString().toLowerCase();
    
    final createdAt = (ticket['created_at'] ?? ticket['date']) as Timestamp?;
    final startedAt = ticket['started_at'] as Timestamp?;
    final resolvedAt = ticket['resolved_at'] as Timestamp?;

    final String techName = ticket['assigned_to_name'] ?? "";
    final String techEmail = ticket['assigned_to_email'] ?? "";
    final String techRole = (ticket['assigned_to_role'] ?? "").toString().toUpperCase();

    final dynamic rawImages = ticket['images'] ?? ticket['image_url'];
    final List<String> imageUrls = rawImages is List 
        ? List<String>.from(rawImages) 
        : (rawImages != null ? [rawImages.toString()] : []);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text("Ticket Details", style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildStatusHeader(status),
                const SizedBox(height: 30),

                // --- DATA INTERFACE CARD ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      _detailRow(Icons.person, "REPORTER_ID", ticket['reporter_name'] ?? "User"),
                      _detailRow(Icons.email, "REPORTER_EMAIL", ticket['reporter_email'] ?? "N/A"),
                      _detailRow(Icons.location_on, "GEOSPATIAL_LOC", ticket['location'] ?? "N/A"),
                      
                      const Divider(color: Colors.white10, height: 30),

                      _buildLabel("DESCRIPTION_STRING"),
                      const SizedBox(height: 12),
                      Text(
                        ticket['description'] ?? ticket['issue_description'] ?? "NULL",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                      ),

                      const Divider(color: Colors.white10, height: 30),

                      _buildInfoRow(
                        label: "ASSIGNED TECHNICIAN",
                        // Improved logic: check email, then name, then fallback
                        value: ticket['assigned_to_email'] ?? ticket['assigned_to_name'] ?? "Pending Auto-Assignment",
                        icon: Icons.engineering_outlined,
                        // Alert if neither email nor name exists
                        valueColor: (ticket['assigned_to_email'] == null && ticket['assigned_to_name'] == null) 
                            ? Colors.orange 
                            : Colors.indigoAccent,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // --- IMAGE BINARY BUFFER ---
                if (imageUrls.isNotEmpty) ...[
                  _buildLabel("EVIDENCE_FILES"),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            imageUrls[index], 
                            width: 320, 
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              width: 200, 
                              color: Colors.white10, 
                              child: const Icon(Icons.broken_image, color: Colors.white24)
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                ],

                // --- SYSTEM LOGS ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      _buildLabel("ACTIVITY_LOG_STREAM"),
                      const SizedBox(height: 20),
                      _timelineItem(
                        Icons.fiber_new, 
                        "Log Created", 
                        createdAt != null ? DateFormat('MMM d, HH:mm').format(createdAt.toDate()) : "00:00",
                        "System initialization complete"
                      ),
                      if (startedAt != null)
                        _timelineItem(
                          Icons.play_circle_fill, 
                          "Process Started", 
                          DateFormat('HH:mm').format(startedAt.toDate()),
                          "${ticket['started_by_name']} [${(ticket['started_by_role'] ?? 'TECH').toString().toUpperCase()}]"
                        ),
                      if (resolvedAt != null)
                        _timelineItem(
                          Icons.check_circle, 
                          "Resolved", 
                          DateFormat('HH:mm').format(resolvedAt.toDate()),
                          "${ticket['resolved_by_name']} [${(ticket['resolved_by_role'] ?? 'TECH').toString().toUpperCase()}]"
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                if (status != 'solved' && status != 'resolved') 
                  _buildActionButtons(context, status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- COMPONENT HELPERS ---

  Widget _buildStatusHeader(String status) {
    Color color = (status == 'solved' || status == 'resolved') ? Colors.green : (status == 'in_progress' ? Colors.blue : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineItem(IconData icon, String title, String time, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.indigoAccent, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(time, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.5, fontFamily: 'monospace'));
  }

  Widget _buildActionButtons(BuildContext context, String status) {
    return Row(
      children: [
        if (status == 'pending' || status == 'assigned')
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _handleStatusUpdate(context, 'in_progress'),
              icon: const Icon(Icons.terminal),
              label: const Text("EXECUTE_WORK"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _handleStatusUpdate(context, 'solved'),
            icon: const Icon(Icons.verified),
            label: const Text("COMMIT_RESOLVE"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
      ],
    );
  }
  // --- UI HELPER METHODS ---

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.indigoAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white38,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: valueColor ?? Colors.white,
                    fontWeight: FontWeight.w500,
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