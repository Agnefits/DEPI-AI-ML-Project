import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/classification_result_model.dart';
import '../../../cases/data/models/case_model.dart';

class ClassifyReportScreen extends StatefulWidget {
  final ClassificationResultModel result;
  final CaseModel caseModel;
  final String imagePath;

  const ClassifyReportScreen({
    super.key,
    required this.result,
    required this.caseModel,
    required this.imagePath,
  });

  @override
  State<ClassifyReportScreen> createState() => _ClassifyReportScreenState();
}

class _ClassifyReportScreenState extends State<ClassifyReportScreen> with SingleTickerProviderStateMixin {
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
    // Sort probabilities in descending order based on what is returned dynamically
    final sortedProbabilities = widget.result.probabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final hasAbnormality = widget.result.detectedLabels.isNotEmpty;
    final statusColor = hasAbnormality ? const Color(0xFFFF4E6A) : const Color(0xFF00E676);

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
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
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
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient & Case Info Card
                    _buildCaseInfoCard(),
                    const SizedBox(height: 20),
                    
                    // Image and Result Summary Section
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // X-Ray Image Preview
                        Expanded(
                          flex: 4,
                          child: _buildImageSection(),
                        ),
                        const SizedBox(width: 16),
                        
                        // Circular Confidence Indicator & Summary
                        Expanded(
                          flex: 3,
                          child: _buildConfidenceIndicatorCard(statusColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Detected Pathologies (Tags)
                    _buildDetectedPathologiesTags(statusColor),
                    if (widget.result.gridcam != null && widget.result.gridcam!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildGridcamSection(),
                    ],
                    const SizedBox(height: 24),

                    // Probability Breakdown Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Probability Breakdown',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Confidence %',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // List of probabilities
                    _buildProbabilityList(sortedProbabilities),
                    const SizedBox(height: 24),

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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D6AFB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6D6AFB).withValues(alpha: 0.3)),
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
                widget.caseModel.diagnosis.isNotEmpty ? widget.caseModel.diagnosis : 'Pending',
              ),
              _buildInfoColumn('Processing Time', '${widget.result.processingTime.toStringAsFixed(2)}s'),
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
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 200,
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
            File(widget.imagePath).existsSync()
                ? Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: const Color(0xFF161B3D),
                    child: const Icon(Icons.broken_image_outlined, color: Colors.white24, size: 48),
                  ),
            _buildScanLineEffect(),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Text(
                  'Uploaded Chest X-Ray',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 11,
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

  Widget _buildConfidenceIndicatorCard(Color statusColor) {
    final progress = widget.result.confidence;
    
    return Container(
      height: 200,
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
          const SizedBox(height: 12),
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              children: [
                Center(
                  child: CustomPaint(
                    size: const Size(90, 90),
                    painter: RadialProgressPainter(
                      progress: progress,
                      colors: [
                        const Color(0xFF6D6AFB),
                        statusColor,
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${(progress * 100).toInt()}%',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.result.detectedLabels.isNotEmpty ? 'Abnormality' : 'Normal',
            style: GoogleFonts.poppins(
              color: statusColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedPathologiesTags(Color statusColor) {
    if (widget.result.detectedLabels.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF00E676).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF00E676), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Pathologies Detected',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'The AI did not identify signs of pulmonary diseases.',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
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
          'Detected Abnormalities',
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
          children: widget.result.detectedLabels.map((label) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor.withValues(alpha: 0.12), statusColor.withValues(alpha: 0.24)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, color: statusColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

  Widget _buildProbabilityList(List<MapEntry<String, double>> sortedProbabilities) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedProbabilities.length,
      itemBuilder: (context, index) {
        final entry = sortedProbabilities[index];
        final name = entry.key;
        final probability = entry.value;
        final isDetected = widget.result.detectedLabels.contains(name);
        
        List<Color> progressColors;
        if (probability >= 0.70) {
          progressColors = [const Color(0xFFFF7B00), const Color(0xFFFF4E6A)];
        } else if (probability >= 0.40) {
          progressColors = [const Color(0xFFFFB236), const Color(0xFFFF7B00)];
        } else if (probability >= 0.10) {
          progressColors = [const Color(0xFF6D6AFB), const Color(0xFF8B88FF)];
        } else {
          progressColors = [const Color(0xFF1E265C), const Color(0xFF6D6AFB).withValues(alpha: 0.5)];
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2343).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDetected ? const Color(0xFFFF4E6A).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (isDetected)
                        const Padding(
                          padding: EdgeInsets.only(right: 6.0),
                          child: Icon(Icons.circle, color: Color(0xFFFF4E6A), size: 8),
                        ),
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          color: isDetected ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight: isDetected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${(probability * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      color: probability >= 0.5 ? const Color(0xFFFF7B00) : Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GradientProgressBar(
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
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1025),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatDetailsJson(widget.result.details),
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

  Widget _buildGridcamSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.blur_on, color: Color(0xFF6D6AFB), size: 24),
              const SizedBox(width: 8),
              Text(
                'AI Attention Heatmaps',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Visualizes regions that influenced the model\'s classification for all 14 disease classes. Tap the grid to view, zoom, and explore in detail.',
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _openFullscreenGridcam(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _getGridcamImage(fit: BoxFit.contain),
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.2),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to Expand & Zoom',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getGridcamImage({BoxFit fit = BoxFit.contain}) {
    try {
      String base64Data = widget.result.gridcam!;
      if (base64Data.startsWith('data:image')) {
        base64Data = base64Data.substring(base64Data.indexOf(',') + 1);
      }
      final bytes = base64Decode(base64Data.trim());
      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            color: const Color(0xFF161B3D),
            alignment: Alignment.center,
            child: Text(
              'Error loading Heatmap Grid',
              style: GoogleFonts.poppins(color: Colors.white38),
            ),
          );
        },
      );
    } catch (_) {
      return Container(
        height: 200,
        color: const Color(0xFF161B3D),
        alignment: Alignment.center,
        child: Text(
          'Invalid Heatmap Data',
          style: GoogleFonts.poppins(color: Colors.white38),
        ),
      );
    }
  }

  void _openFullscreenGridcam() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Heatmap Exploration',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: _getGridcamImage(fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
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

class GradientProgressBar extends StatelessWidget {
  final double value;
  final List<Color> gradientColors;

  const GradientProgressBar({
    super.key,
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

class RadialProgressPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  RadialProgressPainter({required this.progress, required this.colors});

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
      ..shader = LinearGradient(
        colors: colors,
      ).createShader(rect)
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
  bool shouldRepaint(covariant RadialProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
