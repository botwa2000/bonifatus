// lib/models/student_invitation_model.dart

class StudentInvitation {
  final String parentId;
  final String? studentEmail;
  final String firstName;
  final String lastName;
  final String? loginCode;
  final bool usesParentEmail;
  final DateTime expiryDate;

  StudentInvitation({
    required this.parentId,
    this.studentEmail,
    required this.firstName,
    required this.lastName,
    this.loginCode,
    required this.usesParentEmail,
    required this.expiryDate,
  });

  factory StudentInvitation.fromJson(Map<String, dynamic> json) {
    return StudentInvitation(
      parentId: json['parent_id'].toString(),
      studentEmail: json['student_email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      loginCode: json['login_code'],
      usesParentEmail: json['uses_parent_email'] == 1 || json['uses_parent_email'] == true,
      expiryDate: DateTime.parse(json['expiry_date']),
    );
  }

  Map<String, dynamic> toJson() => {
    'parent_id': parentId,
    'student_email': studentEmail,
    'first_name': firstName,
    'last_name': lastName,
    'login_code': loginCode,
    'uses_parent_email': usesParentEmail,
    'expiry_date': expiryDate.toIso8601String(),
  };
}