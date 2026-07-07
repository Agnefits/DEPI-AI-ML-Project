import '../entities/case_entity.dart';

abstract class CaseRepository {
  Future<List<CaseEntity>> getCases();
  Future<CaseEntity> getCaseDetails(String id);
  Future<void> createCase(CaseEntity newCase);
  Future<void> updateCase(CaseEntity updatedCase);
  Future<void> deleteCase(String id);
}
