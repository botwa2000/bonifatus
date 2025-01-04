import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Providers/language_provider.dart';

class StudentListItem extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onEdit;
  final VoidCallback onDisconnect;

  const StudentListItem({
    super.key,
    required this.student,
    required this.onEdit,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final usesParentEmail = student['uses_parent_email'] == 1;
    final firstLetter = (student['first_name'] as String? ?? '').isNotEmpty
        ? (student['first_name'] as String).characters.first.toUpperCase()
        : '?';
    final loginCode = student['login_code']?.toString() ?? '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // New Stack Widget for avatar + account type icon
                Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Text(
                          (student['first_name'] as String? ?? '').isNotEmpty
                              ? (student['first_name'] as String).characters.first.toUpperCase()
                              : '?'
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          student['uses_parent_email'] == 1
                              ? Icons.supervised_user_circle_outlined  // For parent-linked accounts
                              : Icons.person_outlined,  // For independent accounts
                          size: 14,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${student['first_name']} ${student['last_name']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student['email'] ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'disconnect') {
                      onDisconnect();
                    }
                  },
                  itemBuilder: (BuildContext itemContext) {
                    // Get languageProvider with listen: false
                    final languageProvider = Provider.of<LanguageProvider>(
                        itemContext,
                        listen: false
                    );
                    return [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit, size: 20),
                            const SizedBox(width: 8),
                            Text(languageProvider.translate('edit_student')),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'disconnect',
                        child: Row(
                          children: [
                            const Icon(Icons.link_off, size: 20),
                            const SizedBox(width: 8),
                            Text(languageProvider.translate('disconnect_student')),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
            if (student['uses_parent_email'] == 1 && student['login_code']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.key, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${Provider.of<LanguageProvider>(context).translate('login_code')}: ${student['login_code']}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}