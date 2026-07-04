import '../../domain/entities/case_entity.dart';
import '../../domain/repositories/case_repository.dart';
import '../datasources/cases_remote_data_source.dart';
import '../models/case_model.dart';

class CaseRepositoryImpl implements CaseRepository {
  final CasesRemoteDataSource remoteDataSource;

  CaseRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<CaseEntity>> getCases() async {
    return await remoteDataSource.getCases();
  }

  @override
  Future<CaseEntity> getCaseDetails(String id) async {
    return await remoteDataSource.getCaseDetails(id);
  }

  @override
  Future<void> createCase(CaseEntity newCase) async {
    final model = CaseModel(
      id: newCase.id,
      patientName: newCase.patientName,
      diagnosis: newCase.diagnosis,
      status: newCase.status,
      priority: newCase.priority,
      patientId: newCase.patientId,
      additionalInformation: newCase.additionalInformation,
    );
    await remoteDataSource.createCase(model.toAddRequestBody());
  }

  @override
  Future<void> updateCase(CaseEntity updatedCase) async {
    final model = CaseModel(
      id: updatedCase.id,
      patientName: updatedCase.patientName,
      diagnosis: updatedCase.diagnosis,
      status: updatedCase.status,
      priority: updatedCase.priority,
      patientId: updatedCase.patientId,
      additionalInformation: updatedCase.additionalInformation,
    );
    await remoteDataSource.updateCase(updatedCase.id, model.toUpdateRequestBody());
  }

  @override
  Future<void> deleteCase(String id) async {
    await remoteDataSource.deleteCase(id);
  }
}
