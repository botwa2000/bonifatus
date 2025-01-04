import '../../Services/api_service.dart';
import '../../Services/auth_service.dart';

class UserAccountService {
  final ApiService _apiService;
  final AuthService _authService;
  static const String baseUrl = 'https://www.bonifatus.com/api.php';

  UserAccountService(this._apiService, this._authService);

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      final response = await _apiService.makeRequest('get_user_profile', {
        'user_id': userId,
      });

      if (response['success'] == true) {
        return response;
      } else {
        throw Exception(response['message'] ?? 'Failed to load profile');
      }
    } catch (e) {
      print('Error getting user profile: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUserProfile({
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      final response = await _apiService.makeRequest('update_user_profile', {
        'user_id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
      });

      if (response['success'] == true) {
        return response;
      } else {
        throw Exception(response['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      final response = await _apiService.makeRequest('change_password', {
        'user_id': userId,
        'current_password': currentPassword,
        'new_password': newPassword,
      });

      if (response['success'] == true) {
        return response;
      } else {
        throw Exception(response['message'] ?? 'Failed to change password');
      }
    } catch (e) {
      print('Error changing password: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteAccount(String password) async {
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      final response = await _apiService.makeRequest('delete_account', {
        'user_id': userId,
        'password': password,
      });

      if (response['success'] == true) {
        await _authService.logout();
        return response;
      } else {
        throw Exception(response['message'] ?? 'Failed to delete account');
      }
    } catch (e) {
      print('Error deleting account: $e');
      rethrow;
    }
  }
}