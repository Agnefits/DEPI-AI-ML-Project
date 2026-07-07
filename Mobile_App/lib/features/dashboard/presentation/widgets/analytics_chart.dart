import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalyticsChart extends StatelessWidget {
  final List<double> data;
  final String title;
  final Color barColor;

  const AnalyticsChart({
    Key? key,
    required this.data,
    required this.title,
    this.barColor = const Color(0xFF6D6AFB),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxVal = data.isEmpty ? 1.0 : data.reduce((a, b) => a > b ? a : b);
    
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2343),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((val) {
                final heightPercentage = val / (maxVal == 0 ? 1 : maxVal);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 16,
                      height: 120 * heightPercentage,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _ChartLabel('Mon'),
              _ChartLabel('Tue'),
              _ChartLabel('Wed'),
              _ChartLabel('Thu'),
              _ChartLabel('Fri'),
              _ChartLabel('Sat'),
              _ChartLabel('Sun'),
            ],
          )
        ],
      ),
    );
  }
}

class _ChartLabel extends StatelessWidget {
  final String label;
  const _ChartLabel(this.label, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        color: Colors.white54,
        fontSize: 12,
      ),
    );
  }
}
