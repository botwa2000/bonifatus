// lib/screens/parent/parent_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Services/auth_service.dart';
import '../../Services/api_service.dart';
import '../../Services/relationship_service.dart';
import '../../Providers/language_provider.dart';
import '../../models/user_relationship_models.dart';
import 'add_student_screen.dart';
import '../../widgets/student_list_item.dart';
import 'student_edit_dialog.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  _ParentDashboardState createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  final RelationshipService _relationshipService = RelationshipService(ApiService());
  final AuthService _authService = AuthService();
  String? _currentParentId;
  bool _isLoading = false;
  List<ParentStudentRelationship> _students = [];
  late final LanguageProvider _languageProvider;

  @override
  void initState() {
    super.initState();
    _initializeParentId();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _languageProvider = Provider.of<LanguageProvider>(context);
  }

  Future<void> _initializeParentId() async {
    final userId = await _authService.getCurrentUserId();
    setState(() {
      _currentParentId = userId;
    });
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final userId = await AuthService().getCurrentUserId();
      if (userId != null) {
        final result = await _relationshipService.getStudentsByParent(userId);
        if (result['success'] && result['data'] != null) {
          setState(() {
            // Convert the raw data to a format we can display
            _students = (result['data'] as List).map((json) {
              final student = Student(
                id: int.parse(json['student_id'].toString()),
                userId: int.parse(json['student_id'].toString()),
                parentUserId: int.parse(userId),
                firstName: json['first_name'] ?? '',
                lastName: json['last_name'] ?? '',
                email: json['email'],
                loginCode: json['login_code'],
                createdAt: DateTime.parse(json['created_at']),
              );
              return ParentStudentRelationship(
                id: int.parse(json['student_id'].toString()),
                parentId: int.parse(userId),
                studentId: int.parse(json['student_id'].toString()),
                status: RelationshipStatus.active,
                createdAt: DateTime.parse(json['created_at']),
                student: student,
              );
            }).toList();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_languageProvider.translate('error_loading_data'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToStudentDetails(ParentStudentRelationship student) {
    // TODO: Implement navigation to student details screen
    // This is a placeholder - implement your navigation logic here
    print('Navigating to details for student: ${student.student?.firstName}');
  }

  void _showAddStudentDialog() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.email),
            title: Text(languageProvider.translate('add_with_email')),
            onTap: () => _navigateToAddStudent(true),
          ),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: Text(languageProvider.translate('add_without_email')),
            onTap: () => _navigateToAddStudent(false),
          ),
        ],
      ),
    );
  }

  void _navigateToAddStudent(bool withEmail) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddStudentScreen(
          withEmail: withEmail,
          onStudentAdded: () => _loadStudents(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(languageProvider.translate('my_students')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.translate('my_students')),
      ),
      body: _students.isEmpty
          ? Center(
        child: Text(languageProvider.translate('no_students')),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _students.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final studentData = {
            'student_id': _students[index].student?.id,
            'first_name': _students[index].student?.firstName,
            'last_name': _students[index].student?.lastName,
            'email': _students[index].student?.email,
            'login_code': _students[index].student?.loginCode,
            'uses_parent_email': _students[index].student?.email?.contains('@parent.bonifatus.com') == true ? 1 : 0,
          };

          return StudentListItem(
            student: studentData,
            onEdit: () => _showEditDialog(_students[index]),
            onDisconnect: () => _showDisconnectDialog(_students[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudentDialog,
        tooltip: languageProvider.translate('add_student'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditDialog(ParentStudentRelationship student) {
    showDialog(
      context: context,
      builder: (context) => StudentEditDialog(
        student: {
          'student_id': student.student?.id,
          'parent_id': student.parentId,
          'first_name': student.student?.firstName,
          'last_name': student.student?.lastName,
          'email': student.student?.email,
          'login_code': student.student?.loginCode,
          'uses_parent_email': student.student?.email?.contains('@parent.bonifatus.com') == true ? 1 : 0,
        },
        onUpdate: _loadStudents,
      ),
    );
  }

  void _showDisconnectDialog(ParentStudentRelationship student) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.translate('confirm_disconnect')),
        content: Text(languageProvider.translate('cannot_undo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _relationshipService.removeStudent(
                student.parentId.toString(),
                student.studentId.toString(),
              );
              _loadStudents();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(languageProvider.translate('disconnect_student')),
          ),
        ],
      ),
    );
  }
}

// Extracted as a separate widget for reusability
class StudentListTile extends StatelessWidget {
  final ParentStudentRelationship student;
  final VoidCallback onTap;

  const StudentListTile({
    super.key,
    required this.student,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(student.student?.firstName[0] ?? ''),
      ),
      title: Text('${student.student?.firstName} ${student.student?.lastName}'),
      subtitle: Text(student.student?.email ?? ''),
      onTap: onTap,
    );
  }
}