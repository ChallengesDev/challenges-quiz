import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../providers/profile_provider.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../components/sound_manager.dart';

class LightningChallengeScreen extends StatefulWidget {
  const LightningChallengeScreen({super.key});

  @override
  State<LightningChallengeScreen> createState() => _LightningChallengeScreenState();
}

enum OctoState { idle, happy, sad }

class _LightningChallengeScreenState extends State<LightningChallengeScreen> with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _timerController;
  late AnimationController _octoAnimationController;
  
  List<Pergunta> _questions = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  
  // Timer state
  double _questionDuration = 10.0;
  double _secondsRemaining = 10.0;
  int _lastVibrationSecond = -1;
  
  // Quiz progress / answers
  bool _hasAnswered = false;
  String _selectedOption = '';
  bool _isCorrect = false;
  int _correctAnswersCount = 0;
  
  // Transition timer
  Timer? _transitionTimer;
  
  // Octo mascot animation state
  OctoState _octoState = OctoState.idle;

  // Track category names for the summary
  final Set<String> _reinforcedCategories = {};
  
  bool _isReview = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    
    // Dynamic timer controller
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    
    _timerController.addListener(() {
      final totalSecs = _timerController.duration?.inSeconds.toDouble() ?? _questionDuration;
      final remaining = totalSecs * (1.0 - _timerController.value);
      final currentSecond = remaining.ceil();
      
      // Vibrate on final 2 seconds (vibrations around 2.0s and 1.0s)
      if (remaining <= 2.0 && remaining > 0) {
        if (currentSecond != _lastVibrationSecond) {
          _lastVibrationSecond = currentSecond;
          HapticFeedback.mediumImpact();
        }
      }
      
      setState(() {
        _secondsRemaining = remaining;
      });
    });
    
    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleTimeout();
      }
    });

    _octoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _isReview = args?['isReview'] ?? false;

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final profile = Provider.of<ProfileProvider>(context, listen: false);
      
      profile.fetchLightningChallengeStatus(auth.colaborador!.id, auth.isMock).then((_) {
        if (mounted) {
          setState(() {
            _questions = profile.lightningChallengeQuestions;
            _isLoading = false;
          });
          if (_questions.isNotEmpty) {
            _startQuestion();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _timerController.dispose();
    _octoAnimationController.dispose();
    _transitionTimer?.cancel();
    super.dispose();
  }

  void _startQuestion() {
    if (_currentIndex >= _questions.length) {
      _showCelebration();
      return;
    }
    
    // Track category of current question
    final q = _questions[_currentIndex];
    if (q.desafioId.isNotEmpty && q.desafioId != 'lightning-challenge') {
      _reinforcedCategories.add(q.desafioId);
    } else {
      _reinforcedCategories.add('Compliance & LGPD'); // fallback visual topic
    }

    // Dynamic timer duration based on difficulty
    double duracao = 10.0;
    if (q.dificuldade == 'facil') duracao = 10.0;
    if (q.dificuldade == 'medio') duracao = 15.0;
    if (q.dificuldade == 'dificil') duracao = 20.0;

    // Temporary print log to confirm difficulty parameter
    print('DEBUG: Pergunta ${q.id} - Dificuldade vinda do backend: ${q.dificuldade} -> Duracao definida: $duracao');

    setState(() {
      _questionDuration = duracao;
      _hasAnswered = false;
      _selectedOption = '';
      _isCorrect = false;
      _secondsRemaining = duracao;
      _lastVibrationSecond = -1;
      _octoState = OctoState.idle;
    });
    
    _timerController.duration = Duration(milliseconds: (duracao * 1000).toInt());
    _timerController.reset();
    _timerController.forward();
  }

  void _selectOption(String optionLetter, String optionText) {
    if (_hasAnswered) return;
    _timerController.stop();
    
    final correctAnswer = _questions[_currentIndex].respostaCorreta;
    final isCorrect = optionLetter.trim().toUpperCase() == correctAnswer.trim().toUpperCase();
    
    setState(() {
      _hasAnswered = true;
      _selectedOption = optionText;
      _isCorrect = isCorrect;
      
      if (isCorrect) {
        _correctAnswersCount++;
        SoundManager.playSuccess();
        _octoState = OctoState.happy;
      } else {
        SoundManager.playError();
        _octoState = OctoState.sad;
      }
    });
    
    _transitionTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _currentIndex++;
        });
        _startQuestion();
      }
    });
  }

  void _handleTimeout() {
    if (_hasAnswered) return;
    
    setState(() {
      _hasAnswered = true;
      _selectedOption = ''; // timeout
      _isCorrect = false;
      SoundManager.playError();
      _octoState = OctoState.sad;
    });
    
    _transitionTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _currentIndex++;
        });
        _startQuestion();
      }
    });
  }

  void _showCelebration() {
    _confettiController.play();
    
    // Submit results if not in review mode
    if (!_isReview) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final profile = Provider.of<ProfileProvider>(context, listen: false);
      final xpGanho = _calculateXp();
      
      profile.completeLightningChallenge(
        auth.colaborador!.id,
        _correctAnswersCount,
        _questions.length,
        xpGanho,
        auth.isMock,
      );
    }
  }

  int _calculateXp() {
    if (_questions.isEmpty) return 0;
    int base = _correctAnswersCount * 20; // 2x XP = 20 per correct answer
    int bonus = _correctAnswersCount == _questions.length ? 50 : 0;
    return base + bonus;
  }

  @override
  Widget build(BuildContext context) {
    final bool done = _currentIndex >= _questions.length && !_isLoading;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient (warm modern off-white with purple/blue subtle glow)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xffFAF9F6), // Warm off-white
                  Color(0xffF3F0FD), // Very light purple
                  Color(0xffEAF0FD), // Very light blue
                ],
              ),
            ),
            child: SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xff6B5FD3)))
                  : _questions.isEmpty
                      ? _buildEmptyState()
                      : done
                          ? _buildCelebrationScreen()
                          : _buildQuestionScreen(),
            ),
          ),
          
          // Confetti overlay on celebration screen
          if (done)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Color(0xff6B5FD3),
                  Color(0xff3B7DD8),
                  Colors.amber,
                  Colors.green,
                  Colors.pink,
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt_rounded, size: 64, color: Color(0xff6B6B76)),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma Pergunta Disponível',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xff2D2D3A),
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'O desafio relâmpago necessita de perguntas recentes da sua trilha para ser gerado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff6B6B76), fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff6B5FD3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Voltar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionScreen() {
    final question = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Category, Progress Indicator, and Circular Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xff2D2D3A)),
                onPressed: () {
                  // Show exit confirmation dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sair do Desafio?'),
                      content: const Text('Se você sair agora, perderá o progresso desta sessão.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Continuar', style: TextStyle(color: Color(0xff6B5FD3))),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // close dialog
                            Navigator.pop(context); // exit screen
                          },
                          child: const Text('Sair', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Column(
                children: [
                  Text(
                    'Pergunta ${_currentIndex + 1} de ${_questions.length}',
                    style: const TextStyle(
                      color: Color(0xff6B6B76),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xff6B5FD3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      question.desafioId.isNotEmpty && question.desafioId != 'lightning-challenge'
                          ? question.desafioId
                          : 'Compliance & LGPD',
                      style: const TextStyle(
                        color: Color(0xff6B5FD3),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              _buildTimerCircular(),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Visual Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.5),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff6B5FD3)),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Question card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    question.texto,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff2D2D3A),
                      fontFamily: 'Outfit',
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildOptionButton('A', question.alternativaA, question.respostaCorreta),
                        _buildOptionButton('B', question.alternativaB, question.respostaCorreta),
                        _buildOptionButton('C', question.alternativaC, question.respostaCorreta),
                        _buildOptionButton('D', question.alternativaD, question.respostaCorreta),
                      ],
                    ),
                  ),
                  
                  // Mascot feedback footer
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _octoAnimationController,
                        builder: (context, child) {
                          return SizedBox(
                            width: 60,
                            height: 60,
                            child: CustomPaint(
                              painter: ChallengeOctoPainter(
                                state: _octoState,
                                animationValue: _octoAnimationController.value,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _hasAnswered
                            ? Text(
                                _isCorrect ? 'Excelente acerto! 🎉' : 'Que pena... Mas serve de aprendizado!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: _isCorrect ? const Color(0xff137333) : const Color(0xffC5221F),
                                ),
                              )
                            : const Text(
                                'Responda rápido antes do tempo acabar! ⚡',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xff6B6B76),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCircular() {
    final progress = _secondsRemaining / _questionDuration;
    Color timerColor;
    if (_secondsRemaining <= 2.0) {
      timerColor = Colors.redAccent;
    } else if (_secondsRemaining <= 5.0) {
      timerColor = Colors.amber;
    } else {
      timerColor = const Color(0xff3B7DD8); // Premium blue
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 4.5,
            backgroundColor: Colors.white.withOpacity(0.6),
            valueColor: AlwaysStoppedAnimation<Color>(timerColor),
          ),
        ),
        Text(
          '${_secondsRemaining.toInt()}s',
          style: TextStyle(
            color: timerColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  Widget _buildOptionButton(String letter, String text, String correctLetter) {
    final isSelected = _selectedOption == text;
    final isCorrectOption = letter == correctLetter;
    
    Color bg = Colors.white;
    Color border = const Color(0xffE5E5E5);
    Color textCol = const Color(0xff2D2D3A);
    
    if (_hasAnswered) {
      if (isCorrectOption) {
        bg = const Color(0xffE6F4EA);
        border = const Color(0xff137333);
        textCol = const Color(0xff137333);
      } else if (isSelected) {
        bg = const Color(0xffFCE8E6);
        border = const Color(0xffC5221F);
        textCol = const Color(0xffC5221F);
      }
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: _hasAnswered ? null : () => _selectOption(letter, text),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: textCol.withOpacity(0.6), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textCol.withOpacity(0.8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    color: textCol,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrationScreen() {
    final totalXp = _calculateXp();
    final doubleXp = _correctAnswersCount * 20;
    final bonusXp = _correctAnswersCount == _questions.length ? 50 : 0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Desafio Concluído! ⚡',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xff2D2D3A),
                fontFamily: 'Outfit',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _isReview 
                  ? 'Você concluiu a revisão do seu desafio relâmpago!'
                  : 'Parabéns por concluir esta sessão rápida!',
              style: const TextStyle(
                color: Color(0xff6B6B76),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Happy Mascot Painting
          Center(
            child: AnimatedBuilder(
              animation: _octoAnimationController,
              builder: (context, child) {
                return SizedBox(
                  width: 150,
                  height: 150,
                  child: CustomPaint(
                    painter: ChallengeOctoPainter(
                      state: OctoState.happy,
                      animationValue: _octoAnimationController.value,
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Score summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Resumo de Rendimento',
                  style: TextStyle(
                    color: Color(0xff2D2D3A),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Outfit',
                  ),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Acertos', style: TextStyle(color: Color(0xff6B6B76))),
                    Text(
                      '$_correctAnswersCount de ${_questions.length}',
                      style: const TextStyle(
                        color: Color(0xff2D2D3A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('XP de Acertos (2x)', style: TextStyle(color: Color(0xff6B6B76))),
                    Text(
                      _isReview ? '0 XP' : '+$doubleXp XP',
                      style: const TextStyle(
                        color: Color(0xff3B7DD8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bônus Gabarito (100%)', style: TextStyle(color: Color(0xff6B6B76))),
                    Text(
                      _isReview ? '0 XP' : '+$bonusXp XP',
                      style: TextStyle(
                        color: bonusXp > 0 ? Colors.green : const Color(0xff6B6B76),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total de XP Ganho',
                      style: TextStyle(
                        color: Color(0xff2D2D3A),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _isReview ? '0 XP (Revisão)' : '+$totalXp XP',
                      style: const TextStyle(
                        color: Color(0xff6B5FD3),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Reinforced points/categories list card
          if (_reinforcedCategories.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: Color(0xff6B5FD3), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Pontos Fracos Reforçados',
                        style: TextStyle(
                          color: Color(0xff2D2D3A),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._reinforcedCategories.map((cat) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cat,
                            style: const TextStyle(
                              color: Color(0xff2D2D3A),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            
          const SizedBox(height: 32),
          
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Go back home
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff6B5FD3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            child: const Text(
              'Finalizar e Voltar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class ChallengeOctoPainter extends CustomPainter {
  final OctoState state;
  final double animationValue;

  ChallengeOctoPainter({required this.state, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff6B5FD3) // Purple primary
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width * 0.35;

    // Floating/breathing animation offset
    double floatOffset = 0.0;
    if (state == OctoState.idle) {
      floatOffset = math.sin(animationValue * 2 * math.pi) * 4.0;
    } else if (state == OctoState.happy) {
      floatOffset = -math.sin(animationValue * math.pi).abs() * 12.0;
    } else if (state == OctoState.sad) {
      floatOffset = math.sin(animationValue * math.pi).abs() * 2.0;
    }

    final bodyY = centerY + floatOffset;

    // Draw octopus head (rounded dome)
    final path = Path();
    path.moveTo(centerX - radius, bodyY + radius * 0.2);
    path.cubicTo(
      centerX - radius, bodyY - radius * 1.1,
      centerX + radius, bodyY - radius * 1.1,
      centerX + radius, bodyY + radius * 0.2
    );
    path.lineTo(centerX + radius, bodyY + radius * 0.4);
    path.cubicTo(
      centerX + radius * 0.6, bodyY + radius * 0.6,
      centerX - radius * 0.6, bodyY + radius * 0.6,
      centerX - radius, bodyY + radius * 0.4
    );
    path.close();
    canvas.drawPath(path, paint);

    // Draw tentacles (8 stylized legs)
    final tentaclePaint = Paint()
      ..color = const Color(0xff6B5FD3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 8; i++) {
      final angleFraction = i / 7.0;
      final startX = centerX - radius * 0.7 + radius * 1.4 * angleFraction;
      final startY = bodyY + radius * 0.4;

      final tentaclePath = Path();
      tentaclePath.moveTo(startX, startY);

      final waveOffset = math.sin(animationValue * 2 * math.pi + (i * 0.5)) * 4.0;
      final waveX = startX + (state == OctoState.sad ? -2.0 : waveOffset * 0.5);
      final waveY = startY + size.height * 0.18 + (state == OctoState.happy ? 4.0 : waveOffset);

      tentaclePath.quadraticBezierTo(
        startX + (i % 2 == 0 ? 6.0 : -6.0),
        startY + size.height * 0.08,
        waveX,
        waveY
      );
      canvas.drawPath(tentaclePath, tentaclePaint);
    }

    // Draw face/eyes
    final eyePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final pupilPaint = Paint()..color = const Color(0xff2D2D3A)..style = PaintingStyle.fill;

    final eyeSpacing = radius * 0.38;
    final eyeY = bodyY - radius * 0.1;

    if (state == OctoState.happy) {
      final happyStroke = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      // Happy arched eyes
      canvas.drawArc(
        Rect.fromCircle(center: Offset(centerX - eyeSpacing, eyeY + 2), radius: 10),
        math.pi,
        math.pi,
        false,
        happyStroke
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(centerX + eyeSpacing, eyeY + 2), radius: 10),
        math.pi,
        math.pi,
        false,
        happyStroke
      );

      // Blush cheeks
      final blushPaint = Paint()..color = Colors.pink.withOpacity(0.4)..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX - eyeSpacing - 10, eyeY + 8), 5, blushPaint);
      canvas.drawCircle(Offset(centerX + eyeSpacing + 10, eyeY + 8), 5, blushPaint);
    } else if (state == OctoState.sad) {
      final sadStroke = Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      // Cross/dizzy eyes (X)
      canvas.drawLine(Offset(centerX - eyeSpacing - 5, eyeY - 5), Offset(centerX - eyeSpacing + 5, eyeY + 5), sadStroke);
      canvas.drawLine(Offset(centerX - eyeSpacing + 5, eyeY - 5), Offset(centerX - eyeSpacing - 5, eyeY + 5), sadStroke);

      canvas.drawLine(Offset(centerX + eyeSpacing - 5, eyeY - 5), Offset(centerX + eyeSpacing + 5, eyeY + 5), sadStroke);
      canvas.drawLine(Offset(centerX + eyeSpacing + 5, eyeY - 5), Offset(centerX + eyeSpacing - 5, eyeY + 5), sadStroke);
    } else {
      // Idle / Normal blinking eyes
      canvas.drawCircle(Offset(centerX - eyeSpacing, eyeY), 12, eyePaint);
      canvas.drawCircle(Offset(centerX + eyeSpacing, eyeY), 12, eyePaint);

      final pupilOffset = math.sin(animationValue * 2 * math.pi) * 1.2;
      canvas.drawCircle(Offset(centerX - eyeSpacing + pupilOffset, eyeY), 5, pupilPaint);
      canvas.drawCircle(Offset(centerX + eyeSpacing + pupilOffset, eyeY), 5, pupilPaint);
    }

    // Draw mouth
    final mouthPaint = Paint()
      ..color = const Color(0xff2D2D3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final mouthY = bodyY + radius * 0.15;
    if (state == OctoState.happy) {
      final openMouthPaint = Paint()..color = Colors.redAccent.withOpacity(0.8)..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(centerX, mouthY), width: 14, height: 14),
        0,
        math.pi,
        true,
        openMouthPaint
      );
    } else if (state == OctoState.sad) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(centerX, mouthY + 3), width: 12, height: 8),
        math.pi,
        math.pi,
        false,
        mouthPaint
      );
    } else {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(centerX, mouthY), width: 10, height: 6),
        0,
        math.pi,
        false,
        mouthPaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant ChallengeOctoPainter oldDelegate) {
    return oldDelegate.state != state || oldDelegate.animationValue != animationValue;
  }
}
