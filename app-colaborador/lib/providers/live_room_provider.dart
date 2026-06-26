import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../components/sound_manager.dart';

enum LiveRoomStep { joinCode, lobby, question, showAnswer, podium }

class LiveRoomProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _baseUrl = 'http://localhost:8000'; // FastAPI backend

  // State variables
  LiveRoomStep _currentStep = LiveRoomStep.joinCode;
  Map<String, dynamic>? _room;
  Map<String, dynamic>? _participant;
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _participants = [];
  List<Map<String, dynamic>> _ranking = [];
  List<Map<String, dynamic>> _lastRanking = [];
  Map<String, dynamic>? _answerFeedback;

  int _currentQuestionIndex = 0;
  int _timeLeft = 30;
  Timer? _timer;
  Timer? _pollingTimer;
  bool _loading = false;
  String? _selectedAlternative;
  bool _answered = false;
  DateTime? _questionStartTime;
  String? _errorMsg;

  // Getters
  LiveRoomStep get currentStep => _currentStep;
  Map<String, dynamic>? get room => _room;
  Map<String, dynamic>? get participant => _participant;
  List<Map<String, dynamic>> get questions => _questions;
  List<Map<String, dynamic>> get participants => _participants;
  List<Map<String, dynamic>> get ranking => _ranking;
  Map<String, dynamic>? get answerFeedback => _answerFeedback;
  int get currentQuestionIndex => _currentQuestionIndex;
  int get timeLeft => _timeLeft;
  bool get loading => _loading;
  String? get selectedAlternative => _selectedAlternative;
  bool get answered => _answered;
  String? get errorMsg => _errorMsg;

  Map<String, dynamic>? get currentQuestion {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) {
      return null;
    }
    return _questions[_currentQuestionIndex];
  }

  // Action: Join room with 6-character code
  Future<bool> joinRoom(String code, String userId) async {
    _loading = true;
    _errorMsg = null;
    notifyListeners();

    final cleanCode = code.toUpperCase().trim();
    if (cleanCode.length != 6) {
      _errorMsg = 'O código deve ter 6 caracteres.';
      _loading = false;
      notifyListeners();
      return false;
    }

    try {
      final url = Uri.parse('$_baseUrl/api/sala/$cleanCode/entrar');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'usuario_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _room = data['sala'];
        _participant = data['participante'];
        
        // Fetch questions for this room
        await _fetchQuestions();
        
        _currentStep = LiveRoomStep.lobby;
        _startPolling();
        
        _loading = false;
        notifyListeners();
        return true;
      } else {
        final errBody = jsonDecode(utf8.decode(response.bodyBytes));
        _errorMsg = errBody['detail'] ?? 'Erro ao entrar na sala.';
      }
    } catch (e) {
      print('Erro ao entrar na sala: $e');
      _errorMsg = 'Erro ao conectar ao servidor.';
    }

    _loading = false;
    notifyListeners();
    return false;
  }

  // Action: Create room as collaborator
  Future<bool> createRoom(String userId, String empresaId, String origem, String? categoriaId, List<Map<String, dynamic>>? customQuestions) async {
    _loading = true;
    _errorMsg = null;
    notifyListeners();

    try {
      // 1. Criar sala
      final createUrl = Uri.parse('$_baseUrl/api/sala/criar');
      final createRes = await http.post(
        createUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'empresa_id': empresaId,
          'criado_por_usuario_id': userId,
          'tipo': 'colaborador',
          'origem_perguntas': origem,
          'categoria_id': categoriaId,
        }),
      );

      if (createRes.statusCode != 200) {
        final err = jsonDecode(utf8.decode(createRes.bodyBytes));
        _errorMsg = err['detail'] ?? 'Erro ao criar sala.';
        _loading = false;
        notifyListeners();
        return false;
      }

      final roomData = jsonDecode(utf8.decode(createRes.bodyBytes));
      _room = roomData;

      // 2. Adicionar perguntas
      final addUrl = Uri.parse('$_baseUrl/api/sala/${_room!['codigo']}/adicionar-perguntas');
      final addBody = <String, dynamic>{};
      if (origem == 'personalizada' && customQuestions != null) {
        addBody['perguntas'] = customQuestions;
      }

      final addRes = await http.post(
        addUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(addBody),
      );

      if (addRes.statusCode != 200) {
        final err = jsonDecode(utf8.decode(addRes.bodyBytes));
        _errorMsg = err['detail'] ?? 'Erro ao configurar perguntas.';
        _loading = false;
        notifyListeners();
        return false;
      }

      final questionsData = jsonDecode(utf8.decode(addRes.bodyBytes));
      _questions = List<Map<String, dynamic>>.from(questionsData['perguntas']);

      // 3. Entrar na própria sala
      return await joinRoom(_room!['codigo'], userId);
    } catch (e) {
      print('Erro ao criar sala: $e');
      _errorMsg = 'Erro de rede ao criar sala.';
    }

    _loading = false;
    notifyListeners();
    return false;
  }

  // Start room from mobile (if collaborator is the creator)
  Future<void> startRoom() async {
    if (_room == null) return;
    try {
      final url = Uri.parse('$_baseUrl/api/sala/${_room!['codigo']}/iniciar');
      await http.post(url);
    } catch (e) {
      print('Erro ao iniciar sala: $e');
    }
  }

  // Submit Answer (with Kahoot style speed tracking)
  Future<void> submitAnswer(String alternative) async {
    if (_answered || _room == null || currentQuestion == null) return;

    _selectedAlternative = alternative;
    _answered = true;
    notifyListeners();

    final timeSpentMs = DateTime.now().difference(_questionStartTime!).inMilliseconds;

    try {
      final code = _room!['codigo'];
      final url = Uri.parse('$_baseUrl/api/sala/$code/responder');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario_id': _participant!['usuario_id'],
          'pergunta_id': currentQuestion!['id'],
          'alternativa_escolhida': alternative,
          'tempo_resposta_ms': timeSpentMs,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _answerFeedback = data;
        
        if (data['correta'] == true) {
          SoundManager.playSuccess();
        } else {
          SoundManager.playError();
        }
        notifyListeners();
      }
    } catch (e) {
      print('Erro ao enviar resposta: $e');
    }
  }

  // Next question coordination (if creator is collaborator)
  Future<void> nextQuestion() async {
    if (_room == null) return;
    try {
      final url = Uri.parse('$_baseUrl/api/sala/${_room!['codigo']}/proxima-pergunta');
      await http.post(url);
    } catch (e) {
      print('Erro ao avançar pergunta: $e');
    }
  }

  // Finalize room coordination (if creator is collaborator)
  Future<void> finalizeRoom() async {
    if (_room == null) return;
    try {
      final url = Uri.parse('$_baseUrl/api/sala/${_room!['codigo']}/finalizar');
      await http.post(url);
    } catch (e) {
      print('Erro ao finalizar sala: $e');
    }
  }

  // Leave room & clear state
  void leaveRoom() {
    _pollingTimer?.cancel();
    _timer?.cancel();
    _room = null;
    _participant = null;
    _questions = [];
    _participants = [];
    _ranking = [];
    _lastRanking = [];
    _answerFeedback = null;
    _currentStep = LiveRoomStep.joinCode;
    notifyListeners();
  }

  // Fetch Questions
  Future<void> _fetchQuestions() async {
    if (_room == null) return;
    try {
      // Questions are returned as list inside rooms database or fallback
      // In the mock, salas_live_perguntas contains it
      final { data, error } = await _supabase
          .from('salas_live_perguntas')
          .select()
          .eq('sala_id', _room!['id'])
          .order('ordem');

      if (!error && data != null && data.isNotEmpty) {
        _questions = List<Map<String, dynamic>>.from(data);
      } else {
        // Fallback fetch from api stats endpoint
        final res = await http.get(Uri.parse('$_baseUrl/api/sala/${_room!['codigo']}/estatisticas'));
        if (res.statusCode == 200) {
          final statsList = jsonDecode(utf8.decode(res.bodyBytes));
          _questions = List<Map<String, dynamic>>.from(statsList.map((s) => {
            'id': s['pergunta_id'],
            'pergunta_texto': s['pergunta_texto'],
            'ordem': 1
          }));
        }
      }
    } catch (e) {
      print('Erro ao carregar perguntas: $e');
    }
  }

  // Fetch participants
  Future<void> _fetchParticipants() async {
    if (_room == null) return;
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/sala/${_room!['codigo']}/ranking'));
      if (res.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(utf8.decode(res.bodyBytes)));
        _participants = data;
        
        // Update ranking
        _lastRanking = List<Map<String, dynamic>>.from(_ranking);
        _ranking = data;
        
        // If we are showing answer/ranking, check if we climbed
        if (_currentStep == LiveRoomStep.showAnswer) {
          _checkIfClimbed();
        }
        notifyListeners();
      }
    } catch (e) {
      print('Erro ao carregar participantes: $e');
    }
  }

  // Check if current user climbed in the ranking list
  void _checkIfClimbed() {
    if (_lastRanking.isEmpty || _ranking.isEmpty || _participant == null) return;
    
    final userId = _participant!['usuario_id'];
    
    int oldPos = _lastRanking.indexWhere((x) => x['usuario_id'] == userId);
    int newPos = _ranking.indexWhere((x) => x['usuario_id'] == userId);
    
    if (oldPos != -1 && newPos != -1 && newPos < oldPos) {
      // Play climb rank sound!
      SoundManager.playFanfare();
    }
  }

  // Periodic polling coordination
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (_room == null) return;
      await _refreshRoomState();
    });
  }

  Future<void> _refreshRoomState() async {
    if (_room == null || _participant == null) return;
    try {
      final code = _room!['codigo'];
      final url = Uri.parse('$_baseUrl/api/sala/$code/entrar');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'usuario_id': _participant!['usuario_id']}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final updatedRoom = data['sala'];
        
        // Sync local room updates
        _onRoomUpdated(updatedRoom);
        
        // Fetch players list
        await _fetchParticipants();
      }
    } catch (e) {
      print('Erro ao atualizar estado da sala via polling: $e');
    }
  }

  // Handle updates in the room object (triggered via realtime or polling)
  void _onRoomUpdated(Map<String, dynamic> newRoom) {
    if (_room == null) return;
    
    final oldStatus = _room!['status'];
    final newStatus = newRoom['status'];
    final oldIdx = _room!['pergunta_atual_index'];
    final newIdx = newRoom['pergunta_atual_index'];

    _room = newRoom;

    // 1. Status Transition: awaiting -> em_andamento
    if (oldStatus == 'aguardando' && newStatus == 'em_andamento') {
      _currentQuestionIndex = 0;
      _currentStep = LiveRoomStep.question;
      _startQuestionTimer();
      notifyListeners();
    }
    
    // 2. Question advanced: manager clicked "Next Question"
    else if (newStatus == 'em_andamento' && newIdx > oldIdx) {
      _currentQuestionIndex = newIdx;
      _currentStep = LiveRoomStep.question;
      _startQuestionTimer();
      notifyListeners();
    }

    // 3. Status Transition: em_andamento -> finalizada
    else if (newStatus == 'finalizada' && oldStatus != 'finalizada') {
      _timer?.cancel();
      _pollingTimer?.cancel();
      _currentStep = LiveRoomStep.podium;
      notifyListeners();
    }
  }

  // Local Question timer
  void _startQuestionTimer() {
    _timer?.cancel();
    _timeLeft = 30;
    _selectedAlternative = null;
    _answered = false;
    _answerFeedback = null;
    _questionStartTime = DateTime.now();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 1) {
        _timeLeft--;
        notifyListeners();
      } else {
        _timer?.cancel();
        _timeLeft = 0;
        _currentStep = LiveRoomStep.showAnswer;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
