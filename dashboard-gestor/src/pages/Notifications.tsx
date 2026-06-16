import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { 
  Bell, 
  Send, 
  History, 
  Settings, 
  RefreshCw, 
  Check, 
  AlertTriangle, 
  Clock, 
  Users, 
  Calendar,
  Layers,
  User,
  Info
} from 'lucide-react';

const API_URL = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';

interface NotificationHistoryItem {
  id: string;
  titulo: string;
  mensagem: string;
  tipo: 'novo_quiz' | 'conquista' | 'aviso' | 'motivacional';
  destinatario_tipo: 'todos' | 'time' | 'colaborador';
  destinatario_id?: string;
  destinatario_nome: string;
  status: 'enviada' | 'agendada' | 'falhou';
  agendado_para: string;
  criado_em: string;
}

interface TeamOption {
  id: string;
  nome: string;
}

interface UserOption {
  id: string;
  nome: string;
}

export const Notifications: React.FC = () => {
  const [companyId, setCompanyId] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(true);
  const [historyLoading, setHistoryLoading] = useState<boolean>(false);
  const [actionLoading, setActionLoading] = useState<boolean>(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  // Auto notification configurations
  const [configs, setConfigs] = useState({
    novo_quiz: true,
    subiu_nivel: true,
    streak_risco: true,
    ranking_atualizado: true,
    sem_acesso_3_dias: true
  });

  // History list
  const [history, setHistory] = useState<NotificationHistoryItem[]>([]);

  // Manual Notification Form State
  const [form, setForm] = useState({
    titulo: '',
    mensagem: '',
    tipo: 'aviso' as 'novo_quiz' | 'conquista' | 'aviso' | 'motivacional',
    destinatario_tipo: 'todos' as 'todos' | 'time' | 'colaborador',
    destinatario_id: '',
    agendar: false,
    data_agendamento: ''
  });

  // Recipients Options lists
  const [teams, setTeams] = useState<TeamOption[]>([]);
  const [users, setUsers] = useState<UserOption[]>([]);

  // Fetch companyId and initial lists
  useEffect(() => {
    const initialize = async () => {
      try {
        setLoading(true);
        const { data: { session } } = await supabase.auth.getSession();
        if (session) {
          const { data: profile } = await supabase
            .from('usuarios')
            .select('empresa_id')
            .eq('id', session.user.id)
            .single();

          if (profile?.empresa_id) {
            setCompanyId(profile.empresa_id);
            await loadSettings(profile.empresa_id);
            await loadHistory(profile.empresa_id);
            await loadRecipientOptions(profile.empresa_id);
          }
        }
      } catch (err: any) {
        console.error('Erro ao inicializar:', err);
        setMessage({ type: 'error', text: 'Não foi possível carregar as informações iniciais.' });
      } finally {
        setLoading(false);
      }
    };
    initialize();
  }, []);

  const loadSettings = async (compId: string) => {
    try {
      const response = await fetch(`${API_URL}/api/notifications/settings/${compId}`);
      if (response.ok) {
        const data = await response.json();
        setConfigs({
          novo_quiz: data.novo_quiz,
          subiu_nivel: data.subiu_nivel,
          streak_risco: data.streak_risco,
          ranking_atualizado: data.ranking_atualizado,
          sem_acesso_3_dias: data.sem_acesso_3_dias
        });
      }
    } catch (err) {
      console.warn('Erro ao carregar configurações via API. Buscando localmente:', err);
      // Fallback
      const { data } = await supabase
        .from('configuracoes_notificacoes')
        .select('*')
        .eq('empresa_id', compId)
        .maybeSingle();
      if (data) {
        setConfigs({
          novo_quiz: data.novo_quiz,
          subiu_nivel: data.subiu_nivel,
          streak_risco: data.streak_risco,
          ranking_atualizado: data.ranking_atualizado,
          sem_acesso_3_dias: data.sem_acesso_3_dias
        });
      }
    }
  };

  const loadHistory = async (compId: string) => {
    try {
      setHistoryLoading(true);
      const response = await fetch(`${API_URL}/api/notifications/history/${compId}`);
      if (response.ok) {
        const data = await response.json();
        setHistory(data);
      } else {
        throw new Error('Falha ao obter histórico da API');
      }
    } catch (err) {
      console.warn('Erro ao carregar histórico via API. Buscando localmente:', err);
      // Fallback query
      const { data } = await supabase
        .from('notificacoes')
        .select('*')
        .eq('empresa_id', compId)
        .order('criado_em', { ascending: false });

      if (data) {
        // Resolve names locally
        const { data: usersData } = await supabase.from('usuarios').select('id, nome').eq('empresa_id', compId);
        const { data: teamsData } = await supabase.from('times').select('id, nome');

        const userMap = new Map(usersData?.map(u => [u.id, u.nome]));
        const teamMap = new Map(teamsData?.map(t => [t.id, t.nome]));

        const resolved = data.map((n: any) => ({
          ...n,
          destinatario_nome: 
            n.destinatario_tipo === 'todos' ? 'Todos os colaboradores' :
            n.destinatario_tipo === 'time' ? `Time: ${teamMap.get(n.destinatario_id) || 'Desconhecido'}` :
            userMap.get(n.destinatario_id) || 'Desconhecido'
        }));
        setHistory(resolved);
      }
    } finally {
      setHistoryLoading(false);
    }
  };

  const loadRecipientOptions = async (compId: string) => {
    try {
      const { data: teamData } = await supabase.from('times').select('id, nome').order('nome');
      if (teamData) setTeams(teamData);

      const { data: userData } = await supabase
        .from('usuarios')
        .select('id, nome')
        .eq('empresa_id', compId)
        .eq('ativo', true)
        .order('nome');
      if (userData) setUsers(userData);
    } catch (err) {
      console.error('Erro ao carregar destinatários:', err);
    }
  };

  const handleToggleConfig = async (key: keyof typeof configs) => {
    const newVal = !configs[key];
    const oldConfigs = { ...configs };
    setConfigs({ ...configs, [key]: newVal });

    try {
      const response = await fetch(`${API_URL}/api/notifications/settings/${companyId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ [key]: newVal })
      });
      if (!response.ok) throw new Error();
      setMessage({ type: 'success', text: 'Configuração atualizada com sucesso!' });
    } catch (err) {
      setConfigs(oldConfigs); // Revert
      setMessage({ type: 'error', text: 'Não foi possível atualizar a configuração.' });
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.titulo || !form.mensagem) {
      setMessage({ type: 'error', text: 'Título e Mensagem são obrigatórios.' });
      return;
    }
    if (form.destinatario_tipo !== 'todos' && !form.destinatario_id) {
      setMessage({ type: 'error', text: 'Selecione um destinatário específico.' });
      return;
    }
    if (form.agendar && !form.data_agendamento) {
      setMessage({ type: 'error', text: 'Escolha uma data/hora para o agendamento.' });
      return;
    }

    try {
      setActionLoading(true);
      setMessage(null);

      const payload = {
        empresa_id: companyId,
        titulo: form.titulo,
        mensagem: form.mensagem,
        tipo: form.tipo,
        destinatario_tipo: form.destinatario_tipo,
        destinatario_id: form.destinatario_tipo === 'todos' ? null : form.destinatario_id,
        agendar_para: form.agendar ? new Date(form.data_agendamento).toISOString() : null
      };

      const response = await fetch(`${API_URL}/api/notifications/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      if (!response.ok) {
        throw new Error('Erro na resposta da API');
      }

      setMessage({ 
        type: 'success', 
        text: form.agendar ? 'Notificação agendada com sucesso!' : 'Notificação enviada com sucesso!' 
      });

      setForm({
        titulo: '',
        mensagem: '',
        tipo: 'aviso',
        destinatario_tipo: 'todos',
        destinatario_id: '',
        agendar: false,
        data_agendamento: ''
      });

      await loadHistory(companyId);
    } catch (err) {
      console.warn('Erro ao disparar pela API. Tentando inserção direta:', err);
      // Direct supabase insert fallback
      try {
        const directData = {
          empresa_id: companyId,
          titulo: form.titulo,
          mensagem: form.mensagem,
          tipo: form.tipo,
          destinatario_tipo: form.destinatario_tipo,
          destinatario_id: form.destinatario_tipo === 'todos' ? null : form.destinatario_id,
          status: form.agendar ? 'agendada' : 'enviada',
          agendado_para: form.agendar ? new Date(form.data_agendamento).toISOString() : new Date().toISOString()
        };

        const { error } = await supabase.from('notificacoes').insert(directData);
        if (error) throw error;

        setMessage({ type: 'success', text: '[Modo Local] Notificação criada!' });
        setForm({
          titulo: '',
          mensagem: '',
          tipo: 'aviso',
          destinatario_tipo: 'todos',
          destinatario_id: '',
          agendar: false,
          data_agendamento: ''
        });
        await loadHistory(companyId);
      } catch (directErr: any) {
        setMessage({ type: 'error', text: `Erro ao enviar: ${directErr.message || directErr}` });
      }
    } finally {
      setActionLoading(false);
    }
  };

  const handleResend = async (item: NotificationHistoryItem) => {
    if (!window.confirm(`Tem certeza que deseja reenviar a notificação "${item.titulo}" para todos os destinatários agora?`)) {
      return;
    }

    try {
      setActionLoading(true);
      const response = await fetch(`${API_URL}/api/notifications/resend/${item.id}`, {
        method: 'POST'
      });

      if (!response.ok) throw new Error();

      setMessage({ type: 'success', text: `Notificação "${item.titulo}" reenviada com sucesso!` });
      await loadHistory(companyId);
    } catch (err) {
      console.warn('Erro ao reenviar via API. Tentando reenvio direto:', err);
      try {
        const directData = {
          empresa_id: companyId,
          titulo: item.titulo,
          mensagem: item.mensagem,
          tipo: item.tipo,
          destinatario_tipo: item.destinatario_tipo,
          destinatario_id: item.destinatario_id,
          status: 'enviada',
          agendado_para: new Date().toISOString()
        };
        const { error } = await supabase.from('notificacoes').insert(directData);
        if (error) throw error;

        setMessage({ type: 'success', text: `[Modo Local] Notificação "${item.titulo}" reenviada!` });
        await loadHistory(companyId);
      } catch (directErr: any) {
        setMessage({ type: 'error', text: 'Não foi possível reenviar a notificação.' });
      }
    } finally {
      setActionLoading(false);
    }
  };

  const handleManualCheckAutomations = async () => {
    try {
      setActionLoading(true);
      setMessage(null);
      
      const response = await fetch(`${API_URL}/api/notifications/check-automations/${companyId}`, {
        method: 'POST'
      });
      
      if (!response.ok) throw new Error();
      const res = await response.json();
      
      setMessage({ 
        type: 'success', 
        text: `Verificação de automações concluída! Alertas de Streak: ${res.results?.streak_alerts || 0}. Alertas de Inatividade: ${res.results?.inactivity_alerts || 0}.` 
      });
      await loadHistory(companyId);
    } catch (err) {
      setMessage({ type: 'error', text: 'Não foi possível executar a verificação de automações.' });
    } finally {
      setActionLoading(false);
    }
  };

  const handleManualRefreshRanking = async () => {
    try {
      setActionLoading(true);
      setMessage(null);
      
      const response = await fetch(`${API_URL}/api/rankings/refresh/${companyId}`, {
        method: 'POST'
      });
      
      if (!response.ok) throw new Error();
      const res = await response.json();
      
      setMessage({ 
        type: 'success', 
        text: `${res.message} Colaboradores notificados: ${res.notified_top_3_count || 0}.` 
      });
      await loadHistory(companyId);
    } catch (err) {
      setMessage({ type: 'error', text: 'Não foi possível recalcular rankings.' });
    } finally {
      setActionLoading(false);
    }
  };

  const formatDateTime = (dateStr: string) => {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    return date.toLocaleString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getTipoBadgeClass = (tipo: string) => {
    switch (tipo) {
      case 'novo_quiz': return 'badge-info';
      case 'conquista': return 'badge-success';
      case 'aviso': return 'badge-danger';
      case 'motivacional': return 'badge-warning';
      default: return 'badge-info';
    }
  };

  const getTipoLabel = (tipo: string) => {
    switch (tipo) {
      case 'novo_quiz': return 'Novo Quiz';
      case 'conquista': return 'Conquista';
      case 'aviso': return 'Aviso';
      case 'motivacional': return 'Motivacional';
      default: return tipo;
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'enviada': return <span className="badge badge-success" style={{ gap: '4px', display: 'inline-flex', alignItems: 'center' }}><Check size={11} /> Enviada</span>;
      case 'agendada': return <span className="badge badge-info" style={{ gap: '4px', display: 'inline-flex', alignItems: 'center', background: 'rgba(6, 182, 212, 0.15)', color: 'var(--color-cyan)' }}><Clock size={11} /> Agendada</span>;
      case 'falhou': return <span className="badge badge-danger" style={{ gap: '4px', display: 'inline-flex', alignItems: 'center' }}><AlertTriangle size={11} /> Falhou</span>;
      default: return <span className="badge">{status}</span>;
    }
  };

  if (loading) {
    return (
      <div style={{ color: 'var(--text-muted)', textAlign: 'center', padding: '48px' }}>
        Carregando painel de notificações...
      </div>
    );
  }

  return (
    <div className="page-container animate-fade-in">
      {/* Title */}
      <div style={{ marginBottom: '32px', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div>
          <h3 style={{ fontSize: '14px', color: 'var(--color-primary)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Comunicação e Engajamento
          </h3>
          <h1 style={{ fontFamily: 'var(--font-heading)', fontSize: '28px', fontWeight: 700, color: 'var(--text-white)' }}>
            Central de Notificações
          </h1>
        </div>

        {/* Manual Check Buttons */}
        <div style={{ display: 'flex', gap: '12px' }}>
          <button 
            onClick={handleManualCheckAutomations}
            disabled={actionLoading}
            className="btn btn-secondary"
            title="Verifica inatividade de 3 dias e streaks em risco manualmente"
            style={{ fontSize: '13px', display: 'flex', alignItems: 'center', gap: '6px' }}
          >
            <RefreshCw size={14} className={actionLoading ? 'animate-spin' : ''} />
            <span>Verificar Inatividade/Streaks</span>
          </button>
          <button 
            onClick={handleManualRefreshRanking}
            disabled={actionLoading}
            className="btn btn-secondary"
            title="Recalcula rankings das ligas e avisa o top 3 da semana"
            style={{ fontSize: '13px', display: 'flex', alignItems: 'center', gap: '6px' }}
          >
            <RefreshCw size={14} className={actionLoading ? 'animate-spin' : ''} />
            <span>Recalcular Rankings (Top 3)</span>
          </button>
        </div>
      </div>

      {/* Message alert */}
      {message && (
        <div style={{
          padding: '14px 18px',
          borderRadius: 'var(--radius-sm)',
          fontSize: '14px',
          fontWeight: 500,
          marginBottom: '28px',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          backgroundColor: message.type === 'success' ? 'rgba(16, 185, 129, 0.1)' : 'rgba(239, 68, 68, 0.1)',
          border: `1px solid ${message.type === 'success' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(239, 68, 68, 0.2)'}`,
          color: message.type === 'success' ? 'var(--status-success)' : 'var(--status-error)',
          boxShadow: 'var(--shadow-sm)'
        }}>
          <span>{message.text}</span>
          <button onClick={() => setMessage(null)} style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer', display: 'flex' }}>
            &times;
          </button>
        </div>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.3fr', gap: '32px', alignItems: 'start' }}>
        {/* LEFT COLUMN: Automations and Form */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '32px' }}>
          
          {/* Card 1: Automatic Notifications */}
          <div className="card">
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: 'var(--text-white)', marginBottom: '18px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Settings size={18} color="var(--color-primary)" />
              <span>Notificações Automáticas</span>
            </h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '13px', marginBottom: '20px', lineHeight: '1.4' }}>
              Defina quais eventos gerarão alertas e felicitações automáticas para os colaboradores da empresa.
            </p>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              {/* Setting 1: Novo quiz */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingBottom: '12px', borderBottom: '1px solid rgba(255, 255, 255, 0.05)' }}>
                <div>
                  <div style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-white)' }}>Novo quiz disponível</div>
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Notifica colaboradores automaticamente quando novos quizzes forem publicados.</div>
                </div>
                <input
                  type="checkbox"
                  checked={configs.novo_quiz}
                  onChange={() => handleToggleConfig('novo_quiz')}
                  style={{ width: '36px', height: '18px', cursor: 'pointer' }}
                />
              </div>

              {/* Setting 2: Nivel up */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingBottom: '12px', borderBottom: '1px solid rgba(255, 255, 255, 0.05)' }}>
                <div>
                  <div style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-white)' }}>Parabenizar por nível</div>
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Envia mensagem de parabéns automática quando o usuário sobe de nível.</div>
                </div>
                <input
                  type="checkbox"
                  checked={configs.subiu_nivel}
                  onChange={() => handleToggleConfig('subiu_nivel')}
                  style={{ width: '36px', height: '18px', cursor: 'pointer' }}
                />
              </div>

              {/* Setting 3: Streak em risco */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingBottom: '12px', borderBottom: '1px solid rgba(255, 255, 255, 0.05)' }}>
                <div>
                  <div style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-white)' }}>Aviso de streak em risco</div>
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Alerta o colaborador que ele está prestes a perder o streak se não jogar hoje.</div>
                </div>
                <input
                  type="checkbox"
                  checked={configs.streak_risco}
                  onChange={() => handleToggleConfig('streak_risco')}
                  style={{ width: '36px', height: '18px', cursor: 'pointer' }}
                />
              </div>

              {/* Setting 4: Top 3 ranking */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingBottom: '12px', borderBottom: '1px solid rgba(255, 255, 255, 0.05)' }}>
                <div>
                  <div style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-white)' }}>Ranking atualizado (Top 3)</div>
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Parabeniza automaticamente os top 3 melhores colocados na liga da semana.</div>
                </div>
                <input
                  type="checkbox"
                  checked={configs.ranking_atualizado}
                  onChange={() => handleToggleConfig('ranking_atualizado')}
                  style={{ width: '36px', height: '18px', cursor: 'pointer' }}
                />
              </div>

              {/* Setting 5: Inatividade */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <div style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-white)' }}>Lembrete de inatividade</div>
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Notifica colaboradores que não acessam o portal por 3 dias consecutivos.</div>
                </div>
                <input
                  type="checkbox"
                  checked={configs.sem_acesso_3_dias}
                  onChange={() => handleToggleConfig('sem_acesso_3_dias')}
                  style={{ width: '36px', height: '18px', cursor: 'pointer' }}
                />
              </div>
            </div>
          </div>

          {/* Card 2: Send Manual Notification */}
          <div className="card">
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: 'var(--text-white)', marginBottom: '18px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Send size={18} color="var(--color-accent)" />
              <span>Nova Notificação Manual</span>
            </h3>

            <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              
              <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 0.8fr', gap: '16px' }}>
                {/* Title */}
                <div>
                  <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Título</label>
                  <input
                    type="text"
                    className="input"
                    placeholder="Ex: Treinamento Obrigatório"
                    value={form.titulo}
                    onChange={(e) => setForm({ ...form, titulo: e.target.value })}
                    maxLength={60}
                    required
                  />
                </div>
                {/* Type */}
                <div>
                  <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Tipo</label>
                  <select
                    value={form.tipo}
                    onChange={(e) => setForm({ ...form, tipo: e.target.value as any })}
                  >
                    <option value="aviso">Aviso</option>
                    <option value="novo_quiz">Novo Quiz</option>
                    <option value="conquista">Conquista</option>
                    <option value="motivacional">Motivacional</option>
                  </select>
                </div>
              </div>

              {/* Message */}
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Mensagem</label>
                <textarea
                  className="input"
                  placeholder="Escreva a mensagem clara para os colaboradores..."
                  value={form.mensagem}
                  onChange={(e) => setForm({ ...form, mensagem: e.target.value })}
                  rows={3}
                  maxLength={250}
                  required
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                {/* Recipient Type */}
                <div>
                  <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Destinatário</label>
                  <select
                    value={form.destinatario_tipo}
                    onChange={(e) => setForm({ ...form, destinatario_tipo: e.target.value as any, destinatario_id: '' })}
                  >
                    <option value="todos">Todos os colaboradores</option>
                    <option value="time">Um time específico</option>
                    <option value="colaborador">Um colaborador específico</option>
                  </select>
                </div>

                {/* Recipient ID selection */}
                {form.destinatario_tipo !== 'todos' && (
                  <div>
                    <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>
                      {form.destinatario_tipo === 'time' ? 'Selecione o Time' : 'Selecione o Colaborador'}
                    </label>
                    <select
                      value={form.destinatario_id}
                      onChange={(e) => setForm({ ...form, destinatario_id: e.target.value })}
                      required
                    >
                      <option value="">Selecione...</option>
                      {form.destinatario_tipo === 'time' 
                        ? teams.map(t => <option key={t.id} value={t.id}>{t.nome}</option>)
                        : users.map(u => <option key={u.id} value={u.id}>{u.nome}</option>)
                      }
                    </select>
                  </div>
                )}
              </div>

              {/* Scheduling settings */}
              <div style={{ background: 'rgba(255,255,255,0.02)', padding: '12px 16px', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-color)' }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '14px', cursor: 'pointer', color: 'var(--text-main)' }}>
                  <input
                    type="checkbox"
                    checked={form.agendar}
                    onChange={(e) => setForm({ ...form, agendar: e.target.checked })}
                    style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                  />
                  <span>Agendar envio para data futura</span>
                </label>
                
                {form.agendar && (
                  <div style={{ marginTop: '12px' }}>
                    <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Enviar em:</label>
                    <input
                      type="datetime-local"
                      className="input"
                      value={form.data_agendamento}
                      onChange={(e) => setForm({ ...form, data_agendamento: e.target.value })}
                      required
                    />
                  </div>
                )}
              </div>

              {/* Submit */}
              <button 
                type="submit" 
                disabled={actionLoading}
                className="btn btn-primary"
                style={{ width: '100%', gap: '10px', padding: '12px' }}
              >
                <Bell size={16} />
                <span>{form.agendar ? 'Agendar Notificação' : 'Enviar Notificação Agora'}</span>
              </button>
            </form>
          </div>

        </div>

        {/* RIGHT COLUMN: History of Sent Notifications */}
        <div className="card" style={{ height: '100%', minHeight: '600px', display: 'flex', flexDirection: 'column' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: 'var(--text-white)', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <History size={18} color="var(--color-cyan)" />
              <span>Histórico de Envio</span>
            </h3>
            
            <button 
              onClick={() => loadHistory(companyId)}
              disabled={historyLoading}
              className="btn btn-secondary"
              style={{ padding: '6px 12px', fontSize: '12px', display: 'flex', gap: '6px' }}
            >
              <RefreshCw size={12} className={historyLoading ? 'animate-spin' : ''} />
              <span>Atualizar</span>
            </button>
          </div>

          {historyLoading ? (
            <div style={{ color: 'var(--text-muted)', textAlign: 'center', padding: '48px', flexGrow: 1 }}>
              Carregando histórico...
            </div>
          ) : history.length === 0 ? (
            <div style={{ 
              color: 'var(--text-muted)', 
              textAlign: 'center', 
              padding: '64px 24px', 
              flexGrow: 1, 
              display: 'flex', 
              flexDirection: 'column', 
              justifyContent: 'center',
              alignItems: 'center',
              gap: '12px'
            }}>
              <Info size={32} style={{ opacity: 0.3 }} />
              <div>Nenhuma notificação enviada ou agendada ainda.</div>
            </div>
          ) : (
            <div className="table-container" style={{ flexGrow: 1, maxHeight: '680px', overflowY: 'auto' }}>
              <table className="table">
                <thead>
                  <tr>
                    <th>Notificação</th>
                    <th>Destinatário</th>
                    <th>Data</th>
                    <th>Status</th>
                    <th style={{ textAlign: 'center' }}>Ação</th>
                  </tr>
                </thead>
                <tbody>
                  {history.map((h) => (
                    <tr key={h.id}>
                      <td style={{ maxWidth: '240px' }}>
                        <div style={{ fontWeight: 600, color: 'var(--text-white)', marginBottom: '4px', textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }} title={h.titulo}>
                          {h.titulo}
                        </div>
                        <div style={{ fontSize: '12px', color: 'var(--text-muted)', textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }} title={h.mensagem}>
                          {h.mensagem}
                        </div>
                        <div style={{ marginTop: '6px' }}>
                          <span className={`badge ${getTipoBadgeClass(h.tipo)}`} style={{ fontSize: '9px' }}>
                            {getTipoLabel(h.tipo)}
                          </span>
                        </div>
                      </td>
                      <td style={{ fontSize: '13px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          {h.destinatario_tipo === 'todos' && <Users size={12} style={{ color: 'var(--color-primary)' }} />}
                          {h.destinatario_tipo === 'time' && <Layers size={12} style={{ color: 'var(--color-accent)' }} />}
                          {h.destinatario_tipo === 'colaborador' && <User size={12} style={{ color: 'var(--color-cyan)' }} />}
                          <span style={{ fontWeight: 500 }}>{h.destinatario_nome}</span>
                        </div>
                      </td>
                      <td style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                          <Calendar size={11} />
                          <span>{formatDateTime(h.agendado_para)}</span>
                        </div>
                      </td>
                      <td>{getStatusBadge(h.status)}</td>
                      <td style={{ textAlign: 'center' }}>
                        <button
                          onClick={() => handleResend(h)}
                          disabled={actionLoading}
                          className="btn btn-secondary"
                          style={{ padding: '6px 12px', fontSize: '12px' }}
                          title="Reenviar esta notificação agora"
                        >
                          Reenviar
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

      </div>
    </div>
  );
};
