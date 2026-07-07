import '../../domain/entities/case_entity.dart';

class CaseModel extends CaseEntity {
  const CaseModel({
    required super.id,
    required super.patientName,
    super.diagnosis,
    required super.status,
    required super.priority,
    super.patientId,
    super.additionalInformation,
  });

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    return CaseModel(
      id: json['id']?.toString() ?? '',
      patientName: (json['patientName'] ?? json['patient'] ?? json['patient_name'] ?? '') as String,
      diagnosis: (json['diagnosis'] ?? json['condition'] ?? '') as String,
      status: (json['status'] ?? json['caseStatus'] ?? 'active') as String,
      priority: (json['priority'] ?? json['casePriority'] ?? 'medium') as String,
      patientId: int.tryParse(json['patientId']?.toString() ?? '') ?? 0,
      additionalInformation: (json['additionalInformation'] ?? json['notes'] ?? '') as String,
    );
  }

  Map<String, dynamic> toAddRequestBody() {
    return {
      'patientId': patientId,
      'priority': priority,
      'additionalInformation': additionalInformation,
    };
  }

  Map<String, dynamic> toUpdateRequestBody() {
    return {
      'status': status,
      'priority': priority,
      'additionalInformation': additionalInformation,
    };
  }
}
