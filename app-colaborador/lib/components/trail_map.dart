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
      return const Center(
        child: Text('Nenhum desafio nesta trilha.', style: TextStyle(color: Colors.white70)),
      );
    }

    final double nodeHeight = 100.0;
    final double mapHeight = desafios.length * nodeHeight + 80.0;

    return Container(
      width: double.infinity,
      height: mapHeight,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Sinuous Connection Line in background
          Positioned.fill(
            child: CustomPaint(
              painter: ConnectionLinePainter(
                nodesCount: desafios.length,
                nodeHeight: nodeHeight,
              ),
            ),
          ),
          
          // Nodes
          ...List.generate(desafios.length, (index) {
            final desafio = desafios[index];
            final isCompleted = completedDesafiosIds.contains(desafio.id);
            final isActive = desafio.id == activeDesafioId || (completedDesafiosIds.isEmpty && index == 0);
            final isLocked = !isCompleted && !isActive;

            // Coordinates matching the painter
            final double xOffset = _getXOffsetForIndex(index, 75.0);
            final double yPos = index * nodeHeight;

            return Positioned(
              top: yPos,
              left: MediaQuery.of(context).size.width / 2 - 40 + xOffset,
              child: _buildNodeButton(desafio, isCompleted, isActive, isLocked),
            );
          }),
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

  Widget _buildNodeButton(Desafio desafio, bool isCompleted, bool isActive, bool isLocked) {
    Color nodeColor = Colors.grey;
    Color borderColor = Colors.black45;
    IconData nodeIcon = Icons.lock_outline;
    
    if (isCompleted) {
      nodeColor = const Color(0xff00f5d4); // Neon Green
      borderColor = const Color(0xff00b59c);
      nodeIcon = Icons.check;
    } else if (isActive) {
      nodeColor = const Color(0xff6c5ce7); // Purple theme
      borderColor = const Color(0xff4f46e5);
      nodeIcon = Icons.play_arrow;
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
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: const Color(0xff6c5ce7).withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 3,
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: Icon(
                nodeIcon,
                color: isLocked ? Colors.white54 : Colors.white,
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
                Icon(Icons.star, color: Color(0xffffd700), size: 14),
                Icon(Icons.star, color: Color(0xffffd700), size: 14),
                Icon(Icons.star_half, color: Color(0xffffd700), size: 14),
              ],
            ),
            
          const SizedBox(height: 4),
          
          // Challenge Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              desafio.titulo,
              style: const TextStyle(
                color: Colors.white,
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
      ..color = Colors.grey.withOpacity(0.3)
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
