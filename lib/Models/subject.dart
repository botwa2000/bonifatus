// lib/models/subject.dart

class Subject {
  final int subjectId;
  final String subjectName;
  final String categoryName;
  final String categoryCode;
  final int categoryOrder;
  final double weight;
  final String? categoryNameTranslated;
  Map<String, dynamic>? _grade;

  String get gradeName => _grade?['grade_name']?.toString() ?? '';
  String get gradePercentage => _grade?['percentage_equivalent']?.toString() ?? '';

  void setGrade(Map<String, dynamic> gradeData) {
    _grade = {
      'grade_id': int.parse(gradeData['grade_id'].toString()),
      'system_id': int.parse(gradeData['system_id'].toString()),
      'grade_name': gradeData['grade_name'].toString(),
      'grade_value': double.parse(gradeData['grade_value'].toString()),
      'multiplier': double.parse(gradeData['multiplier'].toString()),
      'percentage_equivalent': double.parse(gradeData['percentage_equivalent'].toString()),
      'weight': double.parse(gradeData['weight'].toString()),
    };
  }

  Map<String, dynamic>? get grade => _grade;

  Subject({
    required this.subjectId,
    required this.subjectName,
    required this.categoryName,
    required this.categoryCode,
    required this.categoryOrder,
    this.weight = 1.0,
    this.categoryNameTranslated,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      subjectId: int.parse(json['subject_id']?.toString() ?? '-1'),
      subjectName: json['subject_name']?.toString() ?? 'Unknown Subject',
      categoryName: json['category_name']?.toString() ?? 'Other',
      categoryCode: json['category_code']?.toString() ?? 'OTHER',
      categoryOrder: int.parse(json['category_order']?.toString() ?? '999'),
      weight: double.parse(json['weight']?.toString() ?? '1.0'),
      categoryNameTranslated: json['category_name_translated']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'subject_id': subjectId,
    'subject_name': subjectName,
    'category_name': categoryName,
    'category_code': categoryCode,
    'category_order': categoryOrder,
    'weight': weight,
    'category_name_translated': categoryNameTranslated,
  };

  static List<Map<String, dynamic>> groupByCategory(List<Subject> subjects) {
    print('Summary: Processing ${subjects.length} total subjects for grouping');
    final Map<String, List<Subject>> grouped = {};
    for (var subject in subjects) {
      final categoryName = subject.categoryName;
      if (!grouped.containsKey(categoryName)) {
        grouped[categoryName] = [];
      }
      grouped[categoryName]!.add(subject);
    }
    final result = grouped.entries.map((entry) {
      return {
        'category_name': entry.key,
        'category_name_translated': entry.value.first.categoryNameTranslated,
        'category_order': entry.value.first.categoryOrder,
        'subjects': entry.value.map((s) => s.toJson()).toList()
      };
    }).toList()
      ..sort((a, b) => (a['category_order'] as int).compareTo(b['category_order'] as int));
    print('Summary: Created ${result.length} subject categories');
    return result;
  }
}