import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_analytics_data_usecase.dart';
import '../../domain/usecases/get_dashboard_data_usecase.dart';
import '../../domain/usecases/refresh_dashboard_usecase.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final GetDashboardDataUseCase getDashboardDataUseCase;
  final GetAnalyticsDataUseCase getAnalyticsDataUseCase;
  final RefreshDashboardUseCase refreshDashboardUseCase;

  DashboardBloc({
    required this.getDashboardDataUseCase,
    required this.getAnalyticsDataUseCase,
    required this.refreshDashboardUseCase,
  }) : super(DashboardInitial()) {
    on<LoadDashboardEvent>(_onLoadDashboard);
    on<RefreshDashboardEvent>(_onRefreshDashboard);
    on<LoadAnalyticsEvent>(_onLoadAnalytics);
  }

  Future<void> _onLoadDashboard(LoadDashboardEvent event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final data = await getDashboardDataUseCase();
      emit(DashboardLoaded(dashboardData: data));
    } catch (e) {
      emit(DashboardError(message: e.toString()));
    }
  }

  Future<void> _onRefreshDashboard(RefreshDashboardEvent event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final data = await refreshDashboardUseCase();
      emit(DashboardLoaded(dashboardData: data));
    } catch (e) {
      emit(DashboardError(message: e.toString()));
    }
  }

  Future<void> _onLoadAnalytics(LoadAnalyticsEvent event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final data = await getAnalyticsDataUseCase();
      emit(AnalyticsLoaded(analyticsData: data));
    } catch (e) {
      emit(DashboardError(message: e.toString()));
    }
  }
}
