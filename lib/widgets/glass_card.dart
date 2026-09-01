// lib/widgets/glass_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double blur;
  final bool hasBorder;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderColor,
    this.blur = 20,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // ✅ Use solid background behind the blur for better readability
    final bgColor = backgroundColor ??
        (isDark
            ? const Color(0xFF1A1A2E).withOpacity(0.85)  // Solid dark background
            : Colors.white.withOpacity(0.85));            // Solid white background

    final border = borderColor ??
        (isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.white.withOpacity(0.3));

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor, // ✅ Solid color behind blur
          borderRadius: BorderRadius.circular(borderRadius),
          border: hasBorder ? Border.all(color: border, width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}