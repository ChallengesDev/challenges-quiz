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
      backgroundColor: const Color(0xff0b0f19),
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0f19),
        elevation: 0,
        title: const Text(
          'Minhas Insígnias',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: false,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xff00f5d4))))
          : conquistas.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Grid of Achievements
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Adapt columns to screen width (Responsive grid)
                          int crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: conquistas.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.82,
                            ),
                            itemBuilder: (context, index) {
                              final conquista = conquistas[index];
                              final isUnlocked = unlockedIds.contains(conquista.id);
                              return _buildAchievementCard(context, conquista, isUnlocked);
                            },
                          );
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
          colors: [Color(0xff6c5ce7), Color(0xff4834d4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff6c5ce7).withOpacity(0.3),
            blurRadius: 15,
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
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff00f5d4)),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
                  'Mestre Colecionador',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Você desbloqueou $unlocked de $total conquistas disponíveis.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.87),
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

  Widget _buildAchievementCard(BuildContext context, Conquista conquista, bool isUnlocked) {
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xff151c2c),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked ? const Color(0xff6c5ce7).withOpacity(0.5) : const Color(0xff243049),
            width: 1.5,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: const Color(0xff6c5ce7).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge Icon Area
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? const Color(0xff6c5ce7).withOpacity(0.15)
                    : const Color(0xff0b0f19),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isUnlocked ? const Color(0xff6c5ce7) : const Color(0xff243049),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  displayIcon,
                  style: TextStyle(
                    fontSize: 32,
                    color: isUnlocked ? null : Colors.grey.withOpacity(0.4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isUnlocked ? Colors.white : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            // Description
            Expanded(
              child: Text(
                displayDesc,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isUnlocked ? Colors.white60 : Colors.white30,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Unlocked indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isUnlocked ? const Color(0xff00f5d4).withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUnlocked ? Icons.check_circle : Icons.lock_outline,
                    color: isUnlocked ? const Color(0xff00f5d4) : Colors.white30,
                    size: 10,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isUnlocked ? 'Desbloqueada' : 'Bloqueada',
                    style: TextStyle(
                      color: isUnlocked ? const Color(0xff00f5d4) : Colors.white30,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
          backgroundColor: const Color(0xff151c2c),
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
                    color: isUnlocked ? const Color(0xff6c5ce7).withOpacity(0.2) : const Color(0xff0b0f19),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isUnlocked ? const Color(0xff6c5ce7) : const Color(0xff243049),
                      width: 2.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      icon,
                      style: const TextStyle(fontSize: 44),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
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
                        ? const Color(0xff00f5d4).withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isUnlocked ? const Color(0xff00f5d4) : Colors.white24,
                    ),
                  ),
                  child: Text(
                    isUnlocked ? 'DESBLOQUEADA' : 'BLOQUEADA',
                    style: TextStyle(
                      color: isUnlocked ? const Color(0xff00f5d4) : Colors.white54,
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
                    color: Colors.white70,
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
                      backgroundColor: isUnlocked ? const Color(0xff6c5ce7) : const Color(0xff243049),
                      foregroundColor: Colors.white,
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
            Icon(Icons.stars_outlined, color: Colors.white.withOpacity(0.1), size: 80),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma insígnia encontrada',
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'As conquistas da empresa serão carregadas aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white30, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
