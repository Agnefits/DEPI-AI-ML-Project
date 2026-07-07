import '../entities/dashboard_entity.dart';
import '../repositories/dashboard_repository.dart';

class GetAnalyticsDataUseCase {
  final DashboardRepository repository;

  GetAnalyticsDataUseCase(this.repository);

  Future<AnalyticsEntity> call() {
    return repository.getAnalyticsData();
  }
}
