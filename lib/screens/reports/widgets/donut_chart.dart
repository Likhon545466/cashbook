import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/money_formatter.dart';

class DonutChartData {
  final String label;
  final int value;
  final Color color;

  const DonutChartData({
    required this.label,
    required this.value,
    required this.color,
  });
}

class DonutChart extends StatefulWidget {
  final List<DonutChartData> items;
  final String centerTitle;
  final double thickness;
  final ValueChanged<int?>? onSegmentSelected;

  const DonutChart({
    super.key,
    required this.items,
    this.centerTitle = 'Total',
    this.thickness = 32,
    this.onSegmentSelected,
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _animation;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _animController.forward(from: 0.0);
      _selectedIndex = null;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details, Size size) {
    if (widget.items.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final touchPosition = details.localPosition;
    final dx = touchPosition.dx - center.dx;
    final dy = touchPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    final outerRadius = math.min(size.width, size.height) / 2;
    final innerRadius = outerRadius - widget.thickness - 12;

    if (distance < innerRadius || distance > outerRadius + 8) {
      // Tap outside donut ring or inside inner hole
      if (_selectedIndex != null) {
        HapticFeedback.selectionClick();
        setState(() => _selectedIndex = null);
        widget.onSegmentSelected?.call(null);
      }
      return;
    }

    var angle = math.atan2(dy, dx);
    // Convert angle to [0, 2pi) starting from -pi/2 (top)
    angle += math.pi / 2;
    if (angle < 0) {
      angle += 2 * math.pi;
    }

    final total = widget.items.fold<int>(0, (sum, item) => sum + item.value);
    if (total == 0) return;

    var currentAngle = 0.0;
    int? tappedIndex;

    for (var i = 0; i < widget.items.length; i++) {
      final sweep = (widget.items[i].value / total) * 2 * math.pi;
      if (angle >= currentAngle && angle <= currentAngle + sweep) {
        tappedIndex = i;
        break;
      }
      currentAngle += sweep;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = (_selectedIndex == tappedIndex) ? null : tappedIndex;
    });
    widget.onSegmentSelected?.call(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.fold<int>(0, (sum, item) => sum + item.value);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (widget.items.isEmpty || total == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart_outline_rounded,
                  size: 48, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 10),
              Text(
                'No data for selected period',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final selected = _selectedIndex != null && _selectedIndex! < widget.items.length
        ? widget.items[_selectedIndex!]
        : null;

    final displayAmount = selected != null ? selected.value : total;
    final displayLabel = selected != null ? selected.label : widget.centerTitle;
    final displayPercent = selected != null && total > 0
        ? ((selected.value / total) * 100).toStringAsFixed(1)
        : null;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = math.min(constraints.maxWidth, 240.0);

            return GestureDetector(
              onTapUp: (details) => _handleTap(details, Size(size, size)),
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return CustomPaint(
                          size: Size(size, size),
                          painter: _DonutChartPainter(
                            items: widget.items,
                            progress: _animation.value,
                            selectedIndex: _selectedIndex,
                            thickness: widget.thickness,
                            emptyColor: scheme.surfaceContainerHighest,
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: selected != null
                                  ? selected.color
                                  : scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              MoneyFormatter.currency(displayAmount),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          if (displayPercent != null) ...[
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: selected!.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '$displayPercent%',
                                style: TextStyle(
                                  color: selected.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 2),
                            Text(
                              'Tap slice to inspect',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<DonutChartData> items;
  final double progress;
  final int? selectedIndex;
  final double thickness;
  final Color emptyColor;

  _DonutChartPainter({
    required this.items,
    required this.progress,
    required this.selectedIndex,
    required this.thickness,
    required this.emptyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;

    final total = items.fold<int>(0, (sum, item) => sum + item.value);
    if (total == 0) return;

    var startAngle = -math.pi / 2;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final sweepAngle = (item.value / total) * 2 * math.pi * progress;
      final isSelected = selectedIndex == i;
      final isAnySelected = selectedIndex != null;

      final currentThickness = isSelected ? thickness + 6 : thickness;
      final currentRadius = isSelected ? radius + 2 : radius;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = currentThickness
        ..strokeCap = StrokeCap.butt;

      if (isAnySelected && !isSelected) {
        paint.color = item.color.withValues(alpha: 0.35);
      } else {
        paint.color = item.color;
      }

      // Draw slice arc with small 1.5 degree gap between slices
      final gap = items.length > 1 ? 0.03 : 0.0;
      final effectiveSweep = math.max(0.0, sweepAngle - gap);

      final rect = Rect.fromCircle(center: center, radius: currentRadius - currentThickness / 2);
      canvas.drawArc(
        rect,
        startAngle + gap / 2,
        effectiveSweep,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.items != items;
  }
}
