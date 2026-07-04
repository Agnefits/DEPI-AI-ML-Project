import '../entities/patient.dart';
import '../repositories/patient_repository.dart';

class AddPatient {
  final PatientRepository repository;

  AddPatient(this.repository);

  Future<void> call(Patient patient) async {
    return await repository.addPatient(patient);
  }
}
