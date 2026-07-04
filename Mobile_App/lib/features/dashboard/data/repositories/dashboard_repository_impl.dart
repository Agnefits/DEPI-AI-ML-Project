import '../../../../core/network/dio_client.dart';
import '../../domain/entities/dashboard_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../models/dashboard_model.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DioClient client;

  DashboardRepositoryImpl({required this.client});

  int _countList(dynamic data) {
    if (data is List) return data.length;
    if (data is Map && data['data'] is List) return (data['data'] as List).length;
    return 0;
  }

  Future<int> _fetchPatientCount() async {
    try {
      final response = await client.dio.get('/PatientsApi');
      return _countList(response.data);
    } catch (_) {
      return 0;
    }
  }

  Future<int> _fetchCaseCount() async {
    try {
      final response = await client.dio.get('/CasesApi');
      return _countList(response.data);
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<DashboardEntity> getDashboardData() async {
    final results = await Future.wait([
      _fetchPatientCount(),
      _fetchCaseCount(),
    ]);

    return DashboardModel(
      totalPatients: results[0],
      upcomingAppointments: results[1],
      monthlyRevenue: 15430.50,
      activeDoctors: 12,
      recentActivities: const [
        ActivityModel(
            id: '1',
            title: 'Dr. Smith finished appointment',
            subtitle: 'Patient: John Doe',
            time: '10:30 AM',
            type: 'appointment'),
        ActivityModel(
            id: '2',
            title: 'Payment received',
            subtitle: '\$150 from Jane Roe',
            time: '09:15 AM',
            type: 'payment'),
        ActivityModel(
            id: '3',
            title: 'New patient registered',
            subtitle: 'Alice Johnson',
            time: '08:45 AM',
            type: 'system'),
      ],
    );
  }

  @override
  Future<AnalyticsEntity> getAnalyticsData() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return const AnalyticsModel(
      weeklyPatientData: [20, 35, 40, 25, 45, 60, 50],
      weeklyRevenueData: [500, 800, 1200, 900, 1500, 2000, 1800],
      patientGrowth: 12.5,
      revenueGrowth: 8.4,
    );
  }

  @override
  Future<DashboardEntity> refreshDashboardData() async {
    final results = await Future.wait([
      _fetchPatientCount(),
      _fetchCaseCount(),
    ]);

    return DashboardModel(
      totalPatients: results[0],
      upcomingAppointments: results[1],
      monthlyRevenue: 15580.50,
      activeDoctors: 12,
      recentActivities: const [
        ActivityModel(
            id: '4',
            title: 'Dr. Adams started appointment',
            subtitle: 'Patient: Mark Lee',
            time: 'Just now',
            type: 'appointment'),
        ActivityModel(
            id: '1',
            title: 'Dr. Smith finished appointment',
            subtitle: 'Patient: John Doe',
            time: '10:30 AM',
            type: 'appointment'),
        ActivityModel(
            id: '2',
            title: 'Payment received',
            subtitle: '\$150 from Jane Roe',
            time: '09:15 AM',
            type: 'payment'),
      ],
    );
  }
}
