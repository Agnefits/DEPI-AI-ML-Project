import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../injection/injection_container.dart' as di;
import '../../data/datasources/ai_remote_data_source.dart';
import '../../../cases/data/datasources/cases_remote_data_source.dart';
import '../../../cases/data/models/case_model.dart';
import '../../data/models/classification_result_model.dart';
import 'classify_report_screen.dart';

class ClassifyScreen extends StatefulWidget {
  const ClassifyScreen({super.key});

  @override
  State<ClassifyScreen> createState() => _ClassifyScreenState();
}

class _ClassifyScreenState extends State<ClassifyScreen> {
  final AiRemoteDataSource _dataSource = di.sl<AiRemoteDataSource>();
  final CasesRemoteDataSource _casesDataSource = di.sl<CasesRemoteDataSource>();
  final ImagePicker _picker = ImagePicker();

  List<CaseModel> _cases = [];
  CaseModel? _selectedCase;
  bool _isLoadingCases = true;
  String? _selectedFilePath;
  String? _selectedFileName;
  bool _isSubmitting = false;
  bool _includeGridcam = false;

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

  Future<void> _pickFile() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (image != null) {
      setState(() {
        _selectedFilePath = image.path;
        _selectedFileName = image.name;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedCase == null) {
      _showDialog('Error', 'Please select a case');
      return;
    }
    if (_selectedFilePath == null) {
      _showDialog('Error', 'Please select a file');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final ClassificationResultModel result = await _dataSource.classify(
        int.parse(_selectedCase!.id),
        _selectedFilePath!,
        includeGridcam: _includeGridcam,
      );
      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClassifyReportScreen(
              result: result,
              caseModel: _selectedCase!,
              imagePath: _selectedFilePath!,
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
        title: Text(title,
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message,
          style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (navigateBack) {
                Future.microtask(() {
                  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
                });
              }
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
          'Classify',
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
            const SizedBox(height: 24),
            Text('File',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2343),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload_outlined, color: Colors.white54, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFileName ?? 'Tap to select an image',
                      style: GoogleFonts.poppins(
                        color: _selectedFileName != null ? Colors.white70 : Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2343),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generate AI Attention Heatmaps',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Highlights regions of interest that the AI model focused on for disease detection.',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _includeGridcam,
                    activeThumbColor: const Color(0xFF6D6AFB),
                    onChanged: (val) {
                      setState(() {
                        _includeGridcam = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D6AFB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Classify',
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
