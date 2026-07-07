import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../injection/injection_container.dart' as di;
import '../../../auth/data/datasources/auth_local_data_source.dart';
import '../../../clinical_notes/presentation/screens/clinical_notes_screen.dart';
import '../../../ai/presentation/screens/classify_screen.dart';
import '../../../ai/presentation/screens/analyze_screen.dart';
import '../../../reports/presentation/screens/generate_report_screen.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final auth = await di.sl<AuthLocalDataSource>().loadAuth();
    if (mounted) {
      setState(() {
        _userName = auth?.name ?? 'User';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => di.sl<DashboardBloc>()..add(LoadDashboardEvent()),
      child: _DashboardView(userName: _userName),
    );
  }
}

class _DashboardView extends StatelessWidget {
  final String userName;

  const _DashboardView({
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1025),
      body: SafeArea(
        child: BlocBuilder<DashboardBloc, DashboardState>(
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
            } else if (state is DashboardLoaded) {
              final data = state.dashboardData;
              return RefreshIndicator(
                color: const Color(0xFF6D6AFB),
                backgroundColor: const Color(0xFF1F2343),
                onRefresh: () async {
                  context.read<DashboardBloc>().add(RefreshDashboardEvent());
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DashboardHeader(
                        title: userName,
                        subtitle: 'Welcome back,',
                      ),
                      const SizedBox(height: 32),
                      
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.1,
                        children: [
                          StatCard(
                            title: 'Total Patients',
                            value: data.totalPatients.toString(),
                            icon: Icons.people_alt_outlined,
                            iconColor: const Color(0xFF6D6AFB),
                            onTap: () {
                              StatefulNavigationShell.of(context).goBranch(1);
                            },
                          ),
                          StatCard(
                            title: 'Cases',
                            value: data.upcomingAppointments.toString(),
                            icon: Icons.work_outline,
                            iconColor: Colors.orangeAccent,
                            onTap: () {
                              StatefulNavigationShell.of(context).goBranch(2);
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => const ClinicalNotesScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2343),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6D6AFB).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.note_alt_outlined, color: Color(0xFF6D6AFB), size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                  Text(
                                    'Clinical Notes',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'View and manage patient notes',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => const ClassifyScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2343),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6D6AFB).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.smart_toy_outlined, color: Color(0xFF6D6AFB), size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                  Text(
                                    'Classify',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'AI-powered case classification',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => const AnalyzeScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2343),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6D6AFB).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.analytics_outlined, color: Color(0xFF6D6AFB), size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                  Text(
                                    'Analyze',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'AI-powered case analysis',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => const GenerateReportScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2343),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6D6AFB).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.description_outlined, color: Color(0xFF6D6AFB), size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                  Text(
                                    'Generate Report',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Generate PDF case report',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
                            ],
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
