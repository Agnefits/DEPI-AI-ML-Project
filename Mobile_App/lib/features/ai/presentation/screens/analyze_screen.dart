import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../injection/injection_container.dart' as di;
import '../../data/datasources/ai_remote_data_source.dart';
import '../../../cases/data/datasources/cases_remote_data_source.dart';
import '../../../cases/data/models/case_model.dart';
import '../../data/models/analyze_result_model.dart';
import 'analyze_report_screen.dart';

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  final AiRemoteDataSource _dataSource = di.sl<AiRemoteDataSource>();
  final CasesRemoteDataSource _casesDataSource = di.sl<CasesRemoteDataSource>();
  final _promptController = TextEditingController();

  List<CaseModel> _cases = [];
  CaseModel? _selectedCase;
  bool _isLoadingCases = true;
  String? _selectedFilePath;
  String? _selectedFileName;
  bool _isSubmitting = false;

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

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'txt',
          'csv',
          'xls',
          'xlsx',
          'png',
          'jpg',
          'jpeg',
        ],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _selectedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      _showDialog('Error', 'Failed to pick file: $e');
    }
  }

  Future<void> _submit() async {
    if (_selectedCase == null) {
      _showDialog('Error', 'Please select a case');
      return;
    }
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty && _selectedFilePath == null) {
      _showDialog('Error', 'Please enter a prompt or select a file');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final AnalyzeResultModel result = await _dataSource.analyze(
        int.parse(_selectedCase!.id),
        prompt: prompt.isNotEmpty ? prompt : null,
        filePath: _selectedFilePath,
      );
      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnalyzeReportScreen(
              result: result,
              caseModel: _selectedCase!,
              filePath: _selectedFilePath,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showDialog('Failed', e.toString());
      }
    }
  }

  void _showDialog(String title, String message, {bool navigateBack = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1F2343),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (navigateBack) {
                final navigator = Navigator.of(context, rootNavigator: true);
                Future.microtask(() {
                  navigator.pop();
                });
              }
            },
            child: Text(
              'OK',
              style: GoogleFonts.poppins(color: const Color(0xFF6D6AFB)),
            ),
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
          'Analyze',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Case',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isLoadingCases
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                color: Color(0xFF6D6AFB),
                                strokeWidth: 2,
                              ),
                            ),
                          )
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
                            hint: Text(
                              'Select a case',
                              style: GoogleFonts.poppins(color: Colors.white38),
                            ),
                            items: _cases
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c.patientName.isNotEmpty
                                          ? '${c.patientName} (#${c.id})'
                                          : 'Case #${c.id}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _selectedCase = v),
                          ),
                    const SizedBox(height: 24),
                    Text(
                      'Prompt',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _promptController,
                      maxLines: 3,
                      style: GoogleFonts.poppins(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter your prompt',
                        hintStyle: GoogleFonts.poppins(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF1F2343),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'File',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _pickFile,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 40,
                              horizontal: 24,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2343),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white24,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _selectedFileName != null
                                      ? Icons.insert_drive_file_outlined
                                      : Icons.cloud_upload_outlined,
                                  color: _selectedFileName != null
                                      ? const Color(0xFF6D6AFB)
                                      : Colors.white54,
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedFileName ??
                                      'Tap to select a file (Optional if prompt provided)',
                                  style: GoogleFonts.poppins(
                                    color: _selectedFileName != null
                                        ? Colors.white70
                                        : Colors.white38,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_selectedFilePath != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedFilePath = null;
                                  _selectedFileName = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D6AFB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Analyze',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
