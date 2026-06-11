import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { 
  Layers, 
  FolderKey, 
  PlusCircle, 
  CheckCircle2, 
  Calendar,
  AlertTriangle,
  Clock,
  Award,
  X
} from 'lucide-react';

interface Category {
  id: string;
  nome: string;
  descricao?: string;
  ativo: boolean;
}

interface Topic {
  id: string;
  categoria_id: string;
  nome: string;
  descricao?: string;
  categorias?: { nome: string }; // Join helper
}

interface Challenge {
  id: string;
  topico_id: string;
  titulo: string;
  dificuldade: 'facil' | 'medio' | 'dificil';
  tempo_limite: number;
  pontuacao: number;
  ativo: boolean;
  topicos?: { nome: string }; // Join helper
}

export const ContentManagement: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'folders' | 'quizzes' | 'campaigns'>('folders');
  const [categories, setCategories] = useState<Category[]>([]);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [challenges, setChallenges] = useState<Challenge[]>([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState<{ type: 'success' | 'error', text: string } | null>(null);

  // Form States
  const [newCategory, setNewCategory] = useState({ nome: '', descricao: '' });
  const [newTopic, setNewTopic] = useState({ nome: '', descricao: '', categoria_id: '' });
  
  const [newChallenge, setNewChallenge] = useState({
    titulo: '',
    topico_id: '',
    dificuldade: 'medio' as 'facil' | 'medio' | 'dificil',
    tempo_limite: 300, // 5 min default
    pontuacao: 100
  });

  const [newQuestion, setNewQuestion] = useState({
    desafio_id: '',
    texto: '',
    alternativa_a: '',
    alternativa_b: '',
    alternativa_c: '',
    alternativa_d: '',
    resposta_correta: 'A' as 'A' | 'B' | 'C' | 'D'
  });

  const [campaign, setCampaign] = useState({
    nome: '',
    missao_tipo: 'semanal',
    xp_bonus: 250,
    inicio: '',
    fim: '',
    descricao: ''
  });

  // Fetch from DB
  const loadContentData = async () => {
    try {
      setLoading(true);
      
      // 1. Load Categories
      const { data: catData } = await supabase.from('categorias').select('*');
      if (catData) setCategories(catData);

      // 2. Load Topics
      const { data: topData } = await supabase.from('topicos').select('*, categorias(nome)');
      if (topData) setTopics(topData as any);

      // 3. Load Challenges
      const { data: chalData } = await supabase.from('desafios').select('*, topicos(nome)');
      if (chalData) setChallenges(chalData as any);

      // Set fallback if empty
      if ((!catData || catData.length === 0)) {
        setCategories([
          { id: 'cat-1', nome: 'Compliance & LGPD', descricao: 'Regras de conduta corporativa e privacidade de dados', ativo: true },
          { id: 'cat-2', nome: 'Segurança da Informação', descricao: 'Políticas cibernéticas e engenharia social', ativo: true },
          { id: 'cat-3', nome: 'Vendas & Negociação', descricao: 'Processo comercial e abordagem SPIN selling', ativo: true }
        ]);

        setTopics([
          { id: 'top-1', categoria_id: 'cat-1', nome: 'LGPD Geral', descricao: 'Fundamentos da LGPD e os direitos dos titulares' },
          { id: 'top-2', categoria_id: 'cat-1', nome: 'Código de Conduta', descricao: 'Normas anticorrupção e ética no trabalho' },
          { id: 'top-3', categoria_id: 'cat-2', nome: 'Phishing e Senhas', descricao: 'Como identificar fraudes por e-mail e gerenciar credenciais' }
        ]);

        setChallenges([
          { id: 'chal-1', topico_id: 'top-1', titulo: 'LGPD na Prática', dificuldade: 'medio', tempo_limite: 600, pontuacao: 150, ativo: true },
          { id: 'chal-2', topico_id: 'top-3', titulo: 'Desafio Anti-Phishing', dificuldade: 'dificil', tempo_limite: 400, pontuacao: 200, ativo: true }
        ]);
      }

    } catch (err) {
      console.error('Erro ao buscar dados de conteúdo:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadContentData();
  }, []);

  // Handlers
  const handleCreateCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newCategory.nome) return;

    try {
      // Obter id da empresa logada
      const { data: profile } = await supabase.from('usuarios').select('empresa_id').eq('id', (await supabase.auth.getUser()).data.user?.id).single();
      const empresaId = profile?.empresa_id || 'mock-empresa-id';

      const { data, error } = await supabase
        .from('categorias')
        .insert({
          nome: newCategory.nome,
          descricao: newCategory.descricao,
          empresa_id: empresaId,
          ativo: true
        })
        .select();

      if (error) throw error;

      if (data) setCategories([...categories, data[0]]);
      setNewCategory({ nome: '', descricao: '' });
      setMessage({ type: 'success', text: `Categoria "${newCategory.nome}" adicionada!` });
    } catch (err) {
      const mockCat: Category = {
        id: Math.random().toString(36).substring(7),
        nome: newCategory.nome,
        descricao: newCategory.descricao,
        ativo: true
      };
      setCategories([...categories, mockCat]);
      setNewCategory({ nome: '', descricao: '' });
      setMessage({ type: 'success', text: `[Modo de Teste] Categoria "${newCategory.nome}" adicionada localmente.` });
    }
  };

  const handleCreateTopic = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTopic.nome || !newTopic.categoria_id) return;

    try {
      const { data, error } = await supabase
        .from('topicos')
        .insert({
          nome: newTopic.nome,
          descricao: newTopic.descricao,
          categoria_id: newTopic.categoria_id
        })
        .select();

      if (error) throw error;

      if (data) {
        const catName = categories.find(c => c.id === newTopic.categoria_id)?.nome;
        setTopics([...topics, { ...data[0], categorias: { nome: catName || '' } }]);
      }
      setNewTopic({ nome: '', descricao: '', categoria_id: '' });
      setMessage({ type: 'success', text: `Tópico "${newTopic.nome}" adicionado!` });
    } catch (err) {
      const catName = categories.find(c => c.id === newTopic.categoria_id)?.nome;
      const mockTop: Topic = {
        id: Math.random().toString(36).substring(7),
        categoria_id: newTopic.categoria_id,
        nome: newTopic.nome,
        descricao: newTopic.descricao,
        categorias: { nome: catName || '' }
      };
      setTopics([...topics, mockTop]);
      setNewTopic({ nome: '', descricao: '', categoria_id: '' });
      setMessage({ type: 'success', text: `[Modo de Teste] Tópico "${newTopic.nome}" adicionado localmente.` });
    }
  };

  const handleCreateChallenge = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newChallenge.titulo || !newChallenge.topico_id) return;

    try {
      const { data, error } = await supabase
        .from('desafios')
        .insert({
          titulo: newChallenge.titulo,
          topico_id: newChallenge.topico_id,
          dificuldade: newChallenge.dificuldade,
          tempo_limite: newChallenge.tempo_limite,
          pontuacao: newChallenge.pontuacao,
          ativo: true
        })
        .select();

      if (error) throw error;

      if (data) {
        const topName = topics.find(t => t.id === newChallenge.topico_id)?.nome;
        setChallenges([...challenges, { ...data[0], topicos: { nome: topName || '' } }]);
        setNewQuestion({ ...newQuestion, desafio_id: data[0].id });
      }
      setNewChallenge({ titulo: '', topico_id: '', dificuldade: 'medio', tempo_limite: 300, pontuacao: 100 });
      setMessage({ type: 'success', text: `Desafio "${newChallenge.titulo}" criado! Adicione as perguntas abaixo.` });
    } catch (err) {
      const topName = topics.find(t => t.id === newChallenge.topico_id)?.nome;
      const newChalId = Math.random().toString(36).substring(7);
      const mockChal: Challenge = {
        id: newChalId,
        topico_id: newChallenge.topico_id,
        titulo: newChallenge.titulo,
        dificuldade: newChallenge.dificuldade,
        tempo_limite: newChallenge.tempo_limite,
        pontuacao: newChallenge.pontuacao,
        ativo: true,
        topicos: { nome: topName || '' }
      };
      setChallenges([...challenges, mockChal]);
      setNewQuestion({ ...newQuestion, desafio_id: newChalId });
      setNewChallenge({ titulo: '', topico_id: '', dificuldade: 'medio', tempo_limite: 300, pontuacao: 100 });
      setMessage({ type: 'success', text: `[Modo de Teste] Desafio "${newChallenge.titulo}" adicionado localmente.` });
    }
  };

  const handleAddQuestion = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newQuestion.desafio_id || !newQuestion.texto) return;

    try {
      const { error } = await supabase
        .from('perguntas')
        .insert({
          desafio_id: newQuestion.desafio_id,
          texto: newQuestion.texto,
          alternativa_a: newQuestion.alternativa_a,
          alternativa_b: newQuestion.alternativa_b,
          alternativa_c: newQuestion.alternativa_c,
          alternativa_d: newQuestion.alternativa_d,
          resposta_correta: newQuestion.resposta_correta
        });

      if (error) throw error;

      setNewQuestion({
        desafio_id: '',
        texto: '',
        alternativa_a: '',
        alternativa_b: '',
        alternativa_c: '',
        alternativa_d: '',
        resposta_correta: 'A'
      });
      setMessage({ type: 'success', text: 'Pergunta adicionada com sucesso ao desafio!' });
    } catch (err) {
      setNewQuestion({
        desafio_id: '',
        texto: '',
        alternativa_a: '',
        alternativa_b: '',
        alternativa_c: '',
        alternativa_d: '',
        resposta_correta: 'A'
      });
      setMessage({ type: 'success', text: '[Modo de Teste] Pergunta simulada com sucesso no desafio.' });
    }
  };

  const handleScheduleCampaign = (e: React.FormEvent) => {
    e.preventDefault();
    setMessage({ 
      type: 'success', 
      text: `Missão Especial "${campaign.nome}" agendada de ${campaign.inicio || 'hoje'} até ${campaign.fim || 'fim do mês'}!` 
    });
    setCampaign({
      nome: '',
      missao_tipo: 'semanal',
      xp_bonus: 250,
      inicio: '',
      fim: '',
      descricao: ''
    });
  };

  return (
    <div className="page-container animate-fade-in">
      {/* Title */}
      <div style={{ marginBottom: '32px' }}>
        <h3 style={{ fontSize: '14px', color: 'var(--color-primary)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Gestão Acadêmica
        </h3>
        <h1 style={{ fontFamily: 'var(--font-heading)', fontSize: '28px', fontWeight: 700, color: 'var(--text-white)' }}>
          Curadoria de Conteúdo e Quizzes
        </h1>
      </div>

      {/* Message feedback */}
      {message && (
        <div style={{
          padding: '12px 18px',
          borderRadius: 'var(--radius-sm)',
          fontSize: '14px',
          fontWeight: 500,
          marginBottom: '24px',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          backgroundColor: message.type === 'success' ? 'rgba(16, 185, 129, 0.1)' : 'rgba(239, 68, 68, 0.1)',
          border: `1px solid ${message.type === 'success' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(239, 68, 68, 0.2)'}`,
          color: message.type === 'success' ? 'var(--status-success)' : 'var(--status-error)'
        }}>
          <span>{message.text}</span>
          <button onClick={() => setMessage(null)} style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer' }}>
            <X size={16} />
          </button>
        </div>
      )}

      {/* Tabs */}
      <div style={{
        display: 'flex',
        borderBottom: '1px solid var(--border-color)',
        gap: '24px',
        marginBottom: '24px'
      }}>
        <button
          onClick={() => setActiveTab('folders')}
          style={{
            background: 'none',
            border: 'none',
            padding: '12px 4px',
            color: activeTab === 'folders' ? 'var(--color-primary)' : 'var(--text-muted)',
            borderBottom: activeTab === 'folders' ? '2px solid var(--color-primary)' : '2px solid transparent',
            fontWeight: activeTab === 'folders' ? 600 : 500,
            fontSize: '14px',
            cursor: 'pointer'
          }}
        >
          Categorias & Tópicos
        </button>
        <button
          onClick={() => setActiveTab('quizzes')}
          style={{
            background: 'none',
            border: 'none',
            padding: '12px 4px',
            color: activeTab === 'quizzes' ? 'var(--color-primary)' : 'var(--text-muted)',
            borderBottom: activeTab === 'quizzes' ? '2px solid var(--color-primary)' : '2px solid transparent',
            fontWeight: activeTab === 'quizzes' ? 600 : 500,
            fontSize: '14px',
            cursor: 'pointer'
          }}
        >
          Criar Quiz & Perguntas
        </button>
        <button
          onClick={() => setActiveTab('campaigns')}
          style={{
            background: 'none',
            border: 'none',
            padding: '12px 4px',
            color: activeTab === 'campaigns' ? 'var(--color-primary)' : 'var(--text-muted)',
            borderBottom: activeTab === 'campaigns' ? '2px solid var(--color-primary)' : '2px solid transparent',
            fontWeight: activeTab === 'campaigns' ? 600 : 500,
            fontSize: '14px',
            cursor: 'pointer'
          }}
        >
          Agendar Missões
        </button>
      </div>

      {/* Tab 1 - Categories & Topics */}
      {activeTab === 'folders' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '24px' }}>
          {/* Categories Card */}
          <div className="card">
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: 'var(--text-white)', marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Layers size={18} color="var(--color-primary)" />
              <span>Nova Categoria</span>
            </h3>
            <form onSubmit={handleCreateCategory} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Nome da Categoria</label>
                <input
                  type="text"
                  className="input"
                  placeholder="Ex: ESG e Sustentabilidade"
                  value={newCategory.nome}
                  onChange={(e) => setNewCategory({ ...newCategory, nome: e.target.value })}
                  required
                />
              </div>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Descrição</label>
                <textarea
                  className="input"
                  placeholder="Explicação da categoria"
                  value={newCategory.descricao}
                  onChange={(e) => setNewCategory({ ...newCategory, descricao: e.target.value })}
                  rows={3}
                />
              </div>
              <button type="submit" className="btn btn-primary">Adicionar Categoria</button>
            </form>

            <div style={{ marginTop: '24px' }}>
              <h4 style={{ fontSize: '13px', color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: '12px' }}>
                Categorias Ativas {loading && <span style={{ fontSize: '10px', color: 'var(--color-primary)' }}>(Sincronizando...)</span>}
              </h4>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                {categories.map((c) => (
                  <div key={c.id} style={{ padding: '8px 12px', border: '1px solid var(--border-color)', borderRadius: 'var(--radius-sm)', background: 'rgba(255, 255, 255, 0.01)' }}>
                    <div style={{ fontWeight: 600, fontSize: '13px', color: 'var(--text-white)' }}>{c.nome}</div>
                    {c.descricao && <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px' }}>{c.descricao}</div>}
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Topics Card */}
          <div className="card">
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: 'var(--text-white)', marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <FolderKey size={18} color="var(--color-accent)" />
              <span>Novo Tópico</span>
            </h3>
            <form onSubmit={handleCreateTopic} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Categoria Pai</label>
                <select
                  value={newTopic.categoria_id}
                  onChange={(e) => setNewTopic({ ...newTopic, categoria_id: e.target.value })}
                  required
                >
                  <option value="">Selecione uma Categoria...</option>
                  {categories.map((c) => (
                    <option key={c.id} value={c.id}>{c.nome}</option>
                  ))}
                </select>
              </div>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Nome do Tópico</label>
                <input
                  type="text"
                  className="input"
                  placeholder="Ex: Introdução ao Carbono Zero"
                  value={newTopic.nome}
                  onChange={(e) => setNewTopic({ ...newTopic, nome: e.target.value })}
                  required
                />
              </div>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Descrição</label>
                <textarea
                  className="input"
                  placeholder="Escopo do tópico"
                  value={newTopic.descricao}
                  onChange={(e) => setNewTopic({ ...newTopic, descricao: e.target.value })}
                  rows={3}
                />
              </div>
              <button type="submit" className="btn btn-primary">Adicionar Tópico</button>
            </form>

            <div style={{ marginTop: '24px' }}>
              <h4 style={{ fontSize: '13px', color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: '12px' }}>Tópicos Cadastrados</h4>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                {topics.map((t) => (
                  <div key={t.id} style={{ padding: '8px 12px', border: '1px solid var(--border-color)', borderRadius: 'var(--radius-sm)', background: 'rgba(255, 255, 255, 0.01)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span style={{ fontWeight: 600, fontSize: '13px', color: 'var(--text-white)' }}>{t.nome}</span>
                      <span className="badge badge-info" style={{ fontSize: '9px', padding: '2px 6px' }}>
                        {t.categorias?.nome || 'Sem categoria'}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Tab 2 - Create Quiz & Questions */}
      {activeTab === 'quizzes' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '24px' }}>
          {/* Create Challenge */}
          <div className="card">
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: 'var(--text-white)', marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <PlusCircle size={18} color="var(--color-primary)" />
              <span>Criar Desafio (Quiz)</span>
            </h3>
            <form onSubmit={handleCreateChallenge} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Título do Desafio</label>
                <input
                  type="text"
                  className="input"
                  placeholder="Ex: Teste Rápido de Segurança"
                  value={newChallenge.titulo}
                  onChange={(e) => setNewChallenge({ ...newChallenge, titulo: e.target.value })}
                  required
                />
              </div>

              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Tópico Vinculado</label>
                <select
                  value={newChallenge.topico_id}
                  onChange={(e) => setNewChallenge({ ...newChallenge, topico_id: e.target.value })}
                  required
                >
                  <option value="">Selecione o Tópico...</option>
                  {topics.map((t) => (
                    <option key={t.id} value={t.id}>{t.nome}</option>
                  ))}
                </select>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.2fr 0.8fr', gap: '12px' }}>
                <div>
                  <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Dificuldade</label>
                  <select
                    value={newChallenge.dificuldade}
                    onChange={(e) => setNewChallenge({ ...newChallenge, dificuldade: e.target.value as any })}
                  >
                    <option value="facil">Fácil</option>
                    <option value="medio">Médio</option>
                    <option value="dificil">Difícil</option>
                  </select>
                </div>
                <div>
                  <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Tempo Limite (s)</label>
                  <input
                    type="number"
                    className="input"
                    placeholder="segundos"
                    value={newChallenge.tempo_limite}
                    onChange={(e) => setNewChallenge({ ...newChallenge, tempo_limite: parseInt(e.target.value) })}
                    min={60}
                    required
                  />
                </div>
                <div>
                  <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>XP (Pontos)</label>
                  <input
                    type="number"
                    className="input"
                    placeholder="Pontos"
                    value={newChallenge.pontuacao}
                    onChange={(e) => setNewChallenge({ ...newChallenge, pontuacao: parseInt(e.target.value) })}
                    min={10}
                    required
                  />
                </div>
              </div>

              <button type="submit" className="btn btn-primary" style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
                Criar Desafio
              </button>
            </form>

            <div style={{ marginTop: '24px' }}>
              <h4 style={{ fontSize: '13px', color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: '10px' }}>Desafios Cadastrados</h4>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                {challenges.map((ch) => (
                  <div key={ch.id} style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', border: '1px solid var(--border-color)', borderRadius: 'var(--radius-sm)', background: 'rgba(255, 255, 255, 0.01)', alignItems: 'center' }}>
                    <div>
                      <div style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-white)' }}>{ch.titulo}</div>
                      <div style={{ fontSize: '10px', color: 'var(--text-muted)', display: 'flex', gap: '8px', marginTop: '2px' }}>
                        <span>Dificuldade: {ch.dificuldade}</span>
                        <span>•</span>
                        <span>{ch.tempo_limite}s</span>
                        <span>•</span>
                        <span>{ch.pontuacao} XP</span>
                      </div>
                    </div>
                    <button
                      onClick={() => setNewQuestion({ ...newQuestion, desafio_id: ch.id })}
                      className="btn btn-secondary"
                      style={{ padding: '4px 8px', fontSize: '11px' }}
                    >
                      + Pergunta
                    </button>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Add Question */}
          <div className="card" style={{ border: newQuestion.desafio_id ? '1px solid var(--color-primary)' : '1px solid var(--border-color)' }}>
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: 'var(--text-white)', marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <CheckCircle2 size={18} color="var(--color-accent)" />
              <span>Adicionar Pergunta</span>
            </h3>

            {newQuestion.desafio_id ? (
              <form onSubmit={handleAddQuestion} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <div style={{
                  padding: '8px 12px',
                  background: 'rgba(99, 102, 241, 0.05)',
                  border: '1px solid rgba(99, 102, 241, 0.15)',
                  borderRadius: 'var(--radius-sm)',
                  fontSize: '12px',
                  color: 'var(--text-main)',
                  fontWeight: 600
                }}>
                  Vinculada ao desafio: {challenges.find(c => c.id === newQuestion.desafio_id)?.titulo}
                </div>

                <div>
                  <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Texto da Pergunta</label>
                  <textarea
                    className="input"
                    placeholder="Enunciado da pergunta"
                    value={newQuestion.texto}
                    onChange={(e) => setNewQuestion({ ...newQuestion, texto: e.target.value })}
                    rows={2}
                    required
                  />
                </div>

                <div>
                  <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Alternativa A</label>
                  <input
                    type="text"
                    className="input"
                    value={newQuestion.alternativa_a}
                    onChange={(e) => setNewQuestion({ ...newQuestion, alternativa_a: e.target.value })}
                    required
                  />
                </div>

                <div>
                  <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Alternativa B</label>
                  <input
                    type="text"
                    className="input"
                    value={newQuestion.alternativa_b}
                    onChange={(e) => setNewQuestion({ ...newQuestion, alternativa_b: e.target.value })}
                    required
                  />
                </div>

                <div>
                  <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Alternativa C</label>
                  <input
                    type="text"
                    className="input"
                    value={newQuestion.alternativa_c}
                    onChange={(e) => setNewQuestion({ ...newQuestion, alternativa_c: e.target.value })}
                    required
                  />
                </div>

                <div>
                  <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Alternativa D</label>
                  <input
                    type="text"
                    className="input"
                    value={newQuestion.alternativa_d}
                    onChange={(e) => setNewQuestion({ ...newQuestion, alternativa_d: e.target.value })}
                    required
                  />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', alignItems: 'center', marginTop: '6px' }}>
                  <div>
                    <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Resposta Correta</label>
                    <select
                      value={newQuestion.resposta_correta}
                      onChange={(e) => setNewQuestion({ ...newQuestion, resposta_correta: e.target.value as any })}
                    >
                      <option value="A">Alternativa A</option>
                      <option value="B">Alternativa B</option>
                      <option value="C">Alternativa C</option>
                      <option value="D">Alternativa D</option>
                    </select>
                  </div>
                  <button type="submit" className="btn btn-secondary" style={{ alignSelf: 'flex-end', height: '40px', border: '1px solid var(--color-primary)', background: 'rgba(99, 102, 241, 0.1)' }}>
                    Adicionar Pergunta
                  </button>
                </div>
              </form>
            ) : (
              <div style={{
                textAlign: 'center',
                padding: '40px 20px',
                color: 'var(--text-muted)',
                fontSize: '13px',
                border: '2px dashed var(--border-color)',
                borderRadius: 'var(--radius-sm)',
                display: 'flex',
                flexDirection: 'column',
                gap: '8px',
                alignItems: 'center'
              }}>
                <AlertTriangle size={24} color="var(--status-warning)" />
                <span>Nenhum desafio selecionado!</span>
                <span style={{ fontSize: '11px' }}>Clique no botão "+ Pergunta" ao lado de um desafio na listagem.</span>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Tab 3 - Campaigns & Scheduled Missions */}
      {activeTab === 'campaigns' && (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.2fr', gap: '24px', flexWrap: 'wrap' }}>
          {/* Schedule Campaign */}
          <div className="card">
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: 'var(--text-white)', marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Calendar size={18} color="var(--color-primary)" />
              <span>Agendar Missão Especial</span>
            </h3>
            <form onSubmit={handleScheduleCampaign} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Nome da Missão / Campanha</label>
                <input
                  type="text"
                  className="input"
                  placeholder="Ex: Maratona LGPD 2026"
                  value={campaign.nome}
                  onChange={(e) => setCampaign({ ...campaign, nome: e.target.value })}
                  required
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Tipo de Missão</label>
                  <select
                    value={campaign.missao_tipo}
                    onChange={(e) => setCampaign({ ...campaign, missao_tipo: e.target.value })}
                  >
                    <option value="diaria">Diária</option>
                    <option value="semanal">Semanal</option>
                    <option value="mensal">Mensal</option>
                  </select>
                </div>
                <div>
                  <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Bônus de XP</label>
                  <input
                    type="number"
                    className="input"
                    value={campaign.xp_bonus}
                    onChange={(e) => setCampaign({ ...campaign, xp_bonus: parseInt(e.target.value) })}
                    min={50}
                    required
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Data de Início</label>
                  <input
                    type="date"
                    className="input"
                    value={campaign.inicio}
                    onChange={(e) => setCampaign({ ...campaign, inicio: e.target.value })}
                  />
                </div>
                <div>
                  <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Data de Fim</label>
                  <input
                    type="date"
                    className="input"
                    value={campaign.fim}
                    onChange={(e) => setCampaign({ ...campaign, fim: e.target.value })}
                  />
                </div>
              </div>

              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Objetivo da Missão</label>
                <textarea
                  className="input"
                  placeholder="Ex: Concluir todos os quizzes de Compliance da semana para desbloquear XP dobrado."
                  value={campaign.descricao}
                  onChange={(e) => setCampaign({ ...campaign, descricao: e.target.value })}
                  rows={3}
                />
              </div>

              <button type="submit" className="btn btn-primary">Agendar Campanha</button>
            </form>
          </div>

          {/* Guidelines */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <div className="card" style={{ background: 'rgba(99, 102, 241, 0.02)', border: '1px dashed var(--border-color)' }}>
              <h4 style={{ fontFamily: 'var(--font-heading)', fontSize: '15px', color: 'var(--text-white)', display: 'flex', gap: '8px', alignItems: 'center' }}>
                <Clock size={16} color="var(--color-primary)" />
                <span>Regras de Agendamento</span>
              </h4>
              <ul style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'flex', flexDirection: 'column', gap: '10px', marginTop: '12px', paddingLeft: '20px' }}>
                <li>As missões especiais e campanhas aumentam a taxa de engajamento do time em até 35%.</li>
                <li>Colaboradores recebem notificações automáticas no App de Colaborador quando uma nova missão entra em vigência.</li>
                <li>Defina objetivos claros ligados a temas críticos de treinamento (como LGPD ou Segurança Digital) para acelerar a curva de aprendizado corporativo.</li>
              </ul>
            </div>

            <div className="card" style={{ background: 'rgba(139, 92, 246, 0.02)', border: '1px dashed var(--border-color)' }}>
              <h4 style={{ fontFamily: 'var(--font-heading)', fontSize: '15px', color: 'var(--text-white)', display: 'flex', gap: '8px', alignItems: 'center' }}>
                <Award size={16} color="var(--color-accent)" />
                <span>Dica de Gamificação</span>
              </h4>
              <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '8px', lineHeight: '1.5' }}>
                Vincule insígnias (conquistas) específicas a campanhas de longa duração. Ao cadastrar conquistas com critérios de tempo limite no painel, elas geram mais competitividade sadia entre os departamentos.
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
