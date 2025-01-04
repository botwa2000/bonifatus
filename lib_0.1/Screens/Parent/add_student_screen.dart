// lib/screens/parent/add_student_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Services/auth_service.dart';
import '../../Services/api_service.dart';
import '../../Services/relationship_service.dart';
import '../../Providers/language_provider.dart';
import 'dart:math';
import 'package:flutter/services.dart';

class AddStudentScreen extends StatefulWidget {
  final bool withEmail;
  final VoidCallback? onStudentAdded;

  const AddStudentScreen({
    super.key,
    required this.withEmail,
    this.onStudentAdded,
  });

  @override
  _AddStudentScreenState createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  final bool _showCustomCode = false;
  late LanguageProvider _languageProvider;

// Constants for the validation
  static const int CODE_LENGTH = 6;
  bool _autoGenerateCode = true;
  String? _generatedCode;

  @override
  void initState() {
    super.initState();
    _generateNewCode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _languageProvider = Provider.of<LanguageProvider>(context);
  }

  void _generateNewCode() {
    final random = Random();
    String code = List.generate(CODE_LENGTH, (_) => random.nextInt(10).toString()).join();
    if (mounted) {
      setState(() {
        _generatedCode = code;
        if (_autoGenerateCode) {
          _codeController.text = code;
        }
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final userId = await AuthService().getCurrentUserId();
      if (userId != null) {
        final relationshipService = RelationshipService(ApiService());
        final result = widget.withEmail
            ? await relationshipService.inviteStudent(
          parentId: userId,
          studentEmail: _emailController.text,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
        )
            : await relationshipService.createLocalStudent(
          parentId: userId,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          customCode: _autoGenerateCode ? null : _codeController.text,
        );

        if (mounted) {
          final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
          if (result['success']) {
            String code = result['data']?['login_code'] ?? '';
            if (!widget.withEmail && !_showCustomCode && code.isNotEmpty) {
              _showGeneratedCode(code);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(languageProvider.translate('student_added')),
                  duration: const Duration(seconds: 2),
                ),
              );
              widget.onStudentAdded?.call();
              Navigator.pop(context);
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? languageProvider.translate('error_adding_student')),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: languageProvider.translate('retry'),
                  onPressed: _submitForm,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error adding student: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showGeneratedCode(String code) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.translate('student_login_code')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(languageProvider.translate('save_code_instruction')),
            const SizedBox(height: 16),
            Text(
              code,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to previous screen
            },
            child: Text(languageProvider.translate('done')),
          ),
        ],
      ),
    );
  }

  void _handleSubmit(BuildContext context) {
    if (_isLoading) return;
    _submitForm();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.withEmail
            ? languageProvider.translate('invite_student')
            : languageProvider.translate('add_student')
        ),
      ),
      body: Form(
        key: _formKey,
        child: Focus(
          onKey: (node, event) {
            if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
              _handleSubmit(context);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              TextFormField(
                controller: _firstNameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: languageProvider.translate('first_name'),
                ),
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                validator: (value) => value?.isEmpty ?? true
                    ? languageProvider.translate('please_enter_first_name')
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: languageProvider.translate('last_name'),
                ),
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                validator: (value) => value?.isEmpty ?? true
                    ? languageProvider.translate('please_enter_last_name')
                    : null,
              ),
              if (widget.withEmail) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: languageProvider.translate('email'),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSubmit(context),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return languageProvider.translate('please_enter_email');
                    }
                    if (!value!.contains('@')) {
                      return languageProvider.translate('please_enter_valid_email');
                    }
                    return null;
                  },
                ),
              ] else ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _languageProvider.translate('login_method'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<bool>(
                                title: Text(_languageProvider.translate('auto_generate_code')),
                                value: true,
                                groupValue: _autoGenerateCode,
                                onChanged: (value) {
                                  setState(() {
                                    _autoGenerateCode = value!;
                                    if (_autoGenerateCode) {
                                      _generateNewCode();
                                    }
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<bool>(
                                title: Text(_languageProvider.translate('custom_code')),
                                value: false,
                                groupValue: _autoGenerateCode,
                                onChanged: (value) {
                                  setState(() {
                                    _autoGenerateCode = value!;
                                    if (!_autoGenerateCode) {
                                      _codeController.clear();
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_autoGenerateCode)
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _codeController,
                                  enabled: false,
                                  decoration: InputDecoration(
                                    labelText: _languageProvider.translate('generated_code'),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: _languageProvider.translate('generate_new_code'),
                                onPressed: () {
                                  setState(() {
                                    _generateNewCode();
                                  });
                                },
                              ),
                            ],
                          )
                        else
                          TextField(
                            controller: _codeController,
                            decoration: InputDecoration(
                              labelText: _languageProvider.translate('login_code'),
                              hintText: '123456',
                              border: const OutlineInputBorder(),
                            ),
                            maxLength: CODE_LENGTH,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(CODE_LENGTH),
                            ],
                          ),
                        const SizedBox(height: 8),
                        Text(
                          _languageProvider.translate('code_explanation'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : () => _handleSubmit(context),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(widget.withEmail
                    ? languageProvider.translate('send_invitation')
                    : languageProvider.translate('add_student')
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}