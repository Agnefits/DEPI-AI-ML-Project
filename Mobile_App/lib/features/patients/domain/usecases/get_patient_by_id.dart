import '../entities/patient.dart';
import '../repositories/patient_repository.dart';

class GetPatientById {
  final PatientRepository repository;

  GetPatientById(this.repository);

  Future<Patient> call(String id) async {
    return await repository.getPatient(id);
  }
}
