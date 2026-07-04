import 'package:equatable/equatable.dart';

class CaseEntity extends Equatable {
  final String id;
  final String patientName;
  final String diagnosis;
  final String status;
  final String priority;
  final int patientId;
  final String additionalInformation;

  const CaseEntity({
    required this.id,
    required this.patientName,
    this.diagnosis = '',
    required this.status,
    required this.priority,
    this.patientId = 0,
    this.additionalInformation = '',
  });

  @override
  List<Object?> get props => [id, patientName, diagnosis, status, priority, patientId, additionalInformation];
}
