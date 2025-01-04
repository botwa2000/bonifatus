// .../lib/widgets/subject_grade_card.dart

import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../models/grading_models.dart';

class SubjectGradeCard extends StatelessWidget {
  final Subject subject;
  final Function(Grade) onGradeChanged;
  final VoidCallback onRemove;

  const SubjectGradeCard({
    super.key,
    required this.subject,
    required this.onGradeChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(subject.subjectName),
        subtitle: Text(subject.categoryName),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (subject.grade != null)
              Chip(
                label: Text(subject.gradeName),
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove,
            ),
          ],
        ),
        onTap: () => _showGradeSelector(context),
      ),
    );
  }

  void _showGradeSelector(BuildContext context) {
    // Implement grade selection dialog
  }
}