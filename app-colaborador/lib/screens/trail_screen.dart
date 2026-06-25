import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../components/trail_map.dart';
import '../models/models.dart';

class TrailScreen extends StatefulWidget {
  final String colabId;
  final bool isMock;

  const TrailScreen({
    super.key,
    required this.colabId,
    required this.isMock,
  });

  @override
  State<TrailScreen> createState() => _TrailScreenState();
}

class _TrailScreenState extends State<TrailScreen> {
  String _selectedCategoryName = 'Compliance & LGPD';

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);

    // Group challenges by category mockup or dynamically
    final categories = ['Compliance & LGPD', 'Segurança da Informação', 'Vendas & Negociação', 'Novidades Internas'];

    // Mock challenges for specific trails
    List<Desafio> trailDesafios = [];
    if (_selectedCategoryName == 'Compliance & LGPD') {
      trailDesafios = [
        Desafio(id: 'chal-1', topicoId: 'top-1', titulo: 'LGPD Básica', dificuldade: 'facil', tempoLimite: 300, pontuacao: 100, ativo: true),
        Desafio(id: 'chal-2', topicoId: 'top-1', titulo: 'Dados Sensíveis', dificuldade: 'medio', tempoLimite: 300, pontuacao: 150, ativo: true),
        Desafio(id: 'chal-3', topicoId: 'top-2', titulo: 'Código de Ética', dificuldade: 'medio', tempoLimite: 300, pontuacao: 150, ativo: true),
        Desafio(id: 'chal-4', topicoId: 'top-2', titulo: 'Anticorrupção', dificuldade: 'dificil', tempoLimite: 300, pontuacao: 200, ativo: true),
      ];
    } else if (_selectedCategoryName == 'Segurança da Informação') {
      trailDesafios = [
        Desafio(id: 'chal-5', topicoId: 'top-3', titulo: 'Higiene de Senhas', dificuldade: 'facil', tempoLimite: 300, pontuacao: 100, ativo: true),
        Desafio(id: 'chal-6', topicoId: 'top-3', titulo: 'Evitando Phishing', dificuldade: 'medio', tempoLimite: 300, pontuacao: 150, ativo: true),
      ];
    } else if (_selectedCategoryName == 'Vendas & Negociação') {
      trailDesafios = [
        Desafio(id: 'chal-7', topicoId: 'top-4', titulo: 'SPIN Selling', dificuldade: 'medio', tempoLimite: 300, pontuacao: 150, ativo: true),
      ];
    } else {
      trailDesafios = []; // Novidades Internas starts empty
    }

    final completedQuizzes = profileProvider.completedDesafioIds.toSet();
    
    // Find active desafio (first one not completed)
    String activeId = '';
    if (trailDesafios.isNotEmpty) {
      activeId = trailDesafios.first.id;
      for (var d in trailDesafios) {
        if (!completedQuizzes.contains(d.id)) {
          activeId = d.id;
          break;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sua Trilha de Aprendizado',
            style: TextStyle(
              color: Color(0xff2D2D3A),
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Horizontal Category Chip List Selector with Ready/Preparation Badges
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategoryName == cat;
                final isReady = cat != 'Novidades Internas';
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategoryName = cat;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10, bottom: 4, top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xff6B5FD3) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(
                        color: isSelected ? const Color(0xff6B5FD3) : const Color(0xffE2E2E6),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xff2D2D3A),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isReady 
                                ? (isSelected ? Colors.white.withOpacity(0.2) : const Color(0xff3B7DD8).withOpacity(0.1))
                                : (isSelected ? Colors.white.withOpacity(0.2) : Colors.amber.withOpacity(0.15)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isReady ? 'Pronta' : 'Em preparação',
                            style: TextStyle(
                              color: isReady 
                                  ? (isSelected ? Colors.white : const Color(0xff3B7DD8))
                                  : (isSelected ? Colors.white : Colors.amber.shade800),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Sinuous Duolingo map container or Empty State
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: const Color(0xffE2E2E6)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: trailDesafios.isEmpty
                    ? const EmptyTrailWidget()
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: TrailMap(
                          desafios: trailDesafios,
                          completedDesafiosIds: completedQuizzes,
                          activeDesafioId: activeId,
                          onNodeSelected: (desafio) {
                            Navigator.pushNamed(context, '/quiz', arguments: desafio);
                          },
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyTrailWidget extends StatelessWidget {
  const EmptyTrailWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xff6B5FD3).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.construction_rounded,
                size: 56,
                color: const Color(0xff6B5FD3),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Esta trilha ainda está sendo preparada pela sua empresa',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xff2D2D3A),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Volte em breve para novos desafios corporativos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xff6B6B76),
                fontSize: 13,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
