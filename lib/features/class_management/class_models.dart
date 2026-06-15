class SchoolYear {
  final String id;
  final String name;
  final bool isActive;

  SchoolYear({required this.id, required this.name, required this.isActive});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'is_active': isActive ? 1 : 0,
  };
}

class Section {
  final String id;
  final String schoolYearId;
  final int gradeLevel;
  final String name;
  final String? adviserName;

  Section({
    required this.id,
    required this.schoolYearId,
    required this.gradeLevel,
    required this.name,
    this.adviserName,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'school_year_id': schoolYearId,
    'grade_level': gradeLevel,
    'name': name,
    'adviser_name': adviserName,
  };
}
