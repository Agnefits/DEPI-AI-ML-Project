import '../../domain/entities/dashboard_entity.dart';

class DashboardModel extends DashboardEntity {
  const DashboardModel({
    required super.totalPatients,
    required super.upcomingAppointments,
    required super.monthlyRevenue,
    required super.activeDoctors,
    required super.recentActivities,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      totalPatients: json['totalPatients'] as int,
      upcomingAppointments: json['upcomingAppointments'] as int,
      monthlyRevenue: (json['monthlyRevenue'] as num).toDouble(),
      activeDoctors: json['activeDoctors'] as int,
      recentActivities: (json['recentActivities'] as List)
          .map((e) => ActivityModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ActivityModel extends ActivityEntity {
  const ActivityModel({
    required super.id,
    required super.title,
    required super.subtitle,
    required super.time,
    required super.type,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      time: json['time'] as String,
      type: json['type'] as String,
    );
  }
}

class AnalyticsModel extends AnalyticsEntity {
  const AnalyticsModel({
    required super.weeklyPatientData,
    required super.weeklyRevenueData,
    required super.patientGrowth,
    required super.revenueGrowth,
  });

  factory AnalyticsModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsModel(
      weeklyPatientData: (json['weeklyPatientData'] as List).map((e) => (e as num).toDouble()).toList(),
      weeklyRevenueData: (json['weeklyRevenueData'] as List).map((e) => (e as num).toDouble()).toList(),
      patientGrowth: (json['patientGrowth'] as num).toDouble(),
      revenueGrowth: (json['revenueGrowth'] as num).toDouble(),
    );
  }
}
