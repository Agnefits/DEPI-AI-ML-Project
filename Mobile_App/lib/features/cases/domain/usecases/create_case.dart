import '../entities/case_entity.dart';
import '../repositories/case_repository.dart';

class CreateCaseUseCase {
  final CaseRepository repository;

  CreateCaseUseCase(this.repository);

  Future<void> call(CaseEntity newCase) {
    return repository.createCase(newCase);
  }
}
