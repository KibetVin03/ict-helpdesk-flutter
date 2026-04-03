import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:carousel_slider/carousel_slider.dart'; 
import 'package:photo_view/photo_view.dart'; 
import 'package:photo_view/photo_view_gallery.dart'; 
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart'; // For storage directories
import 'auth_utils.dart';
import 'package:ict_helpdesk/student_dashboard.dart';
import 'widgets/ticket_detail_view.dart'; 
import 'enrol_staff_page.dart';
import 'package:intl/intl.dart';
import 'widgets/ticket_detail_view.dart'; // Ensure the path matches your project structure
import 'logs_page.dart'; // Or 'widgets/logs_page.dart' depending on your folder structure





class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

// Added TickerProvider for the TabController
class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  String get currentUserEmail => FirebaseAuth.instance.currentUser?.email ?? "";
  bool get isAdmin => currentUserEmail.isNotEmpty;
  String _searchText = "";
  final String _statusFilter = "All"; 
  String _selectedTicketCategory = "System Managers"; // Add this declaration
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController; // Add 'late' keyword
  final String _selectedSubTabCategory = "System Managers"; // Default selected sub-tab
  String? _individualEmailFilter; // For filtering a single person's tickets
  final String _activeSubTab = "System Managers"; // The ONLY source of truth for sub-tabs
  String? _lockedEmail; // Used when you click the yellow icon to "lock" onto one person

  double _getChildAspectRatio(double width) {
  if (width < 600) return 0.65; // This makes the cards taller/smaller for mobile
  return 0.88;
}


  @override
  void initState() {
    super.initState();
    // Changed length to 2 to match your Scaffold's AppBar tabs
    _tabController = TabController(length: 2, vsync: this); 
    
    _tabController.addListener(() {
      // This correctly clears search when moving between "Users" and "Tickets"
      if (!_tabController.indexIsChanging) { 
        setState(() {
          _searchText = "";
          _searchController.clear();
        });
      }
    });
  }
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  

  // Change the parameter from AsyncSnapshot to List<QueryDocumentSnapshot>
  Widget _buildSummaryCards(List<QueryDocumentSnapshot> docs) {
    // Now you don't need snapshot.hasData checks because 'docs' is already a list
    
    int total = docs.length;
    int pending = docs.where((doc) => doc['status'] == 'pending').length;
    int resolved = docs.where((doc) => doc['status'] == 'solved').length;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.5, // Adjust based on your card design
      children: [
        _buildStatCard("Total", total.toString(), Colors.blue),
        _buildStatCard("Pending", pending.toString(), Colors.orange),
        _buildStatCard("Resolved", resolved.toString(), Colors.green),
      ],
    );
  }

