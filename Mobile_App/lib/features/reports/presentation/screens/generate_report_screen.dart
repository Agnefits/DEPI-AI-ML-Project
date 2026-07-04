import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../injection/injection_container.dart' as di;
import '../../data/datasources/reports_remote_data_source.dart';
import '../../../cases/data/datasources/cases_remote_data_source.dart';
import '../../../cases/data/models/case_model.dart';

class GenerateReportScreen extends StatefulWidget {
  const GenerateReportScreen({super.key});

  @override
  State<GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends State<GenerateReportScreen> {
  final ReportsRemoteDataSource _dataSource = di.sl<ReportsRemoteDataSource>();
  final CasesRemoteDataSource _casesDataSource = di.sl<CasesRemoteDataSource>();

  List<CaseModel> _cases = [];
  CaseModel? _selectedCase;
  bool _isLoadingCases = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    try {
      final cases = await _casesDataSource.getCases();
      if (mounted) {
        setState(() {
          _cases = cases;
          _isLoadingCases = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCases = false);
      }
    }
  }

  Future<void> _generate() async {
    if (_selectedCase == null) {
      _showDialog('Error', 'Please select a case');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      await _dataSource.generateReport(_selectedCase!.id);
      if (mounted) {
        setState(() => _isGenerating = false);
        _showDialog('Success', 'Report generated successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        _showDialog('Failed', e.toString());
      }
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1F2343),
        title: Text(title,
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message,
          style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Future.microtask(() {
                if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
              });
            },
            child: Text('OK', style: GoogleFonts.poppins(color: const Color(0xFF6D6AFB))),
          ),
        ],
      ),
    );
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
          'Generate Report',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Case',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            _isLoadingCases
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(color: Color(0xFF6D6AFB), strokeWidth: 2)))
                : DropdownButtonFormField<CaseModel>(
                    value: _selectedCase,
                    dropdownColor: const Color(0xFF1F2343),
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1F2343),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: GoogleFonts.poppins(color: Colors.white),
                    hint: Text('Select a case', style: GoogleFonts.poppins(color: Colors.white38)),
                    items: _cases.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.patientName.isNotEmpty ? '${c.patientName} (#${c.id})' : 'Case #${c.id}',
                          overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedCase = v),
                  ),
            const Spacer(),
            if (_isGenerating)
              const Center(child: CircularProgressIndicator(color: Color(0xFF6D6AFB)))
            else
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D6AFB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Generate Report',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
