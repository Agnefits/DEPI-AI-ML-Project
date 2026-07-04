import 'package:dio/dio.dart';
import '../models/case_model.dart';
import '../../../../core/network/dio_client.dart';

abstract class CasesRemoteDataSource {
  Future<List<CaseModel>> getCases();
  Future<CaseModel> getCaseDetails(String id);
  Future<void> createCase(Map<String, dynamic> body);
  Future<void> updateCase(String id, Map<String, dynamic> body);
  Future<void> deleteCase(String id);
  Future<void> uploadCaseImage(String caseId, String filePath);
  Future<List<String>> getCaseImages(String caseId);
}

class CasesRemoteDataSourceImpl implements CasesRemoteDataSource {
  final DioClient client;

  CasesRemoteDataSourceImpl({required this.client});

  @override
  Future<List<CaseModel>> getCases() async {
    final response = await client.dio.get('/CasesApi');

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
        .map((e) => CaseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CaseModel> getCaseDetails(String id) async {
    final response = await client.dio.get('/CasesApi/$id');
    return CaseModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> createCase(Map<String, dynamic> body) async {
    await client.dio.post('/CasesApi', data: body);
  }

  @override
  Future<void> updateCase(String id, Map<String, dynamic> body) async {
    await client.dio.put('/CasesApi/$id', data: body);
  }

  @override
  Future<void> deleteCase(String id) async {
    await client.dio.delete('/CasesApi/$id');
  }

  @override
  Future<void> uploadCaseImage(String caseId, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    await client.dio.post('/ImagesApi/upload/$caseId', data: formData);
  }

  @override
  Future<List<String>> getCaseImages(String caseId) async {
    try {
      final response = await client.dio.get('/ImagesApi/$caseId');
      final data = response.data;
      if (data is List) {
        return data.map((e) => e.toString()).toList();
      }
      if (data is Map && data['data'] is List) {
        return (data['data'] as List).map((e) => e.toString()).toList();
      }
      if (data is Map && data['imageUrls'] is List) {
        return (data['imageUrls'] as List).map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }
}
