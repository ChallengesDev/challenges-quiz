import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../models/models.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final loading = profileProvider.loading;
    final conquistas = profileProvider.conquistas;
    final unlockedIds = profileProvider.unlockedConquistasIds;

    return Scaffold(
      backgroundColor: const Color(0xffFAF9F6),
      appBar: AppBar(
        backgroundColor: const Color(0xffFAF9F6),
        elevation: 0,
        title: const Text(
          'Minhas Conquistas',
          style: TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Outfit'),
        ),
        centerTitle: false,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xff6B5FD3)))
          : conquistas.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Overview Progress Card
                      _buildOverviewCard(conquistas.length, unlockedIds.length),
                      const SizedBox(height: 24),

                      // Section Title
                      const Text(
                        'Galeria de Medalhas',
                        style: TextStyle(
                          color: Color(0xff2D2D3A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // List of Achievements
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: conquistas.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final conquista = conquistas[index];
                          final isUnlocked = unlockedIds.contains(conquista.id);
                          return _buildAchievementCard(context, conquista, isUnlocked, profileProvider);
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildOverviewCard(int total, int unlocked) {
    double progress = total > 0 ? unlocked / total : 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff6B5FD3), Color(0xff3B7DD8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff6B5FD3).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        children: [
          // Circular Progress Indicator
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumo de Conquistas',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Você desbloqueou $unlocked de $total conquistas disponíveis.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(
    BuildContext context,
    Conquista conquista,
    bool isUnlocked,
    ProfileProvider profileProvider,
  ) {
    // Check if the achievement is secret and locked
    final isSecret = conquista.descricao.contains('Segredo') || conquista.nome.contains('Segredo');
    final shouldHideDetails = isSecret && !isUnlocked;

    final String displayName = shouldHideDetails ? 'Conquista Secreta' : conquista.nome;
    final String displayDesc = shouldHideDetails ? 'Continue desafiando seus conhecimentos para revelar...' : conquista.descricao;
    final String displayIcon = shouldHideDetails ? '🔒' : (conquista.icone ?? '🏆');

    return InkWell(
      onTap: () => _showAchievementDetail(context, displayName, displayDesc, displayIcon, isUnlocked, isSecret),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUnlocked ? Colors.white : const Color(0xffFAF9F6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked ? const Color(0xff6B5FD3).withOpacity(0.4) : const Color(0xffE2E2E6),
            width: 1.0,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // Left: Icon area (40x40px)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? const Color(0xff6B5FD3).withOpacity(0.08)
                    : const Color(0xffE5E5E5).withOpacity(0.4),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isUnlocked ? const Color(0xff6B5FD3) : const Color(0xffE2E2E6),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Opacity(
                  opacity: isUnlocked ? 1.0 : 0.35,
                  child: Text(
                    displayIcon,
                    style: const TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Middle: Title + short description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: isUnlocked ? const Color(0xff2D2D3A) : const Color(0xff6B6B76),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayDesc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isUnlocked ? const Color(0xff6B6B76) : const Color(0xff6B6B76).withOpacity(0.7),
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            
            // Right: Status / Progress
            _buildProgressOrStatus(conquista, isUnlocked, profileProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressOrStatus(Conquista conquista, bool isUnlocked, ProfileProvider profileProvider) {
    if (isUnlocked) {
      String displayDate = '20/06';
      if (conquista.id == 'c1') displayDate = '18/06';
      if (conquista.id == 'c3') displayDate = '20/06';
      if (conquista.id == 'c4') displayDate = '22/06';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xffE6F4EA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Color(0xff137333),
                  size: 11,
                ),
                SizedBox(width: 4),
                Text(
                  'Desbloqueada',
                  style: TextStyle(
                    color: Color(0xff137333),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              displayDate,
              style: const TextStyle(
                color: Color(0xff137333),
                fontSize: 8,
              ),
            ),
          ],
        ),
      );
    }

    // Locked achievements: progress visualization
    if (conquista.id == 'c2') {
      // Mente Brilhante: 80% progress
      return SizedBox(
        width: 80,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '80% (Alvo 100%)',
              style: TextStyle(color: Color(0xff6B6B76), fontSize: 8, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                value: 0.8,
                minHeight: 4,
                backgroundColor: Color(0xffE5E5E5),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xff3B7DD8)),
              ),
            ),
          ],
        ),
      );
    } else if (conquista.id == 'c4') {
      // Sem Parar: 3/5 dias progress
      final currentStreak = profileProvider.pontuacao?.streakAtual ?? 0;
      final progressVal = (currentStreak / 5.0).clamp(0.0, 1.0);
      return SizedBox(
        width: 80,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$currentStreak/5 dias',
              style: const TextStyle(color: Color(0xff6B6B76), fontSize: 8, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressVal,
                minHeight: 4,
                backgroundColor: const Color(0xffE5E5E5),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff3B7DD8)),
              ),
            ),
          ],
        ),
      );
    }

    // Default locked state
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xffE5E5E5).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            color: Color(0xff6B6B76),
            size: 11,
          ),
          SizedBox(width: 4),
          Text(
            'Bloqueada',
            style: TextStyle(
              color: Color(0xff6B6B76),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showAchievementDetail(
    BuildContext context,
    String name,
    String description,
    String icon,
    bool isUnlocked,
    bool isSecret,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: isUnlocked ? const Color(0xff6B5FD3).withOpacity(0.1) : const Color(0xffFAF9F6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isUnlocked ? const Color(0xff6B5FD3) : const Color(0xffE2E2E6),
                      width: 2.5,
                    ),
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: isUnlocked ? 1.0 : 0.35,
                      child: Text(
                        icon,
                        style: const TextStyle(fontSize: 44),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xff2D2D3A),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 10),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? const Color(0xff3B7DD8).withOpacity(0.1)
                        : const Color(0xffFAF9F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isUnlocked ? const Color(0xff3B7DD8) : const Color(0xffE2E2E6),
                    ),
                  ),
                  child: Text(
                    isUnlocked ? 'DESBLOQUEADA' : 'BLOQUEADA',
                    style: TextStyle(
                      color: isUnlocked ? const Color(0xff3B7DD8) : const Color(0xff6B6B76),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Description
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xff6B6B76),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                // Button to dismiss
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isUnlocked ? const Color(0xff6B5FD3) : const Color(0xffE2E2E6),
                      foregroundColor: isUnlocked ? Colors.white : const Color(0xff6B6B76),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stars_outlined, color: Color(0xffE2E2E6), size: 80),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma conquista encontrada',
              style: TextStyle(color: Color(0xff2D2D3A), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'As conquistas da empresa serão carregadas aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff6B6B76), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
