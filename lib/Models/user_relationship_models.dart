// lib/models/user_relationship_models.dart

enum UserType { parent, student }
enum RelationshipStatus { pending, active, rejected }

class User {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final UserType userType;
  final bool isVerified;
  final String? verificationCode;
  final DateTime? verificationExpiry;
  final DateTime createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.userType,
    required this.isVerified,
    this.verificationCode,
    this.verificationExpiry,
    required this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      userType: UserType.values.firstWhere(
            (e) => e.toString().split('.').last == json['user_type'],
        orElse: () => UserType.student,
      ),
      isVerified: json['is_verified'] == 1,
      verificationCode: json['verification_code'],
      verificationExpiry: json['verification_expiry'] != null
          ? DateTime.parse(json['verification_expiry'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}

class ParentStudentRelationship {
  final int id;
  final int parentId;
  final int studentId;
  final RelationshipStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Student? student;
  final User? parent;

  ParentStudentRelationship({
    required this.id,
    required this.parentId,
    required this.studentId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.student,
    this.parent,
  });

  factory ParentStudentRelationship.fromJson(Map<String, dynamic> json) {
    return ParentStudentRelationship(
      id: json['relationship_id'],
      parentId: json['parent_id'],
      studentId: json['student_id'],
      status: RelationshipStatus.values.firstWhere(
            (e) => e.toString().split('.').last == json['status'],
        orElse: () => RelationshipStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      student: json['student'] != null
          ? Student.fromJson(json['student'])
          : null,
      parent: json['parent'] != null
          ? User.fromJson(json['parent'])
          : null,
    );
  }
}

class StudentInvitation {
  final int id;
  final int parentId;
  final String? studentEmail;
  final String invitationCode;
  final DateTime expiryDate;
  final bool isAccepted;
  final DateTime createdAt;
  final DateTime? updatedAt;

  StudentInvitation({
    required this.id,
    required this.parentId,
    this.studentEmail,
    required this.invitationCode,
    required this.expiryDate,
    required this.isAccepted,
    required this.createdAt,
    this.updatedAt,
  });

  factory StudentInvitation.fromJson(Map<String, dynamic> json) {
    return StudentInvitation(
      id: json['invitation_id'],
      parentId: json['parent_id'],
      studentEmail: json['student_email'],
      invitationCode: json['invitation_code'],
      expiryDate: DateTime.parse(json['expiry_date']),
      isAccepted: json['is_accepted'] == 1,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}

class Student {
  final int id;
  final int userId;
  final int parentUserId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? loginCode;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Student({
    required this.id,
    required this.userId,
    required this.parentUserId,
    required this.firstName,
    required this.lastName,
    this.email,
    this.loginCode,
    required this.createdAt,
    this.updatedAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['student_id'],
      userId: json['student_user_id'],
      parentUserId: json['parent_user_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      loginCode: json['login_code'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}