import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';

class RankingScreen extends StatefulWidget {
  final String colabId;

  const RankingScreen({
    super.key,
    required this.colabId,
  });

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  int _activeFilterIndex = 0; // 0 = Geral, 1 = Meu Time

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final list = profileProvider.rankingGeral;

    if (profileProvider.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filter simulation
    final displayList = _activeFilterIndex == 0 
        ? list 
        : list.where((u) => u.usuarioId == widget.colabId || u.usuarioId == '1' || u.usuarioId == '2').toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Líderes da Liga',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              ),
              Row(
                children: [
                  _buildFilterBtn('Geral', 0),
                  const SizedBox(width: 8),
                  _buildFilterBtn('Meu Time', 1),
                ],
              )
            ],
          ),
          
          const SizedBox(height: 24),

          // Podium (1st, 2nd, 3rd places) if list has enough data
          if (displayList.length >= 3)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              height: 170,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 2nd Place (Silver)
                  _buildPodiumPillar(displayList[1].nome, '2', const Color(0xffd1d5db), 90),
                  // 1st Place (Gold)
                  _buildPodiumPillar(displayList[0].nome, '1', const Color(0xfff59e0b), 120, isWinner: true),
                  // 3rd Place (Bronze)
                  _buildPodiumPillar(displayList[2].nome, '3', const Color(0xffb45309), 75),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Leaderboard List
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xff151c2c),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xff243049)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ListView.separated(
                  itemCount: displayList.length,
                  separatorBuilder: (context, index) => const Divider(color: Color(0xff243049), height: 1),
                  itemBuilder: (context, index) {
                    final item = displayList[index];
                    final isUser = item.usuarioId == widget.colabId || item.nome.contains('Você');

                    return Container(
                      color: isUser ? const Color(0xff6c5ce7).withOpacity(0.08) : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          // Position
                          SizedBox(
                            width: 32,
                            child: Text(
                              '#${index + 1}',
                              style: TextStyle(
                                color: index == 0 
                                    ? const Color(0xffffd700) 
                                    : (index == 1 ? Colors.grey : (index == 2 ? Colors.brown : Colors.white70)),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          
                          // Avatar placeholder
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: isUser ? const Color(0xff6c5ce7) : const Color(0xff243049),
                            child: Text(
                              item.nome.substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Name
                          Expanded(
                            child: Text(
                              item.nome,
                              style: TextStyle(
                                color: isUser ? const Color(0xff00f5d4) : Colors.white,
                                fontWeight: isUser ? FontWeight.bold : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),

                          // XP / Level details
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${item.xpTotal} XP',
                                style: const TextStyle(color: Color(0xff00f5d4), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Nível ${item.nivel}',
                                style: const TextStyle(color: Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBtn(String text, int index) {
    bool isActive = _activeFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _activeFilterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xff6c5ce7) : const Color(0xff151c2c),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? Colors.transparent : const Color(0xff243049)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumPillar(String name, String pos, Color medalColor, double pillarHeight, {bool isWinner = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Name label above pillar
        SizedBox(
          width: 80,
          child: Text(
            name.split(' ').first,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6),
        
        // Pódio column container
        Container(
          width: 68,
          height: pillarHeight,
          decoration: BoxDecoration(
            color: const Color(0xff151c2c),
            border: Border(
              top: BorderSide(color: medalColor, width: 4),
              left: BorderSide(color: medalColor.withOpacity(0.4), width: 1.5),
              right: BorderSide(color: medalColor.withOpacity(0.4), width: 1.5),
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            boxShadow: isWinner 
                ? [
                    BoxShadow(
                      color: medalColor.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Position Circle badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: medalColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    pos,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                isWinner ? Icons.emoji_events : Icons.emoji_events_outlined,
                color: medalColor,
                size: 20,
              )
            ],
          ),
        ),
      ],
    );
  }
}
