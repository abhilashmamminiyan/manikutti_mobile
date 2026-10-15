import 'dart:math' as math;
import 'package:flutter/material.dart';

class SpiralVoiceWaves extends StatefulWidget {
  final bool isListening;
  final bool isProcessing;
  final VoidCallback onTap;

  const SpiralVoiceWaves({
    super.key,
    required this.isListening,
    required this.isProcessing,
    required this.onTap,
  });

  @override
  State<SpiralVoiceWaves> createState() => _SpiralVoiceWavesState();
}

class _SpiralVoiceWavesState extends State<SpiralVoiceWaves>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Continuous rotation for spiral arms
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // Pulsing wave amplitude
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 170,
        height: 170,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Rotating spiral waves & pulsing sound rings
            AnimatedBuilder(
              animation: Listenable.merge([
                _rotationController,
                _pulseController,
              ]),
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(170, 170),
                  painter: _SpiralWavePainter(
                    rotation: _rotationController.value,
                    pulse: _pulseController.value,
                    isListening: widget.isListening,
                    isProcessing: widget.isProcessing,
                  ),
                );
              },
            ),

            // Center: Manikutti Logo Emblem
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: widget.isListening
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (widget.isListening
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF2563EB))
                            .withOpacity(0.4),
                    blurRadius: 18,
                    spreadRadius: widget.isListening ? 3 : 1,
                  ),
                ],
                border: Border.all(
                  color: widget.isListening
                      ? const Color(0xFF38BDF8).withOpacity(0.8)
                      : Colors.white.withOpacity(0.2),
                  width: 2.0,
                ),
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    'assets/icons/app_icon_foreground.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to high-end wallet icon if asset path fails
                      return const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Color(0xFF38BDF8),
                        size: 34,
                      );
                    },
                  ),
                ),
              ),
            ),

            // Corner Mic Status Badge
            Positioned(
              right: 48,
              bottom: 48,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isListening
                      ? Colors.redAccent
                      : const Color(0xFF2563EB),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (widget.isListening
                                  ? Colors.redAccent
                                  : const Color(0xFF2563EB))
                              .withOpacity(0.6),
                      blurRadius: 8,
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(
                  widget.isListening
                      ? Icons.mic
                      : (widget.isProcessing
                            ? Icons.hourglass_top
                            : Icons.mic_none),
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpiralWavePainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final bool isListening;
  final bool isProcessing;

  _SpiralWavePainter({
    required this.rotation,
    required this.pulse,
    required this.isListening,
    required this.isProcessing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // 1. Draw expanding concentric ripple rings
    final ringPaint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (pulse + (i / 3.0)) % 1.0;
      final radius = 36.0 + (maxRadius - 36.0) * ringProgress;
      final opacity = ((1.0 - ringProgress) * (isListening ? 0.45 : 0.18))
          .clamp(0.0, 1.0);

      ringPaint
        ..strokeWidth = isListening ? (1.5 + (1.0 - ringProgress)) : 1.2
        ..color =
            (isListening ? const Color(0xFF38BDF8) : const Color(0xFF60A5FA))
                .withOpacity(opacity);

      canvas.drawCircle(center, radius, ringPaint);
    }

    // 2. Draw 4 rotating spiral wave arms
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final angleSpeedMultiplier = isListening ? 1.0 : 0.5;
    canvas.rotate(rotation * 2 * math.pi * angleSpeedMultiplier);

    final colors = isListening
        ? [
            const Color(0xFF38BDF8), // Cyan
            const Color(0xFF818CF8), // Indigo
            const Color(0xFF34D399), // Emerald
            const Color(0xFFF472B6), // Pink
          ]
        : [
            const Color(0xFF3B82F6),
            const Color(0xFF60A5FA),
            const Color(0xFF93C5FD),
            const Color(0xFF2563EB),
          ];

    for (int arm = 0; arm < 4; arm++) {
      final armAngleOffset = arm * (math.pi / 2);
      final path = Path();
      const numPoints = 65;

      for (int step = 0; step < numPoints; step++) {
        final t = step / numPoints;
        final angle = armAngleOffset + t * 2.2 * math.pi;
        final wobble = isListening
            ? (0.12 * math.sin((pulse * 2 * math.pi) + (step * 0.2)))
            : 0.0;
        final r = 36.0 + (maxRadius - 36.0) * t * (1.0 + wobble);
        final x = r * math.cos(angle);
        final y = r * math.sin(angle);

        if (step == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final alpha = (tToAlpha(isListening) * (1.0 - (arm % 2 == 0 ? 0.0 : 0.2)))
          .clamp(0.0, 1.0);
      final armPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isListening ? 2.2 : 1.4
        ..strokeCap = StrokeCap.round
        ..color = colors[arm % colors.length].withOpacity(alpha);

      canvas.drawPath(path, armPaint);
    }

    canvas.restore();
  }

  double tToAlpha(bool listening) => listening ? 0.70 : 0.35;

  @override
  bool shouldRepaint(covariant _SpiralWavePainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.pulse != pulse ||
        oldDelegate.isListening != isListening ||
        oldDelegate.isProcessing != isProcessing;
  }
}
