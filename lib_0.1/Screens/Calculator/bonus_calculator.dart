import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../Services/api_service.dart';
import '../../Providers/language_provider.dart';
import '../../models/subject.dart';
import '../../models/grading_models.dart';

class BonusCalculator extends StatefulWidget {
  const BonusCalculator({super.key});

  @override
  State<BonusCalculator> createState() => _BonusCalculatorState();
}

class SubjectSorter {
  static int compare(Subject a, Subject b) {
    try {
      int categoryCompare = a.categoryOrder.compareTo(b.categoryOrder);
      if (categoryCompare != 0) return categoryCompare;
      return a.subjectName.compareTo(b.subjectName);
    } catch (e) {
      print('Error comparing subjects: $e');
      return 0;
    }
  }

  static bool areEqual(Subject subject1, Subject subject2) {
    try {
      return subject1.subjectId == subject2.subjectId;
    } catch (e) {
      print('Error comparing subjects: $e');
      return false;
    }
  }
}

class _BonusCalculatorState extends State<BonusCalculator> {
  final ApiService _apiService = ApiService();
  late final LanguageProvider _languageProvider;

  LanguageProvider get languageProvider => _languageProvider;

  List<GradeSystem> gradeSystems = [];
  List<Grade> gradeDetails = [];
  List<Subject> subjects = [];
  List<GradeFactor> defaultFactors = [];
  List<ClassFactor> classFactors = [];
  List<Subject> selectedSubjects = [];

  String childName = '';
  int childClass = 1;
  int selectedGradeSystem = 1;
  bool isFullTerm = true;
  double totalGrades = 0;
  double averageScore = 0;
  double bonusPoints = 0;
  double percentageScore = 0;
  bool _isLoading = false;
  String? _previousLanguage;

  final Set<String> _expandedCategories = {};

  TextEditingController classController = TextEditingController(text: '1');

  GradeFactor getGradeFactor(String name, double defaultValue) {
    try {
      return defaultFactors.firstWhere(
            (f) => f.name == name,
        orElse: () => GradeFactor(name: name, value: defaultValue),
      );
    } catch (e) {
      return GradeFactor(name: name, value: defaultValue);
    }
  }

// Updated term factor method
  double getTermFactor(bool isFullTerm) {
    final factor = getGradeFactor(
        isFullTerm ? 'term_factor_full' : 'term_factor_mid',
        isFullTerm ? 1.0 : 0.5
    );
    return factor.value;
  }

// Updated class factor method
  double getClassFactor(int classLevel) {
    try {
      return classFactors.firstWhere(
            (f) => f.classId == classLevel,
        orElse: () => ClassFactor(
          classId: classLevel,
          value: classLevel.toDouble(),
        ),
      ).value;
    } catch (e) {
      return classLevel.toDouble();
    }
  }

  @override
  void initState() {
    super.initState();
    _languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLanguage = Provider.of<LanguageProvider>(context).selectedLanguage;
    if (_previousLanguage != newLanguage) {
      _previousLanguage = newLanguage;
      refreshTranslations();
    }
  }

  @override
  void dispose() {
    classController.dispose();
    super.dispose();
  }

  void printDebug(String message) {
    print('\n========== DEBUG ==========');
    print(message);
    print('==========================\n');
  }

  void refreshTranslations() async {
    if (!mounted) return;

    try {
      final translatedSystems = await _apiService.getGradeSystemsTranslated(
          _languageProvider.selectedLanguage
      );

      if (mounted) {
        setState(() {
          gradeSystems = translatedSystems;
          if (translatedSystems.isNotEmpty &&
              !translatedSystems.any((s) => s.id == selectedGradeSystem)) {
            selectedGradeSystem = translatedSystems[0].id;
          }
        });
      }
    } catch (e) {
      print('Error refreshing translations: $e');
    }
  }

