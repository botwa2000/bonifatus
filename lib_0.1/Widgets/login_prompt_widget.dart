import 'package:flutter/material.dart';

class LoginPromptWidget extends StatelessWidget {
  final VoidCallback onLoginTap;

  const LoginPromptWidget({super.key, required this.onLoginTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please log in to access all features',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onLoginTap,
              child: const Text('Log In'),
            ),
          ],
        ),
      ),
    );
  }
}