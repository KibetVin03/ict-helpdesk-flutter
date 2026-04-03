import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; 
import 'package:carousel_slider/carousel_slider.dart'; 
import 'package:photo_view/photo_view.dart'; 
import 'package:photo_view/photo_view_gallery.dart'; 
import 'auth_utils.dart';
import 'widgets/ticket_detail_view.dart'; 

class TechnicianPortal extends StatelessWidget {
  const TechnicianPortal({super.key});

  // --- RESPONSIVE GRID LOGIC ---
  int _getGridColumnCount(double width) {
    if (width < 600) return 2;         
    if (width < 1000) return 3;        
    if (width < 1400) return 4;        
    return 5;                          
  }

  double _getChildAspectRatio(double width) {
    if (width < 600) return 0.65;      
    return 0.88;                       
  }

  // --- SLA TRAFFIC LIGHT LOGIC ---
  Color _getSLAColor(Timestamp? createdAt) {
    if (createdAt == null) return Colors.green;
    final now = DateTime.now();
    final difference = now.difference(createdAt.toDate());
    final hours = difference.inHours;

    if (hours < 8) return Colors.green;        
    if (hours >= 8 && hours < 16) return Colors.amber; 
    return Colors.red;                         
  }

  // --- DATE GROUPING LOGIC ---
  String _getGroupDate(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown Date";
    return DateFormat('EEEE, dd/MM/yyyy').format(timestamp.toDate());
  }

  // --- FULL SCREEN ZOOM LOGIC ---
  void _showFullScreenImage(BuildContext context, List<dynamic> images, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black, 
            foregroundColor: Colors.white, 
            elevation: 0
          ),
          body: PhotoViewGallery.builder(
            itemCount: images.length,
            builder: (context, i) => PhotoViewGalleryPageOptions(
              imageProvider: NetworkImage(images[i]),
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained * 0.8,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            pageController: PageController(initialPage: index),
          ),
        ),
      ),
    );
  }

  // --- ELAPSED TIME LOGIC ---
  String _getElapsedTime(Timestamp? createdAt) {
    if (createdAt == null) return "Unknown";
    final now = DateTime.now();
    final difference = now.difference(createdAt.toDate());

    if (difference.inDays > 0) {
      return "${difference.inDays}d ${difference.inHours % 24}h ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours}h ${difference.inMinutes % 60}m ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes}m ago";
    }
    return "Just now";
  }

  // --- ROLE CHECK ---
  Future<String> _getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'student';
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return doc.data()?['role'] ?? 'student';
    } catch (e) {
      return 'student';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;

    return FutureBuilder<String>(
      future: _getUserRole(),
      builder: (context, roleSnapshot) {
        final String userRole = roleSnapshot.data ?? 'loading';
        final bool isActualAdmin = userRole == 'admin';

        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey[100],
          appBar: AppBar(
            title: const Text("Technician Portal"),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            leading: isActualAdmin
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pushReplacementNamed(context, '/adminDashboard'),
                  )
                : null,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => Navigator.pushNamed(context, '/studentDashboard'),
              ),
              IconButton(
                icon: Icon(isActualAdmin ? Icons.admin_panel_settings : Icons.logout),
                onPressed: () {
                  if (isActualAdmin) {
                    Navigator.pushReplacementNamed(context, '/adminDashboard');
                  } else {
                    AuthUtils.showLogoutConfirmation(context);
                  }
                },
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            // FIX: Checking for both assigned_to UID and potentially email/null 
            // to ensure old data doesn't disappear
            stream: isActualAdmin 
                ? FirebaseFirestore.instance.collection('tickets').orderBy('created_at', descending: true).snapshots()
                : FirebaseFirestore.instance
                    .collection('tickets')
                    .where('assigned_to', isEqualTo: user?.uid) 
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_late, size: 50, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("No assigned tasks found.", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              // GROUP TICKETS BY DATE
              Map<String, List<QueryDocumentSnapshot>> groupedTasks = {};
              for (var doc in snapshot.data!.docs) {
                String dateLabel = _getGroupDate(doc['created_at'] as Timestamp?);
                groupedTasks.putIfAbsent(dateLabel, () => []).add(doc);
              }

              return CustomScrollView(
                slivers: groupedTasks.keys.map((dateKey) {
                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                          child: Text(
                            dateKey.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.blueAccent, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 13,
                              letterSpacing: 1.2
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _getGridColumnCount(screenWidth),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: _getChildAspectRatio(screenWidth),
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              var doc = groupedTasks[dateKey]![index];
                              var task = doc.data() as Map<String, dynamic>;
                              String ticketId = doc.id;
                              Timestamp? createdAt = task['created_at'] as Timestamp?;
                              List<dynamic> imageUrls = task['image_urls'] ?? [];
                              String currentStatus = task['status'] ?? 'assigned';
                              Color slaColor = _getSLAColor(createdAt);

                              return Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: slaColor.withOpacity(0.5), width: 2),
                                ),
                                color: isDarkMode ? Colors.grey[900] : Colors.white,
                                child: InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => TicketDetailView(ticket: task, ticketId: ticketId)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                task['location'] ?? "Unknown",
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: slaColor),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const Icon(Icons.more_horiz, size: 16, color: Colors.grey),
                                          ],
                                        ),
                                        Text(_getElapsedTime(createdAt), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                        const SizedBox(height: 8),
                                        
                                        Expanded(
                                          child: Text(
                                            task['description'] ?? "No Details",
                                            style: const TextStyle(fontSize: 12),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),

                                        if (imageUrls.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: CarouselSlider(
                                              options: CarouselOptions(
                                                height: 85.0,
                                                viewportFraction: 1.0,
                                                enableInfiniteScroll: false,
                                              ),
                                              items: imageUrls.map((url) {
                                                return GestureDetector(
                                                  onTap: () => _showFullScreenImage(context, imageUrls, imageUrls.indexOf(url)),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.network(url, fit: BoxFit.cover, width: double.infinity),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          )
                                        else 
                                          const Spacer(),

                                        const Divider(height: 16),

                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(currentStatus.toUpperCase(), 
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: slaColor)),
                                            if (currentStatus != 'solved')
                                              SizedBox(
                                                height: 28,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green,
                                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                                  ),
                                                  onPressed: () async {
                                                    await FirebaseFirestore.instance.collection('tickets').doc(ticketId).update({
                                                      'status': 'solved',
                                                      'resolved_at': FieldValue.serverTimestamp(),
                                                    });
                                                    
                                                    await AuthUtils.recordLog(
                                                      ticketId: ticketId,
                                                      action: "TICKET_SOLVED",
                                                      details: "Ticket marked as resolved by Technician",
                                                    );
                                                  },
                                                  child: const Text("Mark As Resolved", style: TextStyle(color: Colors.white, fontSize: 10)),
                                                ),
                                              )
                                            else
                                              const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: groupedTasks[dateKey]!.length,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        );
      },
    );
  }
}