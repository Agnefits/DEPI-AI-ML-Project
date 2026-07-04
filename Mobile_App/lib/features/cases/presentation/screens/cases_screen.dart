import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../injection/injection_container.dart' as di;
import '../bloc/cases_bloc.dart';
import '../bloc/cases_event.dart';
import '../bloc/cases_state.dart';
import '../widgets/case_card.dart';
import '../widgets/empty_cases_view.dart';
import 'add_case_screen.dart';
import 'case_details_screen.dart';

class CasesScreen extends StatelessWidget {
  const CasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => di.sl<CasesBloc>()..add(LoadCasesEvent()),
      child: const _CasesView(),
    );
  }
}

class _CasesView extends StatefulWidget {
  const _CasesView();

  @override
  State<_CasesView> createState() => _CasesViewState();
}

class _CasesViewState extends State<_CasesView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';
  final _statusOptions = ['All', 'Active', 'Pending', 'Closed'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1025),
      floatingActionButton: FloatingActionButton(
        heroTag: 'cases_fab',
        backgroundColor: const Color(0xFF6D6AFB),
        onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<CasesBloc>(),
                  child: const AddCaseScreen(),
                ),
              ),
            );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchFilter(),
            Expanded(
              child: BlocBuilder<CasesBloc, CasesState>(
                builder: (context, state) {
                  if (state is CasesLoading || state is CasesInitial) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF6D6AFB)),
                    );
                  } else if (state is CasesError) {
                    return Center(
                      child: Text(
                        'Error: ${state.message}',
                        style: GoogleFonts.poppins(color: Colors.redAccent),
                      ),
                    );
                  } else if (state is CasesLoaded) {
                    final filtered = state.cases.where((c) {
                      if (_statusFilter != 'All' && c.status != _statusFilter) return false;
                      if (_searchQuery.isNotEmpty) {
                        final q = _searchQuery.toLowerCase();
                        return c.patientName.toLowerCase().contains(q) || c.id.toLowerCase().contains(q);
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const EmptyCasesView();
                    }
                    return RefreshIndicator(
                      color: const Color(0xFF6D6AFB),
                      backgroundColor: const Color(0xFF1F2343),
                      onRefresh: () async {
                        context.read<CasesBloc>().add(LoadCasesEvent());
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final caseItem = filtered[index];
                          return CaseCard(
                            caseItem: caseItem,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<CasesBloc>(),
                                    child: CaseDetailsScreen(caseId: caseItem.id),
                                  ),
                                ),
                              );
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
      ),
    );
  }

  Widget _buildSearchFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      color: const Color(0xFF0D1025),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by patient name or case ID',
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
