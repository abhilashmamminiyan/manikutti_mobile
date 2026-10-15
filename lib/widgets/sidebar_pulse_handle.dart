import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Floating handle pinned to the left edge of the screen.
/// Displays an animated pulsing arrow at the top and an options icon below it.
/// Tapping it opens the sidebar drawer.
class SidebarPulseHandle extends StatefulWidget {
  final VoidCallback onTap;
  final double topOffset;

  const SidebarPulseHandle({
    super.key,
    required this.onTap,
    this.topOffset = 135.0,
  });

  @override
  State<SidebarPulseHandle> createState() => _SidebarPulseHandleState();
}

class _SidebarPulseHandleState extends State<SidebarPulseHandle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.25).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.70, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? AppTheme.darkSurfaceContainer
        : AppTheme.surfaceContainerLowest;
    final borderColor = isDark
        ? const Color(0xFF2C3233)
        : AppTheme.outlineVariant.withOpacity(0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(
                top: BorderSide(color: borderColor, width: 1.2),
                right: BorderSide(color: borderColor, width: 1.2),
                bottom: BorderSide(color: borderColor, width: 1.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(2, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top section: Pulsing Arrow pointing right to open the sidebar
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _opacityAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 7),
                Container(
                  width: 14,
                  height: 1,
                  color: borderColor,
                ),
                const SizedBox(height: 7),
                // Options Icon below the pulsing arrow
                Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: isDark ? AppTheme.darkOnSurface : AppTheme.primary,
                ),
              ],
            ),
          ),
        ),
      );
  }
}
