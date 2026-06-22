import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class StreakFreezeScreen extends StatelessWidget {
  const StreakFreezeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final score = profileProvider.pontuacao;

    final int xpAvailable = score?.xpTotal ?? 0;
    final int freezeCount = profileProvider.streakFreezeCount;
    final bool isActive = profileProvider.isStreakFreezeActive;
    final bool canBuy = xpAvailable >= 300;

    return Scaffold(
      backgroundColor: const Color(0xff0b0f19),
      appBar: AppBar(
        title: const Text(
          'Streak Freeze',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            // Beautiful Frozen Flame Visual
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyan.withOpacity(0.1),
                  border: Border.all(color: Colors.cyanAccent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.ac_unit,
                  color: Colors.cyanAccent,
                  size: 64,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Proteja sua Chama!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'O Streak Freeze protege a sua sequência de dias consecutivos se você ficar sem jogar por um dia. Quando ativo, ele é consumido automaticamente para evitar que a chama apague!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Inventory status card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xff151c2c),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xff243049)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quantidade Disponível',
                            style: TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Streak Freezes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xff6c5ce7).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xff6c5ce7)),
                        ),
                        child: Text(
                          '$freezeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xff243049)),
                  const SizedBox(height: 12),
                  // Toggle active
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield, color: Colors.cyanAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Equipar Proteção',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: isActive,
                        onChanged: (val) {
                          if (freezeCount > 0 || isActive) {
                            profileProvider.toggleStreakFreezeActive();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.redAccent,
                                content: Text(
                                  'Você precisa comprar um Streak Freeze primeiro!',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          }
                        },
                        activeColor: Colors.cyanAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Store card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff1e1b4b), Color(0xff0b0f19)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xff312e81)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storefront, color: Color(0xff00f5d4), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Loja de Gamificação',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Troque seus pontos de experiência (XP) acumulados para adquirir mais proteções diárias.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Seu saldo: $xpAvailable XP',
                        style: const TextStyle(
                          color: Color(0xff00f5d4),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Text(
                        'Preço: 300 XP',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: canBuy
                        ? () async {
                            final success = await profileProvider.buyStreakFreeze(authProvider.isMock);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: success ? const Color(0xff00f5d4) : Colors.redAccent,
                                  content: Text(
                                    success
                                        ? 'Streak Freeze adquirido com sucesso!'
                                        : 'Erro ao comprar item. Verifique seus pontos.',
                                    style: TextStyle(
                                      color: success ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff6c5ce7),
                      disabledBackgroundColor: const Color(0xff151c2c),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      canBuy ? 'Comprar por 300 XP' : 'Saldo de XP Insuficiente',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
}
