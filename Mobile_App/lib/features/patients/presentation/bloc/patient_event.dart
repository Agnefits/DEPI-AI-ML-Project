import 'package:equatable/equatable.dart';
import '../../domain/entities/patient.dart';

abstract class PatientEvent extends Equatable {
  const PatientEvent();

  @override
  List<Object> get props => [];
}

class LoadPatientsEvent extends PatientEvent {}

class AddPatientEvent extends PatientEvent {
  final Patient patient;

  const AddPatientEvent(this.patient);

  @override
  List<Object> get props => [patient];
}

class UpdatePatientEvent extends PatientEvent {
  final Patient patient;

  const UpdatePatientEvent(this.patient);

  @override
  List<Object> get props => [patient];
}
