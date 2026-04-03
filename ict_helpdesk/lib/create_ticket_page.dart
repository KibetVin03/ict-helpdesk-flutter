import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'dart:io' show File;
import 'auth_utils.dart';

class CreateTicketPage extends StatefulWidget {
  const CreateTicketPage({super.key});

  @override
  State<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends State<CreateTicketPage> {
  // --- STATE MANAGEMENT ---
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final PageController _pageController = PageController();

  String? _category;
  String? _subCategory;
  final List<XFile> _images = [];
  bool _isSubmitting = false;
  int _currentImageIndex = 0;
  String _uploadStatus = "";

  // --- HIERARCHICAL DATA ---
  final Map<String, List<String>> _categories = {
    'Network': ['No Internet', 'WiFi Login Issue', 'Ethernet Port Broken', 'Slow Connection'],
    'Hardware': ['PC Won\'t Start', 'Printer Jam', 'Keyboard/Mouse Fault', 'Monitor Display Issue', 'Projector Failure'],
    'Software': ['ERP Access', 'OS Activation', 'Antivirus Alert', 'Email Synchronization', 'App Crash'],
    'General': ['Furniture Repair', 'Lighting Issue', 'Other'],
  };

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --- LOGIC: FORM UTILITIES ---

  void _resetForm() {
    _locationController.clear();
    _descriptionController.clear();
    setState(() {
      _category = null;
      _subCategory = null;
      _images.clear();
      _currentImageIndex = 0;
      _uploadStatus = "";
    });
    _formKey.currentState?.reset();
  }

  String _calculatePriority(String? category, String? sub) {
    if (category == 'Network') return 'High';
    if (sub == 'PC Won\'t Start' || sub == 'ERP Access') return 'High';
    if (category == 'General') return 'Low';
    return 'Medium';
  }

  // --- LOGIC: IMAGE HANDLING ---

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> pickedFiles = await picker.pickMultiImage(
          imageQuality: 60,
          maxWidth: 1200,
        );
        if (pickedFiles.isNotEmpty) {
          setState(() {
            _images.addAll(pickedFiles); // Just add the XFiles directly
          });
        }
      } else {
        final XFile? pickedFile = await picker.pickImage(
          source: source, 
          imageQuality: 60,
          maxWidth: 1200,
        );
        if (pickedFile != null) {
          setState(() => _images.add(pickedFile)); // Just add the XFile directly
        }
      }
    } catch (e) {
      _showErrorSnackBar("Gallery access denied or error occurred.");
    }
  }

  void _openGallery(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: PhotoViewGallery.builder(
            itemCount: _images.length,
            builder: (context, i) => PhotoViewGalleryPageOptions(
              imageProvider: kIsWeb 
                ? NetworkImage(_images[i].path) 
                : FileImage(File(_images[i].path)) as ImageProvider,
              initialScale: PhotoViewComputedScale.contained,
            ),
            pageController: PageController(initialPage: index),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
        ),
      ),
    );
  }

  // --- LOGIC: FIREBASE & SUPABASE INTEGRATION ---

Future<void> _handleSubmission() async {
  if (!_formKey.currentState!.validate()) return;
  if (_category == null || _subCategory == null) {
    _showErrorSnackBar("Please select a category and sub-category");
    return;
  }

  setState(() {
    _isSubmitting = true;
    _uploadStatus = "Checking for duplicates...";
  });

  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    final location = _locationController.text.trim();

    // 1. Declare variables at the top of the try block
    String officialRole = 'student'; 
    String officialName = 'Anonymous User';

    // 2. Duplicate Check
    final existing = await FirebaseFirestore.instance
        .collection('tickets')
        .where('location', isEqualTo: location)
        .where('sub_category', isEqualTo: _subCategory)
        .where('status', isNotEqualTo: 'solved')
        .get();

    if (existing.docs.isNotEmpty) {
      _showDuplicateAlert();
      setState(() => _isSubmitting = false);
      return;
    }

    // 3. Fetch Official Profile Data
    setState(() => _uploadStatus = "Fetching profile details...");
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
          
      if (userDoc.exists) {
        final data = userDoc.data();
        // Use .trim().toLowerCase() to ensure the Admin Dashboard filters work perfectly
        officialRole = (data?['role'] ?? 'student').toString().trim().toLowerCase();
        officialName = data?['full_name'] ?? (currentUser.displayName ?? "User");
      }
    }

