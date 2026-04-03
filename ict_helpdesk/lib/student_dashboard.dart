import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'theme_provider.dart';
import 'auth_utils.dart';
import 'faq_page.dart'; // This is where your FAQPage class now lives

// --- DATA MODEL FOR FAQ ---
class FAQItem {
  final String id;
  final String question;
  final String answer;
  final String category;

  FAQItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
  });

  factory FAQItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return FAQItem(
      id: doc.id,
      question: data['question'] ?? 'New Question',
      answer: data['answer'] ?? 'Answer pending...',
      category: data['category'] ?? 'General',
    );
  }
}

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> with TickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  
  // Interactivity State
  String _activeFilter = 'all'; 
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // --- FILTER LOGIC (Requires Composite Index in Firebase) ---
  void _setFilter(String filter) {
    if (_activeFilter != filter) {
      setState(() => _activeFilter = filter);
      _animationController.reset();
      _animationController.forward();
    }
  }

  Stream<QuerySnapshot> _getTicketStream() {
    // Base collection reference
    CollectionReference ticketsRef = _db.collection('tickets');

    if (_activeFilter == 'pending') {
      // FIX: Add 'status' to orderBy BEFORE 'created_at' because of isNotEqualTo
      return ticketsRef
          .where('reporter_id', isEqualTo: _uid)
          .where('status', isNotEqualTo: 'solved')
          .orderBy('status') 
          .orderBy('created_at', descending: true)
          .snapshots();
    } else if (_activeFilter == 'solved') {
      // Equality filters (isEqualTo) don't have this strict ordering requirement
      return ticketsRef
          .where('reporter_id', isEqualTo: _uid)
          .where('status', isEqualTo: 'solved')
          .orderBy('created_at', descending: true)
          .snapshots();
    }

    // Default view
    return ticketsRef
        .where('reporter_id', isEqualTo: _uid)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  // Add this method to resolve the '_getDynamicName' error
  Future<String> _getDynamicName() async {
    try {
      // Use the _uid already defined in your State class
      if (_uid == null) return "User";
      
      DocumentSnapshot userDoc = await _db.collection('users').doc(_uid).get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        // Looks for 'full_name', falls back to 'username', then to 'User'
        return data['full_name'] ?? data['username'] ?? "User";
      }
    } catch (e) {
      debugPrint("Error fetching name: $e");
    }
    return "User";
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F16) : const Color(0xFFF4F7FA),
      appBar: _buildAppBar(isDark),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200), // Centers and pins the layout
              child: Column(
                children: [
                  // 1. INTERACTIVE HERO PANEL (Statistics)
                  _buildHeroPanel(isDark),

                  // 2. SELF-SERVICE WIDGET (Compact Quick-Action)
                  _buildSelfServiceAction(context, isDark),

                  // 3. MAIN CONTENT AREA (Grouped Tickets)
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _getTicketStream(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) return _buildEmptyDisplay();

                        // Grouping by Date (Temporal Separation)
                        Map<String, List<QueryDocumentSnapshot>> grouped = {};
                        for (var doc in docs) {
                          Timestamp? ts = doc['created_at'] as Timestamp?;
                          String dateKey = ts == null 
                              ? "Unknown Date" 
                              : DateFormat('EEEE, dd/MM/yyyy').format(ts.toDate());
                          grouped.putIfAbsent(dateKey, () => []).add(doc);
                        }

                        return FadeTransition(
                          opacity: _animationController,
                          child: CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              ...grouped.keys.map((date) => SliverMainAxisGroup(
                                slivers: [
                                  _buildDateHeader(date, isDark),
                                  _buildTicketGrid(grouped[date]!, width, isDark),
                                ],
                              )),
                              const SliverToBoxAdapter(child: SizedBox(height: 100)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: _buildFab(),
    );
  }

  // --- APP BAR COMPONENT ---
  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.indigo[900],
      title: const Text("UoK Helpdesk Portal", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
      actions: [
        IconButton(
          icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: Colors.white),
          onPressed: () => themeProvider.toggleTheme(context),
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: () => AuthUtils.showLogoutConfirmation(context),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // --- HERO PANEL (Clickable Analytics) ---
  Widget _buildHeroPanel(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('tickets').where('reporter_id', isEqualTo: _uid).snapshots(),
      builder: (context, snapshot) {
        int total = snapshot.data?.docs.length ?? 0;
        int active = snapshot.data?.docs.where((d) => d['status'] != 'solved').length ?? 0;
        int solved = total - active;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo[900]!, Colors.indigo[800]!, Colors.indigo[700]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(color: Colors.indigo.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Welcome back,", style: TextStyle(color: Colors.white60, fontSize: 12)),
              
              // FutureBuilder handles the asynchronous fetch from Firestore
              FutureBuilder<String>(
                future: _getDynamicName(),
                builder: (context, snapshot) {
                  String name = snapshot.data ?? "...";
                  return Text(
                    "$name's Helpdesk", 
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                  );
                },
              ),
              
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statButton("TOTAL", total.toString(), 'all', Colors.white),
                  _statButton("PENDING", active.toString(), 'pending', Colors.orangeAccent),
                  _statButton("RESOLVED", solved.toString(), 'solved', Colors.greenAccent),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statButton(String label, String value, String filter, Color color) {
    bool selected = _activeFilter == filter;
    return GestureDetector(
      onTap: () => _setFilter(filter),
      child: AnimatedScale(
        scale: selected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Colors.white30 : Colors.transparent),
          ),
          child: Column(
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              if (selected) 
                Container(
                  margin: const EdgeInsets.only(top: 4), 
                  width: 12, height: 3, 
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- QUICK ACTION WIDGET ---
  Widget _buildSelfServiceAction(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FAQPage())),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D26) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            border: Border.all(color: Colors.indigo.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.amber.withOpacity(0.1),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Instant Solutions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text("Browse the FAQ library for common ICT fixes", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // --- GRID & TEMPORAL CARDS ---
  Widget _buildDateHeader(String date, bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Row(
          children: [
            const Icon(Icons.history_toggle_off, size: 16, color: Colors.indigoAccent),
            const SizedBox(width: 8),
            Text(
              date.toUpperCase(), 
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.indigoAccent, letterSpacing: 1.5)
            ),
            const Expanded(child: Divider(indent: 12, color: Colors.white10)),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketGrid(List<QueryDocumentSnapshot> docs, double width, bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: width < 600 ? 2 : (width < 1000 ? 3 : 4),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (c, i) => _buildTicketCard(docs[i].id, docs[i].data() as Map<String, dynamic>, isDark),
          childCount: docs.length,
        ),
      ),
    );
  }

  Widget _buildTicketCard(String id, Map<String, dynamic> data, bool isDark) {
    String status = data['status'] ?? 'pending';
    Color statusColor = status == 'solved' ? Colors.green : Colors.orange;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D26) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, '/ticketDetail', arguments: {'id': id, 'data': data}),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 16),
                  Text(data['category']?.toString().toUpperCase() ?? "GENERAL", style: const TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    data['description'] ?? "No Details", 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.3)
                  ),
                  const Spacer(),
                  const Divider(color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        data['created_at'] != null 
                            ? DateFormat('hh:mm a').format((data['created_at'] as Timestamp).toDate()) 
                            : '--:--', 
                        style: const TextStyle(fontSize: 10, color: Colors.grey)
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.indigoAccent),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- ERROR & EMPTY HANDLERS ---
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text("Syncing Failed", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              "Check the Firebase console for missing Composite Indexes.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDisplay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_clear_outlined, size: 64, color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text("No reports found under '$_activeFilter'", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.pushNamed(context, '/createTicket'),
      backgroundColor: Colors.indigo[800],
      icon: const Icon(Icons.add_task_rounded, color: Colors.white),
      label: const Text("NEW REPORT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}