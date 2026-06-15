class Student {
  final int? id;
  final String fullName;
  final String? middleName; // NEW: Added for unique identification
  final String? birthdate; // NEW: Added for unique identification
  final String? gender;
  final String? photoPath;
  final String? parentContact;
  final String? emergencyContact;
  final String? address;
  final String? notes;

  Student({
    required this.id,
    required this.fullName,
    this.middleName, // NEW
    this.birthdate, // NEW
    this.gender,
    this.photoPath,
    this.parentContact,
    this.emergencyContact,
    this.address,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'middle_name': middleName, // NEW: Matches DB column
      'birthdate': birthdate, // NEW: Matches DB column
      'gender': gender,
      'photo_path': photoPath,
      'parent_contact': parentContact,
      'emergency_contact': emergencyContact,
      'address': address,
      'notes': notes,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'],
      fullName: map['full_name'],
      middleName: map['middle_name'] as String?, // NEW
      birthdate: map['birthdate'] as String?, // NEW
      gender: map['gender'] as String?,
      photoPath: map['photo_path'],
      parentContact: map['parent_contact'],
      emergencyContact: map['emergency_contact'],
      address: map['address'],
      notes: map['notes'],
    );
  }
}
