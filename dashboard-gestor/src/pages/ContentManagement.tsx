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
  X,
  Download,
  Upload,
  Sparkles
} from 'lucide-react';
import * as XLSX from 'xlsx';

const API_URL = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';

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
  
  // Excel Import States
  const [importErrors, setImportErrors] = useState<string[]>([]);

  // AI Question Generation States
  const [showAIModal, setShowAIModal] = useState(false);
  const [aiGenerating, setAIGenerating] = useState(false);
  const [generatedQuestions, setGeneratedQuestions] = useState<any[]>([]);
  const [aiStage, setAIStage] = useState<'form' | 'review'>('form');
  const [aiForm, setAIForm] = useState({
    tema: '',
    quantidade: 5,
    dificuldade: 'medio',
    contexto: ''
  });

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

  const downloadTemplate = () => {
    const templateData = [
      {
        pergunta: 'Qual o principal objetivo da LGPD?',
        alternativa_a: 'Garantir a privacidade e proteção de dados pessoais dos cidadãos.',
        alternativa_b: 'Aumentar a venda de produtos e serviços na internet.',
        alternativa_c: 'Controlar o uso de redes sociais nas empresas.',
        alternativa_d: 'Fiscalizar a velocidade da internet residencial.',
        resposta_correta: 'A',
        dificuldade: 'medio',
        tempo_limite: 300,
        pontuacao: 100
      },
      {
        pergunta: 'Qual dessas práticas ajuda a prevenir ataques de Phishing?',
        alternativa_a: 'Compartilhar senhas corporativas apenas com colegas do mesmo time.',
        alternativa_b: 'Desconfiar de links recebidos por e-mails suspeitos e verificar o remetente.',
        alternativa_c: 'Clicar em todos os anexos para verificar se há vírus.',
        alternativa_d: 'Responder aos e-mails solicitando dados bancários imediatamente.',
        resposta_correta: 'B',
        dificuldade: 'facil',
        tempo_limite: 120,
        pontuacao: 80
      }
    ];

    const worksheet = XLSX.utils.json_to_sheet(templateData);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Template Perguntas');
    XLSX.writeFile(workbook, 'template_perguntas_quiz.xlsx');
  };

  const handleImportPlanilha = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setImportErrors([]);
    setMessage(null);

    const reader = new FileReader();
    reader.onload = async (evt) => {
      try {
        const bstr = evt.target?.result;
        const wb = XLSX.read(bstr, { type: 'binary' });
        const wsname = wb.SheetNames[0];
        const ws = wb.Sheets[wsname];
        const rawJson = XLSX.utils.sheet_to_json<any>(ws);

        if (rawJson.length === 0) {
          setMessage({ type: 'error', text: 'Planilha vazia ou com formato inválido.' });
          return;
        }

        const errors: string[] = [];
        const validQuestions: any[] = [];
        let difficultyToUpdate: string | undefined = undefined;
        let timeLimitToUpdate: number | undefined = undefined;
        let scoreToUpdate: number | undefined = undefined;

        rawJson.forEach((row: any, index: number) => {
          const rowNum = index + 2;

          const texto = row.pergunta || row.texto || row.Pergunta || '';
          const altA = row.alternativa_a || row.Alternativa_A || row.alternativa_A || '';
          const altB = row.alternativa_b || row.Alternativa_B || row.alternativa_B || '';
          const altC = row.alternativa_c || row.Alternativa_C || row.alternativa_C || '';
          const altD = row.alternativa_d || row.Alternativa_D || row.alternativa_D || '';
          const resp = row.resposta_correta || row.Resposta_Correta || row.resposta || '';
          const dif = row.dificuldade || row.Dificuldade || '';
          const tempo = row.tempo_limite || row.Tempo_Limite || row.tempo || '';
          const pts = row.pontuacao || row.Pontuacao || row.pontos || '';

          const rowErrors: string[] = [];

          if (!texto.toString().trim()) {
            rowErrors.push('A pergunta está vazia.');
          }
          if (!altA.toString().trim()) {
            rowErrors.push('Alternativa A está vazia.');
          }
          if (!altB.toString().trim()) {
            rowErrors.push('Alternativa B está vazia.');
          }
          if (!altC.toString().trim()) {
            rowErrors.push('Alternativa C está vazia.');
          }
          if (!altD.toString().trim()) {
            rowErrors.push('Alternativa D está vazia.');
          }

          const respUpper = resp.toString().trim().toUpperCase();
          if (!respUpper || !['A', 'B', 'C', 'D'].includes(respUpper)) {
            rowErrors.push(`Resposta correta "${resp}" é inválida. Deve ser A, B, C ou D.`);
          }

          let parsedTempo: number | undefined = undefined;
          if (tempo !== undefined && tempo !== '') {
            parsedTempo = parseInt(tempo);
            if (isNaN(parsedTempo) || parsedTempo <= 0) {
              rowErrors.push(`Tempo limite "${tempo}" é inválido. Deve ser um número inteiro de segundos positivo.`);
              parsedTempo = undefined;
            }
          }

          let parsedPts: number | undefined = undefined;
          if (pts !== undefined && pts !== '') {
            parsedPts = parseInt(pts);
            if (isNaN(parsedPts) || parsedPts < 0) {
              rowErrors.push(`Pontuação "${pts}" é inválida. Deve ser um número inteiro positivo.`);
              parsedPts = undefined;
            }
          }

          let cleanDif = dif.toString().trim().toLowerCase();
          if (cleanDif) {
            cleanDif = cleanDif.replace('fácil', 'facil').replace('médio', 'medio').replace('difícil', 'dificil');
            if (!['facil', 'medio', 'dificil'].includes(cleanDif)) {
              rowErrors.push(`Dificuldade "${dif}" é inválida. Deve ser facil, medio ou dificil.`);
              cleanDif = '';
            }
          }

          if (rowErrors.length > 0) {
            errors.push(`Linha ${rowNum}: ${rowErrors.join(' | ')}`);
          } else {
            validQuestions.push({
              texto: texto.toString().trim(),
              alternativa_a: altA.toString().trim(),
              alternativa_b: altB.toString().trim(),
              alternativa_c: altC.toString().trim(),
              alternativa_d: altD.toString().trim(),
              resposta_correta: respUpper
            });

            if (cleanDif && !difficultyToUpdate) {
              difficultyToUpdate = cleanDif;
            }
            if (parsedTempo !== undefined && timeLimitToUpdate === undefined) {
              timeLimitToUpdate = parsedTempo;
            }
            if (parsedPts !== undefined && scoreToUpdate === undefined) {
              scoreToUpdate = parsedPts;
            }
          }
        });

        if (errors.length > 0) {
          setImportErrors(errors);
        }

        if (validQuestions.length === 0) {
          setMessage({ type: 'error', text: 'Nenhuma pergunta válida encontrada na planilha para importar.' });
          return;
        }

        const response = await fetch(`${API_URL}/api/desafios/${newQuestion.desafio_id}/perguntas/bulk`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            perguntas: validQuestions,
            dificuldade: difficultyToUpdate || null,
            tempo_limite: timeLimitToUpdate || null,
            pontuacao: scoreToUpdate || null
          })
        });

        if (!response.ok) {
          throw new Error('Falha ao importar perguntas no backend.');
        }

        const resData = await response.json();
        
        loadContentData();

        if (errors.length > 0) {
          setMessage({ 
            type: 'success', 
            text: `Importação concluída parcialmente! ${resData.success_count} perguntas importadas com sucesso. Verifique o relatório de erros abaixo para as linhas com problema.` 
          });
        } else {
          setMessage({ 
            type: 'success', 
            text: `Sucesso! Todas as ${resData.success_count} perguntas foram importadas com sucesso.` 
          });
        }

      } catch (err: any) {
        console.error('Erro na importação de perguntas:', err);
        setMessage({ 
          type: 'error', 
          text: `Erro ao conectar com o backend: ${err.message || 'Verifique se o servidor FastAPI está ativo em http://127.0.0.1:8000'}` 
        });
      }
    };
    reader.readAsBinaryString(file);
    e.target.value = '';
  };

  const handleGenerateWithAI = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!aiForm.tema || aiForm.quantidade <= 0) return;

    setAIStage('form');
    setAIGenerating(true);
    setImportErrors([]);

    try {
      const response = await fetch(`${API_URL}/api/gerar-perguntas`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          tema: aiForm.tema,
          quantidade: aiForm.quantidade,
          dificuldade: aiForm.dificuldade,
          contexto: aiForm.contexto || null
        })
      });

      if (!response.ok) {
        throw new Error('Falha ao gerar perguntas com IA.');
      }

      const data = await response.json();
      const mapped = data.map((q: any) => ({
        pergunta: q.pergunta || '',
        alternativa_a: q.alternativa_a || '',
        alternativa_b: q.alternativa_b || '',
        alternativa_c: q.alternativa_c || '',
        alternativa_d: q.alternativa_d || '',
        resposta_correta: (q.resposta_correta || 'A').toUpperCase() as 'A' | 'B' | 'C' | 'D',
        dificuldade: q.dificuldade || aiForm.dificuldade
      }));

      setGeneratedQuestions(mapped);
      setAIStage('review');
    } catch (err: any) {
      console.error(err);
      setMessage({ type: 'error', text: `Erro na geração por IA: ${err.message || 'Verifique se a API está online.'}` });
    } finally {
      setAIGenerating(false);
    }
  };

  const handleSaveAllAI = async () => {
    if (generatedQuestions.length === 0) return;

    setAIGenerating(true);

    try {
      const response = await fetch(`${API_URL}/api/desafios/${newQuestion.desafio_id}/perguntas/bulk`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          perguntas: generatedQuestions.map(q => ({
            texto: q.pergunta,
            alternativa_a: q.alternativa_a,
            alternativa_b: q.alternativa_b,
            alternativa_c: q.alternativa_c,
            alternativa_d: q.alternativa_d,
            resposta_correta: q.resposta_correta
          })),
          dificuldade: generatedQuestions[0]?.dificuldade || null
        })
      });

      if (!response.ok) {
        throw new Error('Falha ao salvar perguntas geradas.');
      }

      const resData = await response.json();
      
      loadContentData();
      setShowAIModal(false);
      setMessage({
        type: 'success',
        text: `Sucesso! Foram geradas e salvas ${resData.success_count} perguntas com Inteligência Artificial.`
      });
    } catch (err: any) {
      console.error(err);
      setMessage({ type: 'error', text: `Erro ao salvar perguntas: ${err.message}` });
    } finally {
      setAIGenerating(false);
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
                    <div style={{ display: 'flex', gap: '6px', alignItems: 'center' }}>
                      <button
                        onClick={() => setNewQuestion({ ...newQuestion, desafio_id: ch.id })}
                        className="btn btn-secondary"
                        style={{ padding: '4px 8px', fontSize: '11px' }}
                        type="button"
                      >
                        + Pergunta
                      </button>
                      <button
                        onClick={() => {
                          setNewQuestion({ ...newQuestion, desafio_id: ch.id });
                          setAIStage('form');
                          setAIForm({ tema: '', quantidade: 5, dificuldade: 'medio', contexto: '' });
                          setGeneratedQuestions([]);
                          setShowAIModal(true);
                        }}
                        className="btn btn-primary"
                        style={{ 
                          padding: '4px 8px', 
                          fontSize: '11px', 
                          display: 'flex', 
                          alignItems: 'center', 
                          gap: '4px',
                          background: 'linear-gradient(135deg, var(--color-primary), var(--color-accent))',
                          border: 'none',
                          cursor: 'pointer'
                        }}
                        type="button"
                      >
                        <span>✨ Gerar Perguntas com IA</span>
                      </button>
                    </div>
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
              <>
                <div style={{
                  padding: '8px 12px',
                  background: 'rgba(99, 102, 241, 0.05)',
                  border: '1px solid rgba(99, 102, 241, 0.15)',
                  borderRadius: 'var(--radius-sm)',
                  fontSize: '12px',
                  color: 'var(--text-main)',
                  fontWeight: 600,
                  marginBottom: '16px'
                }}>
                  Vinculada ao desafio: {challenges.find(c => c.id === newQuestion.desafio_id)?.titulo}
                </div>

                {/* Importação por Planilha */}
                <div style={{
                  padding: '16px',
                  background: 'rgba(255, 255, 255, 0.01)',
                  border: '1px solid var(--border-color)',
                  borderRadius: 'var(--radius-sm)',
                  marginBottom: '20px'
                }}>
                  <div style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-white)', marginBottom: '4px' }}>
                    Importação via Planilha
                  </div>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '12px' }}>
                    Baixe o template padrão, preencha as perguntas e envie o arquivo.
                  </div>
                  <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
                    <button
                      onClick={downloadTemplate}
                      className="btn btn-secondary"
                      style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', padding: '8px 12px', border: '1px solid var(--border-color)', cursor: 'pointer' }}
                      type="button"
                    >
                      <Download size={14} />
                      <span>Baixar Template</span>
                    </button>
                    <label
                      className="btn btn-secondary"
                      style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', padding: '8px 12px', cursor: 'pointer', border: '1px solid var(--border-color)' }}
                    >
                      <Upload size={14} />
                      <span>Importar Planilha</span>
                      <input
                        type="file"
                        accept=".xlsx, .xls, .csv"
                        onChange={handleImportPlanilha}
                        style={{ display: 'none' }}
                      />
                    </label>
                    <button
                      onClick={() => {
                        if (!newQuestion.desafio_id) {
                          setMessage({ type: 'error', text: 'Selecione ou crie um desafio antes de gerar perguntas.' });
                          return;
                        }
                        setAIStage('form');
                        setAIForm({ tema: '', quantidade: 5, dificuldade: 'medio', contexto: '' });
                        setGeneratedQuestions([]);
                        setImportErrors([]);
                        setShowAIModal(true);
                      }}
                      className="btn btn-primary"
                      style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', padding: '8px 12px', cursor: 'pointer', border: 'none', background: 'linear-gradient(135deg, var(--color-primary), var(--color-accent))', color: '#fff', fontWeight: 600 }}
                      type="button"
                    >
                      <Sparkles size={14} />
                      <span>Gerar com IA</span>
                    </button>
                  </div>

                  {importErrors.length > 0 && (
                    <div style={{
                      marginTop: '12px',
                      padding: '10px 12px',
                      backgroundColor: 'rgba(239, 68, 68, 0.05)',
                      border: '1px solid rgba(239, 68, 68, 0.15)',
                      borderRadius: 'var(--radius-sm)',
                      color: 'var(--status-error)',
                      fontSize: '12px'
                    }}>
                      <div style={{ fontWeight: 600, marginBottom: '6px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <span>Erros encontrados ({importErrors.length}):</span>
                        <button 
                          onClick={() => setImportErrors([])} 
                          style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer', fontSize: '10px', textDecoration: 'underline' }}
                        >
                          Limpar
                        </button>
                      </div>
                      <div style={{ maxHeight: '120px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                        {importErrors.map((err, i) => (
                          <div key={i} style={{ fontFamily: 'monospace', fontSize: '11px' }}>• {err}</div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>

                <div style={{ display: 'flex', alignItems: 'center', margin: '20px 0', gap: '12px' }}>
                  <div style={{ flex: 1, height: '1px', backgroundColor: 'var(--border-color)' }}></div>
                  <span style={{ fontSize: '11px', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase' }}>Ou adicionar manualmente</span>
                  <div style={{ flex: 1, height: '1px', backgroundColor: 'var(--border-color)' }}></div>
                </div>

                <form onSubmit={handleAddQuestion} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>

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
            </>
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

      {showAIModal && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(5, 7, 15, 0.85)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
          padding: '20px',
          backdropFilter: 'blur(8px)',
        }}>
          <div className="card animate-fade-in" style={{
            width: '100%',
            maxWidth: aiStage === 'review' ? '800px' : '500px',
            maxHeight: '90vh',
            display: 'flex',
            flexDirection: 'column',
            padding: '32px',
            boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.5), var(--shadow-glow)',
            border: '1px solid var(--border-color)',
            background: '#0f1322'
          }}>
            {/* Header */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
              <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '20px', fontWeight: 600, color: 'var(--text-white)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Sparkles size={20} color="var(--color-primary)" />
                <span>{aiStage === 'review' ? 'Revisar Perguntas da IA' : 'Gerar Perguntas com IA'}</span>
              </h3>
              <button 
                onClick={() => setShowAIModal(false)}
                disabled={aiGenerating}
                style={{ background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer' }}
              >
                <X size={20} />
              </button>
            </div>

            {/* Content */}
            {aiGenerating ? (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '60px 0', gap: '16px' }}>
                <div className="animate-spin" style={{
                  width: '40px',
                  height: '40px',
                  borderRadius: '50%',
                  border: '3px solid rgba(99, 102, 241, 0.1)',
                  borderTopColor: 'var(--color-primary)'
                }}></div>
                <span style={{ fontSize: '14px', color: 'var(--text-muted)' }}>
                  {aiStage === 'review' ? 'Salvando perguntas no banco de dados...' : 'Gemini AI está elaborando as perguntas...'}
                </span>
              </div>
            ) : aiStage === 'form' ? (
              <form onSubmit={handleGenerateWithAI} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                <div>
                  <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Tema do Quiz</label>
                  <input
                    type="text"
                    className="input"
                    placeholder="Ex: Prevenção a Engenharia Social ou Direitos na LGPD"
                    value={aiForm.tema}
                    onChange={(e) => setAIForm({ ...aiForm, tema: e.target.value })}
                    required
                  />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div>
                    <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Quantidade</label>
                    <select
                      value={aiForm.quantidade}
                      onChange={(e) => setAIForm({ ...aiForm, quantidade: parseInt(e.target.value) || 5 })}
                    >
                      <option value={5}>5</option>
                      <option value={10}>10</option>
                      <option value={15}>15</option>
                      <option value={20}>20</option>
                    </select>
                  </div>
                  <div>
                    <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Dificuldade</label>
                    <select
                      value={aiForm.dificuldade}
                      onChange={(e) => setAIForm({ ...aiForm, dificuldade: e.target.value as any })}
                    >
                      <option value="facil">Fácil</option>
                      <option value="medio">Médio</option>
                      <option value="dificil">Difícil</option>
                    </select>
                  </div>
                </div>

                <div>
                  <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Contexto Adicional (Opcional)</label>
                  <textarea
                    className="input"
                    placeholder="Ex: Focar na atuação do DPO e regras de consentimento. Evitar termos muito jurídicos."
                    value={aiForm.contexto}
                    onChange={(e) => setAIForm({ ...aiForm, contexto: e.target.value })}
                    rows={3}
                  />
                </div>

                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '12px' }}>
                  <button 
                    type="button" 
                    className="btn btn-secondary" 
                    onClick={() => setShowAIModal(false)}
                    style={{ border: '1px solid var(--border-color)' }}
                  >
                    Cancelar
                  </button>
                  <button type="submit" className="btn btn-primary">Gerar Perguntas</button>
                </div>
              </form>
            ) : (
              // Stage: Review
              <div style={{ display: 'flex', flexDirection: 'column', flex: 1, overflow: 'hidden' }}>
                <div style={{ 
                  overflowY: 'auto', 
                  flex: 1, 
                  paddingRight: '8px', 
                  display: 'flex', 
                  flexDirection: 'column', 
                  gap: '20px',
                  marginBottom: '24px'
                }}>
                  {generatedQuestions.map((q, qIdx) => (
                    <div key={qIdx} style={{
                      padding: '20px',
                      background: 'rgba(255, 255, 255, 0.01)',
                      border: '1px solid var(--border-color)',
                      borderRadius: 'var(--radius-sm)',
                      position: 'relative'
                    }}>
                      {/* Delete button */}
                      <button
                        onClick={() => {
                          const updated = [...generatedQuestions];
                          updated.splice(qIdx, 1);
                          setGeneratedQuestions(updated);
                        }}
                        style={{
                          position: 'absolute',
                          top: '16px',
                          right: '16px',
                          background: 'none',
                          border: 'none',
                          color: 'var(--status-error)',
                          cursor: 'pointer',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '4px',
                          fontSize: '12px'
                        }}
                        title="Excluir Pergunta"
                      >
                        <X size={16} />
                        <span>Remover</span>
                      </button>

                      {/* Question Text */}
                      <div style={{ marginBottom: '16px', paddingRight: '80px' }}>
                        <label style={{ fontSize: '11px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px', textTransform: 'uppercase' }}>
                          Pergunta {qIdx + 1}
                        </label>
                        <input
                          type="text"
                          className="input"
                          value={q.pergunta}
                          onChange={(e) => {
                            const updated = [...generatedQuestions];
                            updated[qIdx].pergunta = e.target.value;
                            setGeneratedQuestions(updated);
                          }}
                          style={{ fontWeight: 600 }}
                        />
                      </div>

                      {/* Alternatives */}
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '16px' }}>
                        <div>
                          <label style={{ fontSize: '11px', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Alternativa A</label>
                          <input
                            type="text"
                            className="input"
                            value={q.alternativa_a}
                            onChange={(e) => {
                              const updated = [...generatedQuestions];
                              updated[qIdx].alternativa_a = e.target.value;
                              setGeneratedQuestions(updated);
                            }}
                          />
                        </div>
                        <div>
                          <label style={{ fontSize: '11px', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Alternativa B</label>
                          <input
                            type="text"
                            className="input"
                            value={q.alternativa_b}
                            onChange={(e) => {
                              const updated = [...generatedQuestions];
                              updated[qIdx].alternativa_b = e.target.value;
                              setGeneratedQuestions(updated);
                            }}
                          />
                        </div>
                        <div>
                          <label style={{ fontSize: '11px', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Alternativa C</label>
                          <input
                            type="text"
                            className="input"
                            value={q.alternativa_c}
                            onChange={(e) => {
                              const updated = [...generatedQuestions];
                              updated[qIdx].alternativa_c = e.target.value;
                              setGeneratedQuestions(updated);
                            }}
                          />
                        </div>
                        <div>
                          <label style={{ fontSize: '11px', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Alternativa D</label>
                          <input
                            type="text"
                            className="input"
                            value={q.alternativa_d}
                            onChange={(e) => {
                              const updated = [...generatedQuestions];
                              updated[qIdx].alternativa_d = e.target.value;
                              setGeneratedQuestions(updated);
                            }}
                          />
                        </div>
                      </div>

                      {/* Correct Answer & Difficulty */}
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                        <div>
                          <label style={{ fontSize: '11px', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Resposta Correta</label>
                          <select
                            value={q.resposta_correta}
                            onChange={(e) => {
                              const updated = [...generatedQuestions];
                              updated[qIdx].resposta_correta = e.target.value as any;
                              setGeneratedQuestions(updated);
                            }}
                          >
                            <option value="A">Alternativa A</option>
                            <option value="B">Alternativa B</option>
                            <option value="C">Alternativa C</option>
                            <option value="D">Alternativa D</option>
                          </select>
                        </div>
                        <div>
                          <label style={{ fontSize: '11px', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Dificuldade</label>
                          <select
                            value={q.dificuldade}
                            onChange={(e) => {
                              const updated = [...generatedQuestions];
                              updated[qIdx].dificuldade = e.target.value as any;
                              setGeneratedQuestions(updated);
                            }}
                          >
                            <option value="facil">Fácil</option>
                            <option value="medio">Médio</option>
                            <option value="dificil">Difícil</option>
                          </select>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--border-color)', paddingTop: '20px' }}>
                  <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
                    Total: <strong>{generatedQuestions.length}</strong> perguntas para salvar
                  </span>
                  <div style={{ display: 'flex', gap: '12px' }}>
                    <button 
                      type="button" 
                      className="btn btn-secondary" 
                      onClick={() => setAIStage('form')}
                      style={{ border: '1px solid var(--border-color)' }}
                    >
                      Voltar
                    </button>
                    <button 
                      type="button" 
                      className="btn btn-primary" 
                      onClick={handleSaveAllAI}
                      disabled={generatedQuestions.length === 0}
                    >
                      Salvar todas
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
