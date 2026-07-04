import '../entities/case_entity.dart';
import '../repositories/case_repository.dart';

class UpdateCaseUseCase {
  final CaseRepository repository;

  UpdateCaseUseCase(this.repository);

  Future<void> call(CaseEntity updatedCase) {
    return repository.updateCase(updatedCase);
  }
}
