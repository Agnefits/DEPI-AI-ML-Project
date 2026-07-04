import '../repositories/case_repository.dart';

class DeleteCaseUseCase {
  final CaseRepository repository;

  DeleteCaseUseCase(this.repository);

  Future<void> call(String id) {
    return repository.deleteCase(id);
  }
}
