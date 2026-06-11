import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class ProfileProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  Pontuacao? _pontuacao;
  List<Conquista> _conquistas = [];
  List<String> _unlockedConquistasIds = [];
  List<RankingColaborador> _rankingGeral = [];
  bool _loading = false;

  Pontuacao? get pontuacao => _pontuacao;
  List<Conquista> get conquistas => _conquistas;
  List<String> get unlockedConquistasIds => _unlockedConquistasIds;
  List<RankingColaborador> get rankingGeral => _rankingGeral;
  bool get loading => _loading;

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
    } catch (e) {
      print('Erro ao carregar dados de perfil: $e');
    } finally {
      _loading = false;
      notifyListeners();
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
}
