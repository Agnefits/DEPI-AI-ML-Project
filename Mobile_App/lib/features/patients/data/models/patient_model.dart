import '../../domain/entities/patient.dart';

class PatientModel extends Patient {
  const PatientModel({
    required super.id,
    required super.name,
    required super.gender,
    required super.phoneNumber,
    required super.email,
    required super.bloodGroup,
    required super.condition,
    required super.lastVisit,
    required super.status,
    super.address,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? json['fullName'] ?? json['patientName'] ?? '') as String,
      gender: (json['gender'] ?? json['sex'] ?? '') as String,
      phoneNumber: (json['phoneNumber'] ?? json['phone'] ?? json['mobile'] ?? '') as String,
      email: (json['email'] ?? json['emailAddress'] ?? '') as String,
      bloodGroup: (json['bloodGroup'] ?? json['bloodType'] ?? json['blood_group'] ?? '') as String,
      condition: (json['condition'] ?? json['diagnosis'] ?? json['medicalCondition'] ?? json['additionalInformation'] ?? '') as String,
      lastVisit: _parseDate(json['lastVisit'] ?? json['lastVisitDate'] ?? json['last_visit']),
      status: (json['status'] ?? json['patientStatus'] ?? '') as String,
      address: (json['address'] ?? '') as String,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  Map<String, dynamic> toAddRequestBody() {
    return {
      'medicalRecordNumber': 'REC-${DateTime.now().millisecondsSinceEpoch}',
      'fullName': name,
      'gender': gender,
      'phone': phoneNumber,
      'address': address,
      'bloodGroup': bloodGroup,
      'additionalInformation': condition,
      'doctorId': 0,
    };
  }

  Map<String, dynamic> toUpdateRequestBody() {
    return {
      'fullName': name,
      'gender': gender,
      'phone': phoneNumber,
      'address': address,
      'bloodGroup': bloodGroup,
      'additionalInformation': condition,
      'doctorId': 0,
      'isArchived': false,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'phoneNumber': phoneNumber,
      'email': email,
      'bloodGroup': bloodGroup,
      'condition': condition,
      'lastVisit': lastVisit.toIso8601String(),
      'status': status,
    };
  }

  factory PatientModel.fromEntity(Patient patient) {
    return PatientModel(
      id: patient.id,
      name: patient.name,
      gender: patient.gender,
      phoneNumber: patient.phoneNumber,
      email: patient.email,
      bloodGroup: patient.bloodGroup,
      condition: patient.condition,
      lastVisit: patient.lastVisit,
      status: patient.status,
      address: patient.address,
    );
  }
}
