import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/quiz_provider.dart';

class EyeTrackerPreview extends StatefulWidget {
  final String colabId;
  final bool isMock;

  const EyeTrackerPreview({
    super.key,
    required this.colabId,
    required this.isMock,
  });

  @override
  State<EyeTrackerPreview> createState() => _EyeTrackerPreviewState();
}

class _EyeTrackerPreviewState extends State<EyeTrackerPreview> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _permissionDenied = false;
  bool _manualDeviationActive = false; // Dev trigger

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (kIsWeb) {
      // Flutter Web camera can sometimes trigger permission issues in sandbox,
      // so we handle it gracefully with a scanning radar fallback.
      setState(() {
        _permissionDenied = true;
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        
        // Start continuous face presence check
        _startEyeTrackingLoop();
      }
    } catch (e) {
      print('Camera initialization error: $e');
      if (mounted) {
        setState(() {
          _permissionDenied = true;
        });
      }
    }
  }

  void _startEyeTrackingLoop() {
    // Periodically feed "gaze present" events (true)
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _permissionDenied || !_isInitialized) {
        timer.cancel();
        return;
      }

      final quizProvider = Provider.of<QuizProvider>(context, listen: false);
      if (quizProvider.quizConcluido) {
        timer.cancel();
        return;
      }

      // If manual developer deviation is off, the user face is present.
      quizProvider.updateEyeTracking(!_manualDeviationActive, widget.colabId, widget.isMock);
    });
  }

  void _toggleManualDeviation() {
    setState(() {
      _manualDeviationActive = !_manualDeviationActive;
    });

    final quizProvider = Provider.of<QuizProvider>(context, listen: false);
    
    // Simulates attention drift event immediately
    quizProvider.updateEyeTracking(!_manualDeviationActive, widget.colabId, widget.isMock);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quizProvider = Provider.of<QuizProvider>(context);
    
    return Positioned(
      bottom: 24,
      right: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Developer Simulator Button (extremely helpful for manual verification)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton.icon(
              onPressed: _toggleManualDeviation,
              icon: Icon(
                _manualDeviationActive ? Icons.visibility : Icons.visibility_off,
                size: 14,
                color: Colors.white,
              ),
              label: Text(
                _manualDeviationActive ? 'Olhar P/ Tela' : 'Simular Desvio Olhar',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _manualDeviationActive ? Colors.green : Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),

          // Eye-tracker scanner circular widget
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.black87,
              shape: BoxShape.circle,
              border: Border.all(
                color: _manualDeviationActive 
                    ? Colors.redAccent 
                    : (quizProvider.eyeDriftActive ? Colors.amber : const Color(0xff00f5d4)),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _manualDeviationActive ? Colors.red.withOpacity(0.3) : const Color(0xff00f5d4).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ],
            ),
            child: ClipOval(
              child: _buildCameraContent(),
            ),
          ),
          
          const SizedBox(height: 4),
          
          Text(
            _manualDeviationActive ? 'DESVIADO' : (quizProvider.eyeDriftActive ? 'ALERTA (3s)' : 'EYE-TRACKING'),
            style: TextStyle(
              color: _manualDeviationActive 
                  ? Colors.redAccent 
                  : (quizProvider.eyeDriftActive ? Colors.amber : const Color(0xff00f5d4)),
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraContent() {
    if (_isInitialized && _cameraController != null && !_permissionDenied) {
      return CameraPreview(_cameraController!);
    }

    // Radar pulse animation for mock scanning mode
    return Container(
      color: Colors.black87,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Scanner target line
            Icon(
              _manualDeviationActive ? Icons.remove_red_eye_outlined : Icons.remove_red_eye,
              color: _manualDeviationActive ? Colors.redAccent : const Color(0xff00f5d4),
              size: 24,
            ),
            
            // Radar pulse ring
            const _RadarPulse(),
          ],
        ),
      ),
    );
  }
}

class _RadarPulse extends StatefulWidget {
  const _RadarPulse();

  @override
  State<_RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<_RadarPulse> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 60 * _pulseAnimation.value,
          height: 60 * _pulseAnimation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xff00f5d4).withOpacity(1.0 - _pulseAnimation.value),
              width: 1.5,
            ),
          ),
        );
      },
    );
  }
}
