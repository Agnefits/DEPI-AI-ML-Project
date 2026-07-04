import 'package:equatable/equatable.dart';

class DashboardEntity extends Equatable {
  final int totalPatients;
  final int upcomingAppointments;
  final double monthlyRevenue;
  final int activeDoctors;
  final List<ActivityEntity> recentActivities;

  const DashboardEntity({
    required this.totalPatients,
    required this.upcomingAppointments,
    required this.monthlyRevenue,
    required this.activeDoctors,
    required this.recentActivities,
  });

  @override
  List<Object?> get props => [
        totalPatients,
        upcomingAppointments,
        monthlyRevenue,
        activeDoctors,
        recentActivities,
      ];
}

class ActivityEntity extends Equatable {
  final String id;
  final String title;
  final String subtitle;
  final String time;
  final String type; // 'appointment', 'payment', 'system'

  const ActivityEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.type,
  });

  @override
  List<Object?> get props => [id, title, subtitle, time, type];
}

class AnalyticsEntity extends Equatable {
  final List<double> weeklyPatientData;
  final List<double> weeklyRevenueData;
  final double patientGrowth;
  final double revenueGrowth;

  const AnalyticsEntity({
    required this.weeklyPatientData,
    required this.weeklyRevenueData,
    required this.patientGrowth,
    required this.revenueGrowth,
  });

  @override
  List<Object?> get props => [weeklyPatientData, weeklyRevenueData, patientGrowth, revenueGrowth];
}
