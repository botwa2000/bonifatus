// .../lib/Screens/Calculator/logged_in_calculator_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../Services/api_service.dart';
import '../../models/subject.dart';
import '../../models/grading_models.dart';
import '../../Providers/language_provider.dart';
import '../../widgets/grades_results_widget.dart';

class LoggedInCalculatorView extends StatefulWidget {
  final String userId;

  const LoggedInCalculatorView({super.key, required this.userId});

  @override
  _LoggedInCalculatorViewState createState() =>
      _LoggedInCalculatorViewState();
}

class SubjectGradeCard extends StatelessWidget {
  final Subject subject;
  final Function(Grade) onGradeChanged;
  final VoidCallback onRemove;
  final Future<void> Function() onTap;

  const SubjectGradeCard({
    super.key,
    required this.subject,
    required this.onGradeChanged,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: ElevatedButton(
        onPressed: () async {
          try {
            await onTap();
          } catch (e) {
            print('Summary: Error updating grade for ${subject.subjectName} - $e');
          }
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Theme.of(context).cardColor,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.subjectName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subject.grade != null
                          ? 'Current grade: ${subject.gradeName}'
                          : 'Tap to add grade',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  print(
                      'DEBUG: SubjectGradeCard - Delete pressed for ${subject.subjectName}');
                  onRemove();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoggedInCalculatorViewState extends State<LoggedInCalculatorView> {
  late String selectedYear;
  late final LanguageProvider _languageProvider;
  int selectedGradeSystem = 1;
  bool isFullTerm = true;
  bool showLifetimeResults = false;
  bool _isSaving = false;
  bool _isLoading = true;
  List<Subject> selectedSubjects = [];
  double totalBonus = 0;
  double get totalGrades => _calculateTotalGrades();
  double get averageScore => _calculateAverageScore();
  double get percentageScore => _calculatePercentageScore();
  double get bonusPoints => totalBonus;
  int? _existingTestId;
  Subject? selectedSubject;
  Map<String, dynamic> bonusFactors = {'data': {'bon_grade_details': []}};

  double _calculateAverageScore() {
    if (selectedSubjects.isEmpty) return 0.0;
    double total = 0.0;
    int count = 0;
    for (var subject in selectedSubjects) {
      if (subject.grade != null) {
        total += double.parse(subject.grade!['grade_value'].toString());
        count++;
      }
    }
    return count > 0 ? total / count : 0.0;
  }

  double _calculatePercentageScore() {
    if (selectedSubjects.isEmpty) return 0.0;
    double total = 0.0;
    int count = 0;
    for (var subject in selectedSubjects) {
      if (subject.grade != null) {
        total +=
            double.parse(subject.grade!['percentage_equivalent'].toString());
        count++;
      }
    }
    return count > 0 ? total / count : 0.0;
  }

  double _calculateTotalGrades() {
    return selectedSubjects.length.toDouble();
  }

  bool _validateData() {
    if (selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one subject')),
      );
      return false;
    }

    for (var subject in selectedSubjects) {
      if (subject.grade == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please assign grades to all subjects')),
        );
        return false;
      }
    }

    return true;
  }

  void _updateCalculations() {
    if (selectedSubjects.isEmpty) {
      setState(() {
        totalBonus = 0;
      });
      return;
    }

    double total = 0;
    for (var subject in selectedSubjects) {
      if (subject.grade != null) {
        total += subject.grade!['multiplier'] * (isFullTerm ? 1.0 : 0.5);
      }
    }

    setState(() {
      totalBonus = total;
    });
  }

  @override
  void initState() {
    super.initState();
    final currentYear = DateTime.now().year;
    selectedYear = '$currentYear/${(currentYear + 1).toString().substring(2)}';
    _languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    _loadExistingResults();
  }

  void _handleGradeDialogError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _loadExistingResults() async {
    try {
      final response = await ApiService().makeRequest(
          'get_term_results',
          {'student_id': widget.userId}
      );
      print(response); // Print the response here
      if (mounted) {
        // Check if response and success are not null
        if (response != null && response['success'] is bool && response['success']) {
          final results = response['data'] as List<dynamic>?;
          // Check if results is not null and not empty
          if (results != null && results.isNotEmpty) {
            final latestResult = results.first;
            // Check if test_id is not null
            if (latestResult['test_id'] != null) {
              setState(() {
                // Use tryParse to handle potential null values
                _existingTestId = int.tryParse(latestResult['test_id'].toString());
                // Set other fields as needed
              });
            } else {
              // Handle the case where 'test_id' is null
              print('Error: test_id is null in API response');
            }
          }
        } else {
          // Handle API error or null success value
          print('Error loading results: ${response['message'] ?? 'Unknown error'}');
        }
      }
    } catch (e) {
      print('Error loading results: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTermContextBar(),
                      _buildSubjectsList(),
                      const SizedBox(height: 80), // Space for save button
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (selectedSubjects.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: _saveResults,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text('Save Results'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTermContextBar() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedYear,
                  decoration: InputDecoration(
                    labelText: languageProvider.translate('school_year'),
                    border: const OutlineInputBorder(),
                  ),
                  items: _getSchoolYears()
                      .map((year) => DropdownMenuItem(
                    value: year,
                    child: Text(year),
                  ))
                      .toList(),
                  onChanged: (year) {
                    if (year != null) {
                      setState(() => selectedYear = year);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FutureBuilder<List<GradeSystem>>(
                  future: ApiService().getGradeSystemsTranslated(
                      languageProvider.selectedLanguage),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    return DropdownButtonFormField<int>(
                      value: selectedGradeSystem,
                      decoration: InputDecoration(
                        labelText:
                        languageProvider.translate('grade_system'),
                        border: const OutlineInputBorder(),
                      ),
                      items: snapshot.data!
                          .map((system) => DropdownMenuItem(
                        value: system.id,
                        child: Text(system.name),
                      ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedGradeSystem = value);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                  value: true,
                  label: Text(languageProvider.translate('full_term'))),
              ButtonSegment(
                  value: false,
                  label: Text(languageProvider.translate('mid_term'))),
            ],
            selected: {isFullTerm},
            onSelectionChanged: (selection) {
              setState(() => isFullTerm = selection.first);
            },
          ),
          const SizedBox(height: 16),
          GradesResultWidget(
            totalGrades: selectedSubjects.length.toDouble(),
            averageScore: _calculateAverageScore(),
            percentageScore: _calculatePercentageScore(),
            bonusPoints: totalBonus,
            showLifetime: showLifetimeResults,
            onToggleView: () {
              setState(() => showLifetimeResults = !showLifetimeResults);
            },
          ),
        ],
      ),
    );
  }

  List<String> _getSchoolYears() {
    final currentYear = DateTime.now().year;
    final years = <String>[];

    // Add previous year
    years.add('${currentYear - 1}/${(currentYear).toString().substring(2)}');
    // Add current year
    years.add('$currentYear/${(currentYear + 1).toString().substring(2)}');
    // Add next year
    years.add('${currentYear + 1}/${(currentYear + 2).toString().substring(2)}');

    return years;
  }

  Widget _buildSubjectsList() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Subject'),
            onPressed: _showSubjectAndGradeSelector,
          ),
          const SizedBox(height: 16),
          ...selectedSubjects.map((subject) {
            return SubjectGradeCard(
              key: ValueKey(subject.subjectId),
              subject: subject,
              onGradeChanged: (grade) => _updateGrade(subject, grade),
              onRemove: () => _removeSubject(subject),
              onTap: () async {
                // Show grade selection view with existing grade pre-selected
                try {
                  final apiService = ApiService();
                  final bonusFactors = await apiService.getBonusFactors();
                  if (!mounted) return;

                  final gradeDetails = (bonusFactors['data']['bon_grade_details'] as List? ?? [])
                      .where((grade) => grade['system_id'].toString() == selectedGradeSystem.toString())
                      .toList();

                  final result = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(_languageProvider.translate('select_grade')),
                      content: GradeSelectionView(
                        grades: gradeDetails,
                        onGradeSelected: (grade) => Navigator.pop(context, {'grade': grade}),
                      ),
                    ),
                  );

                  if (result != null && mounted) {
                    setState(() {
                      subject.setGrade(result['grade']);
                      _updateCalculations();
                    });
                  }
                } catch (e) {
                  print('DEBUG: Error updating grade: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating grade: $e')),
                    );
                  }
                }
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _saveResults,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.save),
              SizedBox(width: 8),
              Text('Save Results'),
            ],
          ),
        ),
      ),
    );
  }

  void _updateGrade(Subject subject, Grade grade) {
    setState(() {
      final index = selectedSubjects.indexOf(subject);
      if (index != -1) {
        selectedSubjects[index].setGrade(grade.toJson());
        _recalculateBonus();
      }
    });
  }

  void _removeSubject(Subject subject) {
    setState(() {
      selectedSubjects.remove(subject);
      selectedSubject = null;  // Reset selectedSubject when removing a subject
      _recalculateBonus();
    });
  }

  void _recalculateBonus() {
    double total = 0;
    for (var subject in selectedSubjects) {
      if (subject.grade != null) {
        total += subject.grade!['multiplier'] * (isFullTerm ? 1.0 : 0.5);
      }
    }
    setState(() => totalBonus = total);
  }

  void _handleSubjectSelected(Subject subject, void Function(void Function()) setDialogState) {
    // Show grade selection view after subject is selected
    final filteredGrades = bonusFactors['data']['bon_grade_details'] as List? ?? [];
    final selectedGrades = filteredGrades.where(
            (grade) => grade['system_id'].toString() == selectedGradeSystem.toString()
    ).toList();

    setDialogState(() {
      selectedSubject = subject;
    });
  }

  Future<void> _showSubjectAndGradeSelector() async {
    print('DEBUG: Starting combined subject and grade selector');
    final apiService = ApiService();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      // Pre-fetch both subjects and bonus factors at once
      final Future<List<Subject>> subjectsFuture = apiService.getSubjectsTranslated(
          languageProvider.selectedLanguage
      );
      final Future<Map<String, dynamic>> bonusFactorsFuture = apiService.getBonusFactors();

      // Wait for both to complete
      final results = await Future.wait([subjectsFuture, bonusFactorsFuture]);
      final subjects = results[0] as List<Subject>;
      bonusFactors = results[1] as Map<String, dynamic>;

      if (!mounted) return;

      // Show single dialog with both selections
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final gradeDetails = bonusFactors['data']['bon_grade_details'] as List? ?? [];
              final filteredGrades = gradeDetails.where(
                      (grade) => grade['system_id'].toString() == selectedGradeSystem.toString()
              ).toList();

              return AlertDialog(
                title: Text(selectedSubject == null ?
                languageProvider.translate('select_subject') :
                languageProvider.translate('select_grade')
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: selectedSubject == null ?
                  SubjectSelectionView(
                    key: ValueKey('subject_selection_${DateTime.now().millisecondsSinceEpoch}'),
                    subjects: subjects,
                    selectedSubjects: selectedSubjects,
                    onSubjectSelected: (subject) {
                      setDialogState(() {
                        selectedSubject = subject;
                      });
                    },
                    languageProvider: languageProvider,
                  ) :
                  GradeSelectionView(
                    grades: filteredGrades,
                    onGradeSelected: (grade) {
                      Navigator.pop(dialogContext, {
                        'subject': selectedSubject,
                        'grade': grade,
                      });
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(languageProvider.translate('cancel')),
                  ),
                  if (selectedSubject != null)
                    TextButton(
                      onPressed: () {
                        setDialogState(() => selectedSubject = null);
                      },
                      child: Text(languageProvider.translate('back')),
                    ),
                ],
              );
            },
          );
        },
      );

      // Handle the selection result
      if (result != null && mounted) {
        setState(() {
          final subject = result['subject'] as Subject;
          subject.setGrade(result['grade']);
          selectedSubjects.add(subject);
          selectedSubject = null;  // Reset selectedSubject after adding
          _updateCalculations();
        });
      }

    } catch (e, stackTrace) {
      print('DEBUG: Error in subject/grade selector: $e');
      print('DEBUG: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _saveResults() async {
    if (!_validateData()) return;

    setState(() => _isSaving = true);

    try {
      final ApiService apiService = ApiService();
      final String userId = widget.userId;

      // Prepare grades data with explicit type conversions
      final List<Map<String, String>> grades = selectedSubjects.map((s) {
        if (s.grade == null) {
          throw Exception('Grade missing for ${s.subjectName}');
        }
        return {
          'subject_id': s.subjectId.toString(),
          'subject': s.subjectName,
          'grade': s.grade!['grade_value'].toString(),
          'grade_name': s.grade!['grade_name'].toString(),
          'percentage_equivalent': s.grade!['percentage_equivalent'].toString(),
        };
      }).toList();

      final Map<String, dynamic> requestData = {
        'action': 'save_term_results',
        'action_type': _existingTestId != null ? 'update' : 'create',
        'student_id': userId,
        'school_year': selectedYear,
        'term': isFullTerm ? 'full-term' : 'mid-term',
        'grade_system_id': selectedGradeSystem.toString(),
        'total_score': totalGrades.toString(),
        'average_score': averageScore.toString(),
        'bonus_points': bonusPoints.toString(),
        'created_by': userId,
        'grades': grades
      };

      if (_existingTestId != null) {
        requestData['test_id'] = _existingTestId.toString();
      }

      final response = await apiService.makeRequest('save_term_results', requestData);

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Results saved successfully')),
          );
          setState(() {
            selectedSubjects.clear();
            _updateCalculations();
          });
        } else {
          throw Exception(response['message'] ?? 'Failed to save results');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving results: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class SubjectSelectionView extends StatefulWidget {
  final List<Subject> subjects;
  final List<Subject> selectedSubjects;
  final Function(Subject) onSubjectSelected;
  final LanguageProvider languageProvider;

  const SubjectSelectionView({
    super.key,
    required this.subjects,
    required this.selectedSubjects,
    required this.onSubjectSelected,
    required this.languageProvider,
  });

  @override
  State<SubjectSelectionView> createState() => _SubjectSelectionViewState();
}

class _SubjectSelectionViewState extends State<SubjectSelectionView> {
  @override
  Widget build(BuildContext context) {
    final groupedSubjects = Subject.groupByCategory(widget.subjects);
    print('Summary: Processing ${widget.subjects.length} total subjects for grouping');
    print('Summary: Created ${groupedSubjects.length} subject categories');
    return ListView.builder(
      itemCount: groupedSubjects.length,
      itemBuilder: (context, index) {
        final category = groupedSubjects[index];
        final categorySubjects = (category['subjects'] as List).map((s) => Subject.fromJson(s)).toList();

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ExpansionTile(
            title: Text(
              category['category_name'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: categorySubjects.map((subject) {
              final isSelected = widget.selectedSubjects
                  .any((s) => s.subjectId == subject.subjectId);
              return ListTile(
                title: Text(subject.subjectName),
                trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                enabled: !isSelected,
                tileColor: Colors.transparent,
                hoverColor: Theme.of(context).primaryColor.withOpacity(0.1),
                onTap: isSelected ? null : () => widget.onSubjectSelected(subject),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class GradeSelectionView extends StatelessWidget {
  final List<dynamic> grades;
  final Function(Map<String, dynamic>) onGradeSelected;

  const GradeSelectionView({super.key, 
    required this.grades,
    required this.onGradeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: grades.map((grade) => ListTile(
          title: Text(grade['grade_name'].toString()),
          subtitle: Text('${grade['percentage_equivalent']}%'),
          tileColor: Colors.transparent,
          hoverColor: Theme.of(context).primaryColor.withOpacity(0.1),
          onTap: () => onGradeSelected(grade),
        )).toList(),
      ),
    );
  }
}