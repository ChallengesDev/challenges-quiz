import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../models/models.dart';
import '../utils/image_picker_helper.dart';

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

  Future<void> _pickAndUploadPhoto(BuildContext context) async {
    try {
      final picked = await pickImageHelper();
      if (picked == null) return;

      // 1. Format validation (JPG, JPEG, PNG)
      final ext = picked.name.split('.').last.toLowerCase();
      if (ext != 'png' && ext != 'jpg' && ext != 'jpeg') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Formato inválido. Apenas JPG, JPEG e PNG são aceitos.', style: TextStyle(color: Colors.white)),
            ),
          );
        }
        return;
      }

      // 2. Size validation (< 5MB)
      final double sizeInMb = picked.size / (1024 * 1024);
      if (sizeInMb > 5.0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('A imagem deve ser menor do que 5MB.', style: TextStyle(color: Colors.white)),
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xff6B5FD3),
            content: Text('Enviando foto de perfil...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      String? uploadedUrl;

      if (widget.isMock) {
        // In mock mode, encode as base64 data URL
        final base64String = base64Encode(picked.bytes);
        uploadedUrl = 'data:image/$ext;base64,$base64String';
      } else {
        try {
          // Upload directly to Supabase Storage Bucket 'avatars'
          final supabase = Supabase.instance.client;
          final path = '${widget.colab.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
          
          await supabase.storage.from('avatars').uploadBinary(
            path,
            picked.bytes,
            fileOptions: FileOptions(
              contentType: 'image/$ext',
              upsert: true,
            ),
          );
          uploadedUrl = supabase.storage.from('avatars').getPublicUrl(path);
        } catch (storageErr) {
          print('Erro no Supabase Storage: $storageErr. Usando base64 fallback.');
          // Fallback to base64 Data URL if bucket is missing or connection fails
          final base64String = base64Encode(picked.bytes);
          uploadedUrl = 'data:image/$ext;base64,$base64String';
        }
      }

      // Update in auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.updateProfilePicture(uploadedUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Foto de perfil atualizada com sucesso!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      }
    } catch (e) {
      print('Erro ao escolher ou fazer upload da foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Erro ao atualizar foto: $e'),
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Alterar Senha', style: TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold)),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Sua nova senha deve conter pelo menos 6 caracteres.',
                      style: TextStyle(color: Color(0xff6B6B76), fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Color(0xff2D2D3A)),
                      decoration: InputDecoration(
                        labelText: 'Nova Senha',
                        labelStyle: const TextStyle(color: Color(0xff6B6B76)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xffE2E2E6)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xff6B5FD3)),
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
                  child: const Text('Cancelar', style: TextStyle(color: Color(0xff6B6B76))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff6B5FD3),
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
                                  backgroundColor: success ? Colors.green : Colors.redAccent,
                                  content: Text(
                                    success
                                        ? 'Senha redefinida com sucesso!'
                                        : 'Erro ao redefinir a senha. Tente novamente.',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Sair do Aplicativo', style: TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold)),
          content: const Text(
            'Tem certeza que deseja encerrar a sua sessão?',
            style: TextStyle(color: Color(0xff6B6B76)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xff6B6B76))),
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

    final int mockIntegrityScore = widget.isMock ? 98 : 100;
    final int mockExits = widget.isMock ? 2 : 0;
    final int mockSpeedClicks = widget.isMock ? 0 : 0;
    final int mockGazeDrifts = widget.isMock ? 1 : 0;

    return Scaffold(
      backgroundColor: const Color(0xffFAF9F6),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _pickAndUploadPhoto(context),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xff6B5FD3), width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: ClipOval(
                            child: widget.colab.fotoUrl != null && widget.colab.fotoUrl!.isNotEmpty
                                ? (widget.colab.fotoUrl!.startsWith('data:image')
                                    ? Image.memory(
                                        base64Decode(widget.colab.fotoUrl!.split(',')[1]),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 50, color: Color(0xff6B6B76)),
                                      )
                                    : Image.network(
                                        widget.colab.fotoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 50, color: Color(0xff6B6B76)),
                                      ))
                                : Container(
                                    color: const Color(0xff6B5FD3).withOpacity(0.1),
                                    child: Center(
                                      child: Text(
                                        widget.colab.nome.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(
                                          color: Color(0xff6B5FD3),
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xff6B5FD3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.colab.nome,
                    style: const TextStyle(color: Color(0xff2D2D3A), fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.colab.email,
                    style: const TextStyle(color: Color(0xff6B6B76), fontSize: 13),
                  ),
                  if (widget.colab.cargo != null || widget.colab.departamento != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xff3B7DD8).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xff3B7DD8).withOpacity(0.3)),
                      ),
                      child: Text(
                        '${widget.colab.cargo ?? 'Colaborador'}  •  ${widget.colab.departamento ?? 'Geral'}',
                        style: const TextStyle(color: Color(0xff3B7DD8), fontSize: 11, fontWeight: FontWeight.bold),
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
              style: TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold, fontSize: 16),
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
                  const Color(0xff6B5FD3),
                ),
                _buildStatTile(
                  'XP Acumulado',
                  '${widget.score?.xpTotal ?? 0}',
                  Icons.bolt,
                  const Color(0xff3B7DD8),
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
                  const Color(0xffFFD700),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Achievements Card summary
            GestureDetector(
              onTap: () {
                // Change current tab to achievements
                // Since this screen is inside HomeScreen, the parent handles tabs,
                // but we can at least show a visual click or let it stay static
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffE2E2E6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xff6B5FD3).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.stars, color: Color(0xff6B5FD3), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Coleção de Insígnias', style: TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(
                              '$unlockedAchievements de $totalAchievements completadas',
                              style: const TextStyle(color: Color(0xff6B6B76), fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xff6B6B76)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Adjust Daily Goal
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffE2E2E6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.query_builder, color: Color(0xff3B7DD8), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Ajustar Meta Diária',
                        style: TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildGoalChip(context, profileProvider, 'Casual', 5),
                      _buildGoalChip(context, profileProvider, 'Regular', 10),
                      _buildGoalChip(context, profileProvider, 'Sério', 15),
                      _buildGoalChip(context, profileProvider, 'Intenso', 20),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Actions Area
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xff6B5FD3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xffE2E2E6)),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.lock_open, size: 18),
              label: const Text('Alterar Minha Senha', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showChangePasswordDialog(context),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.05),
                foregroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
                ),
                elevation: 0,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE2E2E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
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
                  style: const TextStyle(color: Color(0xff6B6B76), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(color: Color(0xff2D2D3A), fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrityCard(int score, int exits, int gazeDrifts, int speedClicks) {
    Color gaugeColor = const Color(0xff3B7DD8);
    if (score < 80) {
      gaugeColor = Colors.orangeAccent;
    }
    if (score < 50) {
      gaugeColor = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffE2E2E6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xff6B5FD3), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Integridade nos Quizzes',
                style: TextStyle(color: Color(0xff2D2D3A), fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gaugeColor.withOpacity(0.1),
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
                      backgroundColor: const Color(0xffFAF9F6),
                      valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score%',
                        style: const TextStyle(
                          color: Color(0xff2D2D3A),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Índice',
                        style: TextStyle(color: Color(0xff6B6B76), fontSize: 9),
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
                      style: TextStyle(color: Color(0xff2D2D3A), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Trocar de abas, cliques ultrarrápidos ou desviar o olhar reduzem este índice.',
                      style: TextStyle(color: Color(0xff6B6B76), fontSize: 11, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xffE2E2E6)),
          const SizedBox(height: 8),
          const Text(
            'Histórico de Alertas Anti-Fraude:',
            style: TextStyle(color: Color(0xff6B6B76), fontSize: 11, fontWeight: FontWeight.bold),
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
        Text(label, style: const TextStyle(color: Color(0xff6B6B76), fontSize: 10)),
        const SizedBox(height: 4),
        Text(
          count,
          style: TextStyle(
            color: count == '0' ? const Color(0xff2D2D3A) : Colors.orangeAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalChip(BuildContext context, ProfileProvider profileProvider, String label, int minutes) {
    final isSelected = profileProvider.dailyGoalMinutes == minutes;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xff2D2D3A),
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          profileProvider.updateDailyGoal(minutes);
        }
      },
      selectedColor: const Color(0xff6B5FD3),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isSelected ? const Color(0xff6B5FD3) : const Color(0xffE2E2E6)),
      ),
    );
  }
}
