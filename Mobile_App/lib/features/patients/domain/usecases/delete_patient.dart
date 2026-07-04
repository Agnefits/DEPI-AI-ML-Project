import '../repositories/patient_repository.dart';

class DeletePatient {
  final PatientRepository repository;

  DeletePatient(this.repository);

  Future<void> call(String id) async {
    return await repository.deletePatient(id);
  }
}
