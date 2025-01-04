// lib/screens/parent/student_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/relationship_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../Providers/language_provider.dart';
import '../parent/add_student_screen.dart';
import 'student_edit_dialog.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  _StudentListScreenState createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final RelationshipService _relationshipService = RelationshipService(ApiService());
  bool _isLoading = false;
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final userId = await AuthService().getCurrentUserId();
      if (userId != null) {
        final result = await _relationshipService.getStudentsByParent(userId);
        if (result['success']) {
          setState(() => _students = List<Map<String, dynamic>>.from(result['data']));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _disconnectStudent(String studentId) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.translate('disconnect_student')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(languageProvider.translate('confirm_disconnect')),
            const SizedBox(height: 8),
            Text(
              languageProvider.translate('cannot_undo'),
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageProvider.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(languageProvider.translate('disconnect')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final userId = await AuthService().getCurrentUserId();
        if (userId != null) {
          final result = await _relationshipService.removeStudent(userId, studentId);
          if (mounted) {
            if (result['success']) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(languageProvider.translate('student_disconnected'))),
              );
              _loadStudents();
            }
          }
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _editStudent(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => StudentEditDialog(
        student: student,
        onUpdate: _loadStudents,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F0FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          languageProvider.translate('my_students'),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
          ),
        ),
      ),
      body: _students.isEmpty
          ? Center(
        child: Text(languageProvider.translate('no_students')),
      )
          : ListView.builder(
        itemCount: _students.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final student = _students[index];
          final usesParentEmail = student['uses_parent_email'] == true;
          final firstLetter = (student['first_name'] ?? '')[0].toUpperCase();

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFEEE5FF),
                child: Text(
                  firstLetter,
                  style: const TextStyle(
                    color: Color(0xFF7657C7),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text(
                    '${student['first_name']} ${student['last_name']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    usesParentEmail ? '[Parent]' : '[Own]',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7657C7),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student['email'] ?? ''),
                  if (usesParentEmail)
                    Text('Code: ${student['login_code']}'),
                ],
              ),
              trailing: SizedBox(
                width: 100,  // Fixed width for actions
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () => _editStudent(student),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Edit'),
                      ),
                    ),
                    InkWell(
                      onTap: () => _disconnectStudent(student['student_id'].toString()),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Del'),
                      ),
                    ),
                  ],
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddStudentScreen(withEmail: false)),
          );
        },
        backgroundColor: const Color(0xFFEEE5FF),
        child: const Icon(
          Icons.add,
          color: Color(0xFF7657C7),
        ),
      ),
    );
  }
}