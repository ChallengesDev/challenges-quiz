import React, { useEffect, useState, useRef } from 'react';
import { supabase } from '../lib/supabase';
import { 
  Tv, 
  Users, 
  Play, 
  Plus, 
  Trash2, 
  ChevronRight, 
  Trophy, 
  Loader2, 
  HelpCircle, 
  Award, 
  TrendingUp, 
  Check, 
  X, 
  PieChart 
} from 'lucide-react';

const API_URL = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';

interface Category {
  id: string;
  nome: string;
  descricao?: string;
}

interface CustomQuestion {
  texto: string;
  alternativa_a: string;
  alternativa_b: string;
  alternativa_c: string;
  alternativa_d: string;
  resposta_correta: string;
  explicacao?: string;
}

interface Participant {
  usuario_id: string;
  nome: string;
  foto_url: string | null;
  pontuacao_total: number;
  posicao_final: number | null;
}

interface QuestionStat {
  pergunta_id: string;
  pergunta_texto: string;
  total_respostas: number;
  corretas: number;
  taxa_acerto: number;
  respostas_por_alternativa: {
    A: number;
    B: number;
    C: number;
    D: number;
  };
}

export const ModoSalaGestor: React.FC = () => {
  // Navigation & Step
  const [activeStep, setActiveStep] = useState<'config' | 'lobby' | 'game' | 'ended'>('config');
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  // Configuration State
  const [origemPerguntas, setOrigemPerguntas] = useState<'trilha' | 'banco_geral' | 'personalizada'>('banco_geral');
  const [categoriaId, setCategoriaId] = useState<string>('');
  const [categorias, setCategorias] = useState<Category[]>([]);
  const [customQuestions, setCustomQuestions] = useState<CustomQuestion[]>([
    {
      texto: 'Qual é o principal objetivo da LGPD?',
      alternativa_a: 'Garantir o lucro das grandes empresas de tecnologia',
      alternativa_b: 'Proteger os direitos fundamentais de liberdade e de privacidade dos cidadãos',
      alternativa_c: 'Centralizar todas as informações financeiras em um único órgão',
      alternativa_d: 'Fiscalizar o uso de redes sociais por menores de idade',
      resposta_correta: 'B',
      explicacao: 'A LGPD tem como objetivo principal proteger os dados de pessoas físicas, garantindo privacidade e liberdade.'
    }
  ]);

  // Live Room State
  const [sala, setSala] = useState<any>(null);
  const [perguntas, setPerguntas] = useState<any[]>([]);
  const [participantes, setParticipantes] = useState<Participant[]>([]);
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
  const [respostasCount, setRespostasCount] = useState(0);
  const [timeLeft, setTimeLeft] = useState(30);
  const [showRanking, setShowRanking] = useState(false);
  const [stats, setStats] = useState<QuestionStat[]>([]);

  const timerRef = useRef<NodeJS.Timeout | null>(null);

  // Load categories on start
  useEffect(() => {
    const fetchCategories = async () => {
      try {
        const { data, error } = await supabase.from('categorias').select('*').eq('ativo', true);
        if (error) throw error;
        setCategorias(data || []);
        if (data && data.length > 0) {
          setCategoriaId(data[0].id);
        }
      } catch (err) {
        console.error('Erro ao carregar categorias:', err);
      }
    };
    fetchCategories();
  }, []);

  // Poll for room updates & participants
  useEffect(() => {
    if (!sala || activeStep === 'config' || activeStep === 'ended') return;

    // Load participants first
    fetchParticipants();

    // Set up polling interval to fetch participants & answers
    const interval = setInterval(() => {
      fetchParticipants();
      if (activeStep === 'game') {
        fetchRespostasCount();
      }
    }, 2000);

    // Setup Supabase Realtime channel if available
    const channel = supabase.channel(`room_${sala.id}`)
      .on('postgres_changes', { 
        event: '*', 
        schema: 'public', 
        table: 'salas_live_participantes', 
        filter: `sala_id=eq.${sala.id}` 
      }, () => {
        fetchParticipants();
      })
      .subscribe();

    return () => {
      clearInterval(interval);
      supabase.removeChannel(channel);
    };
  }, [sala, activeStep, currentQuestionIndex]);

  // Question countdown timer
  useEffect(() => {
    if (activeStep !== 'game' || showRanking) {
      if (timerRef.current) clearInterval(timerRef.current);
      return;
    }

    setTimeLeft(30);
    timerRef.current = setInterval(() => {
      setTimeLeft((prev) => {
        if (prev <= 1) {
          clearInterval(timerRef.current!);
          // Timer finished, show correct answer & ranking
          setShowRanking(true);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [activeStep, currentQuestionIndex, showRanking]);

  // Helper actions
  const fetchParticipants = async () => {
    if (!sala) return;
    try {
      const res = await fetch(`${API_URL}/api/sala/${sala.codigo}/ranking`);
      if (res.ok) {
        const data = await res.json();
        setParticipantes(data);
      }
    } catch (err) {
      console.error('Erro ao buscar participantes:', err);
    }
  };

  const fetchRespostasCount = async () => {
    if (!sala || perguntas.length === 0) return;
    const currentQ = perguntas[currentQuestionIndex];
    if (!currentQ) return;
    try {
      const { count, error } = await supabase
        .from('salas_live_respostas')
        .select('*', { count: 'exact', head: true })
        .eq('pergunta_id', currentQ.id);

      if (!error && count !== null) {
        setRespostasCount(count);
        // If everyone answered, stop timer & show answer
        if (participantes.length > 0 && count >= participantes.length) {
          setShowRanking(true);
        }
      } else {
        // Fallback check on memory fallback database
        const statsRes = await fetch(`${API_URL}/api/sala/${sala.codigo}/estatisticas`);
        if (statsRes.ok) {
          const statsData = await statsRes.json();
          const curStat = statsData.find((s: any) => s.pergunta_id === currentQ.id);
          if (curStat) {
            setRespostasCount(curStat.total_respostas);
            if (participantes.length > 0 && curStat.total_respostas >= participantes.length) {
              setShowRanking(true);
            }
          }
        }
      }
    } catch (err) {
      console.error('Erro ao contar respostas:', err);
    }
  };

  const addCustomQuestion = () => {
    setCustomQuestions([
      ...customQuestions,
      {
        texto: '',
        alternativa_a: '',
        alternativa_b: '',
        alternativa_c: '',
        alternativa_d: '',
        resposta_correta: 'A',
        explicacao: ''
      }
    ]);
  };

  const removeCustomQuestion = (index: number) => {
    if (customQuestions.length <= 1) return;
    setCustomQuestions(customQuestions.filter((_, i) => i !== index));
  };

  const updateCustomQuestion = (index: number, field: keyof CustomQuestion, value: string) => {
    const updated = [...customQuestions];
    updated[index] = { ...updated[index], [field]: value };
    setCustomQuestions(updated);
  };

  const handleCreateRoom = async () => {
    setLoading(true);
    setErrorMsg(null);
    try {
      const userId = (await supabase.auth.getUser()).data.user?.id || 'mock-gestor-id';
      const companyId = 'mock-company-123'; // fallback company

      // 1. Create Room
      const createRes = await fetch(`${API_URL}/api/sala/criar`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          empresa_id: companyId,
          criado_por_usuario_id: userId,
          tipo: 'gestor',
          origem_perguntas: origemPerguntas,
          categoria_id: origemPerguntas === 'trilha' ? categoriaId : null
        })
      });

      if (!createRes.ok) {
        throw new Error('Falha ao criar sala.');
      }
      const roomData = await createRes.json();

      // 2. Add Questions
      const questionsBody: any = {};
      if (origemPerguntas === 'personalizada') {
        // Validate custom questions
        for (const q of customQuestions) {
          if (!q.texto || !q.alternativa_a || !q.alternativa_b || !q.alternativa_c || !q.alternativa_d) {
            throw new Error('Preencha todas as perguntas e alternativas customizadas.');
          }
        }
        questionsBody.perguntas = customQuestions;
      }

      const addQuestionsRes = await fetch(`${API_URL}/api/sala/${roomData.codigo}/adicionar-perguntas`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(questionsBody)
      });

      if (!addQuestionsRes.ok) {
        throw new Error('Falha ao associar perguntas à sala.');
      }
      const questionsData = await addQuestionsRes.json();

      setSala(roomData);
      setPerguntas(questionsData.perguntas);
      setParticipantes([]);
      setCurrentQuestionIndex(0);
      setActiveStep('lobby');
    } catch (err: any) {
      console.error(err);
      setErrorMsg(err.message || 'Ocorreu um erro ao criar a sala.');
    } finally {
      setLoading(false);
    }
  };

  const handleStartSession = async () => {
    if (!sala) return;
    setLoading(true);
    try {
      const res = await fetch(`${API_URL}/api/sala/${sala.codigo}/iniciar`, {
        method: 'POST'
      });
      if (res.ok) {
        const updated = await res.json();
        setSala(updated);
        setActiveStep('game');
        setShowRanking(false);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleNextQuestion = async () => {
    if (!sala) return;
    setLoading(true);
    try {
      const nextRes = await fetch(`${API_URL}/api/sala/${sala.codigo}/proxima-pergunta`, {
        method: 'POST'
      });
      if (nextRes.ok) {
        const updatedRoom = await nextRes.json();
        setSala(updatedRoom);
        setCurrentQuestionIndex(updatedRoom.pergunta_atual_index);
        setRespostasCount(0);
        setShowRanking(false);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleEndQuiz = async () => {
    if (!sala) return;
    setLoading(true);
    try {
      // 1. Finalize Room
      const res = await fetch(`${API_URL}/api/sala/${sala.codigo}/finalizar`, {
        method: 'POST'
      });
      if (res.ok) {
        const data = await res.json();
        setSala(data.sala);
        setParticipantes(data.participantes);
        
        // 2. Fetch stats
        const statsRes = await fetch(`${API_URL}/api/sala/${sala.codigo}/estatisticas`);
        if (statsRes.ok) {
          const statsData = await statsRes.json();
          setStats(statsData);
        }
        
        setActiveStep('ended');
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="page-container animate-fade-in" style={{ maxWidth: '1200px' }}>
      
      {/* 1. STEP CONFIGURATION */}
      {activeStep === 'config' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h2 style={{ fontFamily: 'var(--font-heading)', fontSize: '24px', fontWeight: 700 }}>
                Modo Sala ao Vivo (Multiplayer)
              </h2>
              <p style={{ color: 'var(--text-muted)', fontSize: '14px', marginTop: '4px' }}>
                Crie uma sessão de quiz competitiva em tempo real estilo Kahoot para seus colaboradores.
              </p>
            </div>
            <Tv size={40} color="var(--color-primary)" />
          </div>

          {errorMsg && (
            <div style={{
              background: 'rgba(239, 68, 68, 0.1)',
              border: '1px solid var(--status-error)',
              color: 'var(--status-error)',
              padding: '16px',
              borderRadius: 'var(--radius-sm)',
              fontSize: '14px'
            }}>
              {errorMsg}
            </div>
          )}

          <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <h3 style={{ fontSize: '18px', fontWeight: 600, color: 'var(--text-main)', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px' }}>
              Configuração da Sessão
            </h3>

            {/* Origem das Perguntas */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <label style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-muted)' }}>
                Origem das Perguntas
              </label>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '16px' }}>
                <button
                  type="button"
                  onClick={() => setOrigemPerguntas('banco_geral')}
                  style={{
                    padding: '16px',
                    borderRadius: 'var(--radius-md)',
                    border: origemPerguntas === 'banco_geral' ? '2px solid var(--color-primary)' : '1px solid var(--border-color)',
                    background: origemPerguntas === 'banco_geral' ? 'rgba(99, 102, 241, 0.1)' : 'transparent',
                    color: 'var(--text-main)',
                    fontWeight: 600,
                    cursor: 'pointer',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    gap: '8px',
                    textAlign: 'center',
                    transition: 'all 0.2s'
                  }}
                >
                  <HelpCircle size={24} color={origemPerguntas === 'banco_geral' ? 'var(--color-primary)' : 'var(--text-muted)'} />
                  Banco Geral
                  <span style={{ fontSize: '11px', fontWeight: 400, color: 'var(--text-muted)' }}>
                    Perguntas aleatórias de segurança e tecnologia
                  </span>
                </button>

                <button
                  type="button"
                  onClick={() => setOrigemPerguntas('trilha')}
                  style={{
                    padding: '16px',
                    borderRadius: 'var(--radius-md)',
                    border: origemPerguntas === 'trilha' ? '2px solid var(--color-primary)' : '1px solid var(--border-color)',
                    background: origemPerguntas === 'trilha' ? 'rgba(99, 102, 241, 0.1)' : 'transparent',
                    color: 'var(--text-main)',
                    fontWeight: 600,
                    cursor: 'pointer',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    gap: '8px',
                    textAlign: 'center',
                    transition: 'all 0.2s'
                  }}
                >
                  <TrendingUp size={24} color={origemPerguntas === 'trilha' ? 'var(--color-primary)' : 'var(--text-muted)'} />
                  Trilha Existente
                  <span style={{ fontSize: '11px', fontWeight: 400, color: 'var(--text-muted)' }}>
                    Carregar perguntas de uma das categorias da empresa
                  </span>
                </button>

                <button
                  type="button"
                  onClick={() => setOrigemPerguntas('personalizada')}
                  style={{
                    padding: '16px',
                    borderRadius: 'var(--radius-md)',
                    border: origemPerguntas === 'personalizada' ? '2px solid var(--color-primary)' : '1px solid var(--border-color)',
                    background: origemPerguntas === 'personalizada' ? 'rgba(99, 102, 241, 0.1)' : 'transparent',
                    color: 'var(--text-main)',
                    fontWeight: 600,
                    cursor: 'pointer',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    gap: '8px',
                    textAlign: 'center',
                    transition: 'all 0.2s'
                  }}
                >
                  <Plus size={24} color={origemPerguntas === 'personalizada' ? 'var(--color-primary)' : 'var(--text-muted)'} />
                  Perguntas Personalizadas
                  <span style={{ fontSize: '11px', fontWeight: 400, color: 'var(--text-muted)' }}>
                    Escreva perguntas personalizadas exclusivas para esta sala
                  </span>
                </button>
              </div>
            </div>

            {/* Trilha/Categoria Selector */}
            {origemPerguntas === 'trilha' && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', animation: 'fadeIn 0.2s ease' }}>
                <label style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-muted)' }}>
                  Selecione a Categoria da Trilha
                </label>
                <select
                  value={categoriaId}
                  onChange={(e) => setCategoriaId(e.target.value)}
                  style={{ maxWith: '400px' }}
                >
                  {categorias.map((c) => (
                    <option key={c.id} value={c.id}>{c.nome}</option>
                  ))}
                </select>
              </div>
            )}

            {/* Custom Questions List Builder */}
            {origemPerguntas === 'personalizada' && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', animation: 'fadeIn 0.2s ease' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--border-color)', paddingTop: '16px' }}>
                  <h4 style={{ fontWeight: 600, fontSize: '15px' }}>Perguntas Customizadas</h4>
                  <button
                    onClick={addCustomQuestion}
                    className="btn btn-secondary"
                    style={{ padding: '6px 12px', fontSize: '12px' }}
                  >
                    <Plus size={14} /> Adicionar Pergunta
                  </button>
                </div>

                {customQuestions.map((q, idx) => (
                  <div key={idx} style={{
                    border: '1px solid var(--border-color)',
                    borderRadius: 'var(--radius-md)',
                    padding: '16px',
                    background: 'rgba(15, 19, 34, 0.4)',
                    display: 'flex',
                    flexDirection: 'column',
                    gap: '12px'
                  }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span style={{ fontWeight: 700, fontSize: '14px', color: 'var(--color-primary)' }}>
                        Pergunta #{idx + 1}
                      </span>
                      {customQuestions.length > 1 && (
                        <button
                          onClick={() => removeCustomQuestion(idx)}
                          style={{ background: 'transparent', border: 'none', color: 'var(--status-error)', cursor: 'pointer' }}
                        >
                          <Trash2 size={16} />
                        </button>
                      )}
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                      <label style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Texto da Pergunta</label>
                      <input
                        type="text"
                        placeholder="Ex: Qual é a definição de um vírus Ransomware?"
                        value={q.texto}
                        onChange={(e) => updateCustomQuestion(idx, 'texto', e.target.value)}
                        className="input"
                      />
                    </div>

                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                      <div>
                        <label style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Alternativa A</label>
                        <input
                          type="text"
                          value={q.alternativa_a}
                          onChange={(e) => updateCustomQuestion(idx, 'alternativa_a', e.target.value)}
                          className="input"
                        />
                      </div>
                      <div>
                        <label style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Alternativa B</label>
                        <input
                          type="text"
                          value={q.alternativa_b}
                          onChange={(e) => updateCustomQuestion(idx, 'alternativa_b', e.target.value)}
                          className="input"
                        />
                      </div>
                      <div>
                        <label style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Alternativa C</label>
                        <input
                          type="text"
                          value={q.alternativa_c}
                          onChange={(e) => updateCustomQuestion(idx, 'alternativa_c', e.target.value)}
                          className="input"
                        />
                      </div>
                      <div>
                        <label style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Alternativa D</label>
                        <input
                          type="text"
                          value={q.alternativa_d}
                          onChange={(e) => updateCustomQuestion(idx, 'alternativa_d', e.target.value)}
                          className="input"
                        />
                      </div>
                    </div>

                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                      <div>
                        <label style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Alternativa Correta</label>
                        <select
                          value={q.resposta_correta}
                          onChange={(e) => updateCustomQuestion(idx, 'resposta_correta', e.target.value)}
                        >
                          <option value="A">A</option>
                          <option value="B">B</option>
                          <option value="C">C</option>
                          <option value="D">D</option>
                        </select>
                      </div>
                      <div>
                        <label style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Explicação (Opcional)</label>
                        <input
                          type="text"
                          value={q.explicacao || ''}
                          onChange={(e) => updateCustomQuestion(idx, 'explicacao', e.target.value)}
                          className="input"
                        />
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}

            {/* Create Room Button */}
            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '12px' }}>
              <button
                onClick={handleCreateRoom}
                disabled={loading}
                className="btn btn-primary"
                style={{ padding: '12px 24px', fontWeight: 600 }}
              >
                {loading ? <Loader2 size={16} className="animate-spin" /> : <Tv size={16} />}
                Criar Sala ao Vivo
              </button>
            </div>

          </div>
        </div>
      )}

      {/* 2. LOBBY WAITING ROOM */}
      {activeStep === 'lobby' && sala && (
        <div style={{ display: 'grid', gridTemplateColumns: '3fr 1.5fr', gap: '24px' }} className="animate-fade-in">
          
          {/* Main Info Board */}
          <div className="card" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: '400px', textAlign: 'center', gap: '24px' }}>
            <span className="badge badge-info" style={{ padding: '6px 12px' }}>Aguardando Jogadores</span>
            
            <div>
              <p style={{ color: 'var(--text-muted)', fontSize: '16px' }}>Código da Sala para projetar:</p>
              <h1 style={{
                fontFamily: 'monospace',
                fontSize: '72px',
                fontWeight: 800,
                color: 'var(--color-cyan)',
                letterSpacing: '8px',
                margin: '12px 0',
                background: 'rgba(6, 182, 212, 0.05)',
                border: '2px dashed var(--color-cyan)',
                borderRadius: 'var(--radius-md)',
                padding: '16px 32px',
                boxShadow: '0 0 30px rgba(6, 182, 212, 0.1)'
              }}>
                {sala.codigo}
              </h1>
            </div>

            <div style={{ maxWidth: '400px' }}>
              <p style={{ fontSize: '15px', color: 'var(--text-main)' }}>
                Peça aos colaboradores para acessarem o <b>Modo Sala</b> no app e digitarem o código acima para competir.
              </p>
            </div>

            <button
              onClick={handleStartSession}
              disabled={loading || participantes.length === 0}
              className="btn btn-primary"
              style={{ padding: '14px 28px', fontSize: '16px', fontWeight: 700 }}
            >
              <Play size={18} /> Iniciar Sessão ({participantes.length} na sala)
            </button>
            
            {participantes.length === 0 && (
              <span style={{ fontSize: '12px', color: 'var(--status-warning)' }}>
                Aguardando a entrada de pelo menos 1 participante para iniciar.
              </span>
            )}
          </div>

          {/* Participant list card */}
          <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <h4 style={{ fontWeight: 600, fontSize: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Users size={18} color="var(--color-primary)" />
              Participantes ({participantes.length})
            </h4>
            
            <div style={{
              display: 'flex',
              flexDirection: 'column',
              gap: '8px',
              overflowY: 'auto',
              maxHeight: '350px',
              paddingRight: '4px'
            }}>
              {participantes.length === 0 ? (
                <div style={{ color: 'var(--text-muted)', fontSize: '13px', textAlign: 'center', padding: '32px 0' }}>
                  Nenhum colaborador entrou ainda...
                </div>
              ) : (
                participantes.map((p) => (
                  <div key={p.usuario_id} style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '12px',
                    padding: '10px 12px',
                    background: 'rgba(255, 255, 255, 0.03)',
                    border: '1px solid var(--border-color)',
                    borderRadius: 'var(--radius-sm)',
                    animation: 'fadeIn 0.2s ease'
                  }}>
                    <div style={{
                      width: '32px',
                      height: '32px',
                      borderRadius: '50%',
                      background: 'linear-gradient(135deg, var(--color-primary), var(--color-accent))',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '14px',
                      fontWeight: 600,
                      color: '#fff',
                      overflow: 'hidden'
                    }}>
                      {p.foto_url ? <img src={p.foto_url} alt={p.nome} style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : p.nome.substring(0, 2).toUpperCase()}
                    </div>
                    <span style={{ fontWeight: 500, fontSize: '14px', color: 'var(--text-main)' }}>
                      {p.nome}
                    </span>
                  </div>
                ))
              )}
            </div>
          </div>

        </div>
      )}

      {/* 3. GAME RUNNING VIEW */}
      {activeStep === 'game' && perguntas.length > 0 && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }} className="animate-fade-in">
          
          {/* Header Info */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '14px', color: 'var(--text-muted)', fontWeight: 600 }}>
              PERGUNTA {currentQuestionIndex + 1} DE {perguntas.length}
            </span>
            <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
              <span className="badge badge-info" style={{ fontSize: '12px', padding: '6px 12px', fontFamily: 'monospace' }}>
                CÓDIGO: {sala.codigo}
              </span>
              <span style={{ fontSize: '14px', color: 'var(--text-muted)' }}>
                Participantes: <b>{participantes.length}</b>
              </span>
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '3.2fr 1.3fr', gap: '24px' }}>
            
            {/* Left: Question area */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
              
              {/* The big question box */}
              <div className="card" style={{
                textAlign: 'center',
                padding: '40px',
                background: 'linear-gradient(135deg, rgba(21, 28, 44, 0.9), rgba(15, 19, 34, 0.9))',
                border: '2px solid rgba(99, 102, 241, 0.3)',
                boxShadow: '0 8px 32px 0 rgba(0, 0, 0, 0.37)'
              }}>
                <h2 style={{ fontSize: '24px', fontWeight: 700, fontFamily: 'var(--font-heading)', color: 'var(--text-main)', lineHeight: '1.4' }}>
                  {perguntas[currentQuestionIndex].pergunta_texto}
                </h2>
              </div>

              {/* Alternatives grid */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div style={{
                  padding: '20px',
                  background: showRanking && perguntas[currentQuestionIndex].resposta_correta === 'A' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(21, 28, 44, 0.6)',
                  border: showRanking && perguntas[currentQuestionIndex].resposta_correta === 'A' ? '2px solid var(--status-success)' : '1px solid var(--border-color)',
                  borderRadius: 'var(--radius-md)',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '16px'
                }}>
                  <span style={{
                    width: '32px',
                    height: '32px',
                    borderRadius: 'var(--radius-sm)',
                    background: 'rgba(239, 68, 68, 0.15)',
                    color: '#ef4444',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontWeight: 800
                  }}>A</span>
                  <span style={{ fontSize: '15px', color: 'var(--text-main)' }}>{perguntas[currentQuestionIndex].alternativa_a}</span>
                </div>

                <div style={{
                  padding: '20px',
                  background: showRanking && perguntas[currentQuestionIndex].resposta_correta === 'B' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(21, 28, 44, 0.6)',
                  border: showRanking && perguntas[currentQuestionIndex].resposta_correta === 'B' ? '2px solid var(--status-success)' : '1px solid var(--border-color)',
                  borderRadius: 'var(--radius-md)',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '16px'
                }}>
                  <span style={{
                    width: '32px',
                    height: '32px',
                    borderRadius: 'var(--radius-sm)',
                    background: 'rgba(59, 130, 246, 0.15)',
                    color: '#3b82f6',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontWeight: 800
                  }}>B</span>
                  <span style={{ fontSize: '15px', color: 'var(--text-main)' }}>{perguntas[currentQuestionIndex].alternativa_b}</span>
                </div>

                <div style={{
                  padding: '20px',
                  background: showRanking && perguntas[currentQuestionIndex].resposta_correta === 'C' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(21, 28, 44, 0.6)',
                  border: showRanking && perguntas[currentQuestionIndex].resposta_correta === 'C' ? '2px solid var(--status-success)' : '1px solid var(--border-color)',
                  borderRadius: 'var(--radius-md)',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '16px'
                }}>
                  <span style={{
                    width: '32px',
                    height: '32px',
                    borderRadius: 'var(--radius-sm)',
                    background: 'rgba(245, 158, 11, 0.15)',
                    color: '#f59e0b',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontWeight: 800
                  }}>C</span>
                  <span style={{ fontSize: '15px', color: 'var(--text-main)' }}>{perguntas[currentQuestionIndex].alternativa_c}</span>
                </div>

                <div style={{
                  padding: '20px',
                  background: showRanking && perguntas[currentQuestionIndex].resposta_correta === 'D' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(21, 28, 44, 0.6)',
                  border: showRanking && perguntas[currentQuestionIndex].resposta_correta === 'D' ? '2px solid var(--status-success)' : '1px solid var(--border-color)',
                  borderRadius: 'var(--radius-md)',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '16px'
                }}>
                  <span style={{
                    width: '32px',
                    height: '32px',
                    borderRadius: 'var(--radius-sm)',
                    background: 'rgba(16, 185, 129, 0.15)',
                    color: '#10b981',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontWeight: 800
                  }}>D</span>
                  <span style={{ fontSize: '15px', color: 'var(--text-main)' }}>{perguntas[currentQuestionIndex].alternativa_d}</span>
                </div>
              </div>

              {/* Explanation block if revealed */}
              {showRanking && perguntas[currentQuestionIndex].explicacao && (
                <div style={{
                  padding: '16px',
                  background: 'rgba(99, 102, 241, 0.05)',
                  borderLeft: '4px solid var(--color-primary)',
                  borderRadius: 'var(--radius-sm)',
                  fontSize: '14px',
                  color: 'var(--text-muted)',
                  animation: 'fadeIn 0.3s ease'
                }}>
                  <b>Explicação:</b> {perguntas[currentQuestionIndex].explicacao}
                </div>
              )}

            </div>

            {/* Right: Timer & Responses count */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
              
              {/* Circular Timer Visual */}
              <div className="card" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '32px', textAlign: 'center', gap: '16px' }}>
                <h4 style={{ fontSize: '13px', textTransform: 'uppercase', color: 'var(--text-muted)', letterSpacing: '0.05em' }}>Tempo Restante</h4>
                
                <div style={{
                  width: '100px',
                  height: '100px',
                  borderRadius: '50%',
                  border: `4px solid ${timeLeft <= 5 ? 'var(--status-error)' : 'var(--color-primary)'}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '32px',
                  fontWeight: 800,
                  color: timeLeft <= 5 ? 'var(--status-error)' : 'var(--text-main)',
                  transition: 'all 0.3s ease',
                  boxShadow: `0 0 20px ${timeLeft <= 5 ? 'rgba(239, 68, 68, 0.2)' : 'rgba(99, 102, 241, 0.2)'}`
                }}>
                  {timeLeft}s
                </div>

                <div style={{ borderTop: '1px solid var(--border-color)', width: '100%', paddingTop: '16px', marginTop: '8px' }}>
                  <p style={{ fontSize: '24px', fontWeight: 800, color: 'var(--color-cyan)' }}>
                    {respostasCount} / {participantes.length}
                  </p>
                  <p style={{ fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', marginTop: '2px' }}>
                    Respostas Recebidas
                  </p>
                </div>

                {!showRanking && (
                  <button
                    onClick={() => setShowRanking(true)}
                    className="btn btn-secondary"
                    style={{ width: '100%', fontSize: '13px' }}
                  >
                    Encerrar Tempo
                  </button>
                )}
              </div>

              {/* Action buttons (Next Question / Finish Room) */}
              {showRanking && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  {currentQuestionIndex < perguntas.length - 1 ? (
                    <button
                      onClick={handleNextQuestion}
                      disabled={loading}
                      className="btn btn-primary"
                      style={{ width: '100%', padding: '14px', fontSize: '15px', fontWeight: 600 }}
                    >
                      Próxima Pergunta <ChevronRight size={16} />
                    </button>
                  ) : (
                    <button
                      onClick={handleEndQuiz}
                      disabled={loading}
                      className="btn btn-danger"
                      style={{ width: '100%', padding: '14px', fontSize: '15px', fontWeight: 600 }}
                    >
                      <Trophy size={16} /> Finalizar Sessão e Ver Pódio
                    </button>
                  )}
                </div>
              )}

            </div>

          </div>

          {/* Partial ranking display during questions interval */}
          {showRanking && (
            <div className="card animate-fade-in" style={{ marginTop: '12px' }}>
              <h3 style={{ fontSize: '16px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px' }}>
                <Award size={18} color="var(--color-accent)" />
                Leaderboard Parcial (Top 5)
              </h3>
              
              <div className="table-container">
                <table className="table">
                  <thead>
                    <tr>
                      <th style={{ width: '80px' }}>Rank</th>
                      <th>Colaborador</th>
                      <th style={{ textAlign: 'right' }}>Pontuação Acumulada</th>
                    </tr>
                  </thead>
                  <tbody>
                    {participantes.slice(0, 5).map((p, idx) => (
                      <tr key={p.usuario_id}>
                        <td style={{ fontWeight: 700, color: idx === 0 ? 'var(--status-warning)' : 'var(--text-main)' }}>
                          #{idx + 1}
                        </td>
                        <td style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                          <div style={{ width: '28px', height: '28px', borderRadius: '50%', background: 'var(--color-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px', color: '#fff', overflow: 'hidden' }}>
                            {p.foto_url ? <img src={p.foto_url} alt={p.nome} style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : p.nome.substring(0, 2).toUpperCase()}
                          </div>
                          <span style={{ fontWeight: 500 }}>{p.nome}</span>
                        </td>
                        <td style={{ textAlign: 'right', fontWeight: 700, color: 'var(--color-cyan)' }}>
                          {p.pontuacao_total} pts
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

        </div>
      )}

      {/* 4. FINAL RESULTS & PODIUM SCREEN */}
      {activeStep === 'ended' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '32px' }} className="animate-fade-in">
          
          {/* Section title */}
          <div style={{ textAlign: 'center' }}>
            <span className="badge badge-success" style={{ padding: '6px 12px', marginBottom: '8px' }}>Sessão Finalizada</span>
            <h2 style={{ fontSize: '32px', fontFamily: 'var(--font-heading)', fontWeight: 800 }}>
              Grande Pódio do Modo Sala!
            </h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '14px', marginTop: '4px' }}>
              Parabéns a todos os participantes pela velocidade e acerto nas respostas.
            </p>
          </div>

          {/* Graphical podium */}
          <div style={{
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'flex-end',
            minHeight: '260px',
            gap: '24px',
            margin: '24px 0',
            paddingBottom: '16px',
            borderBottom: '1px solid var(--border-color)'
          }}>
            {/* 2nd Place */}
            {participantes.length > 1 && (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', width: '150px' }}>
                <div style={{ width: '48px', height: '48px', borderRadius: '50%', background: 'silver', border: '2px solid white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, color: 'black', overflow: 'hidden' }}>
                  {participantes[1].foto_url ? <img src={participantes[1].foto_url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : '2º'}
                </div>
                <div style={{ fontWeight: 600, fontSize: '14px', marginTop: '8px', color: 'var(--text-main)', textAlign: 'center', textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap', width: '100%' }}>
                  {participantes[1].nome}
                </div>
                <div style={{ color: 'var(--color-cyan)', fontSize: '13px', fontWeight: 600 }}>{participantes[1].pontuacao_total} pts</div>
                <div style={{
                  height: '110px',
                  background: 'linear-gradient(to top, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.15))',
                  border: '1px solid var(--border-color)',
                  width: '100%',
                  borderRadius: 'var(--radius-sm) var(--radius-sm) 0 0',
                  marginTop: '12px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '24px',
                  fontWeight: 800,
                  color: 'silver'
                }}>2</div>
              </div>
            )}

            {/* 1st Place */}
            {participantes.length > 0 && (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', width: '180px' }}>
                <div style={{ width: '64px', height: '64px', borderRadius: '50%', background: 'gold', border: '3px solid white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, color: 'black', overflow: 'hidden', boxShadow: '0 0 20px rgba(253, 224, 71, 0.5)' }}>
                  {participantes[0].foto_url ? <img src={participantes[0].foto_url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : '1º'}
                </div>
                <div style={{ fontWeight: 700, fontSize: '16px', marginTop: '8px', color: 'var(--text-main)', textAlign: 'center', textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap', width: '100%' }}>
                  {participantes[0].nome}
                </div>
                <div style={{ color: 'var(--status-warning)', fontSize: '15px', fontWeight: 700 }}>{participantes[0].pontuacao_total} pts</div>
                <div style={{
                  height: '150px',
                  background: 'linear-gradient(to top, rgba(99, 102, 241, 0.1), rgba(99, 102, 241, 0.3))',
                  border: '1px solid rgba(99, 102, 241, 0.4)',
                  width: '100%',
                  borderRadius: 'var(--radius-sm) var(--radius-sm) 0 0',
                  marginTop: '12px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '36px',
                  fontWeight: 800,
                  color: 'gold',
                  boxShadow: '0 0 15px rgba(99, 102, 241, 0.1)'
                }}>1</div>
              </div>
            )}

            {/* 3rd Place */}
            {participantes.length > 2 && (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', width: '150px' }}>
                <div style={{ width: '48px', height: '48px', borderRadius: '50%', background: '#cd7f32', border: '2px solid white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, color: 'black', overflow: 'hidden' }}>
                  {participantes[2].foto_url ? <img src={participantes[2].foto_url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : '3º'}
                </div>
                <div style={{ fontWeight: 600, fontSize: '14px', marginTop: '8px', color: 'var(--text-main)', textAlign: 'center', textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap', width: '100%' }}>
                  {participantes[2].nome}
                </div>
                <div style={{ color: 'var(--color-cyan)', fontSize: '13px', fontWeight: 600 }}>{participantes[2].pontuacao_total} pts</div>
                <div style={{
                  height: '80px',
                  background: 'linear-gradient(to top, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.15))',
                  border: '1px solid var(--border-color)',
                  width: '100%',
                  borderRadius: 'var(--radius-sm) var(--radius-sm) 0 0',
                  marginTop: '12px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '20px',
                  fontWeight: 800,
                  color: '#cd7f32'
                }}>3</div>
              </div>
            )}
          </div>

          {/* Grid: Full Leaderboard & Questions performance statistics */}
          <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1.8fr', gap: '24px' }}>
            
            {/* Full leaderboard */}
            <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <h3 style={{ fontSize: '16px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Trophy size={18} color="var(--status-warning)" />
                Classificação Completa
              </h3>

              <div className="table-container">
                <table className="table">
                  <thead>
                    <tr>
                      <th style={{ width: '60px' }}>Pos</th>
                      <th>Colaborador</th>
                      <th style={{ textAlign: 'right' }}>Total</th>
                    </tr>
                  </thead>
                  <tbody>
                    {participantes.map((p, idx) => (
                      <tr key={p.usuario_id}>
                        <td style={{ fontWeight: 700 }}>#{idx + 1}</td>
                        <td style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <span style={{ fontWeight: 500, fontSize: '13px' }}>{p.nome}</span>
                        </td>
                        <td style={{ textAlign: 'right', fontWeight: 700, color: 'var(--color-cyan)' }}>
                          {p.pontuacao_total} pts
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Question Accuracy breakdown stats */}
            <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <h3 style={{ fontSize: '16px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px' }}>
                <PieChart size={18} color="var(--color-cyan)" />
                Taxa de Acerto por Pergunta (Análise do Grupo)
              </h3>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                {stats.length === 0 ? (
                  <div style={{ color: 'var(--text-muted)', fontSize: '13px', textAlign: 'center', padding: '32px' }}>
                    Carregando análise das questões...
                  </div>
                ) : (
                  stats.map((s, idx) => (
                    <div key={s.pergunta_id} style={{
                      padding: '12px 16px',
                      borderRadius: 'var(--radius-md)',
                      background: 'rgba(255, 255, 255, 0.02)',
                      border: '1px solid var(--border-color)'
                    }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '16px', marginBottom: '8px' }}>
                        <span style={{ fontWeight: 600, fontSize: '14px', color: 'var(--text-main)' }}>
                          {idx + 1}. {s.pergunta_text || s.pergunta_texto}
                        </span>
                        <span style={{
                          fontSize: '12px',
                          fontWeight: 700,
                          color: s.taxa_acerto >= 70 ? 'var(--status-success)' : s.taxa_acerto >= 40 ? 'var(--status-warning)' : 'var(--status-error)',
                          background: s.taxa_acerto >= 70 ? 'rgba(16, 185, 129, 0.1)' : s.taxa_acerto >= 40 ? 'rgba(245, 158, 11, 0.1)' : 'rgba(239, 68, 68, 0.1)',
                          padding: '3px 8px',
                          borderRadius: 'var(--radius-sm)',
                          whiteSpace: 'nowrap'
                        }}>
                          {s.taxa_acerto}% acertos
                        </span>
                      </div>
                      
                      {/* Bar indicator */}
                      <div style={{ width: '100%', height: '6px', background: 'var(--border-color)', borderRadius: '3px', overflow: 'hidden', marginBottom: '8px' }}>
                        <div style={{ width: `${s.taxa_acerto}%`, height: '100%', background: s.taxa_acerto >= 70 ? 'var(--status-success)' : s.taxa_acerto >= 40 ? 'var(--status-warning)' : 'var(--status-error)', borderRadius: '3px' }}></div>
                      </div>

                      {/* Alternatives choices breakdown count */}
                      <div style={{ display: 'flex', gap: '16px', fontSize: '11px', color: 'var(--text-muted)' }}>
                        <span>A: <b>{s.respostas_por_alternativa.A}</b></span>
                        <span>B: <b>{s.respostas_por_alternativa.B}</b></span>
                        <span>C: <b>{s.respostas_por_alternativa.C}</b></span>
                        <span>D: <b>{s.respostas_por_alternativa.D}</b></span>
                        <span style={{ marginLeft: 'auto' }}>Total respostas: <b>{s.total_respostas}</b></span>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>

          </div>

          {/* Restart Session action */}
          <div style={{ display: 'flex', justifyContent: 'center', marginTop: '16px' }}>
            <button
              onClick={() => {
                setSala(null);
                setPerguntas([]);
                setParticipantes([]);
                setCurrentQuestionIndex(0);
                setActiveStep('config');
              }}
              className="btn btn-secondary"
              style={{ padding: '12px 24px', fontWeight: 600 }}
            >
              Criar Nova Sessão
            </button>
          </div>

        </div>
      )}

    </div>
  );
};
