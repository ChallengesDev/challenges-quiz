import 'package:flutter/material.dart';

class StreakFlame extends StatefulWidget {
  final int streak;
  final double size;
  final bool playedToday;
  final bool isStreakFreezeActive;

  const StreakFlame({
    super.key,
    required this.streak,
    this.size = 28,
    required this.playedToday,
    required this.isStreakFreezeActive,
  });

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulsing animation for active streak
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Shaking animation when streak is in risk
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _shakeAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    _updateAnimationState();
  }

  void _updateAnimationState() {
    final now = DateTime.now();
    final isInRisk = widget.streak > 0 && !widget.playedToday && now.hour >= 20;

    if (isInRisk) {
      _shakeController.repeat(reverse: true);
    } else {
      _shakeController.stop();
      _shakeController.reset();
    }
  }

  @override
  void didUpdateWidget(StreakFlame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimationState();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isInRisk = widget.streak > 0 && !widget.playedToday && now.hour >= 20;
    final hasActiveStreak = widget.streak > 0;

    // Determine colors
    Color flameColor = Colors.amber; // Dourado
    Color borderColor = Colors.amber.withOpacity(0.3);
    Color glowColor = Colors.amber.withOpacity(0.1);
    double opacity = 1.0;

    if (isInRisk) {
      flameColor = Colors.redAccent;
      borderColor = Colors.redAccent.withOpacity(0.6);
      glowColor = Colors.red.withOpacity(0.1);
      opacity = 0.65; // Dimmed
    } else if (!hasActiveStreak) {
      flameColor = const Color(0xff6B6B76); // cinza médio
      borderColor = const Color(0xff6B6B76).withOpacity(0.2);
      glowColor = Colors.transparent;
      opacity = 0.5;
    }

    Widget flameWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: isInRisk ? 12 : 8,
            spreadRadius: isInRisk ? 2 : 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ]
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isInRisk ? Icons.warning_amber_rounded : Icons.local_fire_department,
            color: flameColor,
            size: widget.size,
          ),
          const SizedBox(width: 4),
          Text(
            '${widget.streak}',
            style: TextStyle(
              color: flameColor,
              fontWeight: FontWeight.bold,
              fontSize: widget.size * 0.55,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );

    // Apply scaling if streak is active and not shaking
    if (hasActiveStreak && !isInRisk) {
      flameWidget = ScaleTransition(
        scale: _scaleAnimation,
        child: flameWidget,
      );
    }

    // Apply shake translation if in risk
    if (isInRisk) {
      flameWidget = AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: child,
          );
        },
        child: flameWidget,
      );
    }

    return Opacity(
      opacity: opacity,
      child: Tooltip(
        message: isInRisk
            ? 'Sua chama vai apagar! Complete um desafio hoje.'
            : 'Sua Sequência Diária!',
        child: flameWidget,
      ),
    );
  }
}
