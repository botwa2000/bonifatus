class Student {
  final int id;
  final int userId;
  final int parentUserId;
  final int gradeLevel;
  final String schoolYear;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? schoolName;
  final int? schoolId;
  final int currentGradeSystemId;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Student({
    required this.id,
    required this.userId,
    required this.parentUserId,
    required this.gradeLevel,
    required this.schoolYear,
    required this.currentGradeSystemId,
    this.dateOfBirth,
    this.gender,
    this.schoolName,
    this.schoolId,
    this.status = 'active',
    required this.createdAt,
    this.updatedAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['student_id'],
      userId: json['student_user_id'],
      parentUserId: json['parent_user_id'],
      gradeLevel: json['grade_level'],
      schoolYear: json['school_year'],
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'])
          : null,
      gender: json['gender'],
      schoolName: json['school_name'],
      schoolId: json['school_id'],
      currentGradeSystemId: json['current_grade_system_id'],
      status: json['status'] ?? 'active',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}