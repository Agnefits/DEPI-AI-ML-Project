import '../entities/case_entity.dart';
import '../repositories/case_repository.dart';

class GetCasesUseCase {
  final CaseRepository repository;

  GetCasesUseCase(this.repository);

  Future<List<CaseEntity>> call() async {
    return await repository.getCases();
  }
}
