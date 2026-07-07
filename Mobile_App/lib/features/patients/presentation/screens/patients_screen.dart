import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../injection/injection_container.dart' as di;
import '../bloc/patient_bloc.dart';
import '../bloc/patient_event.dart';
import '../bloc/patient_state.dart';
import '../widgets/patient_card.dart';
import 'patient_details_screen.dart';
import 'add_patient_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({Key? key}) : super(key: key);

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';
  final _statusOptions = ['All', 'Active', 'Inactive'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => di.sl<PatientBloc>()..add(LoadPatientsEvent()),
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1025),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1025),
          elevation: 0,
          title: Text(
            'Patients',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Column(
          children: [
            _buildSearchFilter(),
            Expanded(
              child: BlocBuilder<PatientBloc, PatientState>(
                builder: (context, state) {
                  if (state is PatientLoading || state is PatientInitial) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF6D6AFB)));
                  } else if (state is PatientError) {
                    return Center(
                      child: Text(
                        'Error: ${state.message}',
                        style: GoogleFonts.poppins(color: Colors.redAccent),
                      ),
                    );
                  } else if (state is PatientLoaded) {
                    final filtered = state.patients.where((p) {
                      if (_statusFilter != 'All' && p.status != _statusFilter) return false;
                      if (_searchQuery.isNotEmpty) {
                        final q = _searchQuery.toLowerCase();
                        return p.name.toLowerCase().contains(q) || p.phoneNumber.toLowerCase().contains(q);
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          'No patients found.',
                          style: GoogleFonts.poppins(color: Colors.white70),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      color: const Color(0xFF6D6AFB),
                      backgroundColor: const Color(0xFF1F2343),
                      onRefresh: () async {
                        context.read<PatientBloc>().add(LoadPatientsEvent());
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final patient = filtered[index];
                          return PatientCard(
                            patient: patient,
                            onTap: () async {
                              final bloc = context.read<PatientBloc>();
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: bloc,
                                    child: PatientDetailsScreen(patientId: patient.id),
                                  ),
                                ),
                              );
                              if (result == true) {
                                bloc.add(LoadPatientsEvent());
                              }
                            },
                          );
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            return FloatingActionButton(
              heroTag: 'patients_fab',
              backgroundColor: const Color(0xFF6D6AFB),
              onPressed: () {
                final bloc = BlocProvider.of<PatientBloc>(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: bloc,
                      child: const AddPatientScreen(),
                    ),
                  ),
                );
              },
              child: const Icon(Icons.add, color: Colors.white),
            );
          }
        ),
      ),
    );
  }

  Widget _buildSearchFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      color: const Color(0xFF0D1025),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name or phone number',
              hintStyle: GoogleFonts.poppins(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1F2343),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      })
                  : null,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Status: ', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _statusFilter,
                dropdownColor: const Color(0xFF1F2343),
                style: GoogleFonts.poppins(color: Colors.white),
                underline: const SizedBox(),
                items: _statusOptions.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, style: GoogleFonts.poppins(color: Colors.white)),
                )).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _statusFilter = v);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
