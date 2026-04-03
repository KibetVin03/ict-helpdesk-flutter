import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// --- PRO MODELS & ENUMS ---
enum LogCategory { all, critical, updates, access }

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  LogCategory _selectedCategory = LogCategory.all;

  // --- COMPUTE LOG STYLING ---
  Map<String, dynamic> _getLogTheme(String action) {
    action = action.toUpperCase();
    if (action.contains('DELETE') || action.contains('ERROR') || action.contains('FAILED')) {
      return {
        'color': const Color(0xFFFF5252),
        'icon': Icons.gpp_maybe_rounded,
        'bg': const Color(0xFF2D1616),
        'label': 'CRITICAL'
      };
    }
    if (action.contains('CREATED') || action.contains('SUCCESS') || action.contains('SOLVED')) {
      return {
        'color': const Color(0xFF69F0AE),
        'icon': Icons.check_circle_outline_rounded,
        'bg': const Color(0xFF162D21),
        'label': 'SUCCESS'
      };
    }
    if (action.contains('ASSIGNED') || action.contains('UPDATE')) {
      return {
        'color': const Color(0xFF448AFF),
        'icon': Icons.change_circle_outlined,
        'bg': const Color(0xFF161C2D),
        'label': 'UPDATE'
      };
    }
    return {
      'color': const Color(0xFFE0E0E0),
      'icon': Icons.terminal_rounded,
      'bg': const Color(0xFF212121),
      'label': 'INFO'
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          _buildModernAppBar(),
          _buildFilterBar(),
          _buildLogsStream(),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF0A0A0A),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: const Text(
          "NETWORK_AUDIT_TERMINAL",
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        background: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: Image.network(
                  "https://www.transparenttextures.com/patterns/carbon-fibre.png",
                  repeat: ImageRepeat.repeat,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.indigo.withOpacity(0.2), Colors.transparent],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            // Search Field
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: "SEARCH_LOG_ID_OR_EMAIL...",
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Colors.indigoAccent, size: 18),
                filled: true,
                fillColor: const Color(0xFF161616),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
            const SizedBox(height: 12),
            // Category Chips
            SizedBox(
              height: 35,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: LogCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat.name.toUpperCase()),
                      selected: isSelected,
                      onSelected: (s) => setState(() => _selectedCategory = cat),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                      selectedColor: Colors.indigoAccent,
                      backgroundColor: const Color(0xFF1A1A1A),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('logs')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildSliverMessage(Icons.dns_rounded, "SUBSYSTEM_OFFLINE", snapshot.error.toString());
        if (!snapshot.hasData) return _buildLoadingShimmer();

        var docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final email = (data['performed_by_email'] ?? "").toString().toLowerCase();
          final details = (data['details'] ?? "").toString().toLowerCase();
          return email.contains(_searchQuery) || details.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) return _buildSliverMessage(Icons.manage_search_rounded, "NO_RECORDS_MATCH", "Refine search parameters.");

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildLogCard(docs[index]),
              childCount: docs.length,
            ),
          ),
        );
      }
    );
  }

  Widget _buildLogCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final theme = _getLogTheme(data['action'] ?? "");
    final Timestamp? ts = data['timestamp'] as Timestamp?;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _showLogDetailSheet(context, data, theme);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Status Accent Bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: theme['color'],
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(theme['icon'], size: 14, color: theme['color']),
                              const SizedBox(width: 6),
                              Text(
                                theme['label'],
                                style: TextStyle(color: theme['color'], fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                          Text(
                            ts != null ? DateFormat('HH:mm:ss').format(ts.toDate()) : "??:??",
                            style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        data['details'] ?? "NULL_PTR_EXCEPTION",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.alternate_email_rounded, size: 12, color: Colors.white24),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              data['performed_by_email'] ?? "sys.kernel",
                              style: const TextStyle(color: Colors.white24, fontSize: 11),
                            ),
                          ),
                          Text(
                            "#${data['ticket_id']?.toString().toUpperCase().substring(0, 6) ?? 'VOID'}",
                            style: TextStyle(color: Colors.indigoAccent.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// --- ENHANCED DETAIL MODAL ---
  void _showLogDetailSheet(
      BuildContext context, Map<String, dynamic> data, Map<String, dynamic> theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          border: Border(top: BorderSide(color: Colors.white10, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "LOG_METADATA_EXTRACT",
                  style: TextStyle(
                    color: theme['color'],
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white38),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: data.toString()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Metadata copied to clipboard")),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Functional Data Rows
            _detailRow("ACTION_TYPE", data['action']?.toString() ?? "N/A"),
            _detailRow("PERFORMED_BY", data['performed_by_email']?.toString() ?? "System"),
            _detailRow("TARGET_TID", data['ticket_id']?.toString() ?? "GLOBAL"),
            _detailRow(
              "FULL_TIMESTAMP",
              data['timestamp'] is Timestamp
                  ? DateFormat('yyyy-MM-dd | HH:mm:ss').format((data['timestamp'] as Timestamp).toDate())
                  : "INVALID_DATE",
            ),

            const Divider(color: Colors.white10, height: 40),

            // Transition Console
            const Text(
              "TRANSITION_DETAILS",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),

            // The Code Block / Console View
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: SelectableText(
                data['details'] ?? "> NO_DATA_RECORDED",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),

            const Spacer(),

            // Terminal Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.05),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white10),
                  ),
                ),
                child: const Text(
                  "CLOSE_TERMINAL",
                  style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white24, fontSize: 11, fontFamily: 'monospace')),
          Text(value?.toString() ?? "N/A", style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

Widget _buildLoadingShimmer() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: List.generate(
            5,
            (i) => Container(
              height: 100,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverMessage(IconData icon, String title, String sub) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white10),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            Text(sub, style: const TextStyle(color: Colors.white10, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}