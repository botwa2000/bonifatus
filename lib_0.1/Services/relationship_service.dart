// lib/services/relationship_service.dart

import 'api_service.dart';
import 'dart:math';

class RelationshipService {
  final ApiService _apiService;

  RelationshipService(this._apiService);

  // Parent functions
  Future<Map<String, dynamic>> inviteStudent({
    required String parentId,
    String? studentEmail,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final response = await _apiService.makeRequest('add_student', {
        'parent_id': parentId,
        'student_email': studentEmail,
        'first_name': firstName,
        'last_name': lastName,
        'invitation_type': 'email'  // Add this to differentiate
      });

      if (response['success']) {
        return {
          'success': true,
          'student': response['data'],
        };
      }
      return {
        'success': false,
        'message': response['message'] ?? 'Failed to add student',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error adding student: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updateStudent(String studentId, Map<String, dynamic> data) async {
    try {
      Map<String, dynamic> sanitizedData = {
        'student_id': int.tryParse(studentId) ?? 0,
        'parent_id': data['parent_id'],
        'first_name': data['first_name']?.toString().trim(),
        'last_name': data['last_name']?.toString().trim(),
        'uses_parent_email': data['uses_parent_email'] == true || data['uses_parent_email'] == 1 ? 1 : 0,
      };

      // Only add login_code if it's being changed
      if (data['login_code'] != null && data['login_code'].toString().isNotEmpty) {
        sanitizedData['login_code'] = data['login_code'].toString();
        sanitizedData['email'] = "student_${data['parent_id']}_${data['login_code']}@parent.bonifatus.com";
      }

      final response = await _apiService.makeRequest('update_student', sanitizedData);
      print('Update response: $response'); // Debug
      return response;
    } catch (e) {
      print('Error in updateStudent: $e');
      return {
        'success': false,
        'message': 'Failed to update student: $e'
      };
    }
  }

  Future<Map<String, dynamic>> getStudentsByParent(String parentId) async {
    try {
      return await _apiService.makeRequest('get_parent_students', {
        'parent_id': parentId,
      });
    } catch (e) {
      print('Error getting students: $e');
      return {
        'success': false,
        'message': 'Error getting students: $e',
        'data': []
      };
    }
  }

  Future<Map<String, dynamic>> updateStudentLoginMethod(
      String studentId,
      bool useParentEmail,
      {String? email, String? code}
      ) async {
    try {
      final data = {
        'student_id': studentId,
        'uses_parent_email': useParentEmail,
        if (useParentEmail) 'login_code': code,
        if (!useParentEmail) 'email': email,
      };

      return await _apiService.makeRequest('update_student_login', data);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update login method: $e',
      };
    }
  }

  Future<Map<String, dynamic>> addChildWithCode({
    required String parentId,
    required String firstName,
    required String lastName,
    required String code,
  }) async {
    try {
      return await _apiService.makeRequest('add_student', {
        'parent_id': parentId,
        'first_name': firstName,
        'last_name': lastName,
        'login_code': code,
        'uses_parent_email': true
      });
    } catch (e) {
      return {
        'success': false,
        'message': 'Error adding child: $e',
      };
    }
  }

  Future<Map<String, dynamic>> addChildWithEmail({
    required String parentId,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    try {
      return await _apiService.makeRequest('add_student', {
        'parent_id': parentId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'uses_parent_email': false
      });
    } catch (e) {
      return {
        'success': false,
        'message': 'Error adding child: $e',
      };
    }
  }

  String generateRandomCode() {
    return Random().nextInt(900000).toString().padLeft(6, '0');
  }

  Future<Map<String, dynamic>> removeStudent(String parentId, String studentId) async {
    try {
      return await _apiService.makeRequest('remove_student', {
        'parent_id': parentId,
        'student_id': studentId,
      });
    } catch (e) {
      return {
        'success': false,
        'message': 'Error removing student: $e',
      };
    }
  }

  // Student functions
  Future<Map<String, dynamic>> acceptInvitation(String invitationCode) async {
    try {
      return await _apiService.makeRequest('accept_invitation', {
        'invitation_code': invitationCode,
      });
    } catch (e) {
      return {
        'success': false,
        'message': 'Error accepting invitation: $e',
      };
    }
  }

  Future<Map<String, dynamic>> rejectInvitation(String invitationCode) async {
    try {
      return await _apiService.makeRequest('reject_invitation', {
        'invitation_code': invitationCode,
      });
    } catch (e) {
      return {
        'success': false,
        'message': 'Error rejecting invitation: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getParent(String studentId) async {
    try {
      final response = await _apiService.makeRequest(
        'get_parent_info',
        {'student_id': studentId},
      );

      return {
        'success': response['success'] ?? false,
        'data': response['data'],
        'message': response['message']
      };
    } catch (e) {
      print('Error in getParent: $e');
      return {
        'success': false,
        'message': 'Error fetching parent information: $e'
      };
    }
  }

  Future<Map<String, dynamic>> createLocalStudent({
    required String parentId,
    required String firstName,
    required String lastName,
    String? customCode,
  }) async {
    try {
      final code = customCode ?? generateRandomCode();
      return await _apiService.makeRequest('add_student', {
        'parent_id': parentId,  // Send as string, let server convert
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'login_code': code,
      });
    } catch (e) {
      print('Error in createLocalStudent: $e');
      rethrow;
    }
  }

}