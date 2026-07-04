import 'package:equatable/equatable.dart';

class ClinicalNote extends Equatable {
  final String id;
  final String subjective;
  final String objective;
  final String assessment;
  final String plan;
  final String additionalInformation;
  final DateTime date;
  final String patientName;

  const ClinicalNote({
    required this.id,
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
    required this.additionalInformation,
    required this.date,
    required this.patientName,
  });

  @override
  List<Object?> get props => [id, subjective, objective, assessment, plan, additionalInformation, date, patientName];
}
