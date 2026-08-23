// lib/widgets/skeleton_loading.dart
import 'package:flutter/material.dart';
import 'dart:ui';

/// A shimmer effect container that pulses a gradient.
class Shimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color baseColor;
  final Color highlightColor;

  const Shimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        final double offset = _shimmerAnimation.value;
        final LinearGradient gradient = LinearGradient(
          begin: Alignment(offset - 1.0, 0.0),
          end: Alignment(offset + 1.0, 0.0),
          colors: [
            widget.baseColor,
            widget.highlightColor,
            widget.baseColor,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
        return ShaderMask(
          shaderCallback: (Rect bounds) => gradient.createShader(bounds),
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ---- Glassmorphism Skeleton Cards ----

/// Skeleton placeholder for a stat card (used in dashboard grid).
class SkeletonStatCard extends StatelessWidget {
  final bool isDark;
  const SkeletonStatCard({super.key, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    final dark = isDark || Theme.of(context).brightness == Brightness.dark;
    final bgColor = dark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200;
    final shimmerBase = dark ? Colors.grey.shade700 : Colors.grey.shade300;
    final shimmerHighlight = dark ? Colors.grey.shade600 : Colors.grey.shade100;

    return Card(
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(dark ? 0.08 : 0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Shimmer(
          baseColor: shimmerBase,
          highlightColor: shimmerHighlight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, color: shimmerBase, size: 32),
              const SizedBox(height: 8),
              Container(
                height: 22,
                width: 50,
                color: shimmerBase,
              ),
              const SizedBox(height: 4),
              Container(
                height: 14,
                width: 70,
                color: shimmerBase,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton placeholder for a list tile.
class SkeletonListTile extends StatelessWidget {
  final bool isDark;
  const SkeletonListTile({super.key, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    final dark = isDark || Theme.of(context).brightness == Brightness.dark;
    final bgColor = dark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.2);
    final shimmerBase = dark ? Colors.grey.shade700 : Colors.grey.shade300;
    final shimmerHighlight = dark ? Colors.grey.shade600 : Colors.grey.shade100;

    return Card(
      elevation: 0,
      color: bgColor,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(dark ? 0.08 : 0.15), width: 1),
      ),
      child: Shimmer(
        baseColor: shimmerBase,
        highlightColor: shimmerHighlight,
        child: ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: shimmerBase,
          ),
          title: Container(height: 16, color: shimmerBase),
          subtitle: Container(height: 12, color: shimmerBase),
          trailing: Container(width: 40, height: 20, color: shimmerBase),
        ),
      ),
    );
  }
}

/// Skeleton for a profile card.
class SkeletonProfile extends StatelessWidget {
  final bool isDark;
  const SkeletonProfile({super.key, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    final dark = isDark || Theme.of(context).brightness == Brightness.dark;
    final bgColor = dark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.2);
    final shimmerBase = dark ? Colors.grey.shade700 : Colors.grey.shade300;
    final shimmerHighlight = dark ? Colors.grey.shade600 : Colors.grey.shade100;

    return Card(
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(dark ? 0.08 : 0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Shimmer(
          baseColor: shimmerBase,
          highlightColor: shimmerHighlight,
          child: Column(
            children: [
              const CircleAvatar(radius: 50, backgroundColor: Color(0xFFE0E0E0)),
              const SizedBox(height: 12),
              Container(height: 22, width: 150, color: shimmerBase),
              const SizedBox(height: 8),
              Container(height: 16, width: 200, color: shimmerBase),
              const SizedBox(height: 8),
              Container(height: 16, width: 100, color: shimmerBase),
              const SizedBox(height: 8),
              Container(
                height: 24,
                width: 80,
                decoration: BoxDecoration(
                  color: shimmerBase,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for a purchase/order card.
class SkeletonPurchaseCard extends StatelessWidget {
  final bool isDark;
  const SkeletonPurchaseCard({super.key, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    final dark = isDark || Theme.of(context).brightness == Brightness.dark;
    final bgColor = dark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.2);
    final shimmerBase = dark ? Colors.grey.shade700 : Colors.grey.shade300;
    final shimmerHighlight = dark ? Colors.grey.shade600 : Colors.grey.shade100;

    return Card(
      elevation: 0,
      color: bgColor,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(dark ? 0.08 : 0.15), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Shimmer(
          baseColor: shimmerBase,
          highlightColor: shimmerHighlight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(height: 16, width: 80, color: shimmerBase),
                  Container(height: 20, width: 60, color: shimmerBase),
                ],
              ),
              const SizedBox(height: 8),
              Container(height: 14, width: 150, color: shimmerBase),
              Container(height: 14, width: 200, color: shimmerBase),
              Container(height: 14, width: 180, color: shimmerBase),
              const SizedBox(height: 8),
              Container(height: 40, width: double.infinity, color: shimmerBase),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for the banner carousel.
class SkeletonBannerCarousel extends StatelessWidget {
  final bool isDark;
  const SkeletonBannerCarousel({super.key, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    final dark = isDark || Theme.of(context).brightness == Brightness.dark;
    final bgColor = dark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.2);
    final shimmerBase = dark ? Colors.grey.shade700 : Colors.grey.shade300;
    final shimmerHighlight = dark ? Colors.grey.shade600 : Colors.grey.shade100;

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: Card(
            elevation: 0,
            color: bgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withOpacity(dark ? 0.08 : 0.2), width: 1),
            ),
            child: Shimmer(
              baseColor: shimmerBase,
              highlightColor: shimmerHighlight,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: shimmerBase,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(height: 14, width: 100, color: shimmerBase),
                          const SizedBox(height: 4),
                          Container(height: 24, width: 150, color: shimmerBase),
                          const SizedBox(height: 4),
                          Container(height: 16, width: 120, color: shimmerBase),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          width: 60,
          decoration: BoxDecoration(
            color: shimmerBase,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}