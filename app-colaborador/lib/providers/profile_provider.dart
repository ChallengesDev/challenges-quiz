import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ProfileProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  Pontuacao? _pontuacao;
  List<Conquista> _conquistas = [];
  List<String> _unlockedConquistasIds = [];
  List<RankingColaborador> _rankingGeral = [];
  bool _loading = false;
  bool _isMock = false;
  List<String> _completedDesafioIds = [];

  // Gamification state
  int _dailyGoalMinutes = 10;
  double _dailyPlayTimeMinutes = 0.0;
  bool _hasOnboardedGoal = false;
  int _streakFreezeCount = 1;
  bool _isStreakFreezeActive = false;
  bool _playedToday = false;
  bool _shouldShowConfetti = false;
  bool _dailyMissionCompleted = false;

  String _lightningChallengeStatus = 'bloqueado';
  List<Pergunta> _lightningChallengeQuestions = [];

  final List<DailyMission> _availableMissions = [
    DailyMission(id: 'm1', titulo: 'Super Combo', descricao: 'Acerte 3 perguntas seguidas'),
    DailyMission(id: 'm2', titulo: 'Foco Total', descricao: 'Responda a todas as perguntas de um quiz sem errar'),
    DailyMission(id: 'm3', titulo: 'Super Velocidade', descricao: 'Complete um desafio em menos de 3 minutos'),
  ];

  Pontuacao? get pontuacao => _pontuacao;
  List<Conquista> get conquistas => _conquistas;
  List<String> get unlockedConquistasIds => _unlockedConquistasIds;

  String get lightningChallengeStatus => _lightningChallengeStatus;
  List<Pergunta> get lightningChallengeQuestions => _lightningChallengeQuestions;
  List<RankingColaborador> get rankingGeral => _rankingGeral;
  bool get loading => _loading;
  bool get isMock => _isMock;
  List<String> get completedDesafioIds => _completedDesafioIds;

  int get dailyGoalMinutes => _dailyGoalMinutes;
  double get dailyPlayTimeMinutes => _dailyPlayTimeMinutes;
  bool get hasOnboardedGoal => _hasOnboardedGoal;
  int get streakFreezeCount => _streakFreezeCount;
  bool get isStreakFreezeActive => _isStreakFreezeActive;
  bool get playedToday => _playedToday;
  bool get shouldShowConfetti => _shouldShowConfetti;
  bool get dailyMissionCompleted => _dailyMissionCompleted;

  DailyMission get activeMission {
    final now = DateTime.now();
    final index = (now.year + now.month + now.day) % _availableMissions.length;
    return _availableMissions[index];
  }

  Future<void> loadProfileData(String colabId, String companyId, bool isMock) async {
    _loading = true;
    notifyListeners();

    try {
      if (isMock) {
        // Load high-fidelity mock data
        _pontuacao = Pontuacao(
          id: 'mock-p-id',
          usuarioId: colabId,
          xpTotal: 1200,
          nivel: 3,
          streakAtual: 5,
          streakMaximo: 12,
        );

        _conquistas = [
          Conquista(id: 'c1', nome: 'Primeiro Passo', descricao: 'Completou seu primeiro quiz com sucesso!', icone: '🎯', criterio: {}),
          Conquista(id: 'c2', nome: 'Mente Brilhante', descricao: 'Acertou 100% das perguntas de um quiz médio', icone: '⚡', criterio: {}),
          Conquista(id: 'c3', nome: 'Foco Absoluto', descricao: 'Completou um quiz mantendo 100% de integridade', icone: '🛡️', criterio: {}),
          Conquista(id: 'c4', nome: 'Sem Parar', descricao: 'Manteve um streak ativo por 5 dias seguidos', icone: '🔥', criterio: {}),
          Conquista(id: 'c5', nome: 'Super Velocista', descricao: 'Respondeu um quiz completo em tempo recorde (Segredo)', icone: '🚀', criterio: {}),
        ];

        _unlockedConquistasIds = ['c1', 'c3', 'c4']; // c2 e c5 estão bloqueados

        _rankingGeral = [
          RankingColaborador(usuarioId: '1', nome: 'Maria Silva (Você)', posicaoGeral: 1, xpTotal: 1850, nivel: 4),
          RankingColaborador(usuarioId: '2', nome: 'Ana Costa', posicaoGeral: 2, xpTotal: 1540, nivel: 4),
          RankingColaborador(usuarioId: 'colabId', nome: 'João Colaborador', posicaoGeral: 3, xpTotal: 1200, nivel: 3),
          RankingColaborador(usuarioId: '3', nome: 'Carlos Souza', posicaoGeral: 4, xpTotal: 980, nivel: 2),
          RankingColaborador(usuarioId: '4', nome: 'Eduardo Mello', posicaoGeral: 5, xpTotal: 810, nivel: 2),
        ];
      } else {
        // Fetch from Supabase
        
        // 1. Get Score / XP
        final scoreRes = await _supabase
            .from('pontuacoes')
            .select()
            .eq('usuario_id', colabId)
            .maybeSingle();

        if (scoreRes != null) {
          _pontuacao = Pontuacao.fromJson(scoreRes);
        } else {
          // Initialize score row in DB
          final newScore = await _supabase.from('pontuacoes').insert({
            'usuario_id': colabId,
            'xp_total': 0,
            'nivel': 1,
            'streak_atual': 0,
            'streak_maximo': 0
          }).select().single();
          _pontuacao = Pontuacao.fromJson(newScore);
        }

        // 2. Get all Achievements
        final achievementsRes = await _supabase.from('conquistas').select();
        if (achievementsRes != null) {
          _conquistas = (achievementsRes as List).map((c) => Conquista.fromJson(c)).toList();
        }

        // 3. Get employee unlocked achievements
        final unlockedRes = await _supabase
            .from('usuario_conquistas')
            .select('conquista_id')
            .eq('usuario_id', colabId);

        if (unlockedRes != null) {
          _unlockedConquistasIds = (unlockedRes as List).map((uc) => uc['conquista_id'] as String).toList();
        }

        // 4. Get Rankings
        final rankingRes = await _supabase
            .from('rankings')
            .select('*, usuarios(*, pontuacoes(*))')
            .eq('empresa_id', companyId)
            .order('posicao_geral');

        if (rankingRes != null) {
          _rankingGeral = (rankingRes as List).map((r) => RankingColaborador.fromJson(r)).toList();
        }
      }

      // Fetch user meta_diaria preferences directly from usuarios table
      int dbMeta = 10;
      bool dbDefinida = false;
      if (!isMock) {
        try {
          final userRes = await _supabase
              .from('usuarios')
              .select('meta_diaria, meta_diaria_definida')
              .eq('id', colabId)
              .maybeSingle();
          if (userRes != null) {
            dbMeta = userRes['meta_diaria'] as int? ?? 10;
            dbDefinida = userRes['meta_diaria_definida'] as bool? ?? false;
          }
        } catch (dbErr) {
          print('Erro ao carregar meta_diaria do banco: $dbErr');
        }
      }

      // Load SharedPreferences data for Gamification
      final prefs = await SharedPreferences.getInstance();

      // Load completed challenges
      if (isMock) {
        _completedDesafioIds = prefs.getStringList('completed_desafios_$colabId') ?? ['chal-1', 'chal-5'];
      } else {
        try {
          final sessoesRes = await _supabase
              .from('sessoes')
              .select('desafio_id')
              .eq('usuario_id', colabId)
              .eq('concluido', true);
          if (sessoesRes != null) {
            _completedDesafioIds = (sessoesRes as List)
                .map((s) => s['desafio_id'] as String)
                .toSet()
                .toList();
          }
        } catch (dbErr) {
          print('Erro ao carregar desafios concluidos do banco: $dbErr');
          _completedDesafioIds = prefs.getStringList('completed_desafios_$colabId') ?? [];
        }
      }
      if (!isMock && dbDefinida) {
        _dailyGoalMinutes = dbMeta;
        _hasOnboardedGoal = true;
        await prefs.setInt('daily_goal_minutes_$colabId', dbMeta);
        await prefs.setBool('has_onboarded_goal_$colabId', true);
      } else {
        _dailyGoalMinutes = prefs.getInt('daily_goal_minutes_$colabId') ?? 10;
        _hasOnboardedGoal = prefs.getBool('has_onboarded_goal_$colabId') ?? false;
      }
      _dailyPlayTimeMinutes = prefs.getDouble('daily_play_time_$colabId') ?? 0.0;
      _streakFreezeCount = prefs.getInt('streak_freeze_count_$colabId') ?? 1;
      _isStreakFreezeActive = prefs.getBool('is_streak_freeze_active_$colabId') ?? false;

      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month}-${now.day}";
      _dailyMissionCompleted = prefs.getBool('daily_mission_completed_${colabId}_$todayStr') ?? false;

      // Check if day changed
      final lastPlayStr = prefs.getString('last_play_date_$colabId');
      if (lastPlayStr != null) {
        final lastPlayDate = DateTime.parse(lastPlayStr);
        if (lastPlayDate.year != now.year || lastPlayDate.month != now.month || lastPlayDate.day != now.day) {
          // New day!
          _playedToday = false;
          _dailyPlayTimeMinutes = 0.0;
          _dailyMissionCompleted = false;
          await prefs.setDouble('daily_play_time_$colabId', 0.0);
          await prefs.setBool('daily_mission_completed_${colabId}_$todayStr', false);

          // If more than 1 day difference (i.e. did not play yesterday)
          final yesterday = DateTime(now.year, now.month, now.day - 1);
          final didPlayYesterday = lastPlayDate.year == yesterday.year &&
                                   lastPlayDate.month == yesterday.month &&
                                   lastPlayDate.day == yesterday.day;
          
          if (!didPlayYesterday) {
            // Missed streak! Let's check if Streak Freeze protects it
            if (_streakFreezeCount > 0 && _isStreakFreezeActive) {
              _streakFreezeCount--;
              _isStreakFreezeActive = false;
              await prefs.setInt('streak_freeze_count_$colabId', _streakFreezeCount);
              await prefs.setBool('is_streak_freeze_active_$colabId', false);
            } else {
              // Streak is lost
              if (_pontuacao != null) {
                _pontuacao = Pontuacao(
                  id: _pontuacao!.id,
                  usuarioId: _pontuacao!.usuarioId,
                  xpTotal: _pontuacao!.xpTotal,
                  nivel: _pontuacao!.nivel,
                  streakAtual: 0,
                  streakMaximo: _pontuacao!.streakMaximo,
                );
              }
              if (!isMock) {
                await _supabase.from('pontuacoes').update({'streak_atual': 0}).eq('usuario_id', colabId);
              }
            }
          }
        } else {
          _playedToday = true;
        }
      } else {
        _playedToday = false;
      }
    } catch (e) {
      print('Erro ao carregar dados de perfil: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Complete Daily Mission
  Future<void> completeDailyMission(String colabId, bool isMock) async {
    if (_dailyMissionCompleted) return;
    _dailyMissionCompleted = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month}-${now.day}";
      await prefs.setBool('daily_mission_completed_${colabId}_$todayStr', true);
      
      // Award 100 XP
      await addXp(activeMission.xpReward, isMock);
    } catch (e) {
      print('Erro ao completar missão diária: $e');
    }
  }

  // Update Daily Goal
  Future<void> updateDailyGoal(int minutes) async {
    _dailyGoalMinutes = minutes;
    _hasOnboardedGoal = true;
    notifyListeners();

    final colabId = _pontuacao?.usuarioId;
    if (colabId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('daily_goal_minutes_$colabId', minutes);
      await prefs.setBool('has_onboarded_goal_$colabId', true);

      if (!_isMock) {
        await _supabase.from('usuarios').update({
          'meta_diaria': minutes,
          'meta_diaria_definida': true
        }).eq('id', colabId);
      }
    } catch (e) {
      print('Erro ao salvar meta diária: $e');
    }
  }

  // Add study playtime minutes
  Future<void> addPlayTime(double minutes, bool isMock) async {
    if (_pontuacao == null) return;
    final colabId = _pontuacao!.usuarioId;
    final oldTime = _dailyPlayTimeMinutes;
    _dailyPlayTimeMinutes += minutes;
    _playedToday = true;

    // Check if goal just completed
    if (oldTime < _dailyGoalMinutes && _dailyPlayTimeMinutes >= _dailyGoalMinutes) {
      _shouldShowConfetti = true;
      // Award 100 extra XP for hitting daily goal!
      await addXp(100, isMock);
    }

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('daily_play_time_$colabId', _dailyPlayTimeMinutes);
      await prefs.setString('last_play_date_$colabId', DateTime.now().toIso8601String());
    } catch (e) {
      print('Erro ao salvar playtime: $e');
    }
  }

  void consumeConfetti() {
    _shouldShowConfetti = false;
    notifyListeners();
  }

  Future<void> addXp(int xp, bool isMock) async {
    if (_pontuacao == null) return;
    int newXp = _pontuacao!.xpTotal + xp;
    int currentNivel = _pontuacao!.nivel;
    int newNivel = (newXp ~/ 500) + 1;
    if (newNivel < currentNivel) newNivel = currentNivel;

    _pontuacao = Pontuacao(
      id: _pontuacao!.id,
      usuarioId: _pontuacao!.usuarioId,
      xpTotal: newXp,
      nivel: newNivel,
      streakAtual: _pontuacao!.streakAtual,
      streakMaximo: _pontuacao!.streakMaximo,
    );
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_normal_quiz_completed_at_${_pontuacao!.usuarioId}', DateTime.now().toIso8601String());
    } catch (e) {
      // ignore
    }

    if (!isMock) {
      try {
        await _supabase.from('pontuacoes').update({
          'xp_total': newXp,
          'nivel': newNivel,
        }).eq('usuario_id', _pontuacao!.usuarioId);
      } catch (e) {
        print('Erro ao atualizar XP: $e');
      }
    }
  }

  // Buy a Streak Freeze using 300 XP
  Future<bool> buyStreakFreeze(bool isMock) async {
    if (_pontuacao == null || _pontuacao!.xpTotal < 300) return false;

    int newXp = _pontuacao!.xpTotal - 300;
    _pontuacao = Pontuacao(
      id: _pontuacao!.id,
      usuarioId: _pontuacao!.usuarioId,
      xpTotal: newXp,
      nivel: _pontuacao!.nivel,
      streakAtual: _pontuacao!.streakAtual,
      streakMaximo: _pontuacao!.streakMaximo,
    );

    _streakFreezeCount++;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final colabId = _pontuacao!.usuarioId;
      await prefs.setInt('streak_freeze_count_$colabId', _streakFreezeCount);

      if (!isMock) {
        await _supabase.from('pontuacoes').update({
          'xp_total': newXp,
        }).eq('usuario_id', colabId);
      }
      return true;
    } catch (e) {
      print('Erro ao comprar streak freeze: $e');
      return false;
    }
  }

  // Toggle Streak Freeze Activation
  Future<void> toggleStreakFreezeActive() async {
    if (_streakFreezeCount <= 0 && !_isStreakFreezeActive) return;

    _isStreakFreezeActive = !_isStreakFreezeActive;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final colabId = _pontuacao?.usuarioId ?? 'default';
      await prefs.setBool('is_streak_freeze_active_$colabId', _isStreakFreezeActive);
    } catch (e) {
      print('Erro ao ativar/desativar streak freeze: $e');
    }
  }

  // Increment Streak when a quiz is completed
  Future<void> incrementStreak(bool isMock) async {
    if (_pontuacao == null) return;
    final colabId = _pontuacao!.usuarioId;
    
    // Only increment once a day
    if (!_playedToday) {
      int newStreak = _pontuacao!.streakAtual + 1;
      int newMax = newStreak > _pontuacao!.streakMaximo ? newStreak : _pontuacao!.streakMaximo;

      _pontuacao = Pontuacao(
        id: _pontuacao!.id,
        usuarioId: _pontuacao!.usuarioId,
        xpTotal: _pontuacao!.xpTotal,
        nivel: _pontuacao!.nivel,
        streakAtual: newStreak,
        streakMaximo: newMax,
      );
      _playedToday = true;
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_play_date_$colabId', DateTime.now().toIso8601String());

        if (!isMock) {
          await _supabase.from('pontuacoes').update({
            'streak_atual': newStreak,
            'streak_maximo': newMax
          }).eq('usuario_id', colabId);
        }
      } catch (e) {
        print('Erro ao atualizar streak no banco: $e');
      }
    }
  }

  // Unlock Achievement
  Future<void> unlockAchievement(String conquistaId, String colabId, bool isMock) async {
    if (_unlockedConquistasIds.contains(conquistaId)) return;

    try {
      _unlockedConquistasIds.add(conquistaId);
      notifyListeners();

      if (!isMock) {
        await _supabase.from('usuario_conquistas').insert({
          'usuario_id': colabId,
          'conquista_id': conquistaId,
          'conquistado_em': DateTime.now().toIso8601String()
        });
      }
    } catch (e) {
      print('Erro ao registrar conquista desbloqueada: $e');
    }
  }

  // Mark Desafio Completed
  Future<void> markDesafioCompleted(String desafioId, bool isMock) async {
    if (_completedDesafioIds.contains(desafioId)) return;
    _completedDesafioIds.add(desafioId);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final colabId = _pontuacao?.usuarioId ?? 'default';
      await prefs.setStringList('completed_desafios_$colabId', _completedDesafioIds);
    } catch (e) {
      print('Erro ao marcar desafio como concluído: $e');
    }
  }

  Future<void> fetchLightningChallengeStatus(String colabId, bool isMock) async {
    if (isMock) {
      final prefs = await SharedPreferences.getInstance();
      
      final lastCompletedStr = prefs.getString('lightning_challenge_completed_at_$colabId');
      bool completedToday = false;
      if (lastCompletedStr != null) {
        final lastCompleted = DateTime.parse(lastCompletedStr);
        final now = DateTime.now();
        if (lastCompleted.year == now.year && lastCompleted.month == now.month && lastCompleted.day == now.day) {
          completedToday = true;
        }
      }

      final lastNormalCompletedStr = prefs.getString('last_normal_quiz_completed_at_$colabId');
      bool normalCompletedToday = false;
      if (lastNormalCompletedStr != null) {
        final lastNormal = DateTime.parse(lastNormalCompletedStr);
        final now = DateTime.now();
        if (lastNormal.year == now.year && lastNormal.month == now.month && lastNormal.day == now.day) {
          normalCompletedToday = true;
        }
      }

      if (completedToday) {
        _lightningChallengeStatus = 'completado';
      } else if (normalCompletedToday) {
        _lightningChallengeStatus = 'disponivel';
      } else {
        _lightningChallengeStatus = 'bloqueado';
      }

      _lightningChallengeQuestions = [
        Pergunta(
          id: 'lp1',
          desafioId: 'Compliance & LGPD',
          texto: 'Qual é o prazo regulatório da LGPD para comunicar um incidente de segurança à ANPD?',
          alternativaA: '24 horas',
          alternativaB: 'Prazo razoável (estabelecido em até 2 dias úteis)',
          alternativaC: '5 dias úteis',
          alternativaD: 'Imediatamente (em até 1 hora)',
          respostaCorreta: 'B',
          explicacao: 'O artigo 48 da LGPD determina que o controlador deve comunicar à ANPD a ocorrência de incidente de segurança em prazo razoável, estabelecido pela ANPD em até 2 dias úteis.',
          dificuldade: 'facil',
        ),
        Pergunta(
          id: 'lp2',
          desafioId: 'Compliance & LGPD',
          texto: 'Qual base legal da LGPD permite tratar dados pessoais para proteção do crédito?',
          alternativaA: 'Legítimo Interesse',
          alternativaB: 'Execução de Contrato',
          alternativaC: 'Proteção do Crédito',
          alternativaD: 'Obrigação Regulatória',
          respostaCorreta: 'C',
          explicacao: 'A proteção do crédito é uma base legal explícita do artigo 7º da LGPD.',
          dificuldade: 'medio',
        ),
        Pergunta(
          id: 'lp3',
          desafioId: 'Segurança da Informação',
          texto: 'Qual o principal objetivo de um ataque de engenharia social por phishing?',
          alternativaA: 'Criptografar arquivos locais',
          alternativaB: 'Interromper servidores Web',
          alternativaC: 'Manipular o usuário para obter senhas ou informações confidenciais',
          alternativaD: 'Instalar mineradores de cripto',
          respostaCorreta: 'C',
          explicacao: 'O phishing visa induzir o usuário a revelar informações confidenciais por meio de engano.',
          dificuldade: 'dificil',
        ),
        Pergunta(
          id: 'lp4',
          desafioId: 'Compliance & LGPD',
          texto: 'Qual das seguintes opções é considerada um dado pessoal sensível segundo a LGPD?',
          alternativaA: 'Número de telefone residencial',
          alternativaB: 'Filiação a sindicato ou convicção religiosa',
          alternativaC: 'Endereço de e-mail corporativo',
          alternativaD: 'Data de nascimento',
          respostaCorreta: 'B',
          explicacao: 'Dados sobre religião, opinião política e filiação sindical são dados pessoais sensíveis pela LGPD.',
          dificuldade: 'facil',
        ),
      ];

      notifyListeners();
      return;
    }

    try {
      final url = Uri.parse('http://localhost:8000/api/desafio-relampago/$colabId');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        _lightningChallengeStatus = decoded['status'] as String? ?? 'bloqueado';
        final List questionsList = decoded['perguntas'] as List? ?? [];
        _lightningChallengeQuestions = questionsList.map((j) {
          return Pergunta(
            id: j['id'] as String,
            desafioId: j['categoria'] as String? ?? 'Geral',
            texto: j['texto'] as String,
            alternativaA: j['alternativas'][0] as String,
            alternativaB: j['alternativas'][1] as String,
            alternativaC: j['alternativas'][2] as String,
            alternativaD: j['alternativas'][3] as String,
            respostaCorreta: j['resposta_correta'] as String,
            explicacao: j['explicacao'] as String?,
            dificuldade: j['dificuldade'] as String?,
          );
        }).toList();
        notifyListeners();
      }
    } catch (e) {
      print('Erro ao obter status do desafio relâmpago: $e');
      _lightningChallengeStatus = 'bloqueado';
      notifyListeners();
    }
  }

  Future<void> completeLightningChallenge(String colabId, int acertos, int total, int xpGanho, bool isMock) async {
    final nowStr = DateTime.now().toIso8601String();
    
    if (_pontuacao != null) {
      final newXp = _pontuacao!.xpTotal + xpGanho;
      final newNivel = (newXp ~/ 500) + 1;
      _pontuacao = Pontuacao(
        id: _pontuacao!.id,
        usuarioId: _pontuacao!.usuarioId,
        xpTotal: newXp,
        nivel: newNivel,
        streakAtual: _pontuacao!.streakAtual,
        streakMaximo: _pontuacao!.streakMaximo,
        desafioRelampagoDisponivel: false,
        desafioRelampagoCompletadoEm: DateTime.now(),
      );
      _lightningChallengeStatus = 'completado';
      notifyListeners();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lightning_challenge_completed_at_$colabId', nowStr);
      
      if (!isMock) {
        final url = Uri.parse('http://localhost:8000/api/desafio-relampago/completar');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'usuario_id': colabId,
            'acertos': acertos,
            'total': total,
            'xp_ganho': xpGanho
          }),
        ).timeout(const Duration(seconds: 4));
        print('Conclusão do desafio relâmpago salva no backend: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao registrar conclusão do desafio relâmpago: $e');
    }
  }
}
