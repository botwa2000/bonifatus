import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  final ApiService apiService = ApiService();  // This is declared but never used

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey) != null;
  }

  Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await apiService.login(email, password);

      if (response['success'] == true) {
        final token = response['token']?.toString();
        final userId = response['user_id']?.toString();

        // Only proceed if we have both token and userId
        if (token?.isNotEmpty == true && userId?.isNotEmpty == true) {
          await saveLoginInfo(token!, userId!);
          return true;
        }
        print('Login failed: Missing token or userId');
        return false;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> loginWithCode(String email, String code) async {
    try {
      final response = await apiService.loginWithCode(email, code);

      if (response['success'] == true &&
          response['token'] != null &&
          response['user_id'] != null) {

        await saveLoginInfo(
            response['token'],
            response['user_id']
        );
        return true;
      }
      print('Login failed: ${response['message']}');
      return false;
    } catch (e) {
      print('Login with code error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) {
        throw Exception('No logged in user');
      }
      return await apiService.getUserProfile(userId);  // Changed from _apiService to apiService
    } catch (e) {
      print('Error fetching user profile: $e');
      rethrow;
    }
  }

  Future<void> saveLoginInfo(String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<bool> isTokenValid() async {
    final token = await getAuthToken();
    if (token == null) return false;
    return true;
  }
}