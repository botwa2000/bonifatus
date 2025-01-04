// lib/models/grading_models.dart

class GradeSystem {
  final int id;
  final String name;
  final String calculationType;
  final double? maxGrade;
  final double? minGrade;
  final double? passingGrade;

  GradeSystem({
    required this.id,
    required this.name,
    required this.calculationType,
    this.maxGrade,
    this.minGrade,
    this.passingGrade,
  });

  factory GradeSystem.fromJson(Map<String, dynamic> json) {
    return GradeSystem(
      id: int.parse(json['system_id']?.toString() ?? '-1'),
      name: json['system_name']?.toString() ?? 'Unknown System',
      calculationType: json['calculation_type']?.toString() ?? 'weighted_average',
      maxGrade: double.tryParse(json['max_grade']?.toString() ?? ''),
      minGrade: double.tryParse(json['min_grade']?.toString() ?? ''),
      passingGrade: double.tryParse(json['passing_grade']?.toString() ?? ''),
    );
  }
}

class Grade {
  final int id;
  final int systemId;
  final String name;
  final double value;
  final double multiplier;
  final double percentageEquivalent;
  final double weight;

  Grade({
    required this.id,
    required this.systemId,
    required this.name,
    required this.value,
    required this.multiplier,
    required this.percentageEquivalent,
    this.weight = 1.0,
  });

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      id: int.parse(json['grade_id'].toString()),
      systemId: int.parse(json['system_id'].toString()),
      name: json['grade_name'].toString(),
      value: double.parse(json['grade_value'].toString()),
      multiplier: double.parse(json['multiplier'].toString()),
      percentageEquivalent: double.parse(json['percentage_equivalent'].toString()),
      weight: double.parse(json['weight']?.toString() ?? '1.0'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'grade_id': id,
      'system_id': systemId,
      'grade_name': name,
      'grade_value': value,
      'multiplier': multiplier,
      'percentage_equivalent': percentageEquivalent,
      'weight': weight,
    };
  }

}

class GradeFactor {
  final String name;
  final double value;

  GradeFactor({required this.name, required this.value});

  factory GradeFactor.fromJson(Map<String, dynamic> json) {
    return GradeFactor(
      name: json['name'] as String,
      value: double.parse(json['value'].toString()),
    );
  }
}

class ClassFactor {
  final int classId;
  final double value;

  ClassFactor({required this.classId, required this.value});

  factory ClassFactor.fromJson(Map<String, dynamic> json) {
    return ClassFactor(
      classId: int.parse(json['class_id'].toString()),
      value: double.parse(json['value'].toString()),
    );
  }
}