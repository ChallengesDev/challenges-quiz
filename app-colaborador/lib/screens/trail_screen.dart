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
    final categories = ['Compliance & LGPD', 'Segurança da Informação', 'Vendas & Negociação'];

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
    } else {
      trailDesafios = [
        Desafio(id: 'chal-7', topicoId: 'top-4', titulo: 'SPIN Selling', dificuldade: 'medio', tempoLimite: 300, pontuacao: 150, ativo: true),
      ];
    }

    // Set first challenge as active if none completed
    final completedIds = profileProvider.unlockedConquistasIds.toSet(); // we reuse this or just mock completed
    // Let's mock completed quizzes: first challenge completed on LGPD
    final completedQuizzes = {'chal-1', 'chal-5'};
    
    // Find active desafio (first one not completed)
    String activeId = trailDesafios.first.id;
    for (var d in trailDesafios) {
      if (!completedQuizzes.contains(d.id)) {
        activeId = d.id;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dropdown Trail Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sua Trilha',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xff151c2c),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xff243049)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategoryName,
                    dropdownColor: const Color(0xff151c2c),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    iconEnabledColor: const Color(0xff00f5d4),
                    items: categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategoryName = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Sinuous Duolingo map container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xff151c2c),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xff243049)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SingleChildScrollView(
                  child: TrailMap(
                    desafios: trailDesafios,
                    completedDesafiosIds: completedQuizzes,
                    activeDesafioId: activeId,
                    onNodeSelected: (desafio) {
                      // Navigate to quiz screen
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
