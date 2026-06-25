import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentTabIndex = 0;
  late Timer _countdownTimer;
  String _timeUntilMidnight = '00:00:00';
  late ConfettiController _confettiController;
  bool _alertShownToday = false;

  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _startCountdown();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
    
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

  void _updateTime() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final difference = midnight.difference(now);
    
    final hours = difference.inHours.toString().padLeft(2, '0');
    final minutes = (difference.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (difference.inSeconds % 60).toString().padLeft(2, '0');

    _timeUntilMidnight = '$hours:$minutes:$seconds';
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateTime();
        });
      }
    });
  }

  void _checkOnboardingAndAlerts(ProfileProvider profileProvider, AuthProvider authProvider) {
    if (profileProvider.loading) return;

    // 1. Goal onboarding check
    if (!profileProvider.hasOnboardedGoal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOnboardingGoalDialog(profileProvider);
      });
      return;
    }

    // 2. Mascot color onboarding check
    if (authProvider.colaborador != null && authProvider.colaborador!.corMascote == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMascotColorSelectionDialog(authProvider);
      });
      return;
    }

    // 3. Alert check for 20:00 (8 PM)
    final now = DateTime.now();
    if (now.hour >= 20 && !profileProvider.playedToday && !_alertShownToday) {
      _alertShownToday = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.redAccent, width: 2),
              ),
              title: const Row(
                children: [
                  Icon(Icons.local_fire_department, color: Colors.redAccent, size: 28),
                  SizedBox(width: 8),
                  Text('SUA CHAMA VAI APAGAR!', style: TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: const Text(
                'Sua chama está prestes a apagar hoje! Faça pelo menos 1 desafio para manter sua sequência ativa!',
                style: TextStyle(color: Color(0xff6B6B76), fontSize: 14, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendi, vamos jogar!', style: TextStyle(color: Color(0xff6B5FD3), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      });
    }

    // 4. Confetti animation check
    if (profileProvider.shouldShowConfetti) {
      _confettiController.play();
      profileProvider.consumeConfetti();
    }
  }

  void _showMascotColorSelectionDialog(AuthProvider authProvider) {
    String selectedColor = 'roxo';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xff6B5FD3), width: 2),
              ),
              title: const Text(
                'Escolha seu Companheiro!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Selecione a cor do seu Octo. Ele vai te acompanhar na jornada de conformidade!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xff6B6B76), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildColorOptionCard('Roxo', 'roxo', selectedColor, (val) {
                        setDialogState(() => selectedColor = val);
                      }),
                      _buildColorOptionCard('Neon', 'verde', selectedColor, (val) {
                        setDialogState(() => selectedColor = val);
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildColorOptionCard('Ouro', 'dourado', selectedColor, (val) {
                        setDialogState(() => selectedColor = val);
                      }),
                      _buildColorOptionCard('Azul', 'azul', selectedColor, (val) {
                        setDialogState(() => selectedColor = val);
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff6B5FD3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        await authProvider.updateMascotColor(selectedColor);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xff6B5FD3),
                            content: Text(
                              'Octo está pronto para te acompanhar!',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Confirmar Escolha',
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

  Widget _buildColorOptionCard(
    String label,
    String colorKey,
    String selectedColor,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = selectedColor == colorKey;
    final color = _getOptionColor(colorKey);

    return InkWell(
      onTap: () => onSelected(colorKey),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xffE5E5E5),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          children: [
            CustomPaint(
              size: const Size(50, 55),
              painter: OctoPainter(
                state: 'idle',
                colorKey: colorKey,
                level: 1,
                loopValue: 0.0,
                jumpValue: 0.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xff2D2D3A),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getOptionColor(String key) {
    switch (key) {
      case 'verde':
        return const Color(0xff00f5d4);
      case 'dourado':
        return const Color(0xffffd700);
      case 'azul':
        return const Color(0xff00c6ff);
      case 'roxo':
      default:
        return const Color(0xff6B5FD3);
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
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xff6B5FD3), width: 2),
              ),
              title: const Text(
                'Meta de Estudo Diária',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Quanto tempo você quer dedicar por dia?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xff6B6B76), fontSize: 14, height: 1.4),
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
                        backgroundColor: const Color(0xff6B5FD3),
                        foregroundColor: Colors.white,
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
                            backgroundColor: const Color(0xff6B5FD3),
                            content: Text(
                              'Sua meta diária foi definida para $selectedMinutes minutos!',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          color: isSelected ? const Color(0xff6B5FD3).withOpacity(0.08) : const Color(0xffFAF9F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xff6B5FD3) : const Color(0xffE5E5E5),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$label ($minutes min/dia)',
              style: TextStyle(
                color: isSelected ? const Color(0xff2D2D3A) : const Color(0xff6B6B76),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xff6B5FD3), size: 20)
            else
              const Icon(Icons.radio_button_unchecked, color: Color(0xff6B6B76), size: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _confettiController.dispose();
    _breathingController.dispose();
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
    _checkOnboardingAndAlerts(profileProvider, authProvider);

    // Tabs mapping
    final List<Widget> tabs = [
      _buildDashboardTab(colab, score, profileProvider),
      TrailScreen(colabId: colab.id, isMock: authProvider.isMock),
      RankingScreen(colabId: colab.id),
      const AchievementsScreen(),
      ProfileScreen(colab: colab, score: score, isMock: authProvider.isMock),
    ];

    return Scaffold(
      backgroundColor: const Color(0xffFAF9F6),
      appBar: AppBar(
        title: const Text(
          'Challenges Quiz',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xff2D2D3A),
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined, size: 26, color: Color(0xff2D2D3A)),
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
                      border: Border.all(color: const Color(0xffFAF9F6), width: 1.5),
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
                  Color(0xff6B5FD3),
                  Color(0xff3B7DD8),
                  Color(0xffffd700),
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xffE5E5E5), width: 1.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() {
              _currentTabIndex = index;
            });
          },
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xff6B5FD3),
          unselectedItemColor: const Color(0xff6B6B76),
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

  void _navigateToNextChallenge() {
    final allDesafios = [
      Desafio(id: 'chal-1', topicoId: 'top-1', titulo: 'LGPD Básica', dificuldade: 'facil', tempoLimite: 300, pontuacao: 100, ativo: true),
      Desafio(id: 'chal-2', topicoId: 'top-1', titulo: 'Dados Sensíveis', dificuldade: 'medio', tempoLimite: 300, pontuacao: 150, ativo: true),
      Desafio(id: 'chal-3', topicoId: 'top-2', titulo: 'Código de Ética', dificuldade: 'medio', tempoLimite: 300, pontuacao: 150, ativo: true),
      Desafio(id: 'chal-4', topicoId: 'top-2', titulo: 'Anticorrupção', dificuldade: 'dificil', tempoLimite: 300, pontuacao: 200, ativo: true),
      Desafio(id: 'chal-5', topicoId: 'top-3', titulo: 'Higiene de Senhas', dificuldade: 'facil', tempoLimite: 300, pontuacao: 100, ativo: true),
      Desafio(id: 'chal-6', topicoId: 'top-3', titulo: 'Evitando Phishing', dificuldade: 'medio', tempoLimite: 300, pontuacao: 150, ativo: true),
      Desafio(id: 'chal-7', topicoId: 'top-4', titulo: 'SPIN Selling', dificuldade: 'medio', tempoLimite: 300, pontuacao: 150, ativo: true),
    ];
    _fetchCompletedAndStart(allDesafios);
  }

  Future<void> _fetchCompletedAndStart(List<Desafio> allDesafios) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    
    final completedList = prefs.getStringList('completed_challenges_${authProvider.colaborador?.id}') ?? ['chal-1', 'chal-5'];
    final completedSet = completedList.toSet();
    
    Desafio? nextDesafio;
    for (var d in allDesafios) {
      if (!completedSet.contains(d.id)) {
        nextDesafio = d;
        break;
      }
    }
    
    nextDesafio ??= allDesafios.first;
    
    if (mounted) {
      Navigator.pushNamed(context, '/quiz', arguments: nextDesafio);
    }
  }

  void _navigateToCategoryChallenge(String categoryName) {
    final allDesafios = [
      Desafio(id: 'chal-1', topicoId: 'top-1', titulo: 'LGPD Básica', dificuldade: 'facil', tempoLimite: 300, pontuacao: 100, ativo: true),
      Desafio(id: 'chal-2', topicoId: 'top-1', titulo: 'Dados Sensíveis', dificuldade: 'medio', tempoLimite: 300, pontuacao: 150, ativo: true),
      Desafio(id: 'chal-3', topicoId: 'top-2', titulo: 'Código de Ética', dificuldade: 'medio', tempoLimite: 300, pontuacao: 150, ativo: true),
      Desafio(id: 'chal-4', topicoId: 'top-2', titulo: 'Anticorrupção', dificuldade: 'dificil', tempoLimite: 300, pontuacao: 200, ativo: true),
      Desafio(id: 'chal-5', topicoId: 'top-3', titulo: 'Higiene de Senhas', dificuldade: 'facil', tempoLimite: 300, pontuacao: 100, ativo: true),
      Desafio(id: 'chal-6', topicoId: 'top-3', titulo: 'Evitando Phishing', dificuldade: 'medio', tempoLimite: 300, pontuacao: 150, ativo: true),
      Desafio(id: 'chal-7', topicoId: 'top-4', titulo: 'SPIN Selling', dificuldade: 'medio', tempoLimite: 300, pontuacao: 150, ativo: true),
    ];
    
    List<Desafio> categoryDesafios = [];
    if (categoryName == 'Compliance & LGPD') {
      categoryDesafios = allDesafios.where((d) => d.topicoId == 'top-1' || d.topicoId == 'top-2').toList();
    } else if (categoryName == 'Segurança da Informação') {
      categoryDesafios = allDesafios.where((d) => d.topicoId == 'top-3').toList();
    } else {
      categoryDesafios = allDesafios.where((d) => d.topicoId == 'top-4').toList();
    }
    
    _fetchCompletedAndStart(categoryDesafios);
  }

  Widget _buildDashboardTab(Colaborador colab, Pontuacao? score, ProfileProvider profileProvider) {
    int currentXp = score?.xpTotal ?? 0;
    int currentLevel = score?.nivel ?? 1;
    int xpNeededForNext = 500;
    int xpInLevel = currentXp % xpNeededForNext;
    double xpProgress = (xpInLevel / xpNeededForNext).clamp(0.0, 1.0);

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
          // a) Header compacto: nome, nível, foto de perfil customizada
          Row(
            children: [
              // Avatar redondo
              colab.fotoUrl != null && colab.fotoUrl!.isNotEmpty
                  ? (colab.fotoUrl!.startsWith('data:image')
                      ? CircleAvatar(
                          radius: 28,
                          backgroundImage: MemoryImage(base64Decode(colab.fotoUrl!.split(',')[1])),
                          backgroundColor: Colors.transparent,
                        )
                      : CircleAvatar(
                          radius: 28,
                          backgroundImage: NetworkImage(colab.fotoUrl!),
                          backgroundColor: Colors.transparent,
                        ))
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xff6B5FD3),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      colab.nome,
                      style: const TextStyle(color: Color(0xff2D2D3A), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    // Level Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xff6B5FD3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Nível $currentLevel',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // b) Octo em destaque: muito maior, com animação contínua sutil de respiração
          Center(
            child: ScaleTransition(
              scale: _breathingAnimation,
              child: MascotWidget(
                state: profileProvider.playedToday ? 'happy' : 'idle',
                size: 150, // Muito maior
                speechBubbleText: mascotMessage,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // c) BOTÃO PRINCIPAL "▶ Jogar agora"
          ElevatedButton(
            onPressed: _navigateToNextChallenge,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff6B5FD3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: const Color(0xff6B5FD3).withOpacity(0.4),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, size: 24),
                SizedBox(width: 8),
                Text(
                  'Jogar agora',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // d) Faixa horizontal única de indicadores (Streak, Meta, XP)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                // Streak
                Expanded(
                  child: Column(
                    children: [
                      const Text('Sequência', style: TextStyle(color: Color(0xff6B6B76), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text('${score?.streakAtual ?? 0} dias', style: const TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: const Color(0xffE5E5E5)),
                // Meta Diária
                Expanded(
                  child: Column(
                    children: [
                      const Text('Meta Diária', style: TextStyle(color: Color(0xff6B6B76), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              value: (profileProvider.dailyPlayTimeMinutes / profileProvider.dailyGoalMinutes).clamp(0.0, 1.0),
                              strokeWidth: 2.5,
                              backgroundColor: const Color(0xffFAF9F6),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff3B7DD8)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${profileProvider.dailyPlayTimeMinutes.toInt()}/${profileProvider.dailyGoalMinutes}m',
                            style: const TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: const Color(0xffE5E5E5)),
                // XP Nível
                Expanded(
                  child: Column(
                    children: [
                      Text('XP Nível $currentLevel', style: const TextStyle(color: Color(0xff6B6B76), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: xpProgress,
                                minHeight: 5,
                                backgroundColor: const Color(0xffFAF9F6),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff6B5FD3)),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text('$xpInLevel/$xpNeededForNext XP', style: const TextStyle(color: Color(0xff6B6B76), fontSize: 8, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // e) Card "Missão Diária"
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Missão: ${profileProvider.activeMission.titulo}',
                          style: const TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    profileProvider.dailyMissionCompleted
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xffE6F4EA),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Color(0xff137333), size: 12),
                                SizedBox(width: 4),
                                Text('Concluída!', style: TextStyle(color: Color(0xff137333), fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        : Text(
                            'Expira em: $_timeUntilMidnight',
                            style: const TextStyle(color: Color(0xff3B7DD8), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace'),
                          ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  profileProvider.activeMission.descricao,
                  style: const TextStyle(color: Color(0xff6B6B76), fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xffFAF9F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.bolt, color: Color(0xff6B5FD3), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Recompensa: +100 XP extras',
                        style: TextStyle(color: Color(0xff2D2D3A), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // f) Seção "Categorias em Andamento"
          const Text(
            'Categorias em Andamento',
            style: TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 14),

          _buildCategoryCard('Compliance & LGPD', 0.65, const Color(0xff6B5FD3), Icons.gavel_rounded),
          const SizedBox(height: 12),
          _buildCategoryCard('Segurança da Informação', 0.40, const Color(0xff3B7DD8), Icons.security_rounded),
          const SizedBox(height: 12),
          _buildCategoryCard('Vendas & Negociação', 0.10, Colors.amber, Icons.trending_up_rounded),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String name, double progress, Color color, IconData icon) {
    return GestureDetector(
      onTap: () => _navigateToCategoryChallenge(name),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(color: Color(0xff2D2D3A), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: const Color(0xffFAF9F6),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xff6B6B76), size: 20),
          ],
        ),
      ),
    );
  }
}
