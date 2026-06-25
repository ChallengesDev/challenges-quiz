import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/profile_provider.dart';
import '../models/models.dart';
import '../components/sound_manager.dart';

const String apiBaseUrl = 'http://localhost:8000';

enum OctoState { idle, happy, sad }

class TreinaMaisScreen extends StatefulWidget {
  final String colabId;
  final bool isMock;

  const TreinaMaisScreen({
    super.key,
    required this.colabId,
    required this.isMock,
  });

  @override
  State<TreinaMaisScreen> createState() => _TreinaMaisScreenState();
}

class _TreinaMaisScreenState extends State<TreinaMaisScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  List<TreinaMaisItem> _items = [];
  bool _isLoading = true;

  // Active Play Time Tracker Timer
  Timer? _playTimeTimer;

  // Mascot and Animation states
  late AnimationController _octoAnimationController;
  OctoState _octoState = OctoState.idle;
  Timer? _octoStateResetTimer;

  // Map of card index to user response state
  // Key: item ID, Value: selected option (or text)
  final Map<String, String> _userAnswers = {};
  // Map of card index to whether the answer is verified (locked)
  final Map<String, bool> _lockedAnswers = {};
  // Map of card index to correctness of the verified answer
  final Map<String, bool> _answersCorrectness = {};
  // Map of card index to explanations received from API
  final Map<String, String> _answersExplanations = {};
  // Map of liked tips
  final Set<String> _likedTips = {};

  // Floating XP Animation states
  bool _showXpPopUp = false;
  int _lastXpGained = 10;
  double _xpPopUpTop = 150.0;

  bool _isPreloading = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController()..addListener(_onScroll);
    
    // Animate mascot float
    _octoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadFeed();

    // Setup active play time timer: updates daily goal minutes periodically.
    // Every 15 seconds, we award 0.25 minutes of play time.
    _playTimeTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      profileProvider.addPlayTime(0.25, widget.isMock);
    });
  }

  void _onScroll() {
    if (_pageController.hasClients) {
      final page = _pageController.page ?? 0.0;
      if (page >= _items.length - 3) {
        _preloadMoreItems();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _playTimeTimer?.cancel();
    _octoAnimationController.dispose();
    _octoStateResetTimer?.cancel();
    super.dispose();
  }

  // Load feed items from FastAPI or fall back to Supabase directly
  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.isMock) {
        // Mock fallback if offline/mock is forced
        await Future.delayed(const Duration(seconds: 1));
        _items = _generateMockFeed();
        setState(() {
          _isLoading = false;
        });
        if (_items.isNotEmpty) {
          _recordVisualizacao(_items[0].id);
        }
        return;
      }

      // Try fetching from FastAPI
      final url = Uri.parse('$apiBaseUrl/api/treina-mais/feed/${widget.colabId}');
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List decoded = json.decode(utf8.decode(response.bodyBytes));
        _items = decoded.map((j) => TreinaMaisItem.fromJson(j)).toList();
      } else {
        throw Exception('Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('FastAPI feed request failed. Querying Supabase directly: $e');
      _items = await _fetchFeedFallback(widget.colabId);
    } finally {
      setState(() {
        _isLoading = false;
      });
      if (_items.isNotEmpty) {
        _recordVisualizacao(_items[0].id);
      }
    }
  }

  Future<void> _preloadMoreItems() async {
    if (_isPreloading) return;
    _isPreloading = true;

    try {
      List<TreinaMaisItem> newItems = [];
      if (widget.isMock) {
        await Future.delayed(const Duration(milliseconds: 800));
        newItems = _generateMoreMockItems(_items.length);
      } else {
        // Try fetching from FastAPI
        final url = Uri.parse('$apiBaseUrl/api/treina-mais/feed/${widget.colabId}');
        final response = await http.get(url).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final List decoded = json.decode(utf8.decode(response.bodyBytes));
          newItems = decoded.map((j) => TreinaMaisItem.fromJson(j)).toList();
        } else {
          newItems = await _fetchFeedFallback(widget.colabId);
        }
      }

      // Filter out duplicates based on ID
      final existingIds = _items.map((i) => i.id).toSet();
      final filteredNew = newItems.where((i) => !existingIds.contains(i.id)).toList();

      if (filteredNew.isNotEmpty) {
        setState(() {
          _items.addAll(filteredNew);
        });
      } else if (widget.isMock || _items.length < 15) {
        // Generate mock items if no more items to show, to make the infinite scroll smooth
        setState(() {
          _items.addAll(_generateMoreMockItems(_items.length));
        });
      }
    } catch (e) {
      print('Erro ao carregar mais itens em background: $e');
    } finally {
      _isPreloading = false;
    }
  }

  List<TreinaMaisItem> _generateMoreMockItems(int offset) {
    return [
      TreinaMaisItem(
        id: 'mock-tm-new-${offset + 1}',
        empresaId: 'mock-empresa',
        tipo: 'dica',
        categoriaNome: 'Segurança da Informação',
        textoDica: 'Nunca compartilhe seus tokens de acesso ou senhas temporárias por telefone, chat ou e-mail. A TI nunca pedirá esses dados!',
        explicacao: 'Ataques de phishing frequentemente simulam suporte técnico interno.',
        criadoPor: 'ia',
        visto: false,
        criadoEm: DateTime.now(),
      ),
      TreinaMaisItem(
        id: 'mock-tm-new-${offset + 2}',
        empresaId: 'mock-empresa',
        tipo: 'pergunta',
        categoriaNome: 'Compliance & LGPD',
        pergunta: 'Em caso de incidente com dados pessoais, a quem o encarregado (DPO) deve reportar primariamente de acordo com as boas práticas?',
        alternativas: [
          'Ao comitê de privacidade interno e à ANPD.',
          'Diretamente à imprensa para transparência total.',
          'Apenas aos outros colaboradores da empresa.',
          'A nenhuma entidade, tratando apenas internamente.'
        ],
        respostaCorreta: 'Ao comitê de privacidade interno e à ANPD.',
        explicacao: 'O fluxo formal envolve notificar a governança interna e a autoridade regulatória no prazo legal.',
        criadoPor: 'ia',
        visto: false,
        criadoEm: DateTime.now(),
      ),
      TreinaMaisItem(
        id: 'mock-tm-new-${offset + 3}',
        empresaId: 'mock-empresa',
        tipo: 'dica',
        categoriaNome: 'Vendas & Negociação',
        textoDica: 'A técnica de escuta ativa em vendas ajuda a identificar a dor real do cliente antes de propor uma solução. Fale menos, ouça mais!',
        explicacao: 'Clientes compram soluções para seus problemas, não apenas funcionalidades.',
        criadoPor: 'gestor',
        visto: false,
        criadoEm: DateTime.now(),
      ),
    ];
  }

  // Fetch feed directly from Supabase tables
  Future<List<TreinaMaisItem>> _fetchFeedFallback(String usuarioId) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Fetch seen content IDs
      final seenRes = await supabase
          .from('usuario_treina_mais_visto')
          .select('conteudo_id')
          .eq('usuario_id', usuarioId);
      final seenIds = (seenRes as List).map((s) => s['conteudo_id'] as String).toSet();
      
      // Fetch company ID of user
      final userRes = await supabase
          .from('usuarios')
          .select('empresa_id')
          .eq('id', usuarioId)
          .single();
      final empresaId = userRes['empresa_id'];
      
      // Fetch active contents
      final contentsRes = await supabase
          .from('treina_mais_conteudo')
          .select('*, categorias(nome)')
          .eq('empresa_id', empresaId)
          .eq('ativo', true);
          
      final List allContents = contentsRes as List;
      
      List<TreinaMaisItem> feedList = allContents.map((json) {
        final catName = json['categorias'] != null ? json['categorias']['nome'] : null;
        final mappedJson = Map<String, dynamic>.from(json);
        mappedJson['categoria_nome'] = catName;
        mappedJson['visto'] = seenIds.contains(json['id']);
        return TreinaMaisItem.fromJson(mappedJson);
      }).toList();
      
      // Prioritize unseen items, then seen
      final unseen = feedList.where((item) => !item.visto).toList();
      final seen = feedList.where((item) => item.visto).toList();
      return [...unseen, ...seen];
    } catch (e) {
      print('Erro ao obter feed do Supabase directly: $e');
      return _generateMockFeed(); // last resort: mock generator
    }
  }

  // Visual check-in for content card
  Future<void> _recordVisualizacao(String conteudoId) async {
    if (widget.isMock) return;

    try {
      final url = Uri.parse('$apiBaseUrl/api/treina-mais/ver/${widget.colabId}/$conteudoId');
      await http.post(url).timeout(const Duration(seconds: 2));
    } catch (e) {
      print('FastAPI visualizacao logging failed. Using Supabase directly: $e');
      try {
        final supabase = Supabase.instance.client;
        await supabase.from('usuario_treina_mais_visto').upsert({
          'usuario_id': widget.colabId,
          'conteudo_id': conteudoId,
          'visto_em': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'usuario_id, conteudo_id');
      } catch (err) {
        print('Supabase direct visualizacao logging failed: $err');
      }
    }
  }

  // Post response for question card
  Future<void> _responderPergunta(String conteudoId, String respostaUsuario) async {
    setState(() {
      _lockedAnswers[conteudoId] = true;
    });

    try {
      HapticFeedback.lightImpact();

      if (widget.isMock) {
        // Mock feedback logic
        final item = _items.firstWhere((i) => i.id == conteudoId);
        final isCorrect = item.respostaCorreta == respostaUsuario;
        final xpEarned = isCorrect ? 10 : 0;

        _triggerAnswerFeedback(conteudoId, isCorrect, item.respostaCorreta ?? '', xpEarned, item.explicacao ?? 'Explicação mock');
        return;
      }

      final url = Uri.parse('$apiBaseUrl/api/treina-mais/pergunta/responder');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'usuario_id': widget.colabId,
          'conteudo_id': conteudoId,
          'resposta_usuario': respostaUsuario,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final bool correta = data['correta'] as bool;
        final String corretaStr = data['resposta_correta'] as String;
        final int xpGanho = data['xp_ganho'] as int? ?? 0;
        final String exp = data['explicacao'] as String? ?? '';

        _triggerAnswerFeedback(conteudoId, correta, corretaStr, xpGanho, exp);
      } else {
        throw Exception('Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('FastAPI answer submit failed. Simulating locally and updating Supabase: $e');
      
      // Direct Supabase fallback validation
      try {
        final supabase = Supabase.instance.client;
        
        final res = await supabase.from('treina_mais_conteudo').select('*').eq('id', conteudoId).single();
        final corretaStr = res['resposta_correta'] as String;
        final exp = res['explicacao'] as String? ?? 'Conformidade estudada com sucesso.';
        final isCorrect = corretaStr.trim() == respostaUsuario.trim();
        
        int xpGanho = 0;
        if (isCorrect) {
          xpGanho = 10; // Fixed fallback XP
          
          // Update score in public.pontuacoes table
          final scoreRes = await supabase.from('pontuacoes').select('*').eq('usuario_id', widget.colabId).single();
          final int newXp = (scoreRes['xp_total'] as int) + xpGanho;
          final int currentNivel = scoreRes['nivel'] as int;
          int newNivel = (newXp ~/ 500) + 1;
          if (newNivel < currentNivel) newNivel = currentNivel;
          
          await supabase.from('pontuacoes').update({
            'xp_total': newXp,
            'nivel': newNivel
          }).eq('usuario_id', widget.colabId);
        }

        // Logging visual status
        await supabase.from('usuario_treina_mais_visto').upsert({
          'usuario_id': widget.colabId,
          'conteudo_id': conteudoId,
          'visto_em': DateTime.now().toUtc().toIso8601String()
        }, onConflict: 'usuario_id, conteudo_id');

        _triggerAnswerFeedback(conteudoId, isCorrect, corretaStr, xpGanho, exp);
      } catch (err) {
        print('Supabase direct answer logic failed: $err');
      }
    }
  }

  void _triggerAnswerFeedback(String conteudoId, bool correta, String corretaStr, int xpGanho, String exp) {
    setState(() {
      _answersCorrectness[conteudoId] = correta;
      _answersExplanations[conteudoId] = exp;
      
      if (correta) {
        _octoState = OctoState.happy;
        SoundManager.playSuccess();

        // Trigger XP Popup Animation
        _showXpPopUp = true;
        _lastXpGained = xpGanho;
        _xpPopUpTop = 150.0;
        
        // Add XP to local profile provider to show on Home in real-time
        final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
        profileProvider.addXp(xpGanho, widget.isMock);
      } else {
        _octoState = OctoState.sad;
        SoundManager.playError();
      }
    });

    // Reset XP Popup
    if (correta) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _xpPopUpTop = 80.0; // slide up
          });
        }
      });
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) {
          setState(() {
            _showXpPopUp = false;
          });
        }
      });
    }

    // Reset mascot state back to idle after 3.5 seconds
    _octoStateResetTimer?.cancel();
    _octoStateResetTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() {
          _octoState = OctoState.idle;
        });
      }
    });
  }

  List<TreinaMaisItem> _generateMockFeed() {
    return [
      TreinaMaisItem(
        id: 'mock-tm-1',
        empresaId: 'mock-empresa',
        tipo: 'dica',
        categoriaNome: 'Segurança da Informação',
        textoDica: 'A técnica de phishing é a principal porta de entrada para vírus e ataques no ambiente corporativo. Sempre verifique o remetente antes de clicar em um link!',
        explicacao: 'Golpes se disfarçam de e-mails urgentes com erros sutis no endereço.',
        criadoPor: 'ia',
        visto: false,
        criadoEm: DateTime.now(),
      ),
      TreinaMaisItem(
        id: 'mock-tm-2',
        empresaId: 'mock-empresa',
        tipo: 'pergunta',
        categoriaNome: 'Compliance & LGPD',
        pergunta: 'Segundo a LGPD, o consentimento do titular de dados pessoais deve ser obtido de que forma?',
        alternativas: [
          'De forma livre, informada e inequívoca.',
          'Apenas verbalmente em reuniões gravadas.',
          'De forma tácita e automática ao acessar qualquer site.',
          'Por meio de caixas de seleção pré-marcadas em termos de uso.'
        ],
        respostaCorreta: 'De forma livre, informada e inequívoca.',
        explicacao: 'Consentimento implícito ou pré-selecionado é inválido sob as regras da LGPD.',
        criadoPor: 'ia',
        visto: false,
        criadoEm: DateTime.now(),
      ),
      TreinaMaisItem(
        id: 'mock-tm-3',
        empresaId: 'mock-empresa',
        tipo: 'dica',
        categoriaNome: 'Diversidade & Inclusão',
        textoDica: 'A empatia e a escuta ativa reduzem conflitos organizacionais e impulsionam a criatividade dos times. Pratique ouvir sem julgar nas reuniões!',
        explicacao: 'Ambientes plurais produzem soluções até 4x mais inovadoras.',
        criadoPor: 'gestor',
        visto: false,
        criadoEm: DateTime.now(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFAF9F6), // Warm off-white background
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xff6B5FD3)))
              : _items.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: const Color(0xff6B5FD3),
                      onRefresh: _loadFeed,
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        scrollDirection: Axis.vertical,
                        onPageChanged: (index) {
                          _recordVisualizacao(_items[index].id);
                          setState(() {
                            _octoState = OctoState.idle;
                          });
                        },
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
                              child: item.tipo == 'dica'
                                  ? _buildTipCard(item)
                                  : _buildQuestionCard(item),
                            ),
                          );
                        },
                      ),
                    ),

          // Floating XP Indicator Overlay
          if (_showXpPopUp)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutBack,
              top: _xpPopUpTop,
              left: MediaQuery.of(context).size.width / 2 - 60,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: _showXpPopUp ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xff3B7DD8), // Premium blue theme highlight
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff3B7DD8).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '+$_lastXpGained XP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                          fontSize: 15,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_filled_rounded, size: 64, color: Color(0xff6B6B76)),
          const SizedBox(height: 16),
          const Text(
            'Feed do Treina+ Vazio',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xff2D2D3A),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Não há conteúdos cadastrados no momento.',
            style: TextStyle(color: Color(0xff6B6B76)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadFeed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff6B5FD3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Recarregar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Type A Layout: Quick Tip
  Widget _buildTipCard(TreinaMaisItem item) {
    final isLiked = _likedTips.contains(item.id);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
      decoration: BoxDecoration(
        // Warm/Modern sutil gradient
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff6B5FD3), // Purple
            Color(0xff3B7DD8), // Blue
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff6B5FD3).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 10),
          )
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.categoriaNome ?? 'Dica Rápida',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const Icon(Icons.lightbulb_outline_rounded, color: Colors.white70),
            ],
          ),
          const Spacer(flex: 2),

          // Central tip text
          Text(
            item.textoDica ?? '',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'Outfit',
              height: 1.4,
            ),
          ),
          
          if (item.explicacao != null && item.explicacao!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              item.explicacao!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.85),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          
          const Spacer(flex: 3),

          // Action footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AnimatedScale(
                    scale: isLiked ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                        color: isLiked ? Colors.redAccent : Colors.white,
                        size: 32,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (isLiked) {
                            _likedTips.remove(item.id);
                          } else {
                            _likedTips.add(item.id);
                          }
                        });
                      },
                    ),
                  ),
                  Text(
                    isLiked ? '1 Curtida' : 'Curtir',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              const Text(
                'Arrastar para cima ➔',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Type B Layout: Quiz Question with immediate feedback and Octo reaction
  Widget _buildQuestionCard(TreinaMaisItem item) {
    final hasAnswered = _lockedAnswers[item.id] ?? false;
    final isCorrect = _answersCorrectness[item.id] ?? false;
    final selectedOption = _userAnswers[item.id];
    final alternatives = item.alternativas ?? [];
    final explanation = _answersExplanations[item.id] ?? item.explicacao;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
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
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xff6B5FD3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.categoriaNome ?? 'Mini-Pergunta',
                  style: const TextStyle(
                    color: Color(0xff6B5FD3),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const Text(
                'Vale XP ⚡',
                style: TextStyle(color: Color(0xff3B7DD8), fontSize: 11, fontWeight: FontWeight.w600),
              )
            ],
          ),
          const SizedBox(height: 16),

          // Question stem
          Text(
            item.pergunta ?? '',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xff2D2D3A),
              fontFamily: 'Outfit',
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),

          // Options list
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alternatives.length,
              itemBuilder: (context, idx) {
                final option = alternatives[idx];
                final isSelected = selectedOption == option;
                
                Color optionBg = Colors.white;
                Color optionBorder = const Color(0xffE5E5E5);
                Color optionText = const Color(0xff2D2D3A);
                
                if (hasAnswered) {
                  if (option.trim() == item.respostaCorreta?.trim()) {
                    // Correct answer always becomes green
                    optionBg = const Color(0xffE6F4EA);
                    optionBorder = const Color(0xff137333);
                    optionText = const Color(0xff137333);
                  } else if (isSelected) {
                    // Selected incorrect answer becomes red
                    optionBg = const Color(0xffFCE8E6);
                    optionBorder = const Color(0xffC5221F);
                    optionText = const Color(0xffC5221F);
                  }
                } else if (isSelected) {
                  optionBorder = const Color(0xff6B5FD3);
                  optionBg = const Color(0xff6B5FD3).withOpacity(0.05);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: InkWell(
                    onTap: hasAnswered
                        ? null
                        : () {
                            setState(() {
                              _userAnswers[item.id] = option;
                            });
                            _responderPergunta(item.id, option);
                          },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: optionBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: optionBorder, width: 1.8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: optionText.withOpacity(0.6), width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              String.fromCharCode(65 + idx),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: optionText.withOpacity(0.8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: optionText,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Mascot Layout (Glow Octo and Explanation)
          Container(
            height: 100,
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                // Octo Mascot CustomPaint
                AnimatedBuilder(
                  animation: _octoAnimationController,
                  builder: (context, child) {
                    return SizedBox(
                      width: 90,
                      height: 90,
                      child: CustomPaint(
                        painter: TreinaMaisOctoPainter(
                          state: _octoState,
                          animationValue: _octoAnimationController.value,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                
                // Explanations card content (fade in when answered)
                Expanded(
                  child: hasAnswered
                      ? AnimatedOpacity(
                          opacity: hasAnswered ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 400),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xffFAF9F6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xffE5E5E5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isCorrect ? 'Muito bem! 🎉' : 'Ops, incorreto...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isCorrect ? const Color(0xff137333) : const Color(0xffC5221F),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  explanation ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xff6B6B76),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const Text(
                          'Escolha a resposta certa para ver o Octo comemorar!',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xff6B6B76),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TreinaMaisOctoPainter extends CustomPainter {
  final OctoState state;
  final double animationValue;

  TreinaMaisOctoPainter({required this.state, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff6B5FD3) // Purple primary
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width * 0.35;

    // Floating animation offset
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
  bool shouldRepaint(covariant TreinaMaisOctoPainter oldDelegate) {
    return oldDelegate.state != state || oldDelegate.animationValue != animationValue;
  }
}
