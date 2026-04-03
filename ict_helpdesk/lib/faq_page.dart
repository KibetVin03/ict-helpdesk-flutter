import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rbac_service.dart';
import 'auth_utils.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  String _searchQuery = "";
  String _userRole = 'student';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  // 3. Fetch the role using your existing RBACService
  Future<void> _loadRole() async {
    String role = await RBACService.getUserRole();
    setState(() {
      _userRole = role;
    });
  }

  // 4. Create the Add Dialog Function
  void _showAddFaqDialog() {
    final TextEditingController qController = TextEditingController();
    final TextEditingController aController = TextEditingController();
    String selectedCat = 'General';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create FAQ Entry"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qController, decoration: const InputDecoration(labelText: "Question")),
            TextField(controller: aController, decoration: const InputDecoration(labelText: "Answer"), maxLines: 3),
            DropdownButton<String>(
              value: selectedCat,
              items: ['General', 'Network', 'Hardware', 'Software'].map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (newValue) => setState(() => selectedCat = newValue!),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('faqs').add({
                'question': qController.text,
                'answer': aController.text,
                'category': selectedCat,
                'created_at': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ICT Helpdesk - FAQ"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search for a problem...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
        ),
      ),

      floatingActionButton: _userRole == 'admin' 
        ? FloatingActionButton(
            onPressed: _showAddFaqDialog,
            backgroundColor: Colors.indigoAccent,
            child: const Icon(Icons.add_comment),
          )
        : null,
        
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('faqs').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs.where((doc) {
            final question = doc['question'].toString().toLowerCase();
            return question.contains(_searchQuery);
          }).toList();

          if (docs.isEmpty && _searchQuery.isNotEmpty) {
            // Silent Intelligence: Record the 'Miss' so Admin can see it in Analytics
            AuthUtils.recordLog(
              ticketId: "FAQ_ANALYTICS",
              action: "SEARCH_MISS",
              details: "Query: '$_searchQuery' returned 0 results.",
            );
            return const Center(child: Text("No results. The ICT team has been notified."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final faq = docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ExpansionTile(
                  leading: const Icon(Icons.help_outline, color: Colors.blueAccent),
                  title: Text(
                    faq['question'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        faq['answer'],
                        style: const TextStyle(height: 1.5),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}