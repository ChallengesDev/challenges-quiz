import 'package:flutter/material.dart';
import 'dart:math' as math;

class MascotWidget extends StatefulWidget {
  final String state; // 'idle', 'happy', 'sad', 'nervous', 'celebrating'
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
  late AnimationController _bounceController;
  late AnimationController _shakeController;
  late AnimationController _rotateController;

  late Animation<double> _bounceAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    
    // Bounce controller (for happy state)
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bounceAnimation = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Shake controller (for sad state)
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    // Rotate controller (for celebrating state)
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeInOut),
    );

    _updateAnimations();
  }

  void _updateAnimations() {
    // Reset all
    _bounceController.stop();
    _bounceController.reset();
    _shakeController.stop();
    _shakeController.reset();
    _rotateController.stop();
    _rotateController.reset();

    if (widget.state == 'happy') {
      _bounceController.repeat(reverse: true);
    } else if (widget.state == 'sad') {
      _shakeController.repeat(reverse: true);
    } else if (widget.state == 'celebrating') {
      _rotateController.repeat();
      _bounceController.repeat(reverse: true); // bounce while rotating
    }
  }

  @override
  void didUpdateWidget(MascotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimations();
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _shakeController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.speechBubbleText != null && widget.speechBubbleText!.isNotEmpty) ...[
          _buildSpeechBubble(widget.speechBubbleText!),
          const SizedBox(height: 8),
        ],
        AnimatedBuilder(
          animation: Listenable.merge([_bounceController, _shakeController, _rotateController]),
          builder: (context, child) {
            double offset = (widget.state == 'happy' || widget.state == 'celebrating') 
                ? _bounceAnimation.value 
                : 0;

            Widget mascot = SizedBox(
              width: widget.size,
              height: widget.size + 15,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Mascot Shadow
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: widget.size * 0.7,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  
                  // Mascot Body
                  Positioned(
                    bottom: 8,
                    child: Container(
                      width: widget.size * 0.8,
                      height: widget.size * 0.85,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff6c5ce7), Color(0xff8b5cf6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(widget.size * 0.4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff6c5ce7).withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Owl Tummy Patch
                          Positioned(
                            bottom: 0,
                            left: widget.size * 0.15,
                            child: Container(
                              width: widget.size * 0.5,
                              height: widget.size * 0.4,
                              decoration: BoxDecoration(
                                color: const Color(0xffa8a29e).withOpacity(0.2),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(widget.size * 0.25),
                                  topRight: Radius.circular(widget.size * 0.25),
                                ),
                              ),
                            ),
                          ),

                          // Owl Eyes
                          Positioned(
                            top: widget.size * 0.18,
                            left: widget.size * 0.1,
                            right: widget.size * 0.1,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildEye(true),
                                _buildEye(false),
                              ],
                            ),
                          ),

                          // Owl Beak (Dourado)
                          Positioned(
                            top: widget.size * 0.35,
                            left: widget.size * 0.35,
                            child: CustomPaint(
                              size: Size(widget.size * 0.1, widget.size * 0.1),
                              painter: BeakPainter(),
                            ),
                          ),

                          // Mascot Sweat Drop (Nervous state)
                          if (widget.state == 'nervous')
                            Positioned(
                              top: 10,
                              right: 12,
                              child: Container(
                                width: 12,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Colors.cyanAccent,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    bottomLeft: Radius.circular(6),
                                    bottomRight: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );

            // Apply animations based on state
            if (widget.state == 'sad') {
              mascot = Transform.rotate(
                angle: _shakeAnimation.value,
                child: mascot,
              );
            } else if (widget.state == 'celebrating') {
              mascot = Transform.rotate(
                angle: _rotateAnimation.value,
                child: mascot,
              );
            }

            return Transform.translate(
              offset: Offset(0, offset),
              child: mascot,
            );
          },
        ),
      ],
    );
  }

  Widget _buildSpeechBubble(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xff151c2c),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff00f5d4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff00f5d4).withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ]
      ),
      constraints: const BoxConstraints(maxWidth: 240),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Triangle Tip pointing down
          Positioned(
            bottom: -18,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.center,
              child: CustomPaint(
                size: const Size(12, 8),
                painter: SpeechBubbleTipPainter(),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEye(bool isLeft) {
    double eyeSize = widget.size * 0.22;
    
    if (widget.state == 'happy' || widget.state == 'celebrating') {
      // Happy eyes: smiling emoji style or arcs pointing upwards
      return Container(
        width: eyeSize,
        height: eyeSize,
        alignment: Alignment.center,
        child: Icon(Icons.sentiment_very_satisfied, color: const Color(0xff00f5d4), size: eyeSize),
      );
    }
    
    if (widget.state == 'sad') {
      // Sad eyes
      return Container(
        width: eyeSize,
        height: eyeSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey, width: 2),
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: eyeSize * 0.5,
              height: eyeSize * 0.5,
              decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                width: eyeSize * 0.4,
                height: eyeSize * 0.4,
                decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.state == 'nervous') {
      // Nervous wide eyes
      return Container(
        width: eyeSize,
        height: eyeSize,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: eyeSize * 0.6,
            height: eyeSize * 0.6,
            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      );
    }

    // Default 'idle' state eyes
    return Container(
      width: eyeSize,
      height: eyeSize,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: eyeSize * 0.5,
          height: eyeSize * 0.5,
          decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}

class BeakPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xffffd700)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SpeechBubbleTipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff151c2c)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xff00f5d4)
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

