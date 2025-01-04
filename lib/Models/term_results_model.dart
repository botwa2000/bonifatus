// lib/models/term_results_model.dart

class TermResult {
  final int studentId;
  final String schoolYear;
  final bool isFullTerm;
  final List<Map<String, dynamic>> grades;
  final double averageScore;
  final double percentageScore;
  final double totalBonus;
  final DateTime savedAt;

  TermResult({
    required this.studentId,
    required this.schoolYear,
    required this.isFullTerm,
    required this.grades,
    required this.averageScore,
    required this.percentageScore,
    required this.totalBonus,
    required this.savedAt,
  });

  factory TermResult.fromJson(Map<String, dynamic> json) {
    return TermResult(
      studentId: int.parse(json['student_id'].toString()),
      schoolYear: json['school_year'],
      isFullTerm: json['is_full_term'],
      grades: List<Map<String, dynamic>>.from(json['grades']),
      averageScore: double.parse(json['average_score'].toString()),
      percentageScore: double.parse(json['percentage_score'].toString()),
      totalBonus: double.parse(json['total_bonus'].toString()),
      savedAt: DateTime.parse(json['saved_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'student_id': studentId,
    'school_year': schoolYear,
    'is_full_term': isFullTerm,
    'grades': grades,
    'average_score': averageScore,
    'percentage_score': percentageScore,
    'total_bonus': totalBonus,
    'saved_at': savedAt.toIso8601String(),
  };
}