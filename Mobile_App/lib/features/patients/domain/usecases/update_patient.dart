import '../entities/patient.dart';
import '../repositories/patient_repository.dart';

class UpdatePatient {
  final PatientRepository repository;

  UpdatePatient(this.repository);

  Future<void> call(Patient patient) async {
    return await repository.updatePatient(patient);
  }
}
