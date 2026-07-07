import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/analytics_chart.dart';
import '../widgets/section_title.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(LoadAnalyticsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1025),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            context.read<DashboardBloc>().add(LoadDashboardEvent());
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Analytics Overview',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading || state is DashboardInitial) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6D6AFB)));
          } else if (state is DashboardError) {
            return Center(
              child: Text(
                'Error: ${state.message}',
                style: GoogleFonts.poppins(color: Colors.redAccent),
              ),
            );
          } else if (state is AnalyticsLoaded) {
            final data = state.analyticsData;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _GrowthCard(
                          title: 'Patient Growth',
                          percentage: data.patientGrowth,
                          isPositive: data.patientGrowth >= 0,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _GrowthCard(
                          title: 'Revenue Growth',
                          percentage: data.revenueGrowth,
                          isPositive: data.revenueGrowth >= 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const SectionTitle(title: 'Patient Activity (Weekly)'),
                  const SizedBox(height: 16),
                  AnalyticsChart(
                    title: 'Patients Consulted',
                    data: data.weeklyPatientData,
                    barColor: const Color(0xFF6D6AFB),
                  ),
                  const SizedBox(height: 32),
                  const SectionTitle(title: 'Revenue (Weekly)'),
                  const SizedBox(height: 16),
                  AnalyticsChart(
                    title: 'Gross Income (\$)',
                    data: data.weeklyRevenueData,
                    barColor: Colors.greenAccent,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _GrowthCard extends StatelessWidget {
  final String title;
  final double percentage;
  final bool isPositive;

  const _GrowthCard({
    Key? key,
    required this.title,
    required this.percentage,
    required this.isPositive,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2343),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: isPositive ? Colors.greenAccent : Colors.redAccent,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: GoogleFonts.poppins(
                  color: isPositive ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
