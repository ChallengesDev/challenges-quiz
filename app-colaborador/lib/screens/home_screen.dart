import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/notifications_provider.dart';
import '../components/streak_flame.dart';
import '../components/mascot_widget.dart';
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
  late ConfettiController _confettiController;
  bool _alertShownToday = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
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

        // Fetch notifications & subscribe to realtime
        final notificationsProvider = Provider.of<NotificationsProvider>(context, listen: false);
        notificationsProvider.loadNotifications(
          authProvider.colaborador!.id,
          authProvider.isMock
        );
        notificationsProvider.subscribeToRealtimeNotifications(
          authProvider.colaborador!.id,
          authProvider.isMock
        );
        notificationsProvider.updateLastAccess(
          authProvider.colaborador!.id,
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

  void _checkOnboardingAndAlerts(ProfileProvider profileProvider) {
    if (profileProvider.loading) return;

    // 1. Goal onboarding check
    if (!profileProvider.hasOnboardedGoal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOnboardingGoalDialog(profileProvider);
      });
    }

    // 2. Alert check for 20:00 (8 PM)
    final now = DateTime.now();
    if (now.hour >= 20 && !profileProvider.playedToday && !_alertShownToday) {
      _alertShownToday = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xff151c2c),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.redAccent, width: 2),
              ),
              title: const Row(
                children: [
                  Icon(Icons.local_fire_department, color: Colors.redAccent, size: 28),
                  SizedBox(width: 8),
                  Text('SUA CHAMA VAI APAGAR!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: const Text(
                'Sua chama está prestes a apagar hoje! Faça pelo menos 1 desafio para manter sua sequência ativa!',
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendi, vamos jogar!', style: TextStyle(color: Color(0xff00f5d4), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      });
    }

    // 3. Confetti animation check
    if (profileProvider.shouldShowConfetti) {
      _confettiController.play();
      profileProvider.consumeConfetti();
    }
  }

  void _showOnboardingGoalDialog(ProfileProvider profileProvider) {
    int selectedMinutes = 10; // Default selection

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xff151c2c),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xff6c5ce7), width: 2),
              ),
              title: const Text(
                'Meta de Estudo Diária',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Quanto tempo você quer dedicar por dia?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  _buildGoalOnboardingOption('Casual', 5, selectedMinutes, (val) {
                    setDialogState(() {
                      selectedMinutes = val;
                    });
                  }),
                  const SizedBox(height: 12),
                  _buildGoalOnboardingOption('Regular', 10, selectedMinutes, (val) {
                    setDialogState(() {
                      selectedMinutes = val;
                    });
                  }),
                  const SizedBox(height: 12),
                  _buildGoalOnboardingOption('Sério', 15, selectedMinutes, (val) {
                    setDialogState(() {
                      selectedMinutes = val;
                    });
                  }),
                  const SizedBox(height: 12),
                  _buildGoalOnboardingOption('Intenso', 20, selectedMinutes, (val) {
                    setDialogState(() {
                      selectedMinutes = val;
                    });
                  }),
                  const SizedBox(height: 24),
                  // Confirm / Continue button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff00f5d4),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        profileProvider.updateDailyGoal(selectedMinutes);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xff00f5d4),
                            content: Text(
                              'Sua meta diária foi definida para $selectedMinutes minutos!',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Confirmar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGoalOnboardingOption(
    String label, 
    int minutes, 
    int selectedMinutes, 
    ValueChanged<int> onSelected
  ) {
    final isSelected = selectedMinutes == minutes;
    return InkWell(
      onTap: () => onSelected(minutes),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff6c5ce7).withOpacity(0.2) : const Color(0xff0b0f19),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xff6c5ce7) : const Color(0xff243049),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$label ($minutes min/dia)',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xff00f5d4), size: 20)
            else
              const Icon(Icons.radio_button_unchecked, color: Colors.white30, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _confettiController.dispose();
    try {
      Provider.of<NotificationsProvider>(context, listen: false).unsubscribeRealtime();
    } catch (e) {
      print('Erro ao cancelar assinatura realtime de notificações: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final notificationsProvider = Provider.of<NotificationsProvider>(context);
    final colab = authProvider.colaborador;
    final score = profileProvider.pontuacao;
    final unreadCount = notificationsProvider.unreadCount;

    if (colab == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Run alerts and onboarding triggers
    _checkOnboardingAndAlerts(profileProvider);

    // Tabs mapping
    final List<Widget> tabs = [
      _buildDashboardTab(colab, score, profileProvider),
      TrailScreen(colabId: colab.id, isMock: authProvider.isMock),
      RankingScreen(colabId: colab.id),
      const AchievementsScreen(),
      ProfileScreen(colab: colab, score: score, isMock: authProvider.isMock),
    ];

    return Scaffold(
      backgroundColor: const Color(0xff0b0f19),
      appBar: AppBar(
        title: const Text(
          'Challenges Quiz',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined, size: 26),
                onPressed: () {
                  Navigator.pushNamed(context, '/notifications');
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xffef4444),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xff0b0f19), width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            tabs[_currentTabIndex],
            // Confetti effect overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Color(0xff00f5d4),
                  Color(0xff6c5ce7)
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildDashboardTab(Colaborador colab, Pontuacao? score, ProfileProvider profileProvider) {
    int currentXp = score?.xpTotal ?? 0;
    int currentLevel = score?.nivel ?? 1;
    int xpNeededForNext = 500;
    int xpInLevel = currentXp % xpNeededForNext;
    double xpProgress = (xpInLevel / xpNeededForNext).clamp(0.0, 1.0);

    // Mascot phrases for the dashboard
    String mascotMessage = 'Olá! Pronto para mais um desafio de hoje?';
    if (profileProvider.playedToday) {
      if (profileProvider.dailyPlayTimeMinutes >= profileProvider.dailyGoalMinutes) {
        mascotMessage = 'Sensacional! Meta diária cumprida! 🚀';
      } else {
        mascotMessage = 'Ótimo começo! Continue para bater sua meta.';
      }
    } else {
      final now = DateTime.now();
      if (now.hour >= 20) {
        mascotMessage = 'Atenção! Sua chama vai apagar! 🚨';
      }
    }

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
              
              // Interactive Streak Flame
              StreakFlame(
                streak: score?.streakAtual ?? 0,
                playedToday: profileProvider.playedToday,
                isStreakFreezeActive: profileProvider.isStreakFreezeActive,
              ),
            ],
          ),
          
          const SizedBox(height: 24),

          // Reactive Mascot Card on Dashboard
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff151c2c),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xff243049)),
            ),
            child: Row(
              children: [
                MascotWidget(
                  state: profileProvider.playedToday ? 'happy' : 'idle',
                  size: 76,
                  speechBubbleText: mascotMessage,
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'A constância diária garante que você absorva melhor o conhecimento regulamentar e mantenha a conformidade corporativa em alto nível!',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Customizable Daily Goal Progress Card (Circular)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xff151c2c),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xff243049)),
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: (profileProvider.dailyPlayTimeMinutes / profileProvider.dailyGoalMinutes).clamp(0.0, 1.0),
                        strokeWidth: 6,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff00f5d4)),
                      ),
                    ),
                    Text(
                      '${(profileProvider.dailyPlayTimeMinutes).toInt()}/${profileProvider.dailyGoalMinutes}m',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Meta Diária',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profileProvider.dailyPlayTimeMinutes >= profileProvider.dailyGoalMinutes
                            ? 'Meta concluída! +100 XP extras concedidos!'
                            : 'Faltam ${(profileProvider.dailyGoalMinutes - profileProvider.dailyPlayTimeMinutes).toInt().clamp(0, 99)} min para atingir sua meta diária de hoje.',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
