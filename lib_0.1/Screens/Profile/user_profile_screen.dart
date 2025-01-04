import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Services/auth_service.dart';
import '../../Services/api_service.dart';
import '../Auth/login_page.dart';
import '../../Providers/language_provider.dart';
import '../parent/parent_dashboard.dart';
import '../parent/add_student_screen.dart';
import '../Student/student_profile_screen.dart';
import '../Student/parent_connection_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final AuthService _auth = AuthService();
  final ApiService _apiService = ApiService();
  late LanguageProvider _languageProvider;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  Map<String, dynamic> _userProfile = {};

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _languageProvider = Provider.of<LanguageProvider>(context);
  }

  Future<void> _checkLoginStatus() async {
    setState(() => _isLoading = true);
    try {
      bool loggedIn = await _auth.isLoggedIn();
      if (loggedIn) {
        String? userId = await _auth.getCurrentUserId();
        if (userId != null) {
          await _fetchUserProfile(userId);
        }
      } else {
        setState(() => _isLoggedIn = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserProfile(String userId) async {
    try {
      final response = await _apiService.getUserProfile(userId);

      if (response['success']) {
        setState(() {
          _isLoggedIn = true;
          _userProfile = response['data'];
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch user profile');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching profile: $e')),
      );
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _auth.logout();
      setState(() => _isLoggedIn = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during logout: $e')),
      );
    }
  }

  void _navigateToAddStudent(bool withEmail) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => AddStudentScreen(withEmail: withEmail),
      ),
    );
  }

  void _showAddStudentDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.email),
            title: Text(_languageProvider.translate('add_with_email')),
            onTap: () => _navigateToAddStudent(true),
          ),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: Text(_languageProvider.translate('add_without_email')),
            onTap: () => _navigateToAddStudent(false),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final firstNameController = TextEditingController(text: _userProfile['first_name']);
    final lastNameController = TextEditingController(text: _userProfile['last_name']);
    final emailController = TextEditingController(text: _userProfile['email']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageProvider.translate('edit_profile')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(
                    labelText: _languageProvider.translate('first_name')
                ),
              ),
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(
                    labelText: _languageProvider.translate('last_name')
                ),
              ),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                    labelText: _languageProvider.translate('email')
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_languageProvider.translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              try {
                final userId = await _auth.getCurrentUserId();
                if (userId == null) {
                  throw Exception('Not authenticated');
                }

                final response = await _apiService.updateUserProfile(
                  userId,
                  firstName: firstNameController.text,
                  lastName: lastNameController.text,
                  email: emailController.text,
                );

                if (response['success']) {
                  // Update local profile data
                  setState(() {
                    _userProfile = response['data'] ?? _userProfile;
                  });

                  Navigator.pop(context); // Close the dialog first

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_languageProvider.translate('profile_update_success')),
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.only(
                          bottom: MediaQuery.of(context).size.height - 100,
                          left: 10,
                          right: 10,
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }

                  // Refresh profile data
                  await _fetchUserProfile(userId);
                } else {
                  throw Exception(response['message'] ?? 'Failed to update profile');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_languageProvider.translate('profile_update_failed')),
                      behavior: SnackBarBehavior.floating,
                      margin: EdgeInsets.only(
                        bottom: MediaQuery.of(context).size.height - 100,
                        left: 10,
                        right: 10,
                      ),
                      duration: const Duration(seconds: 3),
                      action: SnackBarAction(
                        label: _languageProvider.translate('retry'),
                        onPressed: () {
                          // Keep the dialog open on error
                          // Do nothing here as the dialog is already open
                        },
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(_languageProvider.translate('save')),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    BuildContext? dialogContext;
    final ValueNotifier<double> passwordStrength = ValueNotifier<double>(0.0);

    void showMessage(String message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }

    void updatePasswordStrength(String password) {
      double strength = 0;
      if (password.length >= 8) strength += 0.2;
      if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;
      if (password.contains(RegExp(r'[a-z]'))) strength += 0.2;
      if (password.contains(RegExp(r'[0-9]'))) strength += 0.2;
      if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.2;
      passwordStrength.value = strength;
    }

    Future<void> handlePasswordChange() async {
      if (newPasswordController.text.length < 8) {
        showMessage('Password must be at least 8 characters long');
        return;
      }

      if (newPasswordController.text != confirmPasswordController.text) {
        showMessage('Passwords do not match');
        return;
      }

      try {
        final userId = await _auth.getCurrentUserId();
        if (userId != null) {
          final response = await _apiService.changePassword(
            userId,
            currentPasswordController.text,
            newPasswordController.text,
          );

          // Close the dialog first
          if (dialogContext != null) {
            Navigator.pop(dialogContext!);
          }

          // Then show the result
          if (mounted) {
            if (response['success']) {
              showMessage('Password changed successfully');
            } else {
              showMessage(response['message'] ?? 'Failed to change password');
            }
          }
        }
      } catch (e) {
        if (mounted) {
          showMessage('Error changing password: $e');
        }
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        dialogContext = context;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(_languageProvider.translate('change_password')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    decoration: InputDecoration(
                      labelText: _languageProvider.translate('current_password'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrentPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => obscureCurrentPassword = !obscureCurrentPassword),
                      ),
                    ),
                    obscureText: obscureCurrentPassword,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    decoration: InputDecoration(
                      labelText: _languageProvider.translate('new_password'),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNewPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => obscureNewPassword = !obscureNewPassword),
                      ),
                      helperText: _languageProvider.translate('password_requirements'),
                    ),
                    obscureText: obscureNewPassword,
                    onChanged: updatePasswordStrength,
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<double>(
                    valueListenable: passwordStrength,
                    builder: (context, value, _) => Column(
                      children: [
                        LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.grey[300],
                          color: value <= 0.3
                              ? Colors.red
                              : value <= 0.6
                              ? Colors.orange
                              : Colors.green,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Text('${_languageProvider.translate('password_strength')}: '),
                              Text(
                                value <= 0.3
                                    ? _languageProvider.translate('weak')
                                    : value <= 0.6
                                    ? _languageProvider.translate('medium')
                                    : _languageProvider.translate('strong'),
                                style: TextStyle(
                                  color: value <= 0.3
                                      ? Colors.red
                                      : value <= 0.6
                                      ? Colors.orange
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: _languageProvider.translate('confirm_password'),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
                      ),
                    ),
                    obscureText: obscureConfirmPassword,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_languageProvider.translate('cancel')),
              ),
              TextButton(
                onPressed: handlePasswordChange,
                child: Text(_languageProvider.translate('change_password')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageProvider.translate('delete_account')),
        content: Text(
          _languageProvider.translate('delete_account_confirmation'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_languageProvider.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showPasswordConfirmation();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_languageProvider.translate('delete')),
          ),
        ],
      ),
    );
  }

  void _showPasswordConfirmation() {
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    final scaffoldContext = context;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_languageProvider.translate('confirm_password')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _languageProvider.translate('delete_account_confirmation'),
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: _languageProvider.translate('password'),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                  ),
                ),
                obscureText: obscurePassword,
                enabled: !_isLoading,
                onFieldSubmitted: _isLoading ? null : (_) => _handleDeleteAccount(
                  passwordController.text,
                  dialogContext,
                  scaffoldContext,
                  setDialogState,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text(_languageProvider.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _handleDeleteAccount(
                passwordController.text,
                dialogContext,
                scaffoldContext,
                setDialogState,
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(_languageProvider.translate('delete_account')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteAccount(
      String password,
      BuildContext dialogContext,
      BuildContext scaffoldContext,
      StateSetter setDialogState,
      ) async {
    if (password.isEmpty) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(content: Text(_languageProvider.translate('password_required'))),
      );
      return;
    }

    try {
      setDialogState(() => _isLoading = true);

      final userId = await _auth.getCurrentUserId();
      if (userId == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.deleteAccount(userId, password);

      if (response['success'] == true) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
            SnackBar(
              content: Text(_languageProvider.translate('account_deleted')),
              duration: const Duration(seconds: 2), // Give time to read the message
            ),
          );
        }

        // Wait for the message to be shown
        await Future.delayed(const Duration(seconds: 1));

        await _auth.logout();
        if (mounted) {
          Navigator.pop(dialogContext);  // Close the dialog
          Navigator.pushNamedAndRemoveUntil(
            scaffoldContext,
            '/login',
                (route) => false,
          );
        }
      } else {
        setDialogState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? _languageProvider.translate('failed_delete_account')),
            ),
          );
        }
      }
    } catch (e) {
    print('Error in _handleDeleteAccount: $e');
      setDialogState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isLoggedIn) {
      return const LoginPage();
    }

    String fullName = [
      _userProfile['first_name'] ?? '',
      _userProfile['last_name'] ?? '',
    ].where((s) => s.isNotEmpty).join(' ');

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Existing user info card - keep as is
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _userProfile['email'] ?? '',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // New role-based section
        if (_userProfile['role'] == 'parent') ...[
          ListTile(
            leading: const Icon(Icons.people),
            title: Text(_languageProvider.translate('my_students')),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (context) => const ParentDashboard()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: Text(_languageProvider.translate('add_student')),
            onTap: () => _showAddStudentDialog(),
          ),
        ] else if (_userProfile['role'] == 'student') ...[
          ListTile(
            leading: const Icon(Icons.school),
            title: Text(_languageProvider.translate('my_academic_profile')),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (context) => const StudentProfileScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.family_restroom),
            title: Text(_languageProvider.translate('parent_connection')),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (context) => const ParentConnectionScreen()),
            ),
          ),
        ],

        const Divider(),

        // Keep existing account management options
        ListTile(
          leading: const Icon(Icons.edit),
          title: Text(_languageProvider.translate('edit_profile')),
          onTap: _showEditProfileDialog,
        ),
        ListTile(
          leading: const Icon(Icons.lock),
          title: Text(_languageProvider.translate('change_password')),
          onTap: _showChangePasswordDialog,
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(_languageProvider.translate('logout')),
          onTap: _handleLogout,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: Text(_languageProvider.translate('delete_account')),
          textColor: Colors.red,
          onTap: _showDeleteAccountDialog,
        ),
      ],
    );
  }
}