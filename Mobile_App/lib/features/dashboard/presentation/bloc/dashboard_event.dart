import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object> get props => [];
}

class LoadDashboardEvent extends DashboardEvent {}
class RefreshDashboardEvent extends DashboardEvent {}
class LoadAnalyticsEvent extends DashboardEvent {}