Widget _card(String label, String count, Color color) {
  return Card(
    color: const Color(0xFF1E1E1E),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(count, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    ),
  );
}

  void _showExcelPreview(List<QueryDocumentSnapshot> docs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Export Preview"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Reporter')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Issue/Category')),
                  DataColumn(label: Text('Technician')),
                  DataColumn(label: Text('Tech Email')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Elapsed Time')),
                  DataColumn(label: Text('Reported At')),
                  DataColumn(label: Text('Resolved At')),
                ],
                rows: docs.take(1000000).map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DataRow(cells: [
                    DataCell(Text(data['reporter_name'] ?? 'N/A')),
                    DataCell(Text(data['reporter_email'] ?? 'N/A')),
                    DataCell(Text(data['category'] ?? 'N/A')),
                    DataCell(Text(data['assigned_to_name'] ?? 'Unassigned')),
                    DataCell(Text(data['assigned_to_email'] ?? 'N/A')),
                    DataCell(Text(data['status']?.toString().toUpperCase() ?? 'PENDING')),
                    DataCell(Text(_getDetailedElapsedTime(data['created_at'] as Timestamp?))),
                    DataCell(Text(data['created_at'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((data['created_at'] as Timestamp).toDate()) : 'N/A')),
                    DataCell(Text(data['resolved_at'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((data['resolved_at'] as Timestamp).toDate()) : 'N/A')),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exportToExcel(docs); // Passes the sorted list to Excel
            },
            child: const Text("Download Excel"),
          ),
        ],
      ),
    );
  }

  // --- EXCEL EXPORT LOGIC ---
  Future<void> _exportToExcel(List<QueryDocumentSnapshot> docs) async {
        docs.sort((a, b) {
        Timestamp timeA = (a.data() as Map<String, dynamic>)['created_at'] ?? Timestamp.now();
        Timestamp timeB = (b.data() as Map<String, dynamic>)['created_at'] ?? Timestamp.now();
        return timeB.compareTo(timeA); // newest first
      });
    var excel = Excel.createExcel();
    Sheet sheet = excel['Sheet1'];

// Simplified Styles - Bold only
    CellStyle headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    CellStyle summaryTitleStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      underline: Underline.Single, // Check if your version uses 'underline' or 'underlined'
    );

    CellStyle summaryLabelStyle = CellStyle(
      bold: true,
    );

    // --- COUNTERS ---
    int totalPending = 0;
    int totalResolved = 0;
    int totalInProgress = 0;

    // --- HEADERS ---
    List<String> headerNames = [
      'Ticket ID', 'Reporter Name', 'Reporter Email', 'Category/Issue', 
      'Status', 'Elapsed Time', 'Technician Name', 'Technician Email', 
      'Time Reported', 'Time Resolved'
    ];

    sheet.appendRow(headerNames.map((e) => TextCellValue(e)).toList());

    // Apply bold style to headers (Row 0)
    for (int i = 0; i < headerNames.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.cellStyle = headerStyle;
    }

    // --- DATA ROWS ---
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      String status = (data['status'] ?? 'pending').toString().toLowerCase();
      
      // Count logic
      if (status == 'resolved') {
        totalResolved++;
      } else if (status == 'in progress') totalInProgress++;
      else totalPending++;

      sheet.appendRow([
        TextCellValue(doc.id),
        TextCellValue(data['reporter_name'] ?? 'N/A'),
        TextCellValue(data['reporter_email'] ?? 'N/A'),
        TextCellValue(data['category'] ?? 'N/A'),
        TextCellValue(status.toUpperCase()),
        TextCellValue(_getDetailedElapsedTime(data['created_at'] as Timestamp?)),
        TextCellValue(data['assigned_to_name'] ?? 'Unassigned'),
        TextCellValue(data['assigned_to_email'] ?? 'N/A'),
        TextCellValue(data['created_at'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((data['created_at'] as Timestamp).toDate()) : 'N/A'),
        TextCellValue(data['resolved_at'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((data['resolved_at'] as Timestamp).toDate()) : 'N/A'),
      ]);
    }

// 1. Three rows of separation
    sheet.appendRow([]); // Empty Row 1
    sheet.appendRow([]); // Empty Row 2
    sheet.appendRow([]); // Empty Row 3

    // 2. Add Centered Summary Title (Placing it in Column C/Index 2)
    // We add empty strings for Columns A and B to push it to the middle
    sheet.appendRow([TextCellValue(''), TextCellValue(''), TextCellValue('SUMMARY REPORT')]);
    
    // Target the cell we just created to apply the style
    var titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: sheet.maxRows - 1));
    titleCell.cellStyle = summaryTitleStyle;

    // 3. Helper to add Summary Rows with Column A padding
    void addSummaryRow(String label, int value) {
      // Column A is empty, Column B is the Label, Column C is the Value
      sheet.appendRow([TextCellValue(''), TextCellValue(label), IntCellValue(value)]);
      
      // Apply bold style to the label in Column B (Index 1)
      var labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: sheet.maxRows - 1));
      labelCell.cellStyle = summaryLabelStyle;
    }

    addSummaryRow('Total Resolved:', totalResolved);
    addSummaryRow('Total Pending:', totalPending);
    addSummaryRow('Total In Progress:', totalInProgress);
    addSummaryRow('GRAND TOTAL:', docs.length);

    // --- FORMATTING & SAVING ---
    for (int i = 0; i < 10; i++) {
      sheet.setColumnWidth(i, 25.0);
    }

    final bytes = excel.save();
    final directory = await getApplicationDocumentsDirectory();
    
    // Format filename with timestamp
    String timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final String fileName = "Reports_$timestamp.xlsx"; 
    
    final file = File("${directory.path}/$fileName");
    await file.writeAsBytes(bytes!);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.indigoAccent,
          content: Text("Exported: $fileName"),
        ),
      );
    }
  }
      
  // Note: The second (duplicate) _showExcelPreview has been removed to fix the scope error.
  // --- EXISTING LOGIC: TIME & SLA CALCULATIONS ---
  String _getDetailedElapsedTime(Timestamp? createdAt) {
    if (createdAt == null) return "Pending";
    final now = DateTime.now();
    final diff = now.difference(createdAt.toDate());

    if (diff.inDays > 0) {
      int hours = diff.inHours % 24;
      return "${diff.inDays}d ${hours}h elapsed";
    } else if (diff.inHours > 0) {
      int minutes = diff.inMinutes % 60;
      return "${diff.inHours}h ${minutes}m elapsed";
    } else {
      return "${diff.inMinutes}m elapsed";
    }
  }

  Color _getSLAColor(Timestamp? createdAt) {
    if (createdAt == null) return Colors.green;
    final now = DateTime.now();
    final difference = now.difference(createdAt.toDate());
    final hours = difference.inHours;

    if (hours < 8) return Colors.green;        
    if (hours >= 8 && hours < 16) return Colors.amber; 
    return Colors.red;                         
  }

  // --- EXISTING LOGIC: IMAGE VIEWER ---
  void _showFullScreenImage(BuildContext context, List<dynamic> images, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black, 
            foregroundColor: Colors.white,
            elevation: 0,
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

  // --- EXISTING LOGIC: DATABASE UPDATES ---
  Future<void> _markAsSolved(String ticketId) async {
    try {
await FirebaseFirestore.instance.collection('tickets').doc(ticketId).update({
      'status': 'solved',
      'resolved_at': FieldValue.serverTimestamp(),
    });

    // --- PROFESSIONAL LOGGING ---
    await AuthUtils.recordLog(
      ticketId: ticketId, // CHANGED 'id' TO 'ticketId' TO MATCH YOUR FUNCTION PARAMETER
      action: "TICKET_SOLVED",
      details: "Ticket marked as resolved by ${FirebaseAuth.instance.currentUser?.email}",
    );
    
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ticket marked as solved")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

Future<void> _autoAssignTicket(BuildContext context, String ticketId) async {
    try {
      var techQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'technician')
          .get();

      if (techQuery.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No technicians found in system.")),
          );
        }
        return;
      }

      List<Map<String, dynamic>> techStats = [];
      for (var techDoc in techQuery.docs) {
        final data = techDoc.data();
        var activeTickets = await FirebaseFirestore.instance
            .collection('tickets')
            .where('assigned_to', isEqualTo: techDoc.id)
            .where('status', isNotEqualTo: 'solved')
            .get();
        
        techStats.add({
          'id': techDoc.id,
          'full_name': data['full_name'] ?? "Unknown",
          'email': data['email'] ?? "", // Capture email for RBAC visibility
          'count': activeTickets.docs.length,
        });
      }

      techStats.sort((a, b) => a['count'].compareTo(b['count']));
      
      String bestTechId = techStats.first['id'];
      String bestTechName = techStats.first['full_name'];
      String bestTechEmail = techStats.first['email'];

      // Updated to include email and name fields required by RBACService and UI
      await FirebaseFirestore.instance.collection('tickets').doc(ticketId).update({
        'assigned_to': bestTechId,
        'assigned_to_email': bestTechEmail, 
        'assigned_to_name': bestTechName,
        'status': 'assigned',
        'assigned_at': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Assigned to $bestTechName (${techStats.first['count']} active tickets)")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Auto-assign error: $e")));
      }
    }
  }

