import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class MascotWidget extends StatefulWidget {
  final String state; // 'idle', 'happy', 'sad', 'thinking', 'celebrating', 'nervous'
  final double size;
  final String? speechBubbleText;

  const MascotWidget({
    super.key,
    required this.state,
    this.size = 120,
    this.speechBubbleText,
  });

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget> with TickerProviderStateMixin {
  late AnimationController _loopController;
  late AnimationController _jumpController;
  late Animation<double> _jumpAnimation;

  @override
  void initState() {
    super.initState();

    // Constant breathing/wiggle animation loop
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Jumping animation for happy / celebrating states
    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _jumpAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _jumpController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
      ),
    );

    _updateStateAnimations();
  }

  void _updateStateAnimations() {
    if (widget.state == 'happy' || widget.state == 'celebrating') {
      _jumpController.repeat(reverse: true);
    } else {
      _jumpController.stop();
      _jumpController.reset();
    }
  }

  @override
  void didUpdateWidget(MascotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateStateAnimations();
    }
  }

  @override
  void dispose() {
    _loopController.dispose();
    _jumpController.dispose();
    super.dispose();
  }

  Color _getMascotColor(String colorKey) {
    switch (colorKey) {
      case 'verde':
        return const Color(0xff00f5d4);
      case 'dourado':
        return const Color(0xffffd700);
      case 'azul':
        return const Color(0xff00c6ff);
      case 'roxo':
      default:
        return const Color(0xff6B5FD3);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read user properties from Providers
    final authProvider = Provider.of<AuthProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);

    final colorKey = authProvider.colaborador?.corMascote ?? 'roxo';
    final int level = profileProvider.pontuacao?.nivel ?? 1;

    final themeColor = _getMascotColor(colorKey);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.speechBubbleText != null && widget.speechBubbleText!.isNotEmpty) ...[
          _buildSpeechBubble(widget.speechBubbleText!, themeColor),
          const SizedBox(height: 8),
        ],
        AnimatedBuilder(
          animation: Listenable.merge([_loopController, _jumpController]),
          builder: (context, child) {
            return CustomPaint(
              size: Size(widget.size, widget.size + 15),
              painter: OctoPainter(
                state: widget.state,
                colorKey: colorKey,
                level: level,
                loopValue: _loopController.value,
                jumpValue: _jumpAnimation.value,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSpeechBubble(String text, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xffFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ]),
      constraints: const BoxConstraints(maxWidth: 240),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xff2D2D3A),
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Positioned(
            bottom: -18,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.center,
              child: CustomPaint(
                size: const Size(12, 8),
                painter: SpeechBubbleTipPainter(borderColor: borderColor),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class SpeechBubbleTipPainter extends CustomPainter {
  final Color borderColor;

  SpeechBubbleTipPainter({required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xffFFFFFF)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class OctoPainter extends CustomPainter {
  final String state;
  final String colorKey;
  final int level;
  final double loopValue;
  final double jumpValue;

  OctoPainter({
    required this.state,
    required this.colorKey,
    required this.level,
    required this.loopValue,
    required this.jumpValue,
  });

  List<Color> _getGradients(String key) {
    switch (key) {
      case 'verde':
        return [const Color(0xff00ff87), const Color(0xff00f5d4)];
      case 'dourado':
        return [const Color(0xffffe259), const Color(0xffffa751)];
      case 'azul':
        return [const Color(0xff00c6ff), const Color(0xff0072ff)];
      case 'roxo':
      default:
        return [const Color(0xff8c82f2), const Color(0xff6B5FD3)];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final colors = _getGradients(colorKey);
    final primaryColor = colors[0];
    final secondaryColor = colors[1];

    final double cx = size.width / 2;
    // Bouncing calculation for happy/celebrating states
    final double bounceOffset = (state == 'happy' || state == 'celebrating') ? -jumpValue * 12 : 0;
    final double cy = (size.height * 0.42) + bounceOffset;

    final double headRadiusX = size.width * 0.28;
    final double headRadiusY = size.width * 0.26;

    // 1. Draw Background Glow / Shadow
    final double glowRadius = headRadiusX * (level <= 10 ? 1.4 : (level <= 25 ? 1.8 : 2.2));
    final double glowOpacity = (state == 'happy' || state == 'celebrating')
        ? 0.45 + math.sin(loopValue * 4 * math.pi) * 0.15
        : (level <= 10 ? 0.15 : (level <= 25 ? 0.25 : 0.38));

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [primaryColor.withOpacity(glowOpacity), primaryColor.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: glowRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cx, cy), glowRadius, glowPaint);

    // 2. Draw Orbiting Particles (Evolution Stage 3: Levels 26+)
    if (level >= 26) {
      final particlePaint = Paint()
        ..shader = RadialGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.0)],
        ).createShader(Rect.fromCircle(center: Offset(0, 0), radius: 6.0))
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 4; i++) {
        // Orbit positions
        final double pAngle = (loopValue * 2 * math.pi) + (i * math.pi / 2);
        final double rx = headRadiusX * 1.5;
        final double ry = headRadiusY * 0.9;
        final double px = cx + math.cos(pAngle) * rx;
        final double py = cy + math.sin(pAngle) * ry * (i % 2 == 0 ? 1 : -1);

        // Draw particle glow
        canvas.drawCircle(Offset(px, py), 8.0, Paint()..color = primaryColor.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        canvas.drawCircle(Offset(px, py), 4.0, Paint()..color = Colors.white);
      }
    }

    // 3. Draw Tentacles (behind the body)
    final tentaclePaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor, secondaryColor.darken()],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: headRadiusX * 1.6))
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    final double length = size.width * 0.28;

    for (int i = 0; i < 8; i++) {
      // Base angles distributed along bottom arc (from ~140 to ~40 degrees)
      final double angle = math.pi * 0.15 + (math.pi * 0.70) * (i / 7);
      final double bx = cx + math.cos(angle) * headRadiusX * 0.85;
      final double by = cy + math.sin(angle) * headRadiusY * 0.85;

      double ex = bx;
      double ey = by;

      if (state == 'sad') {
        // Drooping / withered tentacles
        ex = bx + math.cos(angle) * length * 0.6;
        ey = by + length * 0.85;
      } else if (state == 'thinking' && i == 5) {
        // Tentacle 5 curved up to touch head
        ex = cx + headRadiusX * 0.95;
        ey = cy - headRadiusY * 0.15;
      } else if (state == 'celebrating') {
        // Fanning out radiantly
        final double fanAngle = angle + math.sin(loopValue * 6 * math.pi + i) * 0.15;
        ex = cx + math.cos(fanAngle) * length * 1.15;
        ey = cy + math.sin(fanAngle) * length * 1.15;
      } else if (state == 'happy') {
        // Wavy movement
        final double wave = math.sin(loopValue * 4 * math.pi + i * 1.2) * 14.0;
        ex = bx + math.cos(angle) * length * 0.8;
        ey = by + math.sin(angle) * length * 0.8 + wave - 3;
      } else {
        // Idle/thinking standard: slow wiggling
        final double wave = math.sin(loopValue * 2 * math.pi + i * 0.8) * 6.0;
        ex = bx + math.cos(angle) * length * 0.85;
        ey = by + math.sin(angle) * length * 0.85 + wave;
      }

      final path = Path()..moveTo(bx, by);
      if (state == 'thinking' && i == 5) {
        // Curve to the side of the head
        path.cubicTo(bx + 15, by - 5, ex + 25, ey + 30, ex, ey);
      } else {
        path.quadraticBezierTo((bx + ex) / 2 + (i - 3.5) * 3, (by + ey) / 2, ex, ey);
      }
      canvas.drawPath(path, tentaclePaint);
    }

    // 4. Draw Octo Main Body (Head)
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor, secondaryColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: headRadiusX * 2, height: headRadiusY * 2))
      ..style = PaintingStyle.fill;

    final bodyRect = Rect.fromCenter(center: Offset(cx, cy), width: headRadiusX * 2, height: headRadiusY * 2);
    canvas.drawOval(bodyRect, bodyPaint);

    // 5. Draw Geometric Pattern (Evolution Stage 2 & 3: Levels 11+)
    if (level >= 11) {
      final double rotAngle = (level >= 26) ? loopValue * 0.4 * math.pi : loopValue * 0.1 * math.pi;
      
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rotAngle);
      
      final patternPaint = Paint()
        ..color = Colors.white.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      // Hexagonal / concentric patterns
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: headRadiusX * 1.3, height: headRadiusY * 1.3), patternPaint);
      canvas.drawCircle(Offset.zero, headRadiusX * 0.6, patternPaint);
      
      canvas.restore();
    }

    // 6. Draw Eyes
    final double eyeY = cy - headRadiusY * 0.1;
    final double leftEyeX = cx - headRadiusX * 0.32;
    final double rightEyeX = cx + headRadiusX * 0.32;
    final double eyeRadius = size.width * 0.038;

    final eyePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    if (state == 'happy' || state == 'celebrating') {
      // Smiling arcs pointing upwards
      final arcPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(Rect.fromCircle(center: Offset(leftEyeX, eyeY + 2), radius: eyeRadius * 0.8), math.pi, math.pi, false, arcPaint);
      canvas.drawArc(Rect.fromCircle(center: Offset(rightEyeX, eyeY + 2), radius: eyeRadius * 0.8), math.pi, math.pi, false, arcPaint);
    } else if (state == 'sad') {
      // Gentle soft drooping eyes (encouraging)
      canvas.drawCircle(Offset(leftEyeX, eyeY), eyeRadius, eyePaint);
      canvas.drawCircle(Offset(rightEyeX, eyeY), eyeRadius, eyePaint);
      canvas.drawCircle(Offset(leftEyeX - 1.5, eyeY - 1.5), 2.0, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(rightEyeX - 1.5, eyeY - 1.5), 2.0, Paint()..color = Colors.white);

      // Gentle eyebrows pointing up in center
      final browPaint = Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(Rect.fromCircle(center: Offset(leftEyeX + 2, eyeY - 7), radius: eyeRadius * 0.9), math.pi * 1.1, math.pi * 0.7, false, browPaint);
      canvas.drawArc(Rect.fromCircle(center: Offset(rightEyeX - 2, eyeY - 7), radius: eyeRadius * 0.9), math.pi * 1.2, math.pi * 0.7, false, browPaint);
    } else if (state == 'thinking') {
      // Concentrated eyes
      canvas.drawCircle(Offset(leftEyeX, eyeY), eyeRadius, eyePaint);
      canvas.drawCircle(Offset(rightEyeX, eyeY), eyeRadius, eyePaint);
      canvas.drawCircle(Offset(leftEyeX - 1.5, eyeY - 1.5), 2.0, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(rightEyeX - 1.5, eyeY - 1.5), 2.0, Paint()..color = Colors.white);

      // Left eyebrow straight, right tilted up
      final browPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(leftEyeX - 7, eyeY - 7), Offset(leftEyeX + 7, eyeY - 7), browPaint);
      canvas.drawLine(Offset(rightEyeX - 6, eyeY - 10), Offset(rightEyeX + 8, eyeY - 5), browPaint);
    } else if (state == 'nervous') {
      // Wide nervous eyes
      canvas.drawCircle(Offset(leftEyeX, eyeY), eyeRadius, eyePaint);
      canvas.drawCircle(Offset(rightEyeX, eyeY), eyeRadius, eyePaint);
      canvas.drawCircle(Offset(leftEyeX, eyeY), eyeRadius * 0.4, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(rightEyeX, eyeY), eyeRadius * 0.4, Paint()..color = Colors.white);

      // Sweat drop on side of face
      final sweatPaint = Paint()
        ..color = const Color(0xff00f5d4)
        ..style = PaintingStyle.fill;
      final sweatPath = Path()
        ..moveTo(cx + headRadiusX * 0.65, cy - headRadiusY * 0.4)
        ..quadraticBezierTo(cx + headRadiusX * 0.8, cy - headRadiusY * 0.25, cx + headRadiusX * 0.65, cy - headRadiusY * 0.1)
        ..quadraticBezierTo(cx + headRadiusX * 0.5, cy - headRadiusY * 0.25, cx + headRadiusX * 0.65, cy - headRadiusY * 0.4);
      canvas.drawPath(sweatPath, sweatPaint);
    } else {
      // Idle / Default eyes
      canvas.drawCircle(Offset(leftEyeX, eyeY), eyeRadius, eyePaint);
      canvas.drawCircle(Offset(rightEyeX, eyeY), eyeRadius, eyePaint);
      canvas.drawCircle(Offset(leftEyeX - 1.5, eyeY - 1.5), 2.2, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(rightEyeX - 1.5, eyeY - 1.5), 2.2, Paint()..color = Colors.white);
    }

    // 7. Draw Mouth
    final double mouthY = cy + headRadiusY * 0.22;
    if (state == 'happy' || state == 'celebrating') {
      // Open happy mouth
      final mouthPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      canvas.drawArc(Rect.fromCenter(center: Offset(cx, mouthY), width: 14, height: 14), 0, math.pi, true, mouthPaint);
    } else if (state == 'sad') {
      // Subtle frown
      final mouthPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCenter(center: Offset(cx, mouthY + 3), width: 10, height: 6), math.pi, math.pi, false, mouthPaint);
    } else if (state == 'thinking') {
      // Small straight line
      final mouthPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - 5, mouthY + 1), Offset(cx + 5, mouthY + 1), mouthPaint);
    } else if (state == 'nervous') {
      // Squiggly line
      final mouthPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(cx - 5, mouthY)
        ..lineTo(cx - 2, mouthY + 2)
        ..lineTo(cx + 1, mouthY - 2)
        ..lineTo(cx + 5, mouthY);
      canvas.drawPath(path, mouthPaint);
    } else {
      // Idle small smile
      final mouthPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCenter(center: Offset(cx, mouthY), width: 12, height: 8), 0, math.pi, false, mouthPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

extension ColorDarken on Color {
  Color darken([double amount = 0.2]) {
    assert(amount >= 0 && amount <= 1);
    final f = 1 - amount;
    return Color.fromARGB(
      alpha,
      (red * f).round(),
      (green * f).round(),
      (blue * f).round(),
    );
  }
}
