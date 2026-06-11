import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../models/models.dart';

class ProfileScreen extends StatefulWidget {
  final Colaborador colab;
  final Pontuacao? score;
  final bool isMock;

  const ProfileScreen({
    super.key,
    required this.colab,
    required this.score,
    required this.isMock,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isResetting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _showChangePasswordDialog(BuildContext context) {
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xff151c2c),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Alterar Senha', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Sua nova senha deve conter pelo menos 6 caracteres.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nova Senha',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xff243049)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xff6c5ce7)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira uma senha';
                        }
                        if (value.length < 6) {
                          return 'A senha deve ter no mínimo 6 caracteres';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff6c5ce7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isResetting
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setDialogState(() {
                              _isResetting = true;
                            });

                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            final success = await authProvider.resetPassword(_passwordController.text);

                            setDialogState(() {
                              _isResetting = false;
                            });

                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: success ? const Color(0xff00f5d4) : Colors.redAccent,
                                  content: Text(
                                    success
                                        ? 'Senha redefinida com sucesso!'
                                        : 'Erro ao redefinir a senha. Tente novamente.',
                                    style: TextStyle(color: success ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  child: _isResetting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Salvar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff151c2c),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Sair do Aplicativo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'Tem certeza que deseja encerrar a sua sessão?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await authProvider.signOut();
              },
              child: const Text('Sair', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final totalAchievements = profileProvider.conquistas.length;
    final unlockedAchievements = profileProvider.unlockedConquistasIds.length;

    // Custom personal integrity indicators (mocked/calculated based on isMock or default database entries)
    // In a production setup, we can calculate this as: 100 - (number of fraud infractions * 5)
    // Let's create a realistic mock representation for a gamified feel.
    final int mockIntegrityScore = widget.isMock ? 98 : 100;
    final int mockExits = widget.isMock ? 2 : 0;
    final int mockSpeedClicks = widget.isMock ? 0 : 0;
    final int mockGazeDrifts = widget.isMock ? 1 : 0;

    return Scaffold(
      backgroundColor: const Color(0xff0b0f19),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xff6c5ce7),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xff00f5d4), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff6c5ce7).withOpacity(0.3),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.colab.nome.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.colab.nome,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.colab.email,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  if (widget.colab.cargo != null || widget.colab.departamento != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xff151c2c),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xff243049)),
                      ),
                      child: Text(
                        '${widget.colab.cargo ?? 'Colaborador'}  •  ${widget.colab.departamento ?? 'Geral'}',
                        style: const TextStyle(color: Color(0xff00f5d4), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Métrica de Integridade Pessoal (Personal Integrity Score)
            _buildIntegrityCard(mockIntegrityScore, mockExits, mockGazeDrifts, mockSpeedClicks),

            const SizedBox(height: 24),

            // Statistics Grid Title
            const Text(
              'Suas Estatísticas',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _buildStatTile(
                  'Nível Atual',
                  '${widget.score?.nivel ?? 1}',
                  Icons.trending_up,
                  const Color(0xff6c5ce7),
                ),
                _buildStatTile(
                  'XP Acumulado',
                  '${widget.score?.xpTotal ?? 0}',
                  Icons.bolt,
                  const Color(0xff00f5d4),
                ),
                _buildStatTile(
                  'Streak Atual',
                  '${widget.score?.streakAtual ?? 0} dias',
                  Icons.local_fire_department,
                  Colors.orangeAccent,
                ),
                _buildStatTile(
                  'Recorde Streak',
                  '${widget.score?.streakMaximo ?? 0} dias',
                  Icons.workspace_premium,
                  const Color(0xffffd700),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Achievements Card summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff151c2c),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xff243049)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xff6c5ce7).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.stars, color: Color(0xff6c5ce7), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Coleção de Insígnias', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            '$unlockedAchievements de $totalAchievements completadas',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white30),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Actions Area
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff151c2c),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xff243049)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.lock_open, size: 18),
              label: const Text('Alterar Minha Senha', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showChangePasswordDialog(context),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                foregroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sair da Conta', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showLogoutConfirmDialog(context),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff151c2c),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff243049)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrityCard(int score, int exits, int gazeDrifts, int speedClicks) {
    Color gaugeColor = const Color(0xff00f5d4); // neon green
    if (score < 80) {
      gaugeColor = Colors.orangeAccent;
    }
    if (score < 50) {
      gaugeColor = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xff151c2c),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xff243049), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xff00f5d4), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Integridade nos Quizzes',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gaugeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  score >= 90 ? 'Excelente' : (score >= 70 ? 'Regular' : 'Atenção'),
                  style: TextStyle(color: gaugeColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              // Circular score widget
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 6,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Índice',
                        style: TextStyle(color: Colors.white38, fontSize: 9),
                      )
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sua nota de conformidade geral.',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Trocar de abas, cliques ultrarrápidos ou desviar o olhar reduzem este índice.',
                      style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xff243049)),
          const SizedBox(height: 8),
          const Text(
            'Histórico de Alertas Anti-Fraude:',
            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfractionMetric('Saídas de tela', '$exits'),
              _buildInfractionMetric('Desvios de olhar', '$gazeDrifts'),
              _buildInfractionMetric('Cliques rápidos', '$speedClicks'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfractionMetric(String label, String count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 4),
        Text(
          count,
          style: TextStyle(
            color: count == '0' ? Colors.white70 : Colors.orangeAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
