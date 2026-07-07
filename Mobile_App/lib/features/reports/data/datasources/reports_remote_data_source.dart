import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';

abstract class ReportsRemoteDataSource {
  Future<Uint8List> generateReport(String caseId);
}

class ReportsRemoteDataSourceImpl implements ReportsRemoteDataSource {
  final DioClient client;

  ReportsRemoteDataSourceImpl({required this.client});

  @override
  Future<Uint8List> generateReport(String caseId) async {
    final response = await client.dio.post(
      '/ReportsApi/generate/$caseId',
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.data is Uint8List) return response.data as Uint8List;
    throw Exception('Unexpected response format');
  }
}