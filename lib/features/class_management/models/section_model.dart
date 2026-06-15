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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'school_year_id': schoolYearId,
      'grade_level': gradeLevel,
      'name': name,
      'adviser_name': adviserName,
    };
  }

  factory Section.fromMap(Map<String, dynamic> map) {
    return Section(
      id: map['id'],
      schoolYearId: map['school_year_id'],
      gradeLevel: map['grade_level'],
      name: map['name'],
      adviserName: map['adviser_name'],
    );
  }
}
