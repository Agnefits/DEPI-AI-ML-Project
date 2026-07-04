import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/clinical_note.dart';
import '../../data/datasources/clinical_notes_remote_data_source.dart';
import '../../../../injection/injection_container.dart' as di;
import 'edit_clinical_note_screen.dart';

class ClinicalNoteDetailsScreen extends StatefulWidget {
  final String caseId;

  const ClinicalNoteDetailsScreen({super.key, required this.caseId});

  @override
  State<ClinicalNoteDetailsScreen> createState() => _ClinicalNoteDetailsScreenState();
}

class _ClinicalNoteDetailsScreenState extends State<ClinicalNoteDetailsScreen> {
  final ClinicalNotesRemoteDataSource _dataSource = di.sl<ClinicalNotesRemoteDataSource>();
  List<ClinicalNote> _notes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await _dataSource.getCaseNotes(widget.caseId);
      if (mounted) {
        setState(() {
          _notes = notes;
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

  Future<void> _confirmAndApprove(ClinicalNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2343),
        title: Text('Confirm Approval',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to approve this note?',
          style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Approve', style: GoogleFonts.poppins(color: Color(0xFF6D6AFB))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _dataSource.approveNote(note.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note approved')),
        );
        _loadNotes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
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
          'Case Notes',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
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
          child: Text(
            'Error: $_error',
            style: GoogleFonts.poppins(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_notes.isEmpty) {
      return Center(
        child: Text(
          'No notes found',
          style: GoogleFonts.poppins(color: Colors.white54),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF6D6AFB),
      backgroundColor: const Color(0xFF1F2343),
      onRefresh: () async {
        setState(() => _isLoading = true);
        await _loadNotes();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];
          return _NoteDetailCard(
            note: note,
            onEdit: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditClinicalNoteScreen(note: note),
                ),
              );
              if (result == true) _loadNotes();
            },
            onApprove: () => _confirmAndApprove(note),
          );
        },
      ),
    );
  }
}

class _NoteDetailCard extends StatelessWidget {
  final ClinicalNote note;
  final VoidCallback onEdit;
  final VoidCallback onApprove;

  const _NoteDetailCard({
    required this.note,
    required this.onEdit,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
              if (note.patientName.isNotEmpty)
                Text(note.patientName,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF6D6AFB),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _iconButton(Icons.edit_outlined, 'Edit', onEdit),
                  const SizedBox(width: 4),
                  _iconButton(Icons.check_circle_outline, 'Approve', onApprove),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _section('Subjective', note.subjective),
          _section('Objective', note.objective),
          _section('Assessment', note.assessment),
          _section('Plan', note.plan),
          if (note.additionalInformation.isNotEmpty)
            _section('Additional Info', note.additionalInformation),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white54, size: 20),
        ),
      ),
    );
  }

  Widget _section(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: GoogleFonts.poppins(
              color: const Color(0xFF6D6AFB),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            )),
          const SizedBox(height: 2),
          Text(value,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}