  void fetchData() async {
    setState(() => _isLoading = true);

    try {
      final fetchedSubjects = await _apiService.getSubjectsTranslated(
          languageProvider.selectedLanguage
      );

      if (mounted) {
        setState(() {
          subjects = fetchedSubjects;
          subjects.sort(SubjectSorter.compare);
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void updateCalculations() {
    if (selectedSubjects.isEmpty) {
      setState(() {
        totalGrades = 0;
        averageScore = 0;
        percentageScore = 0;
        bonusPoints = 0;
      });
      return;
    }

    int validGradeCount = 0;
    double totalGradePoints = 0;
    double totalBonusPoints = 0;
    double totalPercentage = 0;

    double termFactor = getTermFactor(isFullTerm);
    double classFactor = getClassFactor(childClass);

    for (var subject in selectedSubjects) {
      if (subject.grade != null) {
        final grade = Grade.fromJson(subject.grade!);
        totalGradePoints += grade.value;
        totalBonusPoints += grade.multiplier;
        totalPercentage += grade.percentageEquivalent;
        validGradeCount++;
      }
    }

    totalBonusPoints *= termFactor * classFactor;
    totalBonusPoints = totalBonusPoints.clamp(0, double.infinity);

    setState(() {
      totalGrades = validGradeCount.toDouble();
      averageScore = validGradeCount > 0 ? totalGradePoints / validGradeCount : 0;
      percentageScore = validGradeCount > 0 ? totalPercentage / validGradeCount : 0;
      bonusPoints = totalBonusPoints;
    });
  }

  void incrementClass() {
    if (childClass < 12) {
      setState(() {
        childClass++;
        classController.text = childClass.toString();
        updateCalculations();
      });
    }
  }

  void decrementClass() {
    if (childClass > 1) {
      setState(() {
        childClass--;
        classController.text = childClass.toString();
        updateCalculations();
      });
    }
  }

  Future<void> _showGradeDialog(Subject subject) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Grade for ${subject.subjectName}'),
          content: FutureBuilder<Map<String, dynamic>>(
            future: _apiService.getBonusFactors(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }

              final gradeDetails = (snapshot.data?['data']?['bon_grade_details'] as List? ?? [])
                  .where((grade) {
                String gradeSystemId = grade['system_id'].toString();
                String selectedId = selectedGradeSystem.toString();
                return gradeSystemId == selectedId;
              }).toList();

              return SingleChildScrollView(
                child: ListBody(
                  children: gradeDetails.map<Widget>((grade) {
                    String percentage = grade['percentage_equivalent'].toString();
                    String percentageDisplay = percentage != "0" ? "$percentage%" : "";

                    return ListTile(
                      title: Text(grade['grade_name'].toString()),
                      subtitle: Text(percentageDisplay),
                      onTap: () {
                        setState(() {
                          subject.setGrade({
                            'grade_id': int.parse(grade['grade_id'].toString()),
                            'system_id': int.parse(grade['system_id'].toString()),
                            'grade_name': grade['grade_name'].toString(),
                            'grade_value': double.parse(grade['grade_value'].toString()),
                            'multiplier': double.parse(grade['multiplier'].toString()),
                            'percentage_equivalent': double.parse(grade['percentage_equivalent'].toString()),
                            'weight': double.parse(grade['weight'].toString()),
                          });
                          updateCalculations();
                        });
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showSubjectDialog() {
    final searchController = TextEditingController();
    List<Subject> filteredSubjects = List.from(subjects);
    Set<String> expandedCategories = {};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (searchController.text.isNotEmpty) {
            filteredSubjects = subjects.where((subject) {
              return subject.subjectName
                  .toLowerCase()
                  .contains(searchController.text.toLowerCase());
            }).toList();
            expandedCategories = filteredSubjects
                .map((subject) => subject.categoryName)
                .toSet();
          } else {
            filteredSubjects = List.from(subjects);
            expandedCategories = {};
          }

          final groupedSubjects = Subject.groupByCategory(filteredSubjects);

          return AlertDialog(
            title: Text(
              languageProvider.translate('select_subject'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  // Enhanced search field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        hintText: languageProvider.translate('search_subjects'),
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                      ),
                      onChanged: (value) => setDialogState(() {}),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Enhanced list
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: groupedSubjects.length,
                      itemBuilder: (context, index) {
                        final category = groupedSubjects[index];
                        final categorySubjects = (category['subjects'] as List)
                            .map((s) => Subject.fromJson(Map<String, dynamic>.from(s)))
                            .toList();

                        if (categorySubjects.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              key: Key(category['category_name']),
                              initiallyExpanded: expandedCategories.contains(category['category_name']),
                              title: Text(
                                category['category_name_translated'] ?? category['category_name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              backgroundColor: Colors.transparent,
                              children: categorySubjects.map((subject) {
                                bool isSelected = selectedSubjects
                                    .any((s) => SubjectSorter.areEqual(s, subject));
                                return Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ?
                                    Theme.of(context).primaryColor.withOpacity(0.1) :
                                    Colors.transparent,
                                    border: Border(
                                      bottom: BorderSide(color: Colors.grey.shade200),
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 4,
                                    ),
                                    title: Text(
                                      subject.subjectName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: isSelected ?
                                        Theme.of(context).primaryColor :
                                        null,
                                      ),
                                    ),
                                    trailing: isSelected ?
                                    Icon(
                                      Icons.check_circle,
                                      color: Theme.of(context).primaryColor,
                                    ) : null,
                                    onTap: () {
                                      if (!isSelected) {
                                        setState(() {
                                          selectedSubjects.add(subject);
                                          selectedSubjects.sort(SubjectSorter.compare);
                                        });
                                        updateCalculations();
                                        Navigator.pop(context);
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                              onExpansionChanged: (expanded) {
                                setDialogState(() {
                                  if (expanded) {
                                    expandedCategories.add(category['category_name']);
                                  } else {
                                    expandedCategories.remove(category['category_name']);
                                  }
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  languageProvider.translate('cancel'),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check for error message
    if (languageProvider.translate('error_message') != 'error_message') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              languageProvider.translate('error_message'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: fetchData,
              child: Text(languageProvider.translate('retry')),
            ),
          ],
        ),
      );
    }

    if (gradeSystems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              languageProvider.translate('error_loading_data'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: fetchData,
              child: Text(languageProvider.translate('retry')),
            ),
          ],
        ),
      );
    }


  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: languageProvider.translate('student_name'),
          ),
          onChanged: (value) => setState(() => childName = value),
        ),
        const SizedBox(height: 16),

        // Class selection
        Row(
          children: [
            Text(languageProvider.translate('student_class')),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: decrementClass,
            ),
            SizedBox(
              width: 50,
              child: TextField(
                controller: classController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ClassTextInputFormatter(),
                ],
                onChanged: (value) {
                  setState(() {
                    childClass = int.tryParse(value) ?? 1;
                    updateCalculations();
                  });
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: incrementClass,
            ),
          ],
        ),
        const SizedBox(height: 16),

          // Grade system dropdown
        DropdownButton<int>(
          value: selectedGradeSystem,
          items: gradeSystems.map<DropdownMenuItem<int>>((system) {
            return DropdownMenuItem<int>(
              value: system.id,  // Access the id directly from the GradeSystem object
              child: Text(system.name),  // Access the name directly
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                selectedGradeSystem = value;
                updateCalculations();
              });
            }
          },
        ),
          const SizedBox(height: 16),

          // Term selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                languageProvider.translate('full_term'),
                style: TextStyle(
                  fontWeight: isFullTerm ? FontWeight.bold : FontWeight.normal,
                  color: isFullTerm ? Colors.black : Colors.grey,
                ),
              ),
              Switch(
                value: isFullTerm,
                onChanged: (value) {
                  setState(() {
                    isFullTerm = value;
                    updateCalculations();
                  });
                },
              ),
              Text(
                languageProvider.translate('mid_term'),
                style: TextStyle(
                  fontWeight: isFullTerm ? FontWeight.normal : FontWeight.bold,
                  color: isFullTerm ? Colors.grey : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Add subject button
          ElevatedButton(
            child: Text(languageProvider.translate('add_subject')),
            onPressed: () => _showSubjectDialog(),
          ),

          // Selected subjects list
        ...selectedSubjects.map((subject) => ListTile(
          title: Text(subject.subjectName),
          subtitle: Text(subject.grade != null
              ? '${subject.gradeName} (${subject.gradePercentage}%)'
              : languageProvider.translate('no_grade')),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              setState(() {
                selectedSubjects.remove(subject);
              });
              updateCalculations();
            },
          ),
          onTap: () => _showGradeDialog(subject),
        )),
          const SizedBox(height: 20),

          // Results display
          Text('${languageProvider.translate('total_grades')}: ${totalGrades.toStringAsFixed(2)}'),
          Text('${languageProvider.translate('average_score')}: ${averageScore.toStringAsFixed(2)} (${percentageScore.toStringAsFixed(1)}%)'),
          Text('${languageProvider.translate('bonus_points')}: ${bonusPoints.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}


class _ClassTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '1');
    }
    int value = int.tryParse(newValue.text) ?? 1;
    if (value < 1) value = 1;
    if (value > 12) value = 12;
    return TextEditingValue(
      text: value.toString(),
      selection: TextSelection.collapsed(offset: value.toString().length),
    );
  }
}
