import 'dart:math';
import 'package:flutter/material.dart';
import '../models/models.dart';

class TrailMap extends StatelessWidget {
  final List<Desafio> desafios;
  final Set<String> completedDesafiosIds; // Desafios concluidos
  final String activeDesafioId; // O primeiro que não está concluído
  final Function(Desafio) onNodeSelected;

  const TrailMap({
    super.key,
    required this.desafios,
    required this.completedDesafiosIds,
    required this.activeDesafioId,
    required this.onNodeSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (desafios.isEmpty) {
      return const SizedBox.shrink();
    }

    final double nodeHeight = 120.0;
    // Map height includes N challenges + 1 trophy node
    final double mapHeight = (desafios.length + 1) * nodeHeight + 40.0;
    final allCompleted = completedDesafiosIds.length >= desafios.length;

    return Container(
      width: double.infinity,
      height: mapHeight,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Sinuous Connection Line in background (including connection to the trophy node)
          Positioned.fill(
            child: CustomPaint(
              painter: ConnectionLinePainter(
                nodesCount: desafios.length + 1,
                nodeHeight: nodeHeight,
              ),
            ),
          ),
          
          // Challenge Nodes
          ...List.generate(desafios.length, (index) {
            final desafio = desafios[index];
            final isCompleted = completedDesafiosIds.contains(desafio.id);
            final isActive = desafio.id == activeDesafioId || (completedDesafiosIds.isEmpty && index == 0);
            final isLocked = !isCompleted && !isActive;

            // Coordinates matching the painter
            final double xOffset = _getXOffsetForIndex(index, 75.0);
            final double yPos = index * nodeHeight;

            Widget nodeWidget = _buildNodeButton(context, desafio, isCompleted, isActive, isLocked);

            if (isActive) {
              // Pulse & unlock entry animation
              nodeWidget = ScaleFadeInWidget(
                child: ActiveNodeWidget(
                  child: nodeWidget,
                ),
              );
            }

            return Positioned(
              top: yPos,
              left: MediaQuery.of(context).size.width / 2 - 40 + xOffset,
              child: nodeWidget,
            );
          }),

          // Trophy/Flag Node at the end
          (() {
            final int index = desafios.length;
            final double xOffset = _getXOffsetForIndex(index, 75.0);
            final double yPos = index * nodeHeight;

            Widget trophyWidget = _buildTrophyNodeButton(context, allCompleted);

            if (allCompleted) {
              trophyWidget = ScaleFadeInWidget(
                child: ActiveNodeWidget(
                  glowColor: const Color(0xffFFD700),
                  child: trophyWidget,
                ),
              );
            }

            return Positioned(
              top: yPos,
              left: MediaQuery.of(context).size.width / 2 - 40 + xOffset,
              child: trophyWidget,
            );
          }()),
        ],
      ),
    );
  }

  static double _getXOffsetForIndex(int index, double amplitude) {
    // Sinuous zig-zag: center, right, center, left...
    int state = index % 4;
    if (state == 1) return amplitude;
    if (state == 3) return -amplitude;
    return 0.0;
  }

  Widget _buildNodeButton(BuildContext context, Desafio desafio, bool isCompleted, bool isActive, bool isLocked) {
    Color nodeColor = Colors.grey.shade300;
    Color borderColor = Colors.grey.shade400;
    IconData nodeIcon = Icons.lock_outline;
    Color iconColor = Colors.grey.shade600;
    
    if (isCompleted) {
      nodeColor = const Color(0xff3B7DD8); // Blue secundário
      borderColor = const Color(0xff2A64B3);
      nodeIcon = Icons.check;
      iconColor = Colors.white;
    } else if (isActive) {
      nodeColor = const Color(0xff6B5FD3); // Purple theme
      borderColor = const Color(0xff5548B8);
      nodeIcon = Icons.play_arrow_rounded;
      iconColor = Colors.white;
    }

    return GestureDetector(
      onTap: isLocked ? null : () => onNodeSelected(desafio),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Styled circular node button
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: nodeColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                nodeIcon,
                color: iconColor,
                size: 32,
              ),
            ),
          ),
          
          const SizedBox(height: 6),
          
          // Star rating overlay under node if completed
          if (isCompleted)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: Color(0xffFFD700), size: 14),
                Icon(Icons.star_rounded, color: Color(0xffFFD700), size: 14),
                Icon(Icons.star_rounded, color: Color(0xffFFD700), size: 14),
              ],
            ),
            
          const SizedBox(height: 4),
          
          // Challenge Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffE2E2E6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              desafio.titulo,
              style: const TextStyle(
                color: Color(0xff2D2D3A),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrophyNodeButton(BuildContext context, bool isUnlocked) {
    Color nodeColor = isUnlocked ? const Color(0xffFFD700) : Colors.grey.shade300;
    Color borderColor = isUnlocked ? const Color(0xffD4AF37) : Colors.grey.shade400;
    Color iconColor = isUnlocked ? Colors.white : Colors.grey.shade600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: nodeColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.emoji_events_rounded,
              color: iconColor,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xffE2E2E6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            isUnlocked ? 'Trilha Completa!' : 'Troféu Final',
            style: TextStyle(
              color: isUnlocked ? const Color(0xff3B7DD8) : const Color(0xff6B6B76),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class ConnectionLinePainter extends CustomPainter {
  final int nodesCount;
  final double nodeHeight;

  ConnectionLinePainter({
    required this.nodesCount,
    required this.nodeHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodesCount <= 1) return;

    final paint = Paint()
      ..color = const Color(0xffE2E2E6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    final double centerX = size.width / 2;
    final double amplitude = 75.0;

    final path = Path();
    
    // Starting position of path
    double startX = centerX + TrailMap._getXOffsetForIndex(0, amplitude);
    double startY = 36.0; // center of node
    path.moveTo(startX, startY);

    for (int i = 1; i < nodesCount; i++) {
      double endX = centerX + TrailMap._getXOffsetForIndex(i, amplitude);
      double endY = i * nodeHeight + 36.0;
      
      // Control points for cubic bezier curves
      double ctrlX1 = startX;
      double ctrlY1 = startY + nodeHeight * 0.5;
      double ctrlX2 = endX;
      double ctrlY2 = endY - nodeHeight * 0.5;

      path.cubicTo(ctrlX1, ctrlY1, ctrlX2, ctrlY2, endX, endY);
      
      startX = endX;
      startY = endY;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ActiveNodeWidget extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  const ActiveNodeWidget({
    super.key,
    required this.child,
    this.glowColor = const Color(0xff6B5FD3),
  });

  @override
  State<ActiveNodeWidget> createState() => _ActiveNodeWidgetState();
}

class _ActiveNodeWidgetState extends State<ActiveNodeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _glowAnimation = Tween<double>(begin: 4.0, end: 18.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withOpacity(0.4),
                  blurRadius: _glowAnimation.value,
                  spreadRadius: _glowAnimation.value / 3,
                ),
              ],
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class ScaleFadeInWidget extends StatefulWidget {
  final Widget child;
  const ScaleFadeInWidget({super.key, required this.child});

  @override
  State<ScaleFadeInWidget> createState() => _ScaleFadeInWidgetState();
}

class _ScaleFadeInWidgetState extends State<ScaleFadeInWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
