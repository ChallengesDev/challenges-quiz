import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Load notifications on screen entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final provider = Provider.of<NotificationsProvider>(context, listen: false);
      if (auth.colaborador != null) {
        provider.loadNotifications(auth.colaborador!.id, auth.isMock);
      }
    });
  }

  String _formatTimeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final difference = DateTime.now().difference(date);
      if (difference.inSeconds < 60) {
        return 'Agora';
      } else if (difference.inMinutes < 60) {
        final m = difference.inMinutes;
        return 'Há $m ${m == 1 ? 'minuto' : 'minutos'}';
      } else if (difference.inHours < 24) {
        final h = difference.inHours;
        return 'Há $h ${h == 1 ? 'hora' : 'horas'}';
      } else {
        final d = difference.inDays;
        return 'Há $d ${d == 1 ? 'dia' : 'dias'}';
      }
    } catch (e) {
      return '';
    }
  }

  IconData _getIconForType(String tipo) {
    switch (tipo) {
      case 'novo_quiz':
        return Icons.quiz_outlined;
      case 'conquista':
        return Icons.emoji_events_outlined;
      case 'aviso':
        return Icons.warning_amber_rounded;
      case 'motivacional':
        return Icons.lightbulb_outline_rounded;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color _getColorForType(String tipo) {
    switch (tipo) {
      case 'novo_quiz':
        return const Color(0xff6c5ce7); // Indigo
      case 'conquista':
        return const Color(0xfff59e0b); // Amber Gold
      case 'aviso':
        return const Color(0xffef4444); // Red
      case 'motivacional':
        return const Color(0xff00f5d4); // Neon Mint
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final provider = Provider.of<NotificationsProvider>(context);
    final notifs = provider.notifications;
    final colab = auth.colaborador;

    return Scaffold(
      backgroundColor: const Color(0xff0b0f19),
      appBar: AppBar(
        title: const Text('Notificações', style: TextStyle(fontFamily: 'Outfit')),
        actions: [
          if (notifs.any((n) => n['lida'] == false))
            TextButton.icon(
              icon: const Icon(Icons.done_all, size: 18, color: Color(0xff00f5d4)),
              label: const Text(
                'Lidas',
                style: TextStyle(color: Color(0xff00f5d4), fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                if (colab != null) {
                  provider.markAllAsRead(colab.id, auth.isMock);
                }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: provider.loading && notifs.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xff00f5d4)),
              ),
            )
          : notifs.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xff00f5d4),
                  backgroundColor: const Color(0xff151c2c),
                  onRefresh: () async {
                    if (colab != null) {
                      await provider.loadNotifications(colab.id, auth.isMock);
                    }
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = notifs[index];
                      final notifData = item['notificacoes'] as Map<String, dynamic>? ?? {};
                      final userNotifId = item['id'] as String;
                      final lida = item['lida'] as bool? ?? false;
                      
                      final titulo = notifData['titulo'] as String? ?? 'Notificação';
                      final mensagem = notifData['mensagem'] as String? ?? '';
                      final tipo = notifData['tipo'] as String? ?? 'aviso';
                      final dataStr = item['criado_em'] as String?;

                      final typeColor = _getColorForType(tipo);

                      return GestureDetector(
                        onTap: () {
                          if (!lida && colab != null) {
                            provider.markAsRead(userNotifId, colab.id, auth.isMock);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: lida ? const Color(0xff151c2c) : const Color(0xff1e1b4b).withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: lida ? const Color(0xff243049) : const Color(0xff6c5ce7).withOpacity(0.4),
                              width: lida ? 1 : 1.5,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Type Icon with glowing background circle
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: typeColor.withOpacity(0.2), width: 1.5),
                                ),
                                child: Center(
                                  child: Icon(
                                    _getIconForType(tipo),
                                    color: typeColor,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              
                              // Text Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Title
                                        Expanded(
                                          child: Text(
                                            titulo,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: lida ? FontWeight.w600 : FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        
                                        // Unread Indicator dot
                                        if (!lida)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8, top: 4),
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Color(0xff00f5d4),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    
                                    // Message
                                    Text(
                                      mensagem,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    
                                    // Time Ago tag
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatTimeAgo(dataStr),
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                          ),
                                        ),
                                        if (!lida)
                                          const Text(
                                            'Toque para marcar como lida',
                                            style: TextStyle(
                                              color: Color(0xff6c5ce7),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xff151c2c),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xff243049), width: 2),
              ),
              child: const Center(
                child: Icon(
                  Icons.notifications_off_outlined,
                  color: Colors.white24,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tudo limpo por aqui!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Você não tem nenhuma notificação pendente no momento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
