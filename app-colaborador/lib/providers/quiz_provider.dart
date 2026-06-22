import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../components/sound_manager.dart';
import 'profile_provider.dart';

class QuizProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  Desafio? _currentDesafio;
  List<Pergunta> _perguntas = [];
  int _currentQuestionIndex = 0;
  
  // State variables
  bool _loading = false;
  String _mascotState = 'idle'; // 'idle', 'happy', 'sad', 'nervous', 'celebrating'
  int _score = 0;
  int _streakCount = 0;
  int _correctCount = 0;
  bool _quizConcluido = false;
  
  // Timer variables
  int _timeLeft = 30; // 30s por pergunta
  Timer? _timer;
  
  // Anti-fraud stats
  int _screenExitsCount = 0;
  int _integrityScore = 100;
  List<OcorrenciaFraude> _fraudsLogged = [];
  String? _sessaoId;
  DateTime? _questionStartTime;
  bool _isSuspiciousSpeed = false;
  bool _eyeDriftActive = false;
  DateTime? _eyeDriftStartTime;
  Timer? _eyeDriftTimer;

  // New feedback variables for Duolingo style
  String? _selectedAlternative;
  bool? _isCorrectAnswer;
  bool _showingFeedback = false;

  // Getters
  Desafio? get currentDesafio => _currentDesafio;
  List<Pergunta> get perguntas => _perguntas;
  int get currentQuestionIndex => _currentQuestionIndex;
  Pergunta? get currentPergunta => _perguntas.isNotEmpty && _currentQuestionIndex < _perguntas.length ? _perguntas[_currentQuestionIndex] : null;
  bool get loading => _loading;
  String get mascotState => _mascotState;
  int get score => _score;
  int get streakCount => _streakCount;
  int get correctCount => _correctCount;
  bool get quizConcluido => _quizConcluido;
  int get timeLeft => _timeLeft;
  int get screenExitsCount => _screenExitsCount;
  int get integrityScore => _integrityScore;
  bool get isSuspiciousSpeed => _isSuspiciousSpeed;
  bool get eyeDriftActive => _eyeDriftActive;

  String? get selectedAlternative => _selectedAlternative;
  bool? get isCorrectAnswer => _isCorrectAnswer;
  bool get showingFeedback => _showingFeedback;

  // Initialize Quiz
  Future<void> startQuiz(Desafio desafio, String colabId, bool isMock) async {
    _loading = true;
    _currentDesafio = desafio;
    _perguntas = [];
    _currentQuestionIndex = 0;
    _score = 0;
    _streakCount = 0;
    _correctCount = 0;
    _quizConcluido = false;
    _screenExitsCount = 0;
    _integrityScore = 100;
    _fraudsLogged = [];
    _mascotState = 'idle';
    _isSuspiciousSpeed = false;
    _eyeDriftActive = false;

    _selectedAlternative = null;
    _isCorrectAnswer = null;
    _showingFeedback = false;
    
    notifyListeners();

    try {
      if (isMock) {
        // Load mock questions with explanations
        _perguntas = [
          Pergunta(
            id: 'p1',
            desafioId: desafio.id,
            texto: 'Qual é o prazo regulamentar para notificar a ANPD em caso de incidente de segurança envolvendo dados pessoais?',
            alternativaA: 'Imediatamente, ou seja, em até 2 horas',
            alternativaB: 'Em prazo razoável, geralmente estimado em 2 dias úteis (48 horas)',
            alternativaC: 'Em até 5 dias úteis contados do evento',
            alternativaD: 'Em até 30 dias corridos',
            respostaCorreta: 'B',
            explicacao: 'O artigo 48 da LGPD determina que o controlador deve comunicar à autoridade nacional (ANPD) a ocorrência de incidente de segurança em prazo razoável, estabelecido pela ANPD em até 2 dias úteis.',
          ),
          Pergunta(
            id: 'p2',
            desafioId: desafio.id,
            texto: 'Qual base legal da LGPD permite tratar dados pessoais sem consentimento para proteção do crédito?',
            alternativaA: 'Legítimo Interesse',
            alternativaB: 'Execução de Contrato',
            alternativaC: 'Proteção do Crédito',
            alternativaD: 'Obrigação Legal ou Regulatória',
            respostaCorreta: 'C',
            explicacao: 'A proteção do crédito é uma base legal explícita do artigo 7º, inciso X da LGPD, dispensando o consentimento para a análise de risco de inadimplência.',
          ),
          Pergunta(
            id: 'p3',
            desafioId: desafio.id,
            texto: 'Em segurança digital, qual é o principal objetivo de um ataque de engenharia social por phishing?',
            alternativaA: 'Criptografar os arquivos locais do disco rígido',
            alternativaB: 'Interromper o acesso ao servidor Web corporativo',
            alternativaC: 'Manipular o usuário para obter senhas ou informações confidenciais',
            alternativaD: 'Instalar vírus mineradores de cripto no celular do usuário',
            respostaCorreta: 'C',
            explicacao: 'O phishing é um ataque de engenharia social clássico que visa enganar as pessoas para que compartilhem informações sensíveis, como senhas ou cartões de crédito.',
          ),
        ];
        
        _sessaoId = 'mock-sessao-uuid-${DateTime.now().millisecondsSinceEpoch}';
      } else {
        // Fetch from Supabase
        final response = await _supabase
            .from('perguntas')
            .select()
            .eq('desafio_id', desafio.id);

        if (response != null && response.isNotEmpty) {
          _perguntas = (response as List).map((p) => Pergunta.fromJson(p)).toList();
        }

        // Create Session in DB
        final sessaoRes = await _supabase.from('sessoes').insert({
          'usuario_id': colabId,
          'desafio_id': desafio.id,
          'iniciado_em': DateTime.now().toIso8601String(),
          'concluido': false,
          'pontuacao_total': 0,
          'score_integridade': 100
        }).select().single();

        _sessaoId = sessaoRes['id'] as String;
      }

      _startQuestionTimer();
    } catch (e) {
      print('Erro ao iniciar o quiz: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _startQuestionTimer() {
    _timer?.cancel();
    _timeLeft = 30; // 30 segundos por questão
    _questionStartTime = DateTime.now();
    _isSuspiciousSpeed = false;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 1) {
        _timeLeft--;
        notifyListeners();
      } else {
        // Tempo acabou - errou automaticamente
        _timer?.cancel();
        submitAnswer('timeout', 'mock-user', false);
      }
    });
  }

  // Answer Quiz question (Locks answer and shows feedback)
  Future<bool> submitAnswer(String alternativa, String colabId, bool isMock) async {
    _timer?.cancel();
    
    if (_perguntas.isEmpty || _currentQuestionIndex >= _perguntas.length) return false;
    final currentQ = _perguntas[_currentQuestionIndex];
    final isCorrect = alternativa == currentQ.respostaCorreta;
    
    _selectedAlternative = alternativa;
    _isCorrectAnswer = isCorrect;
    _showingFeedback = true;

    // Calcula velocidade de clique
    final clickDurationMs = DateTime.now().difference(_questionStartTime!).inMilliseconds;
    if (clickDurationMs < 1500 && alternativa != 'timeout') {
      _isSuspiciousSpeed = true;
      _integrityScore = (_integrityScore - 10).clamp(0, 100);
      _logFraudOccurrence('clique_ultrarrapido', 'Respondeu em ${clickDurationMs}ms (tempo suspeito inferior a 1.5s)', colabId, isMock);
    }

    if (isCorrect) {
      _correctCount++;
      _streakCount++;
      _mascotState = 'happy';
      
      // Calculate XP: base XP + combo multiplier
      int baseMultiplier = 1;
      if (_streakCount >= 3) baseMultiplier = 2; // Double XP
      
      final earnedXP = (_currentDesafio?.pontuacao ?? 100) ~/ _perguntas.length * baseMultiplier;
      _score += earnedXP;

      // Play success feedback
      SoundManager.playSuccess();
      HapticFeedback.lightImpact();
    } else {
      _streakCount = 0;
      _mascotState = 'sad';

      // Play failure feedback
      SoundManager.playError();
      HapticFeedback.mediumImpact();
    }
    
    notifyListeners();

    // Saves answer log
    try {
      if (!isMock && _sessaoId != null) {
        await _supabase.from('respostas').insert({
          'sessao_id': _sessaoId,
          'pergunta_id': currentQ.id,
          'alternativa_escolhida': alternativa == 'timeout' ? 'A' : alternativa, // fallback A
          'correta': isCorrect,
          'tempo_resposta': clickDurationMs ~/ 1000
        });
      }
    } catch (e) {
      print('Erro ao registrar resposta no banco: $e');
    }

    return isCorrect;
  }

  // Advance to next question or complete quiz
  Future<void> nextQuestion(String colabId, bool isMock, ProfileProvider profileProvider) async {
    _selectedAlternative = null;
    _isCorrectAnswer = null;
    _showingFeedback = false;

    _currentQuestionIndex++;
    if (_currentQuestionIndex < _perguntas.length) {
      _mascotState = 'idle';
      _startQuestionTimer();
      notifyListeners();
    } else {
      await finishQuiz(colabId, isMock, profileProvider);
    }
  }

  // Finish Quiz flow
  Future<void> finishQuiz(String colabId, bool isMock, ProfileProvider profileProvider) async {
    _timer?.cancel();
    _quizConcluido = true;
    _mascotState = 'celebrating';
    notifyListeners();

    // Sound and vibration feedback for completing the whole challenge
    SoundManager.playFanfare();
    HapticFeedback.heavyImpact();

    // Add playtime: Let's assume 5 minutes spent on this quiz
    await profileProvider.addPlayTime(5.0, isMock);
    await profileProvider.incrementStreak(isMock);

    try {
      if (!isMock && _sessaoId != null) {
        // Complete session in DB
        await _supabase.from('sessoes').update({
          'finalizado_em': DateTime.now().toIso8601String(),
          'concluido': true,
          'pontuacao_total': _score,
          'score_integridade': _integrityScore
        }).eq('id', _sessaoId!);

        // Increment user's global score / XP via provider
        await profileProvider.addXp(_score, isMock);
      } else {
        // In mock mode, we award score to profile provider
        await profileProvider.addXp(_score, isMock);
      }
    } catch (e) {
      print('Erro ao salvar finalização no banco: $e');
    }
  }

  // Anti-fraud: Tab Switch / Screen Loss detection
  void reportScreenExit(String colabId, bool isMock) {
    if (_quizConcluido) return;

    _screenExitsCount++;
    _integrityScore = (_integrityScore - 15).clamp(0, 100);
    _mascotState = 'nervous';
    notifyListeners();

    _logFraudOccurrence(
      'saida_tela',
      'Minimizou o navegador ou trocou de aba. Ocorrência #$_screenExitsCount/3',
      colabId,
      isMock
    );

    // Aborts quiz on 3 strikes
    if (_screenExitsCount >= 3) {
      abortQuizAsSuspicious(colabId, isMock);
    }
  }

  // Abort Quiz automatically due to fraud limits
  Future<void> abortQuizAsSuspicious(String colabId, bool isMock) async {
    _timer?.cancel();
    _quizConcluido = true;
    _score = 0; // Zerado por suspeita de fraude
    _integrityScore = 0; // Integridade zerada
    _mascotState = 'sad';
    notifyListeners();

    try {
      if (!isMock && _sessaoId != null) {
        await _supabase.from('sessoes').update({
          'finalizado_em': DateTime.now().toIso8601String(),
          'concluido': true,
          'pontuacao_total': 0,
          'score_integridade': 0
        }).eq('id', _sessaoId!);
      }
    } catch (e) {
      print('Erro ao registrar aborto no banco: $e');
    }
  }

  // Anti-fraud: Webcam Face Deviation
  void updateEyeTracking(bool facePresent, String colabId, bool isMock) {
    if (_quizConcluido) return;

    if (!facePresent) {
      if (!_eyeDriftActive) {
        _eyeDriftActive = true;
        _eyeDriftStartTime = DateTime.now();
        
        // Start 3s countdown for face absence
        _eyeDriftTimer?.cancel();
        _eyeDriftTimer = Timer(const Duration(seconds: 3), () {
          if (_eyeDriftActive) {
            _integrityScore = (_integrityScore - 10).clamp(0, 100);
            _mascotState = 'nervous';
            notifyListeners();
            _logFraudOccurrence(
              'desvio_olhar',
              'Rosto fora da visão da câmera por mais de 3 segundos.',
              colabId,
              isMock
            );
          }
        });
        notifyListeners();
      }
    } else {
      if (_eyeDriftActive) {
        _eyeDriftActive = false;
        _eyeDriftTimer?.cancel();
        _mascotState = 'idle';
        notifyListeners();
      }
    }
  }

  // Shared logger for fraud events
  Future<void> _logFraudOccurrence(String tipo, String detalhes, String colabId, bool isMock) async {
    final newFraud = OcorrenciaFraude(
      usuarioId: colabId,
      sessaoId: _sessaoId,
      tipoOcorrencia: tipo,
      detalhes: detalhes,
      criadoEm: DateTime.now()
    );

    _fraudsLogged.add(newFraud);

    try {
      if (!isMock) {
        await _supabase.from('ocorrencias_fraude').insert(newFraud.toJson());
      }
    } catch (e) {
      print('Erro ao registrar fraude ocorrencia: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _eyeDriftTimer?.cancel();
    super.dispose();
  }
}
