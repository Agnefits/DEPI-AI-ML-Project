import '../entities/dashboard_entity.dart';
import '../repositories/dashboard_repository.dart';

class RefreshDashboardUseCase {
  final DashboardRepository repository;

  RefreshDashboardUseCase(this.repository);

  Future<DashboardEntity> call() {
    return repository.refreshDashboardData();
  }
}
