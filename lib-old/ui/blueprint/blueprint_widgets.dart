import 'package:flutter/material.dart';

import '../../app/app_theme_controller.dart';

class BlueprintTokens {
  static const Color accent = Color(0xFF1E5DFF);
  static const Color accentSoft = Color(0xFF41C7FF);

  static bool get _isDark => AppThemeController.mode.value == ThemeMode.dark;

  static Color get ink =>
      _isDark ? const Color(0xFFE6EEFF) : const Color(0xFF0D1B39);
  static Color get muted =>
      _isDark ? const Color(0xFF9AA8C7) : const Color(0xFF5B6B8A);
  static Color get bg =>
      _isDark ? const Color(0xFF0B1220) : const Color(0xFFF4F8FF);
  static Color get panel =>
      _isDark ? const Color(0xFF111A2B) : const Color(0xFFFFFFFF);
  static Color get border =>
      _isDark ? const Color(0xFF24314B) : const Color(0xFFD6E2FF);
  static Color get glow =>
      _isDark ? const Color(0xFF1C2E5A) : const Color(0xFFB9D6FF);
}

class BlueprintBackground extends StatelessWidget {
  const BlueprintBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF0B1324), Color(0xFF0E1B34)]
              : const [Color(0xFFF8FBFF), Color(0xFFEEF4FF)],
        ),
      ),
      child: Stack(
        children: [
          CustomPaint(
            painter: _GridPainter(
              lineColor: BlueprintTokens.border.withValues(alpha: 0.6),
              spacing: 32,
            ),
            size: Size.infinite,
          ),
          const _BlueprintShapes(),
        ],
      ),
    );
  }
}

class _BlueprintShapes extends StatelessWidget {
  const _BlueprintShapes();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: _GlowSquare(
              size: 140,
              color: BlueprintTokens.accent.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: _GlowSquare(
              size: 200,
              color: BlueprintTokens.accentSoft.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            top: 120,
            left: 18,
            child: _OutlineSquare(
              size: 86,
              color: BlueprintTokens.border.withValues(alpha: 0.9),
            ),
          ),
          Positioned(
            bottom: 160,
            right: 20,
            child: _OutlineSquare(
              size: 110,
              color: BlueprintTokens.border.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowSquare extends StatelessWidget {
  const _GlowSquare({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: color, blurRadius: 40, spreadRadius: 6)],
      ),
    );
  }
}

class _OutlineSquare extends StatelessWidget {
  const _OutlineSquare({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.lineColor, required this.spacing});

  final Color lineColor;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BlueprintPanel extends StatelessWidget {
  const BlueprintPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.tone,
    this.showAccent = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? tone;
  final bool showAccent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tone ?? BlueprintTokens.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BlueprintTokens.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: BlueprintTokens.glow.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showAccent)
            Container(
              height: 4,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                gradient: LinearGradient(
                  colors: [BlueprintTokens.accent, BlueprintTokens.accentSoft],
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class BlueprintTag extends StatelessWidget {
  const BlueprintTag({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? BlueprintTokens.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tone),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
