import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:js_interop';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web; // Cross-platform HTML stub compiles on web and native
import '../providers/auth_provider.dart';
import '../providers/quiz_provider.dart';
import '../providers/profile_provider.dart';
import '../components/mascot_widget.dart';
import '../components/eye_tracker_preview.dart';
import '../models/models.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with WidgetsBindingObserver {
  bool _initialized = false;
  web.EventListener? _webVisibilityListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Set up Web visibility change listener
    _setupWebVisibilityListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Desafio) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final quizProvider = Provider.of<QuizProvider>(context, listen: false);

        quizProvider.startQuiz(
          args,
          authProvider.colaborador?.id ?? 'mock-user-123',
          authProvider.isMock
        );
        _initialized = true;
      }
    }
  }

  void _setupWebVisibilityListener() {
    if (kIsWeb) {
      _webVisibilityListener = ((web.Event event) {
        if (web.document.visibilityState == 'hidden') {
          _triggerScreenExit();
        }
      }).toJS as web.EventListener;
      web.document.addEventListener('visibilitychange', _webVisibilityListener!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Switched apps on mobile
      _triggerScreenExit();
    }
  }

  void _triggerScreenExit() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final quizProvider = Provider.of<QuizProvider>(context, listen: false);
    
    if (quizProvider.quizConcluido) return;

    quizProvider.reportScreenExit(
      authProvider.colaborador?.id ?? 'mock-user-123',
      authProvider.isMock
    );

    // Show warning dialog
    if (mounted && quizProvider.screenExitsCount < 3) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xff151c2c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.redAccent, width: 2),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                SizedBox(width: 8),
                Text('ALERTA DE SEGURANÇA', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Você saiu da aba do quiz! Esta foi a ocorrência ${quizProvider.screenExitsCount} de 3.\n\nNa 3ª ocorrência, seu quiz será cancelado automaticamente por suspeita de fraude!',
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar para o Quiz', style: TextStyle(color: Color(0xff00f5d4), fontWeight: FontWeight.bold)),
              )
            ],
          );
        },
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (kIsWeb && _webVisibilityListener != null) {
      web.document.removeEventListener('visibilitychange', _webVisibilityListener!);
    }
    super.dispose();
  }

  String _getReinforcementPhrase(bool isCorrect, int questionIndex) {
    final correctPhrases = ["Perfeito!", "Você sabe disso!", "Excelente!", "Fantástico!", "Muito bem!"];
    final incorrectPhrases = ["Quase lá! Vamos tentar de novo", "Essa foi difícil, continue!", "Não desanime!", "Foco no aprendizado!"];
    if (isCorrect) {
      return correctPhrases[questionIndex % correctPhrases.length];
    } else {
      return incorrectPhrases[questionIndex % incorrectPhrases.length];
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final quizProvider = Provider.of<QuizProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null || args is! Desafio || authProvider.colaborador == null) {
      return Scaffold(
        backgroundColor: const Color(0xff0b0f19),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text('Desafio inválido ou sessão expirada.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff6c5ce7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                child: const Text('Ir para Início', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      );
    }

    final colab = authProvider.colaborador!;
    
    // Redirect if completed
    if (quizProvider.quizConcluido) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/result'));
    }

    if (quizProvider.loading || quizProvider.perguntas.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xff0b0f19),
        body: Center(child: CircularProgressIndicator(color: Color(0xff6c5ce7))),
      );
    }

    final currentQ = quizProvider.currentPergunta;
    final totalQ = quizProvider.perguntas.length;
    final indexQ = quizProvider.currentQuestionIndex;

    if (currentQ == null) {
      return const Scaffold(
        backgroundColor: Color(0xff0b0f19),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Determine Mascot contextual text
    String mascotSpeechText = 'Você consegue! Leia com atenção.';
    if (quizProvider.showingFeedback) {
      mascotSpeechText = _getReinforcementPhrase(quizProvider.isCorrectAnswer!, indexQ);
    } else if (quizProvider.timeLeft < 10) {
      mascotSpeechText = 'Rápido! O tempo está acabando!';
    }

    return Scaffold(
      backgroundColor: const Color(0xff0b0f19),
      body: SafeArea(
        child: Stack(
          children: [
            // Main Quiz Layout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () {
                          // Show exit confirmation
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xff151c2c),
                              title: const Text('Abandonar Quiz?', style: TextStyle(color: Colors.white)),
                              content: const Text('Seu progresso nesta sessão será perdido.', style: TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Abandonar', style: TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      // Progress Bar
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: (indexQ + 1) / totalQ,
                              minHeight: 10,
                              backgroundColor: const Color(0xff151c2c),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff6c5ce7)),
                            ),
                          ),
                        ),
                      ),
                      
                      // Integrity score badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: quizProvider.integrityScore < 70 ? Colors.redAccent.withOpacity(0.1) : const Color(0xff151c2c),
                          border: Border.all(
                            color: quizProvider.integrityScore < 70 ? Colors.redAccent : const Color(0xff243049),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 14, color: quizProvider.integrityScore < 70 ? Colors.redAccent : const Color(0xff00f5d4)),
                            const SizedBox(width: 4),
                            Text(
                              'Integridade: ${quizProvider.integrityScore}%',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: quizProvider.integrityScore < 70 ? Colors.redAccent : const Color(0xff00f5d4),
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Mascot + Combo Indicator + Timer Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Streak/Combo Badge
                      if (quizProvider.streakCount >= 2)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orangeAccent),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Combo x${quizProvider.streakCount}',
                                style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                        )
                      else
                        const SizedBox(width: 80),

                      // Bouncing Mascot with dynamic speech bubble
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: MascotWidget(
                          state: quizProvider.mascotState, 
                          size: 90,
                          speechBubbleText: mascotSpeechText,
                        ),
                      ),

                      // Circular countdown timer
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: quizProvider.timeLeft < 10 ? Colors.redAccent : const Color(0xff00f5d4),
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${quizProvider.timeLeft}',
                            style: TextStyle(
                              color: quizProvider.timeLeft < 10 ? Colors.redAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Question Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xff151c2c),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xff243049)),
                    ),
                    child: Text(
                      currentQ.texto,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Answers list (A, B, C, D)
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 120), // Padding to clear bottom feedback bar
                      children: [
                        _buildAlternativeButton(context, 'A', currentQ.alternativaA, colab.id, authProvider.isMock),
                        const SizedBox(height: 12),
                        _buildAlternativeButton(context, 'B', currentQ.alternativaB, colab.id, authProvider.isMock),
                        const SizedBox(height: 12),
                        _buildAlternativeButton(context, 'C', currentQ.alternativaC, colab.id, authProvider.isMock),
                        const SizedBox(height: 12),
                        _buildAlternativeButton(context, 'D', currentQ.alternativaD, colab.id, authProvider.isMock),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Eye-tracker webcam preview overlay
            EyeTrackerPreview(colabId: colab.id, isMock: authProvider.isMock),

            // Bottom feedback panel (Duolingo style)
            if (quizProvider.showingFeedback)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildFeedbackPanel(context, quizProvider, colab.id, authProvider.isMock, profileProvider),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlternativeButton(BuildContext context, String prefix, String text, String colabId, bool isMock) {
    final quizProvider = Provider.of<QuizProvider>(context);
    final currentQ = quizProvider.currentPergunta!;
    final isShowingFeedback = quizProvider.showingFeedback;
    final isSelected = quizProvider.selectedAlternative == prefix;
    final isCorrectOption = currentQ.respostaCorreta == prefix;
    
    Color buttonColor = const Color(0xff151c2c);
    Color borderColor = const Color(0xff243049);
    double opacity = 1.0;

    if (isShowingFeedback) {
      if (isCorrectOption) {
        buttonColor = const Color(0xff1b4332).withOpacity(0.4);
        borderColor = const Color(0xff2ecc71);
      } else if (isSelected && !quizProvider.isCorrectAnswer!) {
        buttonColor = const Color(0xff4a1525).withOpacity(0.4);
        borderColor = Colors.redAccent;
      } else {
        opacity = 0.4;
      }
    }

    return Opacity(
      opacity: opacity,
      child: ElevatedButton(
        onPressed: isShowingFeedback
            ? null
            : () {
                quizProvider.submitAnswer(prefix, colabId, isMock);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: isShowingFeedback && (isCorrectOption || isSelected) ? 2.5 : 1.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xff6c5ce7).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xff6c5ce7)),
              ),
              child: Text(
                prefix,
                style: const TextStyle(
                  color: Color(0xff6c5ce7),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackPanel(
    BuildContext context, 
    QuizProvider quizProvider, 
    String colabId, 
    bool isMock, 
    ProfileProvider profileProvider
  ) {
    final isCorrect = quizProvider.isCorrectAnswer!;
    final currentQ = quizProvider.currentPergunta!;
    final hasExplanation = currentQ.explicacao != null && currentQ.explicacao!.isNotEmpty;

    final Color panelColor = isCorrect ? const Color(0xff1b4332) : const Color(0xff4a1525);
    final Color textColor = isCorrect ? const Color(0xff2ecc71) : Colors.redAccent;
    final IconData icon = isCorrect ? Icons.check_circle : Icons.error;

    // Reinforcement text inside feedback
    final reinforcement = _getReinforcementPhrase(isCorrect, quizProvider.currentQuestionIndex);

    // Calculate dynamic XP shown
    int baseMultiplier = 1;
    if (quizProvider.streakCount >= 3) baseMultiplier = 2;
    final earnedXP = (quizProvider.currentDesafio?.pontuacao ?? 100) ~/ quizProvider.perguntas.length * baseMultiplier;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: panelColor,
        border: Border(top: BorderSide(color: textColor, width: 2)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reinforcement,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isCorrect) ...[
                      const SizedBox(height: 2),
                      Text(
                        '+$earnedXP XP obtido!',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          if (!isCorrect) ...[
            const SizedBox(height: 12),
            Text(
              'A resposta correta era: ${currentQ.respostaCorreta}',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            if (hasExplanation) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentQ.explicacao!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ],

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              quizProvider.nextQuestion(colabId, isMock, profileProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isCorrect ? const Color(0xff2ecc71) : Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Entendi, continuar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
