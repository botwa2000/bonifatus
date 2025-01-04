// ...lib/Screens/Parent/student_edit_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../Services/relationship_service.dart';
import '../../Services/api_service.dart';
import '../../Providers/language_provider.dart';
import 'dart:math';

class StudentEditDialog extends StatefulWidget {
  final Map<String, dynamic> student;
  final VoidCallback onUpdate;

  const StudentEditDialog({
    super.key,
    required this.student,
    required this.onUpdate,
  });

  @override
  _StudentEditDialogState createState() => _StudentEditDialogState();
}

class _StudentEditDialogState extends State<StudentEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _codeController;
  bool _isLoading = false;
  bool _usesParentEmail = true;
  final bool _useCustomCode = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.student['first_name']);
    _lastNameController = TextEditingController(text: widget.student['last_name']);
    _emailController = TextEditingController(text: widget.student['email']);
    _codeController = TextEditingController(text: widget.student['login_code'] ?? '');
    _usesParentEmail = widget.student['uses_parent_email'] == 1;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _generateNewCode() {
    final random = Random();
    String code = List.generate(6, (_) => random.nextInt(10).toString()).join();
    setState(() {
      _codeController.text = code;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_usesParentEmail) {
      final code = _codeController.text.trim();
      if (code.length != 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.translate('code_must_be_6_digits')),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final relationshipService = RelationshipService(ApiService());

      final requestData = {
        'student_id': widget.student['student_id'],
        'parent_id': widget.student['parent_id'],
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'uses_parent_email': _usesParentEmail ? 1 : 0,
      };

      if (_usesParentEmail) {
        final currentCode = widget.student['login_code']?.toString() ?? '';
        final newCode = _codeController.text.trim();
        if (newCode != currentCode) {
          requestData['login_code'] = newCode;
        }
      } else {
        requestData['email'] = _emailController.text.trim();
      }

      print('Update request data: $requestData');

      final response = await relationshipService.updateStudent(
        widget.student['student_id'].toString(),
        requestData,
      );

      if (mounted) {
        if (response['success']) {
          widget.onUpdate();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(languageProvider.translate('student_updated')),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ??
                  languageProvider.translate('error_updating_student')),
            ),
          );
        }
      }
    } catch (e) {
      print('Error updating student: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentCode = widget.student['login_code']?.toString() ?? '';

    return AlertDialog(
      title: Text(languageProvider.translate('edit_student')),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: languageProvider.translate('first_name'),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: languageProvider.translate('last_name'),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                languageProvider.translate('login_method'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text(
                        languageProvider.translate('login_with_parent_email'),
                        style: const TextStyle(fontSize: 14),
                      ),
                      value: true,
                      groupValue: _usesParentEmail,
                      onChanged: (value) => setState(() {
                        _usesParentEmail = value!;
                        if (_usesParentEmail) _generateNewCode();
                      }),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text(
                        languageProvider.translate('login_with_student_email'),
                        style: const TextStyle(fontSize: 14),
                      ),
                      value: false,
                      groupValue: _usesParentEmail,
                      onChanged: (value) => setState(() => _usesParentEmail = value!),
                    ),
                  ),
                ],
              ),
              if (_usesParentEmail) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.translate('login_code'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          hintText: '123456',
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.casino, size: 20),
                            tooltip: languageProvider.translate('generate_new_code'),
                            onPressed: _generateNewCode,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return languageProvider.translate('please_enter_code');
                          }
                          if (value.length != 6) {
                            return languageProvider.translate('code_must_be_6_digits');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        languageProvider.translate('code_explanation'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: languageProvider.translate('email'),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(languageProvider.translate('cancel')),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text(languageProvider.translate('save')),
        ),
      ],
    );
  }
}