import '../entities/dashboard_entity.dart';

abstract class DashboardRepository {
  Future<DashboardEntity> getDashboardData();
  Future<AnalyticsEntity> getAnalyticsData();
  Future<DashboardEntity> refreshDashboardData();
}
