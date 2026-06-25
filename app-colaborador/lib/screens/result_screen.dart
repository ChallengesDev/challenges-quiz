import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../providers/quiz_provider.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    
    // Play confetti explosion on mount
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quizProvider = Provider.of<QuizProvider>(context);

    final finalScore = quizProvider.score;
    final totalQ = quizProvider.perguntas.length;
    final correctQ = quizProvider.correctCount;
    final integrity = quizProvider.integrityScore;

    bool isSuspicious = integrity < 70;

    return Scaffold(
      backgroundColor: const Color(0xffFAF9F6),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Confetti overlay
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Color(0xff6B5FD3),
              Color(0xff3B7DD8),
              Color(0xffFFD700),
              Colors.orangeAccent,
              Colors.lightBlue,
            ],
          ),
          
          // Result Body Card
          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSuspicious ? Colors.redAccent : const Color(0xffE2E2E6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSuspicious 
                          ? Colors.red.withOpacity(0.05) 
                          : const Color(0xff6B5FD3).withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Victory Badge Header
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isSuspicious 
                              ? Colors.redAccent.withOpacity(0.1) 
                              : const Color(0xff6B5FD3).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSuspicious ? Icons.gavel_rounded : Icons.emoji_events_rounded,
                          color: isSuspicious ? Colors.redAccent : const Color(0xffFFD700),
                          size: 48,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Text(
                      isSuspicious ? 'Sessão Registrada como Suspeita' : 'Desafio Concluído!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSuspicious ? Colors.redAccent : const Color(0xff2D2D3A),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    
                    const SizedBox(height: 6),
                    
                    Text(
                      isSuspicious 
                          ? 'Múltiplas saídas de tela ou tempo de reação suspeitos detectados.'
                          : 'Seu progresso foi salvo e sincronizado com o gestor.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xff6B6B76), fontSize: 12, height: 1.4),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Score Card Details
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xffFAF9F6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xffE2E2E6)),
                      ),
                      child: Column(
                        children: [
                          // XP Gained
                          _buildStatRow(
                            'XP Ganhos',
                            '+$finalScore XP',
                            valueColor: const Color(0xff6B5FD3),
                          ),
                          const Divider(color: Color(0xffE2E2E6)),
                          
                          // Correct Answers
                          _buildStatRow(
                            'Acertos',
                            '$correctQ de $totalQ perguntas',
                            valueColor: const Color(0xff2D2D3A),
                          ),
                          const Divider(color: Color(0xffE2E2E6)),
                          
                          // Integrity Score
                          _buildStatRow(
                            'Score de Integridade',
                            '$integrity / 100',
                            valueColor: isSuspicious ? Colors.redAccent : const Color(0xff3B7DD8),
                            icon: Icon(
                              Icons.shield_outlined,
                              size: 14,
                              color: isSuspicious ? Colors.redAccent : const Color(0xff3B7DD8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Exit Button
                    ElevatedButton(
                      onPressed: () {
                        // Pop quiz session, return to home
                        Navigator.pushReplacementNamed(context, '/home');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff6B5FD3),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Voltar ao Início',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {required Color valueColor, Widget? icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xff6B6B76), fontSize: 13, fontWeight: FontWeight.w600)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) icon,
            if (icon != null) const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
