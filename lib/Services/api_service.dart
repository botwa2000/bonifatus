import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grading_models.dart';
import '../models/subject.dart';

class ApiService {
  static const bool DEBUG = true;
  static const String baseUrl = 'https://www.bonifatus.com/api.php';
  static const String USER_ID_KEY = 'user_id';
  static const String TOKEN_KEY = 'auth_token';
  Map<String, dynamic>? _cachedBonusFactors;

  static const String MAINTENANCE_MESSAGE = 'Service temporarily unavailable. Please try again later.';
  static const String CONNECTION_ERROR = 'Unable to connect to server. Please check your internet connection.';
  static const String SERVER_ERROR = 'Server is currently under maintenance. Please try again later.';

  void _debugPrint(String message) {
    if (DEBUG) {
      if (message.contains('Retrieved')) {
        // Only log counts for data retrieval
        print('ApiService Debug: $message');
      } else if (!message.contains('data:')) {
        // Skip logging raw data dumps
        print('ApiService Debug: $message');
      }
    }
  }

  void logDataSummary(dynamic data) {
    try {
      if (data is List) {
        print('Data summary: ${data.length} records');
        return;
      }

      if (data is Map && data['data'] != null) {
        final summaries = <String>[];
        if (data['data'] is Map) {
          final dataMap = data['data'] as Map<String, dynamic>;
          dataMap.forEach((key, value) {
            if (value is List) {
              summaries.add('$key: ${value.length} records');
            }
          });
        } else if (data['data'] is List) {
          summaries.add('${(data['data'] as List).length} records');
        }
        if (summaries.isNotEmpty) {
          print('Data summary: ${summaries.join(', ')}');
        }
      }
    } catch (e) {
      print('Error in logDataSummary: $e');
    }
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(TOKEN_KEY);
  }

  Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(USER_ID_KEY);
  }

  Future<Map<String, dynamic>> getTermResults(String studentId) async {
    return makeRequest('get_term_results', {'student_id': studentId});
  }

  Future<Map<String, dynamic>> saveTermResults(Map<String, dynamic> data) async {
    try {
      print('Sending request with data: ${json.encode(data)}');

      final response = await makeRequest('save_term_results', data);
      print('Raw response: ${response.toString()}');

      return response;
    } catch (e) {
      print('Error in saveTermResults: $e');
      return {
        'success': false,
        'message': 'Failed to save results: $e',
      };
    }
  }

  bool _isValidJson(String str) {
    try {
      json.decode(str);
      return true;
    } catch (e) {
      return false;
    }
  }

  String _cleanJsonString(String jsonStr) {
    try {
      if (jsonStr.trim().startsWith('{') && jsonStr.trim().endsWith('}')) {
        // Already valid JSON
        return jsonStr.trim();
      }
      // Remove PHP debug output that appears before JSON
      int firstBraceIndex = jsonStr.indexOf('{');
      int lastBraceIndex = jsonStr.lastIndexOf('}');

      if (firstBraceIndex == -1 || lastBraceIndex == -1) {
        return '{"success":false,"message":"Invalid response format"}';
      }

      String cleaned = jsonStr.substring(firstBraceIndex, lastBraceIndex + 1);
      // Validate JSON before returning
      json.decode(cleaned); // This will throw if invalid
      return cleaned;
    } catch (e) {
      print('Error cleaning JSON string: $e');
      return '{"success":false,"message":"Failed to clean JSON"}';
    }
  }

  String? _formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == '\\1') {
      return null;
    }
    try {
      final date = DateTime.parse(dateStr);
      return date.toIso8601String();
    } catch (e) {
      print('Error parsing date: $dateStr');
      return null;
    }
  }

  Map<String, dynamic> _cleanDateFields(Map<String, dynamic> item) {
    var cleaned = Map<String, dynamic>.from(item);
    var dateFields = ['updated_at', 'created_at'];

    for (var field in dateFields) {
      if (cleaned[field] != null) {
        var value = cleaned[field];
        if (value is String) {
          if (value.isEmpty || value == '\\1' || value == '\$1' || value == '"\$1"' || value == 'null') {
            cleaned[field] = null;
          } else {
            try {
              DateTime.parse(value);  // Validate date format
              cleaned[field] = value;
            } catch (e) {
              cleaned[field] = null;
            }
          }
        }
      }
    }
    return cleaned;
  }

  Future<Map<String, dynamic>> makeRequest(String action, Map<String, dynamic> data) async {
    try {
      final token = await getAuthToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final requestBody = {
        'action': action,
        ...data,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Empty response from server',
        };
      }

      try {
        // First try to decode as regular JSON object
        final decoded = json.decode(response.body);

        // If we got an array, wrap it in a map
        if (decoded is List) {
          return {
            'success': true,
            'data': decoded,
          };
        }

        // Otherwise return as is
        return decoded is Map<String, dynamic>
            ? decoded
            : {'success': true, 'data': decoded};

      } catch (e) {
        return {
          'success': false,
          'message': 'Invalid JSON response: $e',
        };
      }

    } catch (e) {
      print('API Error: $e');
      return {
        'success': false,
        'message': 'Request failed: $e'
      };
    }
  }

  // Authentication methods
  Future<Map<String, dynamic>> register(
      String email,
      String password,
      String userType, {
        String? firstName,
        String? lastName,
      }) async {
    try {
      final response = await makeRequest('register', {
        'email': email,
        'password': password,
        'user_type': userType,
        'first_name': firstName,
        'last_name': lastName,
      });

      if (response['success'] == true) {
        return {
          'success': true,
          'message': response['message'],
          'action': response['action'] ?? 'verify',
          'data': response['data'] ?? {},
          'user_id': response['user_id'],
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Registration failed',
          'action': response['action'] ?? 'retry',
          'data': response['data'] ?? {},
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Registration failed: $e',
        'action': 'retry',
        'data': {},
      };
    }
  }

  Future<Map<String, dynamic>> verifyRegistration(String email, String code) async {
    _debugPrint('Sending verification request for email: $email with code: $code');
    try {
      final response = await makeRequest('verify', {
        'email': email,
        'code': code,
      });

      _debugPrint('Verification response: $response');
      return response;
    } catch (e) {
      _debugPrint('Verification error: $e');
      return {
        'success': false,
        'message': 'Verification failed: $e',
        'action': 'retry'
      };
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await makeRequest('login', {
        'email': email,
        'password': password,
      });

      _debugPrint('Login response: $response');

      if (response['success'] == true) {
        // Extract user data from correct location in response
        final userData = response['data'] ?? {};
        return {
          'success': true,
          'message': response['message'] ?? 'Login successful',
          'user_id': userData['user_id']?.toString() ?? '',
          'token': userData['token']?.toString() ?? '',
          'data': userData
        };
      }

      return {
        'success': false,
        'message': response['message'] ?? 'Invalid credentials',
        'data': null
      };
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'message': 'Login failed: $e',
        'data': null
      };
    }
  }

  Future<Map<String, dynamic>> loginWithCode(String email, String code) async {
    try {
      print('Code login attempt - Email: $email, Code: $code');

      final response = await makeRequest('login_with_code', {
        'email': email.trim(),
        'code': code.trim(),
      });

      print('Login response: $response');

      // Check both success flag and data presence
      if (response['success'] == true &&
          response['data'] != null &&
          response['data']['token'] != null &&
          response['data']['student_id'] != null) {

        return {
          'success': true,
          'message': response['message'] ?? 'Login successful',
          'token': response['data']['token'],
          'user_id': response['data']['student_id'].toString(),
        };
      }

      return {
        'success': false,
        'message': response['message'] ?? 'Invalid email or code',
      };
    } catch (e) {
      print('Login with code error: $e');
      return {
        'success': false,
        'message': 'Login failed: $e'
      };
    }
  }

  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    _debugPrint('Fetching user profile for ID: $userId');
    final response = await makeRequest('get_user_profile', {
      'user_id': userId,
    });
    _debugPrint('Profile response: $response');
    return response;
  }

  Future<Map<String, dynamic>> getStudentParent(String studentId) async {
    try {
      return await makeRequest('get_parent_info', {
        'student_id': studentId,
      });
    } catch (e) {
      print('Error getting student parent: $e');
      return {
        'success': false,
        'message': 'Failed to get parent information: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updateUserProfile(String userId, {
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    Map<String, dynamic> data = {
      'user_id': userId,
    };

    if (firstName != null) data['first_name'] = firstName;
    if (lastName != null) data['last_name'] = lastName;
    if (email != null) data['email'] = email;

    return makeRequest('update_user_profile', data);
  }

  Future<Map<String, dynamic>> changePassword(String userId, String currentPassword, String newPassword) async {
    return makeRequest('change_password', {
      'user_id': userId,
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<Map<String, dynamic>> deleteAccount(String userId, String password) async {
    print('Attempting to delete account for user $userId');
    try {
      final requestData = {
        'user_id': int.parse(userId),  // Ensure user_id is sent as a number
        'password': password,
        'action': 'delete_account'  // Include action in the request
      };
      print('Delete account request data: $requestData');

      final token = await getAuthToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      );

      print('Response status code: ${response.statusCode}');
      // print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        print('Error response: ${response.body}');
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e, stackTrace) {
      print('Error in deleteAccount: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Failed to delete account: $e',
      };
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    return makeRequest('request_password_reset', {'email': email.trim()});
  }

  Future<Map<String, dynamic>> verifyResetCode(String email, String code) async {
    return makeRequest('verify_reset_code', {'email': email, 'code': code});
  }

  Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    return makeRequest('reset_password', {
      'email': email,
      'code': code,
      'new_password': newPassword,
    });
  }

  Future<List<Map<String, dynamic>>> executeQuery(String query, List<dynamic> params) async {
    try {
      final response = await makeRequest('execute_query', {
        'query': query,
        'params': params,
      });

      if (response['success'] == true && response['data'] != null) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('Error executing query: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getBonusFactors() async {
    try {
      if (_cachedBonusFactors != null) {
        return _cachedBonusFactors!;
      }

      final response = await makeRequest('get_bonus_factors', {});

      if (DEBUG) {
        // print('Raw bonus factors response: ${response.toString()}');
      }

      if (response['success'] == true &&
          response['data'] != null &&
          response['data'] is Map<String, dynamic>) {

        // Process and clean up any date fields in all sub-objects
        var cleanedData = Map<String, dynamic>.from(response['data']);

        for (var key in cleanedData.keys) {
          if (cleanedData[key] is List) {
            cleanedData[key] = (cleanedData[key] as List).map((item) {
              if (item is Map<String, dynamic>) {
                return _cleanDateFields(item);
              }
              return item;
            }).toList();
          }
        }

        response['data'] = cleanedData;
        _cachedBonusFactors = response;

        return response;
      }

      // Return empty data structure for unsuccessful response
      return {
        'success': false,
        'message': response['message'] ?? 'Failed to fetch bonus factors',
        'data': {
          'bon_bonus_factors': [],
          'bon_grade_details': [],
          'bon_default_grades': [],
          'bon_default_factors': [],
          'bon_class_factors': [],
          'bon_subjects': []
        }
      };
    } catch (e) {
      print('Error in getBonusFactors: $e');
      return {
        'success': false,
        'message': 'Error: $e',
        'data': {
          'bon_bonus_factors': [],
          'bon_grade_details': [],
          'bon_default_grades': [],
          'bon_default_factors': [],
          'bon_class_factors': [],
          'bon_subjects': []
        }
      };
    }
  }

  Future<List<Map<String, dynamic>>> getGradeDetails() async {
    final response = await getBonusFactors();
    if (response['data'] != null && response['data']['bon_grade_details'] != null) {
      var details = List<Map<String, dynamic>>.from(response['data']['bon_grade_details']);
      return details.map((grade) {
        return {
          'grade_id': int.parse(grade['grade_id'].toString()),
          'system_id': int.parse(grade['system_id'].toString()),
          'grade_name': grade['grade_name'].toString(),
          'grade_value': double.parse(grade['grade_value'].toString()),
          'multiplier': double.parse(grade['multiplier'].toString()),
          'percentage_equivalent': double.parse(grade['percentage_equivalent'].toString()),
          'weight': double.parse(grade['weight'].toString()),
        };
      }).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getDefaultGrades() async {
    final response = await getBonusFactors();
    if (response['data'] != null && response['data']['bon_default_grades'] != null) {
      return List<Map<String, dynamic>>.from(response['data']['bon_default_grades']);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getDefaultFactors() async {
    final response = await getBonusFactors();
    if (response['data'] != null && response['data']['bon_default_factors'] != null) {
      return List<Map<String, dynamic>>.from(response['data']['bon_default_factors']);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getClassFactors() async {
    final response = await getBonusFactors();
    if (response['data'] != null && response['data']['bon_class_factors'] != null) {
      return List<Map<String, dynamic>>.from(response['data']['bon_class_factors']);
    }
    return [];
  }

  // Translations

  Future<Map<String, dynamic>> getTranslations(String languageId) async {
    try {
      _debugPrint('Requesting translations for language: $languageId');

      final response = await makeRequest('get_translations', {
        'language_id': languageId,
      });

      // _debugPrint('Raw translation response: ${response.toString()}');

      if (response['data'] != null &&
          response['data']['translations'] != null &&
          response['data']['languages'] != null) {
        final languages = (response['data']['languages'] as List?)?.length ?? 0;
        _debugPrint('Found $languages languages in response');
        return response;
      } else {
        _debugPrint('Translation request failed - Invalid data structure');
        return {
          'success': false,
          'message': SERVER_ERROR,
          'data': null
        };
      }
    } catch (e, stackTrace) {
      _debugPrint('Error in getTranslations: $e');
      _debugPrint('Stack trace: $stackTrace');

      // Determine error message based on error type
      String errorMessage;
      if (e.toString().contains('NetworkException') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        errorMessage = CONNECTION_ERROR;
      } else {
        errorMessage = MAINTENANCE_MESSAGE;
      }

      return {
        'success': false,
        'message': errorMessage,
        'data': null
      };
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableLanguages() async {
    final response = await makeRequest('get_languages', {});
    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    }
    return [];
  }

  Future<List<Subject>> getSubjectsTranslated(String languageId) async {
    try {
      final response = await makeRequest('get_subjects_translated', {
        'language_id': languageId,
      });

      if (response['success'] == true &&
          response['data'] != null &&
          response['data']['subjects'] != null) {
        var rawSubjects = response['data']['subjects'] as List;
        return rawSubjects
            .map((json) => Subject.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error in getSubjectsTranslated: $e');
      return [];
    }
  }

  Future<List<GradeSystem>> getGradeSystemsTranslated(String languageId) async {
    try {
      final response = await makeRequest('get_grade_systems_translated', {
        'language_id': languageId,
      });

      if (response['success'] == true &&
          response['data'] != null &&
          response['data']['grade_systems'] != null) {
        final systems = response['data']['grade_systems'] as List;

        return systems
            .map((system) => GradeSystem.fromJson(Map<String, dynamic>.from(system)))
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
      }
      return [];
    } catch (e) {
      print('Error getting translated grade systems: $e');
      return [];
    }
  }
}