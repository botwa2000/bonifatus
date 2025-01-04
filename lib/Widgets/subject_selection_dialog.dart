//lib/widgets/subject_selection_dialog.dart

import 'package:flutter/material.dart';
import '../models/subject.dart';

class SubjectSelectionDialog extends StatefulWidget {
  final List<Subject> availableSubjects;
  final List<Subject> selectedSubjects;
  final Function(Subject) onSubjectSelected;

  const SubjectSelectionDialog({
    super.key,
    required this.availableSubjects,
    required this.selectedSubjects,
    required this.onSubjectSelected,
  });

  @override
  State<SubjectSelectionDialog> createState() => _SubjectSelectionDialogState();
}

class _SubjectSelectionDialogState extends State<SubjectSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Subject> _filteredSubjects = [];
  Set<String> _expandedCategories = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _filteredSubjects = List.from(widget.availableSubjects);
  }

  void _filterSubjects(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredSubjects = widget.availableSubjects;
        _expandedCategories = {};
      } else {
        _filteredSubjects = widget.availableSubjects.where((subject) {
          return subject.subjectName.toLowerCase().contains(_searchQuery) ||
              subject.categoryName.toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupedSubjects = Subject.groupByCategory(_filteredSubjects);

    return Dialog(
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Subject',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search subjects...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: _filterSubjects,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: groupedSubjects.length,
                itemBuilder: (context, index) {
                  final category = groupedSubjects[index];
                  final subjects = (category['subjects'] as List)
                      .map((s) => Subject.fromJson(s as Map<String, dynamic>))
                      .toList();

                  if (subjects.isEmpty) return const SizedBox.shrink();

                  Widget content = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: subjects.map((subject) {
                      final isSelected = widget.selectedSubjects
                          .any((s) => s.subjectId == subject.subjectId);
                      return ListTile(
                        title: Text(subject.subjectName),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        enabled: !isSelected,
                        onTap: () {
                          widget.onSubjectSelected(subject);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  );

                  // If searching, show subjects directly without expansion tile
                  if (_searchQuery.isNotEmpty) {
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              category['category_name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          content,
                        ],
                      ),
                    );
                  }

                  // Otherwise, use expansion tile
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ExpansionTile(
                      key: Key(category['category_name']),
                      title: Text(category['category_name']),
                      initiallyExpanded: _expandedCategories.contains(category['category_name']),
                      onExpansionChanged: (expanded) {
                        setState(() {
                          if (expanded) {
                            _expandedCategories.add(category['category_name']);
                          } else {
                            _expandedCategories.remove(category['category_name']);
                          }
                        });
                      },
                      children: [content],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}