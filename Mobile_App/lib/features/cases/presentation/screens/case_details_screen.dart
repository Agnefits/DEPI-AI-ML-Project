import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/case_entity.dart';
import '../../domain/usecases/get_case_details.dart';
import '../../domain/usecases/delete_case.dart';
import '../../data/datasources/cases_remote_data_source.dart';
import '../../../../injection/injection_container.dart' as di;
import '../bloc/cases_bloc.dart';
import '../bloc/cases_event.dart';
import '../widgets/status_badge.dart';
import 'edit_case_screen.dart';

class CaseDetailsScreen extends StatefulWidget {
  final String caseId;

  const CaseDetailsScreen({super.key, required this.caseId});

  @override
  State<CaseDetailsScreen> createState() => _CaseDetailsScreenState();
}

class _CaseDetailsScreenState extends State<CaseDetailsScreen> {
  final GetCaseDetailsUseCase _getCaseDetails = di.sl<GetCaseDetailsUseCase>();
  final DeleteCaseUseCase _deleteCase = di.sl<DeleteCaseUseCase>();
  final CasesRemoteDataSource _remoteDataSource = di.sl<CasesRemoteDataSource>();
  final _picker = ImagePicker();
  CaseEntity? _caseItem;
  List<String> _imageUrls = [];
  bool _isLoading = true;
  String? _error;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadCase();
  }

  Future<void> _loadCase() async {
    try {
      final results = await Future.wait([
        _getCaseDetails(widget.caseId),
        _remoteDataSource.getCaseImages(widget.caseId),
      ]);
      if (mounted) {
        setState(() {
          _caseItem = results[0] as CaseEntity;
          _imageUrls = results[1] as List<String>;
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

  Future<void> _pickAndUploadImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isUploading = true);

    try {
      await _remoteDataSource.uploadCaseImage(widget.caseId, picked.path);
      final images = await _remoteDataSource.getCaseImages(widget.caseId);
      if (mounted) {
        setState(() {
          _imageUrls = images;
          _isUploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2343),
        title: Text(
          'Delete Case',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this case?',
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
      await _deleteCase(widget.caseId);
      if (mounted) {
        context.read<CasesBloc>().add(LoadCasesEvent());
        Navigator.pop(context);
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
          'Case Details',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_caseItem != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF6D6AFB)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<CasesBloc>(),
                      child: EditCaseScreen(caseItem: _caseItem!),
                    ),
                  ),
                );
              },
            ),
          if (_caseItem != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _handleDelete,
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
          child: Text(
            'Error: $_error',
            style: GoogleFonts.poppins(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final caseItem = _caseItem!;
    return RefreshIndicator(
      color: const Color(0xFF6D6AFB),
      backgroundColor: const Color(0xFF1F2343),
      onRefresh: () async {
        setState(() => _isLoading = true);
        await _loadCase();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              caseItem.patientName,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                StatusBadge(status: caseItem.priority),
                const SizedBox(width: 12),
                StatusBadge(status: caseItem.status),
              ],
            ),
            const SizedBox(height: 24),
            if (caseItem.diagnosis.isNotEmpty)
              _InfoRow(label: 'Diagnosis', value: caseItem.diagnosis),
            if (caseItem.additionalInformation.isNotEmpty)
              _InfoRow(label: 'Notes', value: caseItem.additionalInformation),
            if (caseItem.patientId > 0)
              _InfoRow(label: 'Patient ID', value: caseItem.patientId.toString()),
            const SizedBox(height: 24),
            _buildImagesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Images',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_isUploading)
              const               SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  color: const Color(0xFF6D6AFB), strokeWidth: 2,
                ),
              )
            else
              IconButton(
                icon: Icon(Icons.add_photo_alternate_outlined,
                    color: const Color(0xFF6D6AFB)),
                onPressed: _pickAndUploadImage,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_imageUrls.isEmpty && !_isUploading)
          Text(
            'No images yet',
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
          ),
        ..._imageUrls.map((url) {
          final isNetwork = url.startsWith('http');
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isNetwork
                  ? Image.network(url, height: 200, width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink())
                  : Image.file(File(url), height: 200, width: double.infinity,
                      fit: BoxFit.cover),
            ),
          );
        }),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
