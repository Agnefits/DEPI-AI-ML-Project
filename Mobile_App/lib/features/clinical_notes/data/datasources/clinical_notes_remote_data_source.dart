import '../models/clinical_note_model.dart';
import '../../../../core/network/dio_client.dart';

abstract class ClinicalNotesRemoteDataSource {
  Future<List<ClinicalNoteModel>> getNotes();
  Future<List<ClinicalNoteModel>> getCaseNotes(String caseId);
  Future<void> addCaseNote(String caseId, Map<String, dynamic> body);
  Future<void> updateNote(String id, Map<String, dynamic> body);
  Future<void> approveNote(String id);
}

class ClinicalNotesRemoteDataSourceImpl implements ClinicalNotesRemoteDataSource {
  final DioClient client;

  ClinicalNotesRemoteDataSourceImpl({required this.client});

  @override
  Future<List<ClinicalNoteModel>> getNotes() async {
    final response = await client.dio.get('/ClinicalNotesApi');

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
        .map((e) => ClinicalNoteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ClinicalNoteModel>> getCaseNotes(String caseId) async {
    final response = await client.dio.get('/ClinicalNotesApi/case/$caseId');

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
        .map((e) => ClinicalNoteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> addCaseNote(String caseId, Map<String, dynamic> body) async {
    await client.dio.post('/ClinicalNotesApi', data: {
      'caseId': int.tryParse(caseId) ?? 0,
      ...body,
    });
  }

  @override
  Future<void> updateNote(String id, Map<String, dynamic> body) async {
    await client.dio.put('/ClinicalNotesApi/$id', data: body);
  }

  @override
  Future<void> approveNote(String id) async {
    await client.dio.post('/ClinicalNotesApi/$id/approve');
  }
}
