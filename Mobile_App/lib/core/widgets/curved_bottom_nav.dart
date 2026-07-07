import 'dart:math';
import 'package:flutter/material.dart';

class CurvedBottomNavItem {
  final IconData icon;
  final String label;

  const CurvedBottomNavItem({
    required this.icon,
    required this.label,
  });
}

class CurvedBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<CurvedBottomNavItem> items;

  const CurvedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  State<CurvedBottomNav> createState() => _CurvedBottomNavState();
}

class _CurvedBottomNavState extends State<CurvedBottomNav>
    with TickerProviderStateMixin {
  static const double _bumpRadius = 30;
  static const double _navBarHeight = 60;

  late AnimationController _controller;
  late Animation<double> _positionAnim;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _positionAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(CurvedBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width / widget.items.length;

        final currentBumpX = itemWidth * (widget.currentIndex + 0.5);
        final previousBumpX = itemWidth * (_previousIndex + 0.5);
        final bumpX =
            previousBumpX + (currentBumpX - previousBumpX) * _positionAnim.value;

        return SizedBox(
          height: _bumpRadius + _navBarHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: Size(width, _bumpRadius + _navBarHeight),
                painter: _BumpPainter(
                  bumpX: bumpX,
                  bumpRadius: _bumpRadius,
                  navBarHeight: _navBarHeight,
                ),
              ),
              Positioned(
                left: bumpX - 18,
                top: _bumpRadius - 18,
                child: Icon(
                  widget.items[widget.currentIndex].icon,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              Positioned(
                top: _bumpRadius + 2,
                left: 0,
                right: 0,
                bottom: 0,
                child: Row(
                  children: List.generate(widget.items.length, (index) {
                    final isActive = index == widget.currentIndex;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => widget.onTap(index),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.items[index].icon,
                              color: isActive ? Colors.transparent : Colors.grey,
                              size: 22,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.items[index].label,
                              style: TextStyle(
                                color: isActive ? Colors.white : Colors.grey,
                                fontSize: isActive ? 12 : 11,
                                fontWeight:
                                    isActive ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BumpPainter extends CustomPainter {
  final double bumpX;
  final double bumpRadius;
  final double navBarHeight;

  _BumpPainter({
    required this.bumpX,
    required this.bumpRadius,
    required this.navBarHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bumpRect = Rect.fromCircle(
      center: Offset(bumpX, bumpRadius),
      radius: bumpRadius,
    );

    final shadowPaint = Paint()
      ..color = const Color(0xFF6D6AFB).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final shadowPath = Path()
      ..addOval(bumpRect.translate(0, 2));

    canvas.drawPath(shadowPath, shadowPaint);

    final bodyPaint = Paint()
      ..color = const Color(0xFF1F2343)
      ..style = PaintingStyle.fill;

    final bodyPath = Path()
      ..moveTo(0, bumpRadius)
      ..lineTo(bumpX - bumpRadius, bumpRadius)
      ..arcTo(bumpRect, pi, pi, false)
      ..lineTo(size.width, bumpRadius)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(bodyPath, bodyPaint);

    final strokePaint = Paint()
      ..color = const Color(0xFF6D6AFB).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final strokePath = Path()
      ..moveTo(bumpX - bumpRadius, bumpRadius)
      ..arcTo(bumpRect, pi, pi, false);

    canvas.drawPath(strokePath, strokePaint);
  }

  @override
  bool shouldRepaint(_BumpPainter oldDelegate) =>
      oldDelegate.bumpX != bumpX;
}
