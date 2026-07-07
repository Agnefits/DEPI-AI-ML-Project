import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/analyze_result_model.dart';
import '../../../cases/data/models/case_model.dart';

class AnalyzeReportScreen extends StatefulWidget {
  final AnalyzeResultModel result;
  final CaseModel caseModel;
  final String? filePath;

  const AnalyzeReportScreen({
    super.key,
    required this.result,
    required this.caseModel,
    this.filePath,
  });

  @override
  State<AnalyzeReportScreen> createState() => _AnalyzeReportScreenState();
}

class _AnalyzeReportScreenState extends State<AnalyzeReportScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showRawDetails = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sort ICD-10 diagnostics by probability in descending order
    final sortedDiagnostics = widget.result.icd10Diagnostics.toList()
      ..sort((a, b) => b.probability.compareTo(a.probability));

    // Get the highest diagnostic probability for confidence display
    final overallConfidence = sortedDiagnostics.isNotEmpty
        ? sortedDiagnostics.first.probability
        : 0.88; // fallback to backend default if empty

    final hasAbnormality = widget.result.entities.any(
      (e) =>
          e.type.toLowerCase() == 'disease' ||
          e.type.toLowerCase() == 'abnormality',
    );
    final statusColor = hasAbnormality
        ? const Color(0xFFFF4E6A)
        : const Color(0xFF00E676);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1025),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0D1025),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'AI Analysis Report',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B1B3A), Color(0xFF0D1025)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient & Case Info Card
                    _buildCaseInfoCard(),
                    const SizedBox(height: 20),

                    // File and Confidence summary
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Attached File preview (Image or Doc)
                        Expanded(flex: 4, child: _buildFileSection()),
                        const SizedBox(width: 16),

                        // Circular Confidence Indicator & Summary
                        Expanded(
                          flex: 3,
                          child: _buildConfidenceIndicatorCard(
                            overallConfidence,
                            statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // AI Clinical Summary/Findings
                    _buildFindingsCard(),
                    const SizedBox(height: 24),

                    // Extracted Medical Entities (Tags)
                    _buildExtractedEntitiesTags(),
                    const SizedBox(height: 24),

                    // ICD-10 Diagnostics
                    if (sortedDiagnostics.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ICD-10 Diagnostics',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Probability %',
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDiagnosticsList(sortedDiagnostics),
                      const SizedBox(height: 24),
                    ],

                    // Details collapsible card
                    _buildDetailsCard(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2343),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.caseModel.patientName.isNotEmpty
                        ? widget.caseModel.patientName
                        : 'Patient Case #${widget.caseModel.id}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Priority: ${widget.caseModel.priority.toUpperCase()}',
                    style: GoogleFonts.poppins(
                      color: _getPriorityColor(widget.caseModel.priority),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D6AFB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6D6AFB).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'ID: #${widget.result.analysisId}',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF8B88FF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(color: Colors.white12, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoColumn(
                'Diagnosis',
                widget.caseModel.diagnosis.isNotEmpty
                    ? widget.caseModel.diagnosis
                    : 'Pending',
              ),
              _buildInfoColumn(
                'Model Client',
                widget.result.client.toUpperCase(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFileSection() {
    final path = widget.filePath;
    final isImage =
        path != null &&
        (path.endsWith('.png') ||
            path.endsWith('.jpg') ||
            path.endsWith('.jpeg') ||
            path.endsWith('.gif'));

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2343),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (path == null) ...[
              Container(
                color: const Color(0xFF161B3D),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.text_snippet_outlined,
                      color: Colors.white24,
                      size: 48,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Text-only Prompt Input',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else if (isImage && File(path).existsSync()) ...[
              Image.file(File(path), fit: BoxFit.cover),
              _buildScanLineEffect(),
            ] else ...[
              Container(
                color: const Color(0xFF161B3D),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.document_scanner_outlined,
                      color: Color(0xFF6D6AFB),
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        path.split('/').last.split('\\').last,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (path != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    isImage ? 'Uploaded Scan/Image' : 'Uploaded File Content',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanLineEffect() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          backgroundBlendMode: BlendMode.overlay,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.05),
              Colors.transparent,
              Colors.white.withValues(alpha: 0.05),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceIndicatorCard(double progress, Color statusColor) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2343),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Confidence',
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              children: [
                Center(
                  child: CustomPaint(
                    size: const Size(80, 80),
                    painter: _AnalyzeRadialProgressPainter(
                      progress: progress,
                      colors: [const Color(0xFF6D6AFB), statusColor],
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${(progress * 100).toInt()}%',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.result.status.toUpperCase(),
            style: GoogleFonts.poppins(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFindingsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2343),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Findings & Analysis',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Divider(color: Colors.white12, height: 1),
          ),
          Text(
            widget.result.text.isNotEmpty
                ? widget.result.text
                : 'No clear text findings returned from the model.',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedEntitiesTags() {
    if (widget.result.entities.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF00E676).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF00E676).withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF00E676),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Medical Entities Identified',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'The AI did not extract specific disease or pathology entities.',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Extracted Medical Entities',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.result.entities.map((ent) {
            final isDisease =
                ent.type.toLowerCase() == 'disease' ||
                ent.type.toLowerCase() == 'abnormality';
            final color = isDisease
                ? const Color(0xFFFF4E6A)
                : const Color(0xFF00E676);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.1),
                    color.withValues(alpha: 0.22),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDisease
                        ? Icons.warning_amber_rounded
                        : Icons.label_outline,
                    color: color,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${ent.entity} (${ent.type})',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDiagnosticsList(List<Icd10DiagnosticModel> diagnostics) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: diagnostics.length,
      itemBuilder: (context, index) {
        final diag = diagnostics[index];
        final code = diag.code;
        final probability = diag.probability;

        List<Color> progressColors;
        if (probability >= 0.70) {
          progressColors = [const Color(0xFFFF7B00), const Color(0xFFFF4E6A)];
        } else if (probability >= 0.40) {
          progressColors = [const Color(0xFFFFB236), const Color(0xFFFF7B00)];
        } else if (probability >= 0.10) {
          progressColors = [const Color(0xFF6D6AFB), const Color(0xFF8B88FF)];
        } else {
          progressColors = [
            const Color(0xFF1E265C),
            const Color(0xFF6D6AFB).withValues(alpha: 0.5),
          ];
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2343).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    code,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${(probability * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      color: probability >= 0.5
                          ? const Color(0xFFFF7B00)
                          : Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _AnalyzeGradientProgressBar(
                value: probability,
                gradientColors: progressColors,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2343),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Technical Metadata',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            trailing: Icon(
              _showRawDetails ? Icons.expand_less : Icons.expand_more,
              color: Colors.white70,
            ),
            onTap: () {
              setState(() {
                _showRawDetails = !_showRawDetails;
              });
            },
          ),
          if (_showRawDetails)
            Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                bottom: 16.0,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1025),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatDetailsJson(widget.result.rawResponse),
                  style: GoogleFonts.firaCode(
                    color: const Color(0xFF00E676),
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDetailsJson(String detailsStr) {
    try {
      final parsed = jsonDecode(detailsStr);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(parsed);
    } catch (_) {
      return detailsStr;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'critical':
        return const Color(0xFFFF4E6A);
      case 'medium':
        return const Color(0xFFFFB236);
      default:
        return const Color(0xFF00E676);
    }
  }
}

class _AnalyzeGradientProgressBar extends StatelessWidget {
  final double value;
  final List<Color> gradientColors;

  const _AnalyzeGradientProgressBar({
    required this.value,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF161B3D),
        borderRadius: BorderRadius.circular(3),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth * value;
          return Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              height: 6,
              width: width > 0 ? width : 0,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.last.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnalyzeRadialProgressPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _AnalyzeRadialProgressPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;

    final bgPaint = Paint()
      ..color = const Color(0xFF161B3D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, bgPaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = LinearGradient(colors: colors).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-3.14159 / 2);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(rect, 0, 3.14159 * 2 * progress, false, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AnalyzeRadialProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