@override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;

    // RESPONSIVE COLUMN LOGIC
    int getGridColumnCount(double width) {
      if (width < 600) return 2;
      if (width < 1000) return 3;
      if (width < 1400) return 4;
      return 5;
    }

    // ASPECT RATIO LOGIC
    double getChildAspectRatio(double width) {
      if (width < 600) return 0.65;
      return 0.85; 
    }
 
        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            title: const Text("UoK Admin Panel"),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            leading: const Icon(Icons.admin_panel_settings),
            actions: [
              // 1. ADDED: SYSTEM AUDIT LOGS BUTTON
              IconButton(
                icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                tooltip: "System Audit Logs",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LogsPage()),
                  );
                },
              ),

              IconButton(
                icon: const Icon(Icons.engineering),
                tooltip: "Switch to Technician",
                onPressed: () => Navigator.pushReplacementNamed(context, '/techDashboard'),
              ),
              // --- FIXED: EXCEL DOWNLOAD WITH DATE PICKER & TECH DETAILS ---
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tickets').snapshots(),
                builder: (context, snapshot) {
                  return IconButton(
                    icon: const Icon(Icons.file_download),
                    tooltip: "Export to Excel",
                    onPressed: () async {
                      if (!snapshot.hasData) return;

                      final DateTime now = DateTime.now();

                      final DateTimeRange? pickedRange = await showDateRangePicker(
                        context: context,
                        initialDateRange: null, 
                        firstDate: DateTime(2026),
                        lastDate: now,
                        helpText: 'Select Export Period',
                        builder: (context, child) => Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
                            child: Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: Colors.indigoAccent,
                                  onPrimary: Colors.white,
                                  surface: const Color(0xFF1E1E1E),
                                  onSurface: Colors.white,
                                  secondary: Colors.indigoAccent.withOpacity(0.3),
                                ), dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF121212)),
                              ),
                              child: child!,
                            ),
                          ),
                        ),
                      );

                      if (pickedRange != null) {
                        // Fetch from Firestore using the selected range
                        final querySnapshot = await FirebaseFirestore.instance
                            .collection('tickets')
                            .where('created_at', isGreaterThanOrEqualTo: pickedRange.start)
                            .where('created_at', isLessThanOrEqualTo: pickedRange.end)
                            .get();

                        List<QueryDocumentSnapshot> fetchedDocs = querySnapshot.docs;

                        // SORT: Latest on top (Descending)
                        fetchedDocs.sort((a, b) {
                          Timestamp timeA = (a.data() as Map<String, dynamic>)['created_at'] ?? Timestamp.now();
                          Timestamp timeB = (b.data() as Map<String, dynamic>)['created_at'] ?? Timestamp.now();
                          return timeB.compareTo(timeA); 
                        });

                        if (fetchedDocs.isNotEmpty) {
                          _showExcelPreview(fetchedDocs);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("No tickets found for this period.")),
                          );
                        }
                      }

                      if (pickedRange != null) {
                        final docsToExport = snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final Timestamp? createdAt = data['created_at'] as Timestamp?;

                          if (createdAt == null) return false;
                          final date = createdAt.toDate();

                          // Filter by selected Date Range
                          bool inRange = date.isAfter(pickedRange.start) &&
                              date.isBefore(pickedRange.end.add(const Duration(days: 1)));

                          // Maintain current UI filters (Search & Status)
                          final name = (data['reporter_name'] ?? '').toString().toLowerCase();
                          final email = (data['reporter_email'] ?? '').toString().toLowerCase();
                          final status = (data['status'] ?? '').toString().toLowerCase();

                          bool matchesSearch = _searchText.isEmpty ||
                              name.contains(_searchText.toLowerCase()) ||
                              email.contains(_searchText.toLowerCase());

                          bool matchesStatus = _statusFilter == "All" ||
                              status == _statusFilter.toLowerCase();

                          return inRange && matchesSearch && matchesStatus;
                        }).toList();

                        if (docsToExport.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("No tickets found for the selected period."),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        } else {
                          _showExcelPreview(docsToExport);
                        }
                      }
                    },
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.person_outline),
                tooltip: 'Switch to Student',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StudentDashboard()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => AuthUtils.showLogoutConfirmation(context),
              ),
            ],
            bottom: TabBar(
              controller: _tabController, // Add this line
              indicatorColor: Colors.white,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(icon: Icon(Icons.people), text: "Users"),
                Tab(icon: Icon(Icons.assignment), text: "Tickets"),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // This column puts the Search Bar above the User List
              Column(
                children: [
                  _buildSearchBar(), 
                  Expanded(child: _buildUserList()),
                ],
              ),
              // This column puts the Search Bar above the Ticket Grid
              Column(
                children: [
                  _buildSearchBar(),
                  Expanded(child: _buildTicketGrid(context)),
                ],
              ),
            ],
          ),
          floatingActionButton: AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              return _tabController.index == 0 
                ? FloatingActionButton.extended(
                    onPressed: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const EnrolStaffPage())
                    ),
                    backgroundColor: Colors.indigoAccent,
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    label: const Text("Enrol Staff", style: TextStyle(color: Colors.white)),
                  )
                : const SizedBox.shrink();
            },
          ),
        );
   
  }

  // --- USER MANAGEMENT SECTION ---
  Widget _buildUserList() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF1E1E1E),
            child: const TabBar(
              indicatorColor: Colors.indigoAccent,
              labelColor: Colors.indigoAccent,
              unselectedLabelColor: Colors.grey,
              isScrollable: true,
              tabs: [
                Tab(text: "System Managers"),
                Tab(text: "Supportive Staff"),
                Tab(text: "Students"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFilteredUserList(['admin', 'technician', 'tech']), 
                _buildFilteredUserList(['staff']),
                _buildFilteredUserList(['student']),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildFilteredUserList(List<String> roles) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: roles)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        // Dynamic Search Scope: Users only
          var filteredUsers = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String name = (data['full_name'] ?? "").toString().toLowerCase();
          String email = (data['email'] ?? "").toString().toLowerCase();
          
          // Ensure the search text is also lowercased for comparison
          String searchLower = _searchText.toLowerCase();

          return searchLower.isEmpty || 
                name.contains(searchLower) || 
                email.contains(searchLower);
        }).toList();

        if (filteredUsers.isEmpty) return const Center(child: Text("No users found", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            var user = filteredUsers[index].data() as Map<String, dynamic>;
            String userId = filteredUsers[index].id;
            String role = (user['role'] ?? 'student').toString().toLowerCase();

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: role == 'admin' ? Colors.red : Colors.indigo,
                child: Icon(role == 'student' ? Icons.school : Icons.engineering, color: Colors.white, size: 20),
              ),
              title: Text(user['full_name'] ?? "No Name", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text("Role: $role\n${user['email']}", style: const TextStyle(color: Colors.white70)),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.manage_search, color: Colors.amberAccent),
                    tooltip: "Track Individual Reports",
                    onPressed: () {
                      final String targetEmail = (user['email'] ?? "").toString().toLowerCase();
                      final String userRole = (user['role'] ?? "").toString().toLowerCase().trim();

                      // Logic to determine which nested tab index needs to open
                      String targetCategory = "System Managers";
                      if (userRole == 'student') {
                        targetCategory = "Students";
                      } else if (userRole == 'staff') {
                        targetCategory = "Supportive Staff";
                      }

                      setState(() {
                        _searchText = targetEmail;
                        _searchController.text = targetEmail;
                        _individualEmailFilter = targetEmail; // Lock results to this specific user
                        _selectedTicketCategory = targetCategory; // Prepare the sub-tab index
                      });

                      // Main navigation: Switch from "Users" to "Tickets"
                      _tabController.animateTo(1); 
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note, color: Colors.indigoAccent),
                    onPressed: () => _showUserActions(userId),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showUserActions(String id) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Wrap(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("User Management", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings, color: Colors.white),
            title: const Text("Change User Role To Technician", style: TextStyle(color: Colors.white)),
            onTap: () {
              FirebaseFirestore.instance.collection('users').doc(id).update({'role': 'technician'});
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, color: Colors.white),
            title: const Text('Change User Role To Staff', style: TextStyle(color: Colors.white)),
            onTap: () {
              FirebaseFirestore.instance.collection('users').doc(id).update({'role': 'staff'}); 
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.school, color: Colors.white),
            title: const Text("Change User Role To Student", style: TextStyle(color: Colors.white)),
            onTap: () {
              FirebaseFirestore.instance.collection('users').doc(id).update({'role': 'student'});
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Delete User Record", style: TextStyle(color: Colors.red)),
            onTap: () {
              FirebaseFirestore.instance.collection('users').doc(id).delete();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

// --- TICKET GRID SECTION ---
  Widget _buildTicketGrid(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF1E1E1E),

          ),
Expanded(
  child: StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('tickets')
        .orderBy('created_at', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

      final allDocs = snapshot.data!.docs;

      // Logic to calculate the correct index for initialIndex
      int subTabIndex = 0; // Managers
      if (_selectedTicketCategory == "Supportive Staff") subTabIndex = 1;
      if (_selectedTicketCategory == "Students") subTabIndex = 2;

      // --- CENTRALIZED FILTERING ENGINE ---
      final filteredDocs = allDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final email = (data['reporter_email'] ?? '').toString().toLowerCase();
        
        // 1. Check Individual Email Lock (from Yellow Button)
        if (_individualEmailFilter != null) {
          return email == _individualEmailFilter;
        }

        // 2. Check General Search Box
        if (_searchText.isNotEmpty) {
          final name = (data['reporter_name'] ?? '').toString().toLowerCase();
          return name.contains(_searchText) || email.contains(_searchText);
        }
        
        return true; // Show all if no filters active
      }).toList();

      return DefaultTabController(
        // Forces the TabController to refresh to the new subTabIndex
        key: ValueKey(_selectedTicketCategory + (_individualEmailFilter ?? "")), 
        length: 3,
        initialIndex: subTabIndex,
        child: Column(
          children: [
            TabBar(
              onTap: (index) {
                setState(() {
                  // Keep state in sync when user clicks tabs manually
                  _individualEmailFilter = null; // Unlock individual view on manual click
                  if (index == 0) _selectedTicketCategory = "System Managers";
                  if (index == 1) _selectedTicketCategory = "Supportive Staff";
                  if (index == 2) _selectedTicketCategory = "Students";
                });
              },
              tabs: const [
                Tab(text: "Managers"),
                Tab(text: "Staff"),
                Tab(text: "Students"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 0: Managers
                  _buildTabGrid(filteredDocs.where((doc) {
                    final role = (doc['reporter_role'] ?? '').toString().toLowerCase();
                    return role == 'admin' || role == 'technician' || role == 'tech';
                  }).toList()),
                  
                  // Tab 1: Staff
                  _buildTabGrid(filteredDocs.where((doc) {
                    final role = (doc['reporter_role'] ?? '').toString().toLowerCase();
                    return role != 'admin' && role != 'technician' && role != 'tech' && role != 'student';
                  }).toList()),
                  
                  // Tab 2: Students
                  _buildTabGrid(filteredDocs.where((doc) {
                    final role = (doc['reporter_role'] ?? '').toString().toLowerCase();
                    return role == 'student';
                  }).toList()),
                ],
              ),
            ),
          ],
        ),
      );
    },
  ),
)
        ],
      ),
    );
  }

  // FIXED: Only ONE declaration of _buildTabGrid
  Widget _buildTabGrid(List<QueryDocumentSnapshot> docs) {
    final double screenWidth = MediaQuery.of(context).size.width;

    // 1. Grouping Logic
    Map<String, List<QueryDocumentSnapshot>> groupedTasks = {};
    for (var doc in docs) {
      Timestamp? createdAt = doc['created_at'] as Timestamp?;
      String dateLabel = createdAt == null 
          ? "Unknown Date" 
          : DateFormat('EEEE, dd/MM/yyyy').format(createdAt.toDate());
      groupedTasks.putIfAbsent(dateLabel, () => []).add(doc);
    }

// 2. Sliver Layout
    return CustomScrollView(
      slivers: [
        // A. TOP SUMMARY SECTION
        // This converts your box-based cards into a sliver that scrolls with the list
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _buildSummaryCards(docs), // Using the docs passed into _buildTabGrid
          ),
        ),

        // B. DATE-GROUPED TICKET GRIDS
        // We use the spread operator (...) to expand the list of slivers into the parent list
        ...groupedTasks.keys.map((dateKey) {
          return SliverMainAxisGroup(
            slivers: [
              // Date Header for each group
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text(
                    dateKey.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              
              // The Grid of tickets for this specific date
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    // Responsive column logic
                    crossAxisCount: (screenWidth < 600) ? 2 : (screenWidth < 1000 ? 3 : 4),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: (screenWidth < 600) ? 0.65 : 0.88,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      var doc = groupedTasks[dateKey]![index];
                      var ticket = doc.data() as Map<String, dynamic>;
                      String ticketId = doc.id;

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TicketDetailView(
                                ticket: ticket,
                                ticketId: ticketId,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: _buildTicketCard(id: ticketId, ticket: ticket),
                      );
                    },
                    childCount: groupedTasks[dateKey]!.length,
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Text(
        message,
        style: const TextStyle(color: Colors.white24, fontStyle: FontStyle.italic, fontSize: 14),
      ),
    );
  }

Widget _buildTicketCard({required String id, required Map<String, dynamic> ticket}) {
    String status = (ticket['status'] ?? 'pending').toString().toLowerCase();
    Timestamp? createdAt = ticket['created_at'];
    Color slaColor = (status == 'solved') ? Colors.green : _getSLAColor(createdAt);
    List<dynamic> imageUrls = ticket['image_urls'] ?? [];
    
    // CAPTURE TECHNICIAN DATA
    String techName = ticket['assigned_to_name'] ?? "Unassigned";
    String techEmail = ticket['assigned_to_email'] ?? "";

    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: slaColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: slaColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    ticket['location'] ?? "Unknown", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    overflow: TextOverflow.ellipsis
                  ),
                ),
                _buildStatusBadge(status, slaColor),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Wrap(
                    spacing: 8, runSpacing: 4, alignment: WrapAlignment.center,
                    children: [
                      _buildChip(ticket['category'], Colors.indigo),
                      if (ticket['hardware'] != null && ticket['hardware'] != "N/A" && ticket['hardware'] != "")
                        _buildChip(ticket['hardware'], Colors.blueGrey),
                      if (ticket['software'] != null && ticket['software'] != "N/A" && ticket['software'] != "")
                        _buildChip(ticket['software'], Colors.teal),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text("DESCRIPTION", style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1.2)),
                  const SizedBox(height: 5),
                  Text(
                    ticket['description'] ?? "No details provided.",
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // TECHNICIAN INFO SECTION
                Row(
                  children: [
                    Icon(Icons.engineering, size: 14, color: techName == "Unassigned" ? Colors.amber : Colors.indigoAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        techName == "Unassigned" ? "Waiting for Technician..." : "Tech: $techName",
                        style: TextStyle(
                          fontSize: 11, 
                          color: techName == "Unassigned" ? Colors.amber : Colors.indigoAccent,
                          fontWeight: FontWeight.bold
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("By: ${ticket['reporter_name'] ?? 'User'}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(_getDetailedElapsedTime(createdAt), style: TextStyle(fontSize: 11, color: slaColor, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (status != 'solved')
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
                        onPressed: () => _markAsSolved(id),
                      ),
                    _buildAssignmentMenu(id),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, color: Colors.white38, size: 20),
                      onPressed: () {
                         Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TicketDetailView(ticket: ticket, ticketId: id),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(dynamic label, Color color) {
    if (label == null || label == "") return const SizedBox.shrink();
    return Chip(
      label: Text(label.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),
      backgroundColor: color.withOpacity(0.2),
      side: BorderSide(color: color.withOpacity(0.5)),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

void _showManualAssignDialog(String tId) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text("Select Technician", style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'technician')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            var techs = snapshot.data!.docs;
            return ListView.separated(
              shrinkWrap: true,
              itemCount: techs.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.white10),
              itemBuilder: (context, index) {
                // Safely extract technician data
                final techData = techs[index].data() as Map<String, dynamic>;
                final String techName = techData['full_name'] ?? "Technician";
                final String techEmail = techData['email'] ?? "No Email";

                return ListTile(
                  title: Text(techName, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(techEmail, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  onTap: () {
                    // Update ticket with both ID and Email
                    FirebaseFirestore.instance.collection('tickets').doc(tId).update({
                      'assigned_to': techs[index].id,         // Internal UID
                      'assigned_to_email': techEmail,         // Required for RBAC/Filtering
                      'assigned_to_name': techName,           // For UI Display
                      'status': 'assigned',
                      'assigned_at': FieldValue.serverTimestamp(),
                    });
                    Navigator.pop(context);
                  },
                );
              },
            );
          },
        ),
      ),
    ),
  );
}
  
Widget _buildFilteredTicketList(Stream<QuerySnapshot> stream) {
  return StreamBuilder<QuerySnapshot>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      final docs = snapshot.data?.docs ?? [];
      if (docs.isEmpty) {
        return const Center(
          child: Text(
            "No tickets in this category",
            style: TextStyle(color: Colors.white54),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final ticketId = docs[index].id;
          final ticket = docs[index].data() as Map<String, dynamic>;

          // 1. DATA MAPPING
          final status = (ticket['status'] ?? 'pending').toString().toLowerCase();
          final rawCreated = ticket['created_at'] ?? ticket['date'] ?? ticket['reported_on'];
          final createdAt = (rawCreated as Timestamp?)?.toDate();
          final startedAt = (ticket['started_at'] as Timestamp?)?.toDate();
          final resolvedAt = (ticket['resolved_at'] as Timestamp?)?.toDate();

          // 2. PRIVACY LOGIC
          // Note: Ensure currentUserEmail and isAdmin are defined in your State class
          final bool isAssignedTech = ticket['assigned_to_email'] == currentUserEmail;
          final bool canSeeTechDetails = isAdmin || isAssignedTech;

          // 3. SLA URGENCY
          Color slaColor = Colors.green;
          String timeElapsed = "Just now";
          if (createdAt != null) {
            final diff = DateTime.now().difference(createdAt);
            if (diff.inHours >= 24) {
              slaColor = Colors.red;
            } else if (diff.inHours >= 8) slaColor = Colors.amber;
            timeElapsed = diff.inDays > 0 ? "${diff.inDays}d ago" : "${diff.inHours}h ago";
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: const Color(0xFF1E1E1E),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(width: 6, color: status == 'solved' ? Colors.blueGrey : slaColor),
                  Expanded(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ticket['category'] ?? ticket['location'] ?? 'General Issue',
                              style: const TextStyle(
                                color: Colors.white, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 16
                              ),
                            ),
                          ),
                          _buildProStatusBadge(status),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          
                          // REPORTER INFO (Includes Email as requested)
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 12, color: Colors.white38),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "${ticket['reporter_name'] ?? 'User'} (${ticket['reporter_email'] ?? 'No Email'})",
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 6),
                          Text(
                            ticket['description'] ?? ticket['issue_description'] ?? 'No description',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),

                          const Divider(color: Colors.white10, height: 20),

                          // TECHNICIAN INFO (Privacy Protected Section)
                          if (canSeeTechDetails) 
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ticket['assigned_to_name'] != null 
                                    ? Colors.indigoAccent.withOpacity(0.1) 
                                    : Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: ticket['assigned_to_name'] != null 
                                      ? Colors.indigoAccent.withOpacity(0.2) 
                                      : Colors.transparent
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.engineering, size: 14, color: Colors.indigoAccent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      ticket['assigned_to_name'] != null
                                          ? "${ticket['assigned_to_name']} (${ticket['assigned_to_email']})"
                                          : "Unassigned",
                                      style: const TextStyle(
                                        color: Colors.indigoAccent, 
                                        fontSize: 11, 
                                        fontWeight: FontWeight.bold
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            const Text(
                              "Technician info restricted to Admin/Assigned",
                              style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic),
                            ),

                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              _buildProMetaInfo(Icons.timer_outlined, "Logged: $timeElapsed", Colors.white30),
                              if (startedAt != null)
                                _buildProMetaInfo(Icons.play_circle_fill, "Started: ${DateFormat('h:mm a').format(startedAt)}", Colors.amber),
                              if (resolvedAt != null)
                                _buildProMetaInfo(Icons.check_circle, "Solved: ${DateFormat('h:mm a').format(resolvedAt)}", Colors.green),
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white12, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TicketDetailView(ticket: ticket, ticketId: ticketId),
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
      );
    },
  );
}

  // --- UNIQUE PRO HELPERS ---
  Widget _buildProStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'solved':
      case 'resolved':
        color = Colors.green;
        break;
      case 'in_progress':
        color = Colors.blue;
        break;
      case 'assigned':
        color = Colors.indigoAccent;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4), width: 0.5),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildProMetaInfo(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
  // --- SEARCH BAR WIDGET ---
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search name, email, or role...",
          prefixIcon: const Icon(Icons.search, color: Colors.indigoAccent),
          // FIXED: The 'X' button only appears when there is text
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  onPressed: () {
                    setState(() {
                      _searchText = "";
                      _searchController.clear();
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchText = value.toLowerCase();
          });
        },
      ),
    );
  }
// Inside class _AdminDashboardState ...

  Widget _buildAssignmentMenu(String ticketId) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.person_add_alt_1, color: Colors.indigoAccent),
      tooltip: "Assign Technician",
      onSelected: (val) {
        if (val == 'auto') {
          _autoAssignTicket(context, ticketId);
        } else {
          _showManualAssignDialog(ticketId);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'auto', 
          child: ListTile(
            leading: Icon(Icons.auto_awesome, color: Colors.amber),
            title: Text("Smart Auto-Assign"),
          ),
        ),
        const PopupMenuItem(
          value: 'manual', 
          child: ListTile(
            leading: Icon(Icons.handyman, color: Colors.indigoAccent),
            title: Text("Manual Assign"),
          ),
        ),
      ],
    );
  } // Ensure _showManualAssignDialog and _autoAssignTicket are also here...
  Widget _buildStatCard(String label, String value, Color color) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.5)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
} 
} // This is the final closing brace of _AdminDashboardState