import 'package:flutter/material.dart';

class MascotWidget extends StatefulWidget {
  final String state; // 'idle', 'happy', 'sad', 'nervous'
  final double size;

  const MascotWidget({
    super.key,
    required this.state,
    this.size = 120,
  });

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceAnimation = Tween<double>(begin: 0, end: -15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    // Automatically trigger bounce if status is happy
    if (widget.state == 'happy') {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(MascotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == 'happy') {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        double offset = (widget.state == 'happy') ? _bounceAnimation.value : 0;
        return Transform.translate(
          offset: Offset(0, offset),
          child: SizedBox(
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
          ),
        );
      },
    );
  }

  Widget _buildEye(bool isLeft) {
    double eyeSize = widget.size * 0.22;
    
    if (widget.state == 'happy') {
      // Happy eyes: arcs pointing upwards (smiling eyes)
      return Container(
        width: eyeSize,
        height: eyeSize,
        alignment: Alignment.center,
        child: Icon(Icons.sentiment_very_satisfied, color: const Color(0xff00f5d4), size: eyeSize),
      );
    }
    
    if (widget.state == 'sad') {
      // Teary eyes
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
            // Tear overlay
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
