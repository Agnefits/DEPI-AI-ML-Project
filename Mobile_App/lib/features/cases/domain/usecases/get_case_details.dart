import '../entities/case_entity.dart';
import '../repositories/case_repository.dart';

class GetCaseDetailsUseCase {
  final CaseRepository repository;

  GetCaseDetailsUseCase(this.repository);

  Future<CaseEntity> call(String id) {
    return repository.getCaseDetails(id);
  }
}
