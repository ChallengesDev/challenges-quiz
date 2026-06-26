import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../providers/auth_provider.dart';
import '../providers/live_room_provider.dart';
import '../providers/profile_provider.dart';

class LiveRoomScreen extends StatefulWidget {
  const LiveRoomScreen({super.key});

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  late ConfettiController _confettiController;

  // Custom Quiz Creator State
  String _origemPerguntas = 'banco_geral';
  String? _selectedCategoryId;
  final List<Map<String, dynamic>> _customQuestions = [];

  @override
  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    
    // Seed one custom question template
    _addCustomQuestionTemplate();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _addCustomQuestionTemplate() {
    setState(() {
      _customQuestions.add({
        'texto': '',
        'alternativa_a': '',
        'alternativa_b': '',
        'alternativa_c': '',
        'alternativa_d': '',
        'resposta_correta': 'A',
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final liveRoomProvider = Provider.of<LiveRoomProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);

    final colab = authProvider.colaborador;
    if (colab == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Trigger confetti if we are in the podium step and the user won 1st place
    if (liveRoomProvider.currentStep == LiveRoomStep.podium &&
        liveRoomProvider.ranking.isNotEmpty &&
        liveRoomProvider.ranking[0]['usuario_id'] == colab.id) {
      _confettiController.play();
    }

    return Scaffold(
      backgroundColor: const Color(0xffFAF9F6),
      appBar: AppBar(
        title: const Text('Modo Sala ao Vivo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            liveRoomProvider.leaveRoom();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildBody(context, liveRoomProvider, colab, profileProvider),
            ),
            // Confetti Overlay
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
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    LiveRoomProvider provider,
    dynamic colab,
    ProfileProvider profileProvider,
  ) {
    switch (provider.currentStep) {
      case LiveRoomStep.joinCode:
        return _buildJoinCodeStep(context, provider, colab, profileProvider);
      case LiveRoomStep.lobby:
        return _buildLobbyStep(context, provider, colab);
      case LiveRoomStep.question:
        return _buildQuestionStep(context, provider, colab);
      case LiveRoomStep.showAnswer:
        return _buildShowAnswerStep(context, provider, colab);
      case LiveRoomStep.podium:
        return _buildPodiumStep(context, provider, colab);
    }
  }

  // Phase 1: Join / Create Room Page
  Widget _buildJoinCodeStep(
    BuildContext context,
    LiveRoomProvider provider,
    dynamic colab,
    ProfileProvider profileProvider,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Splash banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff6B5FD3), Color(0xff3B7DD8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              children: [
                Icon(Icons.flash_on, color: Colors.amber, size: 48),
                SizedBox(height: 12),
                Text(
                  'Desafio em Grupo!',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
                SizedBox(height: 6),
                Text(
                  'Junte-se à sala para responder em tempo real e competir no ranking.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 1. Enter Room Section
          const Text(
            'Entrar com Código',
            style: TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'CÓDIGO (ex: AB3D7G)',
                    counterText: '',
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xffE5E5E5)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: provider.loading
                    ? null
                    : () {
                        provider.joinRoom(_codeController.text, colab.id);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff6B5FD3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: provider.loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Entrar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          if (provider.errorMsg != null) ...[
            const SizedBox(height: 8),
            Text(
              provider.errorMsg!,
              style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],

          const SizedBox(height: 32),
          const Divider(height: 1, color: Color(0xffE5E5E5)),
          const SizedBox(height: 32),

          // 2. Create Room Section
          const Text(
            'Criar Minha Sala',
            style: TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),

          // Selector
          Row(
            children: [
              _buildOriginOption('banco_geral', 'Banco Geral', Icons.quiz),
              const SizedBox(width: 8),
              _buildOriginOption('trilha', 'Trilha Empresa', Icons.map),
              const SizedBox(width: 8),
              _buildOriginOption('personalizada', 'Personalizada', Icons.edit_note),
            ],
          ),

          const SizedBox(height: 16),

          if (_origemPerguntas == 'trilha') ...[
            const Text(
              'Escolha a Categoria',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff6B6B76)),
            ),
            const SizedBox(height: 8),
            // Select category - hardcode category option since we have them in schema.sql
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              hint: const Text('Selecione uma trilha'),
              decoration: InputDecoration(
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'cat-compliance', child: Text('Compliance & LGPD')),
                DropdownMenuItem(value: 'cat-security', child: Text('Segurança da Informação')),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedCategoryId = val;
                });
              },
            ),
            const SizedBox(height: 16),
          ],

          if (_origemPerguntas == 'personalizada') ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Perguntas Customizadas',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff6B6B76)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _customQuestions.length,
              itemBuilder: (context, index) {
                final q = _customQuestions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pergunta #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff6B5FD3))),
                            if (_customQuestions.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _customQuestions.removeAt(index);
                                  });
                                },
                              ),
                          ],
                        ),
                        TextField(
                          decoration: const InputDecoration(hintText: 'Texto da pergunta'),
                          onChanged: (val) => q['texto'] = val,
                        ),
                        TextField(
                          decoration: const InputDecoration(hintText: 'Alternativa A'),
                          onChanged: (val) => q['alternativa_a'] = val,
                        ),
                        TextField(
                          decoration: const InputDecoration(hintText: 'Alternativa B'),
                          onChanged: (val) => q['alternativa_b'] = val,
                        ),
                        TextField(
                          decoration: const InputDecoration(hintText: 'Alternativa C'),
                          onChanged: (val) => q['alternativa_c'] = val,
                        ),
                        TextField(
                          decoration: const InputDecoration(hintText: 'Alternativa D'),
                          onChanged: (val) => q['alternativa_d'] = val,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Resposta Correta: '),
                            DropdownButton<String>(
                              value: q['resposta_correta'],
                              items: const [
                                DropdownMenuItem(value: 'A', child: Text('A')),
                                DropdownMenuItem(value: 'B', child: Text('B')),
                                DropdownMenuItem(value: 'C', child: Text('C')),
                                DropdownMenuItem(value: 'D', child: Text('D')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    q['resposta_correta'] = val;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Pergunta'),
              onPressed: _addCustomQuestionTemplate,
            ),
            const SizedBox(height: 16),
          ],

          ElevatedButton.icon(
            onPressed: provider.loading
                ? null
                : () async {
                    String? catId = _origemPerguntas == 'trilha' ? (_selectedCategoryId ?? 'cat-compliance') : null;
                    bool ok = await provider.createRoom(
                      colab.id,
                      colab.empresaId ?? 'mock-company-123',
                      _origemPerguntas,
                      catId,
                      _origemPerguntas == 'personalizada' ? _customQuestions : null,
                    );
                    if (ok) {
                      _codeController.clear();
                    }
                  },
            icon: const Icon(Icons.group_add),
            label: const Text('Criar Sala ao Vivo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3B7DD8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOriginOption(String id, String label, IconData icon) {
    final active = _origemPerguntas == id;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _origemPerguntas = id;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xff6B5FD3).withOpacity(0.08) : Colors.white,
            border: Border.all(color: active ? const Color(0xff6B5FD3) : const Color(0xffE5E5E5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? const Color(0xff6B5FD3) : const Color(0xff6B6B76)),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? const Color(0xff2D2D3A) : const Color(0xff6B6B76),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Phase 2: Lobby Waiting Room
  Widget _buildLobbyStep(
    BuildContext context,
    LiveRoomProvider provider,
    dynamic colab,
  ) {
    final isCreator = provider.room != null && provider.room!['criado_por_usuario_id'] == colab.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Text('Código da Sala', style: TextStyle(color: Color(0xff6B6B76), fontSize: 13)),
                const SizedBox(height: 8),
                Text(
                  provider.room?['codigo'] ?? '',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 48,
                    fontWeight: FontWeight.extrabold,
                    color: Color(0xff3B7DD8),
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aguardando o início da partida...',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Jogadores na Sala (${provider.participants.length})',
          style: const TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: provider.participants.length,
            itemBuilder: (context, index) {
              final p = provider.participants[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffE5E5E5)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xff6B5FD3),
                      backgroundImage: p['foto_url'] != null ? NetworkImage(p['foto_url']) : null,
                      child: p['foto_url'] == null
                          ? Text(
                              p['nome'].substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p['nome'] ?? 'Colaborador',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        if (isCreator) ...[
          ElevatedButton.icon(
            onPressed: provider.participants.isEmpty
                ? null
                : () {
                    provider.startRoom();
                  },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Começar Jogo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff6B5FD3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.hourglass_empty, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aguardando o criador iniciar a sessão...',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  // Phase 3: Active Question View
  Widget _buildQuestionStep(
    BuildContext context,
    LiveRoomProvider provider,
    dynamic colab,
  ) {
    final q = provider.currentQuestion;
    if (q == null) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top timer bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pergunta ${provider.currentQuestionIndex + 1}/${provider.questions.length}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff6B6B76)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: provider.timeLeft <= 5 ? Colors.red.withOpacity(0.1) : const Color(0xff6B5FD3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${provider.timeLeft}s',
                style: TextStyle(
                  fontWeight: FontWeight.extrabold,
                  color: provider.timeLeft <= 5 ? Colors.red : const Color(0xff6B5FD3),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Big Question Box
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Center(
              child: Text(
                q['pergunta_texto'] ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff2D2D3A), height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Alternatives Grid Buttons
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _buildAlternativeButton(provider, 'A', q['alternativa_a'] ?? '', Colors.red),
              const SizedBox(height: 12),
              _buildAlternativeButton(provider, 'B', q['alternativa_b'] ?? '', Colors.blue),
              const SizedBox(height: 12),
              _buildAlternativeButton(provider, 'C', q['alternativa_c'] ?? '', Colors.amber),
              const SizedBox(height: 12),
              _buildAlternativeButton(provider, 'D', q['alternativa_d'] ?? '', Colors.green),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlternativeButton(
    LiveRoomProvider provider,
    String key,
    String text,
    Color color,
  ) {
    final isSelected = provider.selectedAlternative == key;
    final hasAnswered = provider.answered;

    return Expanded(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: hasAnswered ? null : () => provider.submitAnswer(key),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? color : Colors.white,
            foregroundColor: isSelected ? Colors.white : const Color(0xff2D2D3A),
            elevation: isSelected ? 4 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isSelected ? Colors.transparent : const Color(0xffE5E5E5),
                width: 1.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    key,
                    style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontWeight: FontWeight.extrabold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Phase 4: Intermediate feedback after a question
  Widget _buildShowAnswerStep(
    BuildContext context,
    LiveRoomProvider provider,
    dynamic colab,
  ) {
    final q = provider.currentQuestion;
    final isCreator = provider.room != null && provider.room!['criado_por_usuario_id'] == colab.id;
    final fb = provider.answerFeedback;
    final correta = fb != null && fb['correta'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Correct/incorrect banner card
        Card(
          color: correta ? const Color(0xffE6F4EA) : const Color(0xffFCE8E6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
            child: Column(
              children: [
                Icon(
                  correta ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: correta ? Colors.green : Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  correta ? 'Resposta Correta!' : 'Resposta Errada!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: correta ? Colors.green[800] : Colors.red[800],
                  ),
                ),
                const SizedBox(height: 8),
                if (fb != null) ...[
                  Text(
                    '+${fb['pontos_ganhos']} Pontos',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text('Total: ${fb['pontuacao_total']} pts'),
                ] else ...[
                  const Text('O tempo esgotou!', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Intermediate ranking list
        const Text(
          'Classificação Parcial (Top 5)',
          style: TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: ListView.builder(
            itemCount: provider.ranking.length > 5 ? 5 : provider.ranking.length,
            itemBuilder: (context, index) {
              final p = provider.ranking[index];
              final isMe = p['usuario_id'] == colab.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xff6B5FD3).withOpacity(0.08) : Colors.white,
                  border: Border.all(color: isMe ? const Color(0xff6B5FD3) : const Color(0xffE5E5E5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      '#${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.extrabold,
                        color: index == 0 ? Colors.amber[800] : const Color(0xff6B6B76),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        p['nome'] ?? 'Colaborador',
                        style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
                      ),
                    ),
                    Text(
                      '${p['pontuacao_total']} pts',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        if (isCreator) ...[
          const SizedBox(height: 16),
          if (provider.currentQuestionIndex < provider.questions.length - 1) ...[
            ElevatedButton(
              onPressed: () => provider.nextQuestion(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff6B5FD3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Avançar Pergunta'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () => provider.finalizeRoom(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ver Resultados Finais'),
            ),
          ],
        ] else ...[
          const SizedBox(height: 16),
          const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Aguardando o criador avançar...', style: TextStyle(color: Color(0xff6B6B76), fontSize: 13)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  // Phase 5: Podium view
  Widget _buildPodiumStep(
    BuildContext context,
    LiveRoomProvider provider,
    dynamic colab,
  ) {
    final userPosIdx = provider.ranking.indexWhere((x) => x['usuario_id'] == colab.id);
    final userPos = userPosIdx != -1 ? userPosIdx + 1 : null;
    final totalPoints = userPosIdx != -1 ? provider.ranking[userPosIdx]['pontuacao_total'] : 0;
    
    // Earned XP formula: points / 10
    final earnedXp = (totalPoints ~/ 10).clamp(10, 500);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Congrats title
        Text(
          userPos == 1 ? '🥇 Você venceu! 🥇' : 'Partida Encerrada!',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xff2D2D3A), fontFamily: 'Outfit'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Você terminou em #${userPos ?? "?"} lugar com $totalPoints pontos.',
          style: const TextStyle(color: Color(0xff6B6B76)),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        // Visual podium step diagram
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 2nd
            if (provider.ranking.length > 1) ...[
              _buildPodiumPosition(provider.ranking[1]['nome'], '2', 80, Colors.grey[300]!),
              const SizedBox(width: 12),
            ],
            // 1st
            if (provider.ranking.isNotEmpty) ...[
              _buildPodiumPosition(provider.ranking[0]['nome'], '1', 120, Colors.amber[300]!),
              const SizedBox(width: 12),
            ],
            // 3rd
            if (provider.ranking.length > 2) ...[
              _buildPodiumPosition(provider.ranking[2]['nome'], '3', 60, Colors.brown[300]!),
            ],
          ],
        ),

        const SizedBox(height: 24),

        // Reward Summary Card
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.star, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recompensa Recebida',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xff2D2D3A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Você ganhou +$earnedXp XP de progresso no sistema!',
                        style: const TextStyle(fontSize: 12, color: Color(0xff6B6B76)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),

        ElevatedButton(
          onPressed: () {
            provider.leaveRoom();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff6B5FD3),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Voltar para o Início'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPodiumPosition(String name, String step, double height, Color color) {
    return Column(
      children: [
        SizedBox(
          width: 75,
          child: Text(
            name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 75,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.extrabold, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
