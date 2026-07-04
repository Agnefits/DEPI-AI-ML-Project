import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../injection/injection_container.dart' as di;
import '../../../cases/data/datasources/cases_remote_data_source.dart';
import '../../../cases/data/models/case_model.dart';
import '../../../cases/presentation/widgets/case_card.dart';
import 'clinical_note_details_screen.dart';
import 'add_clinical_note_screen.dart';

class ClinicalNotesScreen extends StatefulWidget {
  const ClinicalNotesScreen({super.key});

  @override
  State<ClinicalNotesScreen> createState() => _ClinicalNotesScreenState();
}

class _ClinicalNotesScreenState extends State<ClinicalNotesScreen> {
  final CasesRemoteDataSource _dataSource = di.sl<CasesRemoteDataSource>();
  List<CaseModel> _cases = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    try {
      final cases = await _dataSource.getCases();
      if (mounted) {
        setState(() {
          _cases = cases;
          _isLoading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1025),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1025),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Clinical Notes',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'clinical_notes_fab',
        backgroundColor: const Color(0xFF6D6AFB),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddClinicalNoteScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
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
        child: Text(
          'Error: $_error',
          style: GoogleFonts.poppins(color: Colors.redAccent),
        ),
      );
    }

    if (_cases.isEmpty) {
      return Center(
        child: Text(
          'No cases found',
          style: GoogleFonts.poppins(color: Colors.white54),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF6D6AFB),
      backgroundColor: const Color(0xFF1F2343),
      onRefresh: _loadCases,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _cases.length,
        itemBuilder: (context, index) {
          final caseItem = _cases[index];
          return CaseCard(
            caseItem: caseItem,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClinicalNoteDetailsScreen(caseId: caseItem.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
