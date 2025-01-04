import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../Services/api_service.dart';
import '../../Utils/digit_only_formatter.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _verificationController = TextEditingController();

  // Focus Nodes
  final _firstNameFocusNode = FocusNode();
  final _lastNameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _verificationCodeFocusNode = FocusNode();

  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  String _userType = 'parent';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  double _passwordStrength = 0;
  bool _isEmailSent = false;
  String _verificationCode = '';
  int _remainingAttempts = 3;
  Timer? _resendTimer;
  int _resendCountdown = 0;
  String _firstName = '';
  String _lastName = '';

  @override
  void dispose() {
    // Dispose controllers
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _verificationController.dispose();

    // Dispose focus nodes
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _verificationCodeFocusNode.dispose();

    _resendTimer?.cancel();
    super.dispose();
  }

  // Your existing helper methods here...
  void _updatePasswordStrength(String password) {
    double strength = 0;
    if (password.length >= 8) strength += 0.2;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.2;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.2;

    setState(() {
      _passwordStrength = strength;
    });
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        final response = await _apiService.register(
          _email,
          _password,
          _userType,
          firstName: _firstName,
          lastName: _lastName,
        );

        if (response['success'] == true) {
          setState(() {
            _isEmailSent = true;
          });
          _startResendTimer();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response['message'] ?? 'Registration successful')),
            );
          }
        } else {
          _handleRegistrationError(response);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error during registration: $e')),
          );
        }
      }
    }
  }

  void _handleRegistrationError(Map<String, dynamic> response) {
    switch (response['action']) {
      case 'login_or_reset':
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Account Exists'),
            content: Text(response['message'] ?? 'An account with this email already exists.'),
            actions: [
              TextButton(
                child: const Text('Login'),
                onPressed: () => Navigator.pushNamed(context, '/login'),
              ),
              TextButton(
                child: const Text('Reset Password'),
                onPressed: () => Navigator.pushNamed(context, '/reset-password'),
              ),
            ],
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Registration failed')),
        );
    }
  }

  Future<void> _verifyCode() async {
    if (_verificationCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit code')),
      );
      return;
    }

    try {
      final response = await _apiService.verifyRegistration(_email, _verificationCode);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email verified successfully')),
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        }
      } else {
        if (response['remainingAttempts'] != null) {
          setState(() {
            _remainingAttempts = response['remainingAttempts'];
          });
        }

        switch (response['action']) {
          case 'register':
            setState(() {
              _isEmailSent = false;
            });
            break;
          case 'resend':
            setState(() {
              _resendCountdown = 0;
            });
            break;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Verification failed${_remainingAttempts > 0 ? ' ($_remainingAttempts attempts remaining)' : ''}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during verification: $e')),
        );
      }
    }
  }

  void _startResendTimer() {
    setState(() {
      _resendCountdown = 60;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          _resendTimer?.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isEmailSent) ...[
                  TextFormField(
                    controller: _firstNameController,
                    focusNode: _firstNameFocusNode,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'First Name'),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_lastNameFocusNode);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your first name';
                      }
                      return null;
                    },
                    onChanged: (value) => setState(() => _firstName = value),
                    onSaved: (value) => _firstName = value!,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    focusNode: _lastNameFocusNode,
                    decoration: const InputDecoration(labelText: 'Last Name'),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_emailFocusNode);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your last name';
                      }
                      return null;
                    },
                    onChanged: (value) => setState(() => _lastName = value),
                    onSaved: (value) => _lastName = value!,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_passwordFocusNode);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                    onChanged: (value) => setState(() => _email = value),
                    onSaved: (value) => _email = value!,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_confirmPasswordFocusNode);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters long';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _updatePasswordStrength(value);
                      _password = value;
                    },
                    onSaved: (value) => _password = value!,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _passwordStrength,
                    backgroundColor: Colors.grey[300],
                    color: _passwordStrength <= 0.3 ? Colors.red : _passwordStrength <= 0.6 ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _register(),
                    validator: (value) {
                      if (value != _password) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    onSaved: (value) => _confirmPassword = value!,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _userType,
                    decoration: const InputDecoration(labelText: 'User Type'),
                    items: ['parent', 'student'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value.capitalize()),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _userType = value!),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _register,
                    child: const Text('Register'),
                  ),
                ] else ...[
                  Text('Enter the 6-digit verification code sent to $_email'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _verificationController,
                    focusNode: _verificationCodeFocusNode,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Verification Code',
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [
                      DigitOnlyFormatter(),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onFieldSubmitted: (_) => _verifyCode(),
                    onChanged: (value) => _verificationCode = value,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _verifyCode,
                    child: const Text('Verify'),
                  ),
                  const SizedBox(height: 16),
                  if (_resendCountdown > 0)
                    Text('Resend code in $_resendCountdown seconds')
                  else
                    TextButton(
                      child: const Text('Resend Code'),
                      onPressed: () {
                        _register();
                        _startResendTimer();
                      },
                    ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  child: const Text('Already have an account? Login here'),
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}