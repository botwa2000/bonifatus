// lib/screens/student/student_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Services/auth_service.dart';
import '../../Services/api_service.dart';
import '../../Providers/language_provider.dart';
import '../../models/user_relationship_models.dart';
import '../../Services/relationship_service.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  _StudentProfileScreenState createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  Map<String, dynamic> _academicProfile = {};
  User? _parentInfo;

  @override
  void initState() {
    super.initState();
    _loadStudentProfile();
  }

  Future<void> _loadStudentProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId != null) {
        // Load student's academic profile
        final response = await _apiService.makeRequest(
          'get_student_academic_profile',
          {'student_id': userId},
        );

        if (response['success']) {
          setState(() => _academicProfile = response['data'] ?? {});
        }

        // Load parent information if connected
        final relationshipService = RelationshipService(_apiService);
        final parentResponse = await relationshipService.getParent(userId);

        if (parentResponse['success']) {
          setState(() => _parentInfo = parentResponse['parent']);
        }
      }
    } catch (e) {
      // Error handling
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.translate('academic_profile')),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStudentProfile,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Academic Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                children: [
                  ListTile(
                    title: Text(languageProvider.translate('grade_level')),
                    subtitle: Text(_academicProfile['grade_level']?.toString() ?? '-'),
                  ),
                  ListTile(
                    title: Text(languageProvider.translate('school_year')),
                    subtitle: Text(_academicProfile['school_year']?.toString() ?? '-'),
                  ),
                  if (_academicProfile['school_name'] != null)
                    ListTile(
                      title: Text(languageProvider.translate('school')),
                      subtitle: Text(_academicProfile['school_name']),
                    ),
                ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Parent Connection Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.translate('parent_connection'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (_parentInfo != null) ...[
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(
                          '${_parentInfo!.firstName} ${_parentInfo!.lastName}',
                        ),
                        subtitle: Text(_parentInfo!.email),
                      ),
                    ] else
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text(
                          languageProvider.translate('no_parent_connected'),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Recent Performance Card (if you want to show recent grades/tests)
            if (_academicProfile['recent_tests'] != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.translate('recent_performance'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      // Add recent test results here
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}