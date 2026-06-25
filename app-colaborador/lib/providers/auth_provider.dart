import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  Session? _session;
  Colaborador? _colaborador;
  bool _loading = false;
  bool _isMock = false;

  Session? get session => _session;
  Colaborador? get colaborador => _colaborador;
  bool get loading => _loading;
  bool get isMock => _isMock;
  bool get isAuthenticated => _session != null || (_isMock && _colaborador != null);

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    _loading = true;
    notifyListeners();

    try {
      // 1. Tenta carregar sessão mock do cache local
      final prefs = await SharedPreferences.getInstance();
      final mockSessionStr = prefs.getString('mock_colab_session');
      if (mockSessionStr != null) {
        final Map<String, dynamic> data = jsonDecode(mockSessionStr);
        _session = null; // não há sessão Supabase real
        _isMock = true;
        final bool mockOnboarding = prefs.getBool('onboarding_completo_${data['id']}') ?? false;
        _colaborador = Colaborador(
          id: data['id'],
          nome: data['nome'],
          email: data['email'],
          cargo: data['cargo'],
          departamento: data['departamento'],
          ativo: true,
          primeiroAcesso: data['primeiro_acesso'] ?? false,
          empresaId: data['empresa_id'] ?? 'mock-company-123',
          corMascote: data['cor_mascote'],
          fotoUrl: data['foto_url'],
          onboardingCompleto: mockOnboarding,
        );
        _loading = false;
        notifyListeners();
        return;
      }

      // 2. Se não houver mock, tenta buscar a sessão real do Supabase
      final currentSession = _supabase.auth.currentSession;
      if (currentSession != null) {
        _session = currentSession;
        await _fetchUserProfile(currentSession.user.id);
      }
    } catch (e) {
      print('Erro ao inicializar sessão auth: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('usuarios')
          .select()
          .eq('id', userId)
          .single();

      bool onboardingCompleto = false;
      if (response.containsKey('onboarding_completo') && response['onboarding_completo'] != null) {
        onboardingCompleto = response['onboarding_completo'] as bool;
      } else {
        // Fallback para API do backend se a coluna não estiver mapeada/presente no select do Supabase
        try {
          final url = Uri.parse('http://localhost:8000/api/usuarios/$userId/onboarding');
          final apiRes = await http.get(url).timeout(const Duration(seconds: 3));
          if (apiRes.statusCode == 200) {
            final decoded = json.decode(utf8.decode(apiRes.bodyBytes));
            onboardingCompleto = decoded['onboarding_completo'] as bool? ?? false;
          }
        } catch (apiErr) {
          print('Erro ao consultar onboarding no backend: $apiErr');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final localOnboarding = prefs.getBool('onboarding_completo_$userId') ?? false;
      if (localOnboarding) {
        onboardingCompleto = true;
      }

      final Map<String, dynamic> colabMap = Map<String, dynamic>.from(response);
      colabMap['onboarding_completo'] = onboardingCompleto;

      _colaborador = Colaborador.fromJson(colabMap);
    } catch (e) {
      print('Erro ao carregar perfil do Supabase: $e');
      // Fallback em caso de erro de RLS ou offline
      final prefs = await SharedPreferences.getInstance();
      final localOnboarding = prefs.getBool('onboarding_completo_$userId') ?? false;
      
      _colaborador = Colaborador(
        id: userId,
        nome: _supabase.auth.currentUser?.userMetadata?['nome'] ?? 'Colaborador',
        email: _supabase.auth.currentUser?.email ?? '',
        ativo: true,
        primeiroAcesso: false,
        onboardingCompleto: localOnboarding,
      );
    }
  }

  Future<bool> signIn(String email, String password) async {
    _loading = true;
    notifyListeners();

    // 1. Valida credenciais mock imediatamente para o modo de demonstração offline
    if (email == 'colaborador@challenges.com' && password == 'Challenges@123') {
      final prefs = await SharedPreferences.getInstance();
      final bool mockResetDone = prefs.getBool('mock_reset_done') ?? false;

      final mockData = {
        'id': 'mock-colab-uuid-123',
        'nome': 'João Colaborador',
        'email': 'colaborador@challenges.com',
        'cargo': 'Analista de Sistemas',
        'departamento': 'TI / Tecnologia',
        'primeiro_acesso': !mockResetDone,
        'cor_mascote': prefs.getString('mock_cor_mascote'),
        'foto_url': prefs.getString('mock_foto_url')
      };

      try {
        await prefs.setString('mock_colab_session', jsonEncode(mockData));
      } catch (e) {
        print('Erro ao salvar cache de mock: $e');
      }

      final bool mockOnboarding = prefs.getBool('onboarding_completo_${mockData['id']}') ?? false;
      _session = null;
      _isMock = true;
      _colaborador = Colaborador(
        id: mockData['id'] as String,
        nome: mockData['nome'] as String,
        email: mockData['email'] as String,
        cargo: mockData['cargo'] as String,
        departamento: mockData['departamento'] as String,
        ativo: true,
        primeiroAcesso: !mockResetDone,
        empresaId: 'mock-company-123',
        corMascote: mockData['cor_mascote'] as String?,
        fotoUrl: mockData['foto_url'] as String?,
        onboardingCompleto: mockOnboarding,
      );

      if (!mockResetDone) {
        print('Simulação: E-mail de redefinição de senha enviado para colaborador@challenges.com');
        await prefs.setBool('mock_reset_done', true);
      }

      _loading = false;
      notifyListeners();
      return true;
    }

    // 2. Caso contrário, tenta autenticação real no Supabase
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        _session = response.session;
        _isMock = false;
        await _fetchUserProfile(response.session!.user.id);

        if (_colaborador != null && _colaborador!.primeiroAcesso) {
          try {
            await _supabase.auth.resetPasswordForEmail(email);
            print('E-mail de redefinição de senha enviado para $email');
          } catch (mailErr) {
            print('Erro ao enviar e-mail de redefinição: $mailErr');
          }

          try {
            await _supabase.from('usuarios').update({'primeiro_acesso': false}).eq('id', _colaborador!.id);
          } catch (dbErr) {
            print('Erro ao atualizar primeiro_acesso no banco: $dbErr');
          }
        }

        _loading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Falha ao autenticar com e-mail/senha: $e');
    }

    _loading = false;
    notifyListeners();
    return false;
  }

  Future<bool> resetPassword(String newPassword) async {
    if (_colaborador == null) return false;
    _loading = true;
    notifyListeners();

    try {
      if (_isMock) {
        // Atualiza mock no SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final mockSessionStr = prefs.getString('mock_colab_session');
        if (mockSessionStr != null) {
          final Map<String, dynamic> data = jsonDecode(mockSessionStr);
          data['primeiro_acesso'] = false; // Já redefinido
          await prefs.setString('mock_colab_session', jsonEncode(data));
        }

        _colaborador = Colaborador(
          id: _colaborador!.id,
          nome: _colaborador!.nome,
          email: _colaborador!.email,
          cargo: _colaborador!.cargo,
          departamento: _colaborador!.departamento,
          ativo: true,
          primeiroAcesso: false,
          corMascote: _colaborador!.corMascote,
        );
        _loading = false;
        notifyListeners();
        return true;
      } else {
        // Redefine no Supabase Auth e desativa flag na tabela pública
        await _supabase.auth.updateUser(
          UserAttributes(password: newPassword),
        );

        await _supabase
            .from('usuarios')
            .update({'primeiro_acesso': false})
            .eq('id', _colaborador!.id);

        _colaborador = Colaborador(
          id: _colaborador!.id,
          nome: _colaborador!.nome,
          email: _colaborador!.email,
          cargo: _colaborador!.cargo,
          departamento: _colaborador!.departamento,
          ativo: _colaborador!.ativo,
          primeiroAcesso: false,
          empresaId: _colaborador!.empresaId,
          corMascote: _colaborador!.corMascote,
        );
        _loading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Erro ao redefinir senha: $e');
    }

    _loading = false;
    notifyListeners();
    return false;
  }

  Future<void> updateMascotColor(String color) async {
    if (_colaborador == null) return;
    try {
      if (_isMock) {
        final prefs = await SharedPreferences.getInstance();
        final mockSessionStr = prefs.getString('mock_colab_session');
        if (mockSessionStr != null) {
          final Map<String, dynamic> data = jsonDecode(mockSessionStr);
          data['cor_mascote'] = color;
          await prefs.setString('mock_colab_session', jsonEncode(data));
        }
        await prefs.setString('mock_cor_mascote', color);
      } else {
        await _supabase
            .from('usuarios')
            .update({'cor_mascote': color})
            .eq('id', _colaborador!.id);
      }

      _colaborador = Colaborador(
        id: _colaborador!.id,
        nome: _colaborador!.nome,
        email: _colaborador!.email,
        cargo: _colaborador!.cargo,
        departamento: _colaborador!.departamento,
        ativo: _colaborador!.ativo,
        primeiroAcesso: _colaborador!.primeiroAcesso,
        empresaId: _colaborador!.empresaId,
        metaDiaria: _colaborador!.metaDiaria,
        metaDiariaDefinida: _colaborador!.metaDiariaDefinida,
        corMascote: color,
        fotoUrl: _colaborador!.fotoUrl,
        onboardingCompleto: _colaborador!.onboardingCompleto,
      );
      notifyListeners();
    } catch (e) {
      print('Erro ao atualizar cor do mascote: $e');
    }
  }

  Future<void> updateProfilePicture(String? url) async {
    if (_colaborador == null) return;
    try {
      if (_isMock) {
        final prefs = await SharedPreferences.getInstance();
        final mockSessionStr = prefs.getString('mock_colab_session');
        if (mockSessionStr != null) {
          final Map<String, dynamic> data = jsonDecode(mockSessionStr);
          data['foto_url'] = url;
          await prefs.setString('mock_colab_session', jsonEncode(data));
        }
        if (url != null) {
          await prefs.setString('mock_foto_url', url);
        } else {
          await prefs.remove('mock_foto_url');
        }
      } else {
        await _supabase
            .from('usuarios')
            .update({'foto_url': url})
            .eq('id', _colaborador!.id);
      }

      _colaborador = Colaborador(
        id: _colaborador!.id,
        nome: _colaborador!.nome,
        email: _colaborador!.email,
        cargo: _colaborador!.cargo,
        departamento: _colaborador!.departamento,
        ativo: _colaborador!.ativo,
        primeiroAcesso: _colaborador!.primeiroAcesso,
        empresaId: _colaborador!.empresaId,
        metaDiaria: _colaborador!.metaDiaria,
        metaDiariaDefinida: _colaborador!.metaDiariaDefinida,
        corMascote: _colaborador!.corMascote,
        fotoUrl: url,
        onboardingCompleto: _colaborador!.onboardingCompleto,
      );
      notifyListeners();
    } catch (e) {
      print('Erro ao atualizar foto de perfil: $e');
    }
  }

  Future<void> completeOnboardingTour() async {
    if (_colaborador == null) return;
    
    final updatedColab = Colaborador(
      id: _colaborador!.id,
      nome: _colaborador!.nome,
      email: _colaborador!.email,
      cargo: _colaborador!.cargo,
      departamento: _colaborador!.departamento,
      ativo: _colaborador!.ativo,
      primeiroAcesso: _colaborador!.primeiroAcesso,
      empresaId: _colaborador!.empresaId,
      metaDiaria: _colaborador!.metaDiaria,
      metaDiariaDefinida: _colaborador!.metaDiariaDefinida,
      corMascote: _colaborador!.corMascote,
      fotoUrl: _colaborador!.fotoUrl,
      onboardingCompleto: true,
    );
    
    _colaborador = updatedColab;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completo_${updatedColab.id}', true);
      
      final mockSessionStr = prefs.getString('mock_colab_session');
      if (mockSessionStr != null) {
        final Map<String, dynamic> data = jsonDecode(mockSessionStr);
        data['onboarding_completo'] = true;
        await prefs.setString('mock_colab_session', jsonEncode(data));
      }
    } catch (e) {
      print('Erro ao salvar onboarding localmente: $e');
    }

    if (!_isMock) {
      try {
        await _supabase
            .from('usuarios')
            .update({'onboarding_completo': true})
            .eq('id', updatedColab.id);
        print('Onboarding marcado como completo no Supabase.');
      } catch (e) {
        print('Erro ao salvar onboarding_completo direto no Supabase: $e');
      }
      
      try {
        final url = Uri.parse('http://localhost:8000/api/usuarios/${updatedColab.id}/onboarding');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'onboarding_completo': true}),
        ).timeout(const Duration(seconds: 4));
        print('Onboarding enviado para o backend FastAPI: ${response.statusCode}');
      } catch (e) {
        print('Erro ao enviar onboarding para o backend FastAPI: $e');
      }
    }
  }

  Future<void> signOut() async {
    _loading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mock_colab_session');

      if (!_isMock) {
        await _supabase.auth.signOut();
      }
    } catch (e) {
      print('Erro ao deslogar: $e');
    } finally {
      _session = null;
      _colaborador = null;
      _isMock = false;
      _loading = false;
      notifyListeners();
    }
  }
}
