import '../../domain/entities/clinical_note.dart';

class ClinicalNoteModel extends ClinicalNote {
  const ClinicalNoteModel({
    required super.id,
    required super.subjective,
    required super.objective,
    required super.assessment,
    required super.plan,
    required super.additionalInformation,
    required super.date,
    required super.patientName,
  });

  factory ClinicalNoteModel.fromJson(Map<String, dynamic> json) {
    return ClinicalNoteModel(
      id: json['id']?.toString() ?? '',
      subjective: (json['subjective'] ?? '') as String,
      objective: (json['objective'] ?? '') as String,
      assessment: (json['assessment'] ?? '') as String,
      plan: (json['plan'] ?? '') as String,
      additionalInformation: (json['additionalInformation'] ?? '') as String,
      date: _parseDate(json['date'] ?? json['createdAt'] ?? json['timestamp']),
      patientName: (json['patientName'] ?? json['patient'] ?? json['patient_name'] ?? '') as String,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjective': subjective,
      'objective': objective,
      'assessment': assessment,
      'plan': plan,
      'additionalInformation': additionalInformation,
      'patientName': patientName,
    };
  }

  factory ClinicalNoteModel.fromEntity(ClinicalNote entity) {
    return ClinicalNoteModel(
      id: entity.id,
      subjective: entity.subjective,
      objective: entity.objective,
      assessment: entity.assessment,
      plan: entity.plan,
      additionalInformation: entity.additionalInformation,
      date: entity.date,
      patientName: entity.patientName,
    );
  }
}
