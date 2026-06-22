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
    Color flameColor = Colors.orangeAccent;
    Color borderColor = Colors.orangeAccent.withOpacity(0.5);
    Color glowColor = Colors.orange.withOpacity(0.2);
    double opacity = 1.0;

    if (isInRisk) {
      flameColor = Colors.redAccent;
      borderColor = Colors.redAccent.withOpacity(0.6);
      glowColor = Colors.red.withOpacity(0.1);
      opacity = 0.65; // Dimmed
    } else if (!hasActiveStreak) {
      flameColor = Colors.grey;
      borderColor = Colors.grey.withOpacity(0.3);
      glowColor = Colors.transparent;
      opacity = 0.5;
    } else if (widget.isStreakFreezeActive) {
      flameColor = Colors.cyanAccent;
      borderColor = Colors.cyanAccent.withOpacity(0.6);
      glowColor = Colors.cyan.withOpacity(0.2);
    }

    Widget flameWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xff151c2c),
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: isInRisk ? 12 : 8,
            spreadRadius: isInRisk ? 2 : 1,
          )
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
          if (widget.isStreakFreezeActive) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.ac_unit,
              color: Colors.cyanAccent,
              size: 12,
            )
          ]
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

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/streak_freeze');
      },
      child: Opacity(
        opacity: opacity,
        child: Tooltip(
          message: isInRisk
              ? 'Sua chama vai apagar! Clique para ver proteção.'
              : 'Sua Sequência! Clique para ver Streak Freeze.',
          child: flameWidget,
        ),
      ),
    );
  }
}
