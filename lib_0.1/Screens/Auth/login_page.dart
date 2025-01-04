// lib/screens/Auth/login_page.dart

import 'package:flutter/material.dart';
import '../../Services/auth_service.dart';
import '../../Utils/digit_only_formatter.dart';
import 'package:provider/provider.dart';
import '../../Providers/language_provider.dart';
import 'package:flutter/services.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _credentialController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _credentialFocusNode = FocusNode();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscureCredential = true;
  bool _isCodeLogin = false;

  @override
  void dispose() {
    _emailController.dispose();
    _credentialController.dispose();
    _emailFocusNode.dispose();
    _credentialFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final success = _isCodeLogin
            ? await _authService.loginWithCode(
          _emailController.text,
          _credentialController.text,
        )
            : await _authService.login(
          _emailController.text,
          _credentialController.text,
        );

        if (mounted) {
          if (success) {
            Navigator.pushReplacementNamed(context, '/');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(Provider.of<LanguageProvider>(context, listen: false)
                    .translate(_isCodeLogin ? 'invalid_code_or_email' : 'invalid_credentials')),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(Provider.of<LanguageProvider>(context, listen: false)
                  .translate('login_failed')),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.translate('login')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                decoration: InputDecoration(
                  labelText: languageProvider.translate('email'),
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onEditingComplete: () {
                  FocusScope.of(context).requestFocus(_credentialFocusNode);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return languageProvider.translate('please_enter_email');
                  }
                  if (!value.contains('@')) {
                    return languageProvider.translate('please_enter_valid_email');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(languageProvider.translate('login_with_password')),
                  Switch(
                    value: _isCodeLogin,
                    onChanged: (value) {
                      setState(() {
                        _isCodeLogin = value;
                        _credentialController.clear();
                      });
                    },
                  ),
                  Text(languageProvider.translate('login_with_code')),
                ],
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _credentialController,
                focusNode: _credentialFocusNode,
                decoration: InputDecoration(
                  labelText: languageProvider.translate(
                      _isCodeLogin ? 'login_code' : 'password'
                  ),
                  prefixIcon: Icon(_isCodeLogin ? Icons.pin : Icons.lock),
                  suffixIcon: _isCodeLogin ? null : IconButton(
                    icon: Icon(_obscureCredential ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureCredential = !_obscureCredential),
                  ),
                ),
                obscureText: !_isCodeLogin && _obscureCredential,
                keyboardType: _isCodeLogin ? TextInputType.number : TextInputType.text,
                maxLength: _isCodeLogin ? 6 : null,
                inputFormatters: _isCodeLogin ? [
                  DigitOnlyFormatter(),
                  LengthLimitingTextInputFormatter(6),
                ] : null,
                textInputAction: TextInputAction.done,
                onEditingComplete: _handleLogin,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return languageProvider.translate(
                        _isCodeLogin ? 'please_enter_code' : 'please_enter_password'
                    );
                  }
                  if (_isCodeLogin && value.length != 6) {
                    return languageProvider.translate('code_must_be_6_digits');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(languageProvider.translate('login')),
              ),

              if (!_isCodeLogin) ...[
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/reset-password');
                  },
                  child: Text(languageProvider.translate('forgot_password')),
                ),
              ],

              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: Text(
                    '${languageProvider.translate('no_account')} '
                        '${languageProvider.translate('register_here')}'
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}