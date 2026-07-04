import '../models/patient_model.dart';
import '../../../../core/network/dio_client.dart';
import '../../../auth/data/datasources/auth_local_data_source.dart';

abstract class PatientsRemoteDataSource {
  Future<List<PatientModel>> getPatients();
  Future<PatientModel> getPatient(String id);
  Future<void> addPatient(Map<String, dynamic> body);
  Future<void> updatePatient(String id, Map<String, dynamic> body);
  Future<void> deletePatient(String id);
}

class PatientsRemoteDataSourceImpl implements PatientsRemoteDataSource {
  final DioClient client;
  final AuthLocalDataSource authLocalDataSource;

  PatientsRemoteDataSourceImpl({
    required this.client,
    required this.authLocalDataSource,
  });

  @override
  Future<List<PatientModel>> getPatients() async {
    final response = await client.dio.get('/PatientsApi');

    final data = response.data;
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map && data['data'] is List) {
      list = data['data'] as List<dynamic>;
    } else {
      return [];
    }

    return list
        .map((e) => PatientModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PatientModel> getPatient(String id) async {
    final response = await client.dio.get('/PatientsApi/$id');
    return PatientModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> addPatient(Map<String, dynamic> body) async {
    final auth = await authLocalDataSource.loadAuth();
    body['doctorId'] = int.tryParse(auth?.id ?? '') ?? 0;

    await client.dio.post('/PatientsApi', data: body);
  }

  @override
  Future<void> updatePatient(String id, Map<String, dynamic> body) async {
    final auth = await authLocalDataSource.loadAuth();
    body['doctorId'] = int.tryParse(auth?.id ?? '') ?? 0;

    await client.dio.put('/PatientsApi/$id', data: body);
  }

  @override
  Future<void> deletePatient(String id) async {
    await client.dio.delete('/PatientsApi/$id');
  }
}
