import '../entities/dashboard_entity.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardDataUseCase {
  final DashboardRepository repository;

  GetDashboardDataUseCase(this.repository);

  Future<DashboardEntity> call() {
    return repository.getDashboardData();
  }
}