// 4. Technician Assignment Logic
    setState(() => _uploadStatus = "Assigning technician...");
    
    QuerySnapshot techSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'technician')
        .get();

    String assignedTechId = "";
    String assignedTechEmail = ""; 
    String assignedTechName = "";  
    String currentStatus = 'pending';

    if (techSnapshot.docs.isNotEmpty) {
      List<Map<String, dynamic>> workloads = [];
      
      for (var tech in techSnapshot.docs) {
        // Fix: Explicitly cast data to Map to access fields
        final techData = tech.data() as Map<String, dynamic>;
        
        // Count active tickets to balance the workload
        QuerySnapshot tasks = await FirebaseFirestore.instance
            .collection('tickets')
            .where('assigned_to', isEqualTo: tech.id)
            .where('status', isNotEqualTo: 'solved')
            .get();
        
        workloads.add({
          'id': tech.id, 
          'email': techData['email'] ?? "", 
          'name': techData['full_name'] ?? "Technician", 
          'count': tasks.docs.length
        });
      }
      
      // Sort technicians by the number of active tickets (ascending)
      workloads.sort((a, b) => a['count'].compareTo(b['count']));
      
      // Select the technician with the least work
      var bestTech = workloads.first;
      
      assignedTechId = bestTech['id'];
      assignedTechEmail = bestTech['email']; 
      assignedTechName = bestTech['name'];   
      currentStatus = 'assigned';
    }

    // 5. Image Upload
    List<String> imageUrls = [];
    if (_images.isNotEmpty) {
      for (int i = 0; i < _images.length; i++) {
        setState(() => _uploadStatus = "Uploading image ${i + 1}...");
        final fileName = 'tickets/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        
        if (kIsWeb) {
          final bytes = await _images[i].readAsBytes();
          await Supabase.instance.client.storage.from('screenshots').uploadBinary(fileName, bytes);
        } else {
          await Supabase.instance.client.storage.from('screenshots').upload(fileName, File(_images[i].path));
        }
        imageUrls.add(Supabase.instance.client.storage.from('screenshots').getPublicUrl(fileName));
      }
    }

// 6. Firestore Finalize
    setState(() => _uploadStatus = "Finalizing ticket...");

    DocumentReference docRef = await FirebaseFirestore.instance.collection('tickets').add({
      'reporter_id': currentUser?.uid,
      'reporter_name': officialName != "Anonymous User" ? officialName : currentUser?.email,
      'reporter_email': currentUser?.email ?? "No Email",
      'reporter_role': officialRole, 
      'location': location,
      'category': _category,
      'sub_category': _subCategory,
      'description': _descriptionController.text.trim(),
      'image_urls': imageUrls,
      'status': currentStatus,
      'assigned_to': assignedTechId,
      'assigned_to_email': assignedTechEmail, // ADD THIS: For Security/Filters
      'assigned_to_name': assignedTechName,   // ADD THIS: For Admin UI
      'priority': _calculatePriority(_category, _subCategory),
      'created_at': FieldValue.serverTimestamp(),
      'assigned_at': assignedTechId.isNotEmpty ? FieldValue.serverTimestamp() : null, // Good for tracking
      'resolved_at': null,
      'subscribers': [currentUser?.uid],
      'is_read_by_admin': false,
    });

    // --- PROFESSIONAL LOGGING ---
    await AuthUtils.recordLog(
      ticketId: docRef.id,
      action: "TICKET_CREATED",
      details: "New $_category report submitted by $officialName",
    );

    if (mounted) _showSuccessDialog();

  } catch (e) {
    _showErrorSnackBar("Submission failed: $e");
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}
  // --- UI COMPONENTS ---

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent)
    );
  }

  void _showDuplicateAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Report Already Exists"),
        content: const Text("An active ticket for this specific issue at this location is already being processed."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Understand"))],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: const Text("Your ticket has been submitted. Technicians have been notified and will respond shortly.", textAlign: TextAlign.center),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("Return to Dashboard"),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Create New Support Ticket", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(),
                      const SizedBox(height: 25),
                      _buildInputCard(isDark),
                      const SizedBox(height: 25),
                      _buildImageSection(isDark),
                      const SizedBox(height: 40),
                      _buildSubmitButton(),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isSubmitting) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Report a Technical Issue", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
        SizedBox(height: 8),
        Text("Please provide accurate details to help us resolve the issue faster.", style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildInputCard(bool isDark) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Location Field
            TextFormField(
              controller: _locationController,
              decoration: _inputDecoration("Location / Room Number", Icons.location_on, isDark),
              validator: (v) => v!.length < 3 ? "Please enter a valid location" : null,
            ),
            const SizedBox(height: 20),

            // Category Dropdown
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: _inputDecoration("Broad Category", Icons.category, isDark),
              items: _categories.keys.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() { _category = val; _subCategory = null; }),
            ),
            const SizedBox(height: 20),

            // Sub-Category Dropdown
            if (_category != null)
              DropdownButtonFormField<String>(
                initialValue: _subCategory,
                decoration: _inputDecoration("Specific Issue", Icons.subtitles, isDark),
                items: _categories[_category]!.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _subCategory = val),
              ),
            
            const SizedBox(height: 20),

            // Description Field
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: _inputDecoration("Detailed Description", Icons.description, isDark),
              validator: (v) => v!.length < 10 ? "Please explain the issue more clearly" : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Visual Evidence (Photos)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        if (_images.isNotEmpty) _buildImageCarousel(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text("Camera"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text("Gallery"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _images.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _openGallery(index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb 
                          ? Image.network(_images[index].path, fit: BoxFit.cover, width: double.infinity)
                          : Image.file(File(_images[index].path), fit: BoxFit.cover, width: double.infinity),
                      ),
                    ),
                    Positioned(
                      top: 10, right: 10,
                      child: CircleAvatar(
                        backgroundColor: Colors.red,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white, size: 18),
                          onPressed: () => setState(() => _images.removeAt(index)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_images.length, (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.all(3),
            width: _currentImageIndex == index ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(color: _currentImageIndex == index ? Colors.indigo : Colors.grey, borderRadius: BorderRadius.circular(5)),
          )),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _handleSubmission,
        child: const Text("SUBMIT SUPPORT REQUEST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(_uploadStatus, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.indigo),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: isDark ? Colors.black26 : Colors.grey[100],
    );
  }
}