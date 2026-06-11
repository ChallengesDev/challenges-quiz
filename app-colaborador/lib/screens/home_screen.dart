import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../components/streak_flame.dart';
import '../models/models.dart';

// Screens mapped in tabs
import 'trail_screen.dart';
import 'ranking_screen.dart';
import 'achievements_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  late Timer _countdownTimer;
  String _timeUntilMidnight = '00:00:00';

  @override
  void initState() {
    super.initState();
    _startCountdown();
    
    // Load profile stats
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      if (authProvider.colaborador != null) {
        // Fetch real stats
        profileProvider.loadProfileData(
          authProvider.colaborador!.id,
          authProvider.colaborador!.empresaId ?? 'mock-company-123',
          authProvider.isMock
        );
      }
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day + 1);
      final difference = midnight.difference(now);
      
      final hours = difference.inHours.toString().padLeft(2, '0');
      final minutes = (difference.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (difference.inSeconds % 60).toString().padLeft(2, '0');

      if (mounted) {
        setState(() {
          _timeUntilMidnight = '$hours:$minutes:$seconds';
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final colab = authProvider.colaborador;
    final score = profileProvider.pontuacao;

    if (colab == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Tabs mapping
    final List<Widget> tabs = [
      _buildDashboardTab(colab, score),
      TrailScreen(colabId: colab.id, isMock: authProvider.isMock),
      RankingScreen(colabId: colab.id),
      const AchievementsScreen(),
      ProfileScreen(colab: colab, score: score, isMock: authProvider.isMock),
    ];

    return Scaffold(
      backgroundColor: const Color(0xff0b0f19),
      body: SafeArea(
        child: tabs[_currentTabIndex],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xff243049), width: 1.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() {
              _currentTabIndex = index;
            });
          },
          backgroundColor: const Color(0xff151c2c),
          selectedItemColor: const Color(0xff00f5d4), // neon green
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Painel',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Trilha',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              activeIcon: Icon(Icons.emoji_events),
              label: 'Rankings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.stars_outlined),
              activeIcon: Icon(Icons.stars),
              label: 'Insígnias',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab(Colaborador colab, Pontuacao? score) {
    int currentXp = score?.xpTotal ?? 0;
    int currentLevel = score?.nivel ?? 1;
    // XP limits: 500 XP per level
    int nextLevelXp = currentLevel * 500;
    int prevLevelXp = (currentLevel - 1) * 500;
    int xpInLevel = currentXp - prevLevelXp;
    int xpNeededForNext = 500;
    double xpProgress = (xpInLevel / xpNeededForNext).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card (Profile summary + Streak)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Avatar Circle
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xff6c5ce7),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xff00f5d4), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff6c5ce7).withOpacity(0.4),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: Center(
                      child: Text(
                        colab.nome.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        colab.nome,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      // Level Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xff6c5ce7).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xff6c5ce7), width: 1),
                        ),
                        child: Text(
                          'Nível $currentLevel',
                          style: const TextStyle(color: Color(0xff6c5ce7), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Streak Flame Component
              StreakFlame(streak: score?.streakAtual ?? 0),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // XP Progress Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff151c2c),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xff243049)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Progresso do Level', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(
                      '$xpInLevel / $xpNeededForNext XP',
                      style: const TextStyle(color: Color(0xff00f5d4), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: xpProgress,
                    minHeight: 12,
                    backgroundColor: const Color(0xff0b0f19),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff00f5d4)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Daily Mission Countdown Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff1e1b4b), Color(0xff0f172a)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xff312e81)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.hourglass_empty, color: Colors.orangeAccent, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Missão Diária',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    Text(
                      _timeUntilMidnight,
                      style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Conclua pelo menos 1 quiz da sua trilha para acumular 100 XP extras e manter seu streak!',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                
                // Motivational Message from manager
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Color(0xffffd700), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mensagem do Líder: "Excelente trabalho! Cada quiz respondido é um passo rumo à excelência."',
                          style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Categories Progress grid
          const Text(
            'Categorias em Andamento',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 14),

          _buildCategoryCard('Compliance & LGPD', 0.65, const Color(0xff6c5ce7)),
          const SizedBox(height: 12),
          _buildCategoryCard('Segurança da Informação', 0.40, const Color(0xff00f5d4)),
          const SizedBox(height: 12),
          _buildCategoryCard('Vendas & Negociação', 0.10, Colors.amber),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String name, double progress, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff151c2c),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff243049)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xff0b0f19),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
