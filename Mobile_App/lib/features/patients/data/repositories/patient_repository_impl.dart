import '../../domain/entities/patient.dart';
import '../../domain/repositories/patient_repository.dart';
import '../datasources/patients_remote_data_source.dart';
import '../models/patient_model.dart';

class PatientRepositoryImpl implements PatientRepository {
  final PatientsRemoteDataSource remoteDataSource;

  PatientRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Patient>> getPatients() async {
    return await remoteDataSource.getPatients();
  }

  @override
  Future<Patient> getPatient(String id) async {
    return await remoteDataSource.getPatient(id);
  }

  @override
  Future<void> addPatient(Patient patient) async {
    final body = PatientModel.fromEntity(patient).toAddRequestBody();
    await remoteDataSource.addPatient(body);
  }

  @override
  Future<void> updatePatient(Patient patient) async {
    final body = PatientModel.fromEntity(patient).toUpdateRequestBody();
    await remoteDataSource.updatePatient(patient.id, body);
  }

  @override
  Future<void> deletePatient(String id) async {
    await remoteDataSource.deletePatient(id);
  }
}
