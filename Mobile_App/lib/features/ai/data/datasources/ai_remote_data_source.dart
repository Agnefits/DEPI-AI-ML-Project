import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';

abstract class AiRemoteDataSource {
  Future<String> classify(int caseId, String filePath);
  Future<String> analyze(int caseId, String prompt, String filePath);
}

class AiRemoteDataSourceImpl implements AiRemoteDataSource {
  final DioClient client;

  AiRemoteDataSourceImpl({required this.client});

  @override
  Future<String> classify(int caseId, String filePath) async {
    final formData = FormData.fromMap({
      'caseId': caseId,
      'file': await MultipartFile.fromFile(filePath),
    });

    final response = await client.dio.post(
      '/Ai/classify',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return response.data?.toString() ?? 'Success';
  }

  @override
  Future<String> analyze(int caseId, String prompt, String filePath) async {
    final formData = FormData.fromMap({
      'prompt': prompt,
      'caseId': caseId,
      'file': await MultipartFile.fromFile(filePath),
    });

    final response = await client.dio.post(
      '/Ai/analyze',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return response.data?.toString() ?? 'Success';
  }
}
