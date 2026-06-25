import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = false;
  RealtimeChannel? _channel;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get loading => _loading;
  int get unreadCount => _notifications.where((n) => n['lida'] == false).length;

  // Load all notifications for the collaborator
  Future<void> loadNotifications(String colabId, bool isMock) async {
    if (isMock) {
      // Return high-fidelity mock list
      if (_notifications.isEmpty) {
        _notifications = [
          {
            'id': 'mock-un-1',
            'usuario_id': colabId,
            'lida': false,
            'criado_em': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
            'notificacoes': {
              'id': 'mock-n-1',
              'titulo': 'Novo Quiz Disponível! 🎯',
              'mensagem': 'O quiz "Segurança da Informação e LGPD" foi liberado. Participe e acumule 100 XP!',
              'tipo': 'novo_quiz',
              'agendado_para': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
            }
          },
          {
            'id': 'mock-un-2',
            'usuario_id': colabId,
            'lida': false,
            'criado_em': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
            'notificacoes': {
              'id': 'mock-n-2',
              'titulo': 'Streak em Risco! 🔥',
              'mensagem': 'Não perca seu streak de 5 dias! Conclua pelo menos um desafio antes de dormir.',
              'tipo': 'motivacional',
              'agendado_para': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
            }
          },
          {
            'id': 'mock-un-3',
            'usuario_id': colabId,
            'lida': true,
            'criado_em': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
            'notificacoes': {
              'id': 'mock-n-3',
              'titulo': 'Parabéns pelo Nível 3! ⚡',
              'mensagem': 'Você subiu de nível! Continue assim para acumular mais conquistas.',
              'tipo': 'conquista',
              'agendado_para': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
            }
          },
          {
            'id': 'mock-un-4',
            'usuario_id': colabId,
            'lida': true,
            'criado_em': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
            'notificacoes': {
              'id': 'mock-n-4',
              'titulo': 'Aviso de Manutenção ⚠️',
              'mensagem': 'O portal passará por manutenção programada no sábado das 22h às 23h.',
              'tipo': 'aviso',
              'agendado_para': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
            }
          }
        ];
      }
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('usuario_notificacoes')
          .select('*, notificacoes(*)')
          .eq('usuario_id', colabId)
          .order('criado_em', ascending: false);

      if (response != null) {
        _notifications = List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      print('Erro ao carregar notificações do banco: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Subscribe to Realtime notifications channel on Supabase
  void subscribeToRealtimeNotifications(String colabId, bool isMock) {
    if (isMock) return;

    // Unsubscribe from any pre-existing channel first
    unsubscribeRealtime();

    try {
      _channel = _supabase
          .channel('public:usuario_notificacoes:usuario_id=eq.$colabId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'usuario_notificacoes',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'usuario_id',
              value: colabId,
            ),
            callback: (payload) async {
              print('Realtime change received: ${payload.eventType}');
              // Reload all notifications to fetch nested 'notificacoes' metadata cleanly
              await loadNotifications(colabId, false);
            },
          );
          
      _channel?.subscribe();
      print('Subscribed to Realtime notifications for user: $colabId');
    } catch (e) {
      print('Falha ao assinar realtime channel de notificações: $e');
    }
  }

  // Unsubscribe from Realtime channel
  void unsubscribeRealtime() {
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
      _channel = null;
      print('Realtime channel unsubscribed.');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String userNotifId, String colabId, bool isMock) async {
    final idx = _notifications.indexWhere((n) => n['id'] == userNotifId);
    if (idx != -1) {
      _notifications[idx]['lida'] = true;
      notifyListeners();
    }

    if (isMock) return;

    try {
      await _supabase
          .from('usuario_notificacoes')
          .update({'lida': true})
          .eq('id', userNotifId);
    } catch (e) {
      print('Erro ao marcar notificação como lida no banco: $e');
    }
  }

  // Mark all notifications as read for current user
  Future<void> markAllAsRead(String colabId, bool isMock) async {
    for (var n in _notifications) {
      n['lida'] = true;
    }
    notifyListeners();

    if (isMock) return;

    try {
      await _supabase
          .from('usuario_notificacoes')
          .update({'lida': true})
          .eq('usuario_id', colabId)
          .eq('lida', false);
    } catch (e) {
      print('Erro ao marcar todas como lidas no banco: $e');
    }
  }

  // Update last access timestamp in public.usuarios
  Future<void> updateLastAccess(String colabId, bool isMock) async {
    if (isMock) return;
    try {
      await _supabase
          .from('usuarios')
          .update({'ultimo_acesso': DateTime.now().toIso8601String()})
          .eq('id', colabId);
      print('Last access updated for user: $colabId');
    } catch (e) {
      print('Erro ao atualizar ultimo_acesso no banco: $e');
    }
  }

  @override
  void dispose() {
    unsubscribeRealtime();
    super.dispose();
  }
}
