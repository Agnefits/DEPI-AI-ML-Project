import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/patient.dart';
import '../../domain/usecases/get_patient_by_id.dart';
import '../../domain/usecases/delete_patient.dart';
import '../../../../injection/injection_container.dart' as di;
import '../widgets/patient_info_row.dart';
import '../widgets/status_badge.dart';
import '../bloc/patient_bloc.dart';
import '../bloc/patient_event.dart';
import 'edit_patient_screen.dart';
import '../../../cases/data/datasources/cases_remote_data_source.dart';
import '../../../cases/data/models/case_model.dart';
import '../../../cases/presentation/bloc/cases_bloc.dart';
import '../../../cases/presentation/screens/add_case_screen.dart';

class PatientDetailsScreen extends StatefulWidget {
  final String patientId;

  const PatientDetailsScreen({Key? key, required this.patientId}) : super(key: key);

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  final GetPatientById _getPatientById = di.sl<GetPatientById>();
  final DeletePatient _deletePatient = di.sl<DeletePatient>();
  final CasesRemoteDataSource _casesDataSource = di.sl<CasesRemoteDataSource>();
  Patient? _patient;
  bool _isLoading = true;
  String? _error;
  List<CaseModel> _patientCases = [];
  bool _isLoadingCases = true;

  @override
  void initState() {
    super.initState();
    _loadPatient();
  }

  Future<void> _loadPatient() async {
    try {
      final patient = await _getPatientById(widget.patientId);
      if (mounted) {
        setState(() {
          _patient = patient;
          _isLoading = false;
        });
        _loadPatientCases(patient);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPatientCases(Patient patient) async {
    try {
      final allCases = await _casesDataSource.getCases();
      final patientIdInt = int.tryParse(patient.id);
      if (mounted) {
        setState(() {
          _patientCases = allCases
              .where((c) => patientIdInt != null ? c.patientId == patientIdInt : c.patientName == patient.name)
              .toList();
          _isLoadingCases = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCases = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2343),
        title: Text(
          'Delete Patient',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this patient?',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _deletePatient(widget.patientId);
      if (mounted) {
        context.read<PatientBloc>().add(LoadPatientsEvent());
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1025),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1025),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Patient Details',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_patient != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _handleDelete,
            ),
          if (_patient != null)
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF6D6AFB)),
              onPressed: () {
                final bloc = BlocProvider.of<PatientBloc>(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: bloc,
                      child: EditPatientScreen(patient: _patient!),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6D6AFB)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error loading patient',
                style: GoogleFonts.poppins(
                  color: Colors.redAccent,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadPatient();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final patient = _patient!;
    return RefreshIndicator(
      color: const Color(0xFF6D6AFB),
      backgroundColor: const Color(0xFF1F2343),
      onRefresh: () async {
        setState(() {
          _isLoading = true;
          _isLoadingCases = true;
          _error = null;
        });
        await _loadPatient();
      },
      child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF1F2343),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF6D6AFB), width: 2),
              ),
              child: Center(
                child: Text(
                  patient.name.isNotEmpty ? patient.name.substring(0, 1).toUpperCase() : '?',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              patient.name,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: StatusBadge(status: patient.status),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2343),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Information',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                PatientInfoRow(
                  label: 'Gender',
                  value: patient.gender,
                  icon: Icons.person_outline,
                ),
                PatientInfoRow(
                  label: 'Blood Group',
                  value: patient.bloodGroup,
                  icon: Icons.water_drop_outlined,
                ),
                PatientInfoRow(
                  label: 'Phone Number',
                  value: patient.phoneNumber,
                  icon: Icons.phone_outlined,
                ),
                PatientInfoRow(
                  label: 'Email Address',
                  value: patient.email,
                  icon: Icons.email_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2343),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medical Details',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                PatientInfoRow(
                  label: 'Primary Condition',
                  value: patient.condition,
                  icon: Icons.medical_services_outlined,
                ),
                PatientInfoRow(
                  label: 'Last Visit',
                  value: '${patient.lastVisit.toLocal()}'.split(' ')[0],
                  icon: Icons.calendar_today_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2343),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Patient Cases',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: di.sl<CasesBloc>(),
                              child: AddCaseScreen(patientId: patient.id),
                            ),
                          ),
                        ).then((_) => _loadPatientCases(patient));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D6AFB).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, color: Color(0xFF6D6AFB), size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isLoadingCases)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF6D6AFB), strokeWidth: 2)))
                else if (_patientCases.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text('No cases found',
                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14)),
                    ),
                  )
                else
                  ..._patientCases.map((c) => _caseTile(c)),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _caseTile(CaseModel c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1025),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Case #${c.id}',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('${c.status} · ${c.priority}',
                  style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: c.status == 'Closed' ? Colors.green.withValues(alpha: 0.2) : const Color(0xFF6D6AFB).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(c.status,
              style: GoogleFonts.poppins(
                color: c.status == 'Closed' ? Colors.green : const Color(0xFF6D6AFB),
                fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
