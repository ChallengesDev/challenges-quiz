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
      return const Center(child: CircularProgressIndicator(color: Color(0xff6B5FD3)));
    }

    // Filter simulation
    final displayList = _activeFilterIndex == 0 
        ? list 
        : list.where((u) => u.usuarioId == widget.colabId || u.usuarioId == '1' || u.usuarioId == '2').toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Líderes da Liga',
                style: TextStyle(color: Color(0xff2D2D3A), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
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
          
          const SizedBox(height: 20),

          // Podium (1st, 2nd, 3rd places) if list has enough data
          if (displayList.length >= 3)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              height: 180,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 2nd Place (Silver)
                  _buildPodiumPillar(displayList[1].nome, '2', const Color(0xffC0C0C0), 95),
                  // 1st Place (Gold)
                  _buildPodiumPillar(displayList[0].nome, '1', const Color(0xffFFD700), 125, isWinner: true),
                  // 3rd Place (Bronze)
                  _buildPodiumPillar(displayList[2].nome, '3', const Color(0xffCD7F32), 80),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Leaderboard List
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xffE2E2E6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayList.length,
                  separatorBuilder: (context, index) => const Divider(color: Color(0xffE2E2E6), height: 1),
                  itemBuilder: (context, index) {
                    final item = displayList[index];
                    final isUser = item.usuarioId == widget.colabId || item.nome.contains('Você');

                    Color positionColor = const Color(0xff6B6B76);
                    if (index == 0) positionColor = const Color(0xffFFD700);
                    if (index == 1) positionColor = const Color(0xffC0C0C0);
                    if (index == 2) positionColor = const Color(0xffCD7F32);

                    return Container(
                      color: isUser ? const Color(0xff6B5FD3).withOpacity(0.06) : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          // Position
                          SizedBox(
                            width: 32,
                            child: Text(
                              '#${index + 1}',
                              style: TextStyle(
                                color: positionColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          
                          // Avatar placeholder
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: isUser ? const Color(0xff6B5FD3) : const Color(0xffFAF9F6),
                            child: Text(
                              item.nome.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: isUser ? Colors.white : const Color(0xff2D2D3A), 
                                fontSize: 11, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Name
                          Expanded(
                            child: Text(
                              item.nome,
                              style: TextStyle(
                                color: isUser ? const Color(0xff6B5FD3) : const Color(0xff2D2D3A),
                                fontWeight: isUser ? FontWeight.bold : FontWeight.w600,
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
                                style: const TextStyle(color: Color(0xff3B7DD8), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Nível ${item.nivel}',
                                style: const TextStyle(color: Color(0xff6B6B76), fontSize: 10),
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
          color: isActive ? const Color(0xff6B5FD3) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? Colors.transparent : const Color(0xffE2E2E6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xff6B6B76),
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
            style: const TextStyle(color: Color(0xff2D2D3A), fontSize: 11, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6),
        
        // Pódio column container
        Container(
          width: 68,
          height: pillarHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: medalColor, width: 4),
              left: const BorderSide(color: Color(0xffE2E2E6), width: 1.5),
              right: const BorderSide(color: Color(0xffE2E2E6), width: 1.5),
              bottom: const BorderSide(color: Color(0xffE2E2E6), width: 1.5),
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: isWinner ? medalColor.withOpacity(0.15) : Colors.black.withOpacity(0.02),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              )
            ],
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Icon(
                isWinner ? Icons.emoji_events_rounded : Icons.emoji_events_outlined,
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
