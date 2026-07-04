import '../entities/patient.dart';
import '../repositories/patient_repository.dart';

class GetPatients {
  final PatientRepository repository;

  GetPatients(this.repository);

  Future<List<Patient>> call() async {
    return await repository.getPatients();
  }
}
