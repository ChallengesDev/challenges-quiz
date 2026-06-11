import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { 
  Users, 
  BookOpen, 
  Activity, 
  Trophy, 
  ShieldAlert, 
  Award, 
  TrendingDown, 
  Lightbulb
} from 'lucide-react';
import { InteractiveChart } from '../components/InteractiveChart';

export const DashboardOverview: React.FC = () => {
  const [stats, setStats] = useState({
    colaboradoresAtivos: 142,
    quizzesCriados: 48,
    participacaoAtiva: '78%', // DAU/WAU ratio
    rankingGeral: '#4'
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchRealStats = async () => {
      try {
        setLoading(true);
        
        // 1. Contagem de Colaboradores Ativos
        const { count: usersCount, error: err1 } = await supabase
          .from('usuarios')
          .select('*', { count: 'exact', head: true })
          .eq('ativo', true);

        // 2. Contagem de Desafios/Quizzes Criados
        const { count: challengesCount, error: err2 } = await supabase
          .from('desafios')
          .select('*', { count: 'exact', head: true });

        // 3. Posição no Ranking Geral
        const { data: rankings, error: err3 } = await supabase
          .from('rankings')
          .select('posicao_geral')
          .limit(1);

        const newStats = { ...stats };
        if (usersCount !== null && !err1) newStats.colaboradoresAtivos = usersCount;
        if (challengesCount !== null && !err2) newStats.quizzesCriados = challengesCount;
        if (rankings && rankings.length > 0 && !err3) {
          newStats.rankingGeral = `#${rankings[0].posicao_geral}`;
        }

        setStats(newStats);
      } catch (err) {
        console.error('Erro ao buscar estatísticas do banco:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchRealStats();
  }, []);

  // Mock engagement chart data points (evolution of WAU)
  const engagementData = [
    { label: 'Seg', value: 65 },
    { label: 'Ter', value: 78 },
    { label: 'Qua', value: 84 },
    { label: 'Qui', value: 72 },
    { label: 'Sex', value: 78 },
    { label: 'Sáb', value: 45 },
    { label: 'Dom', value: 38 }
  ];

  // Mock department performance data points
  const deptPerformanceData = [
    { label: 'TI / Tecnologia', value: 89 },
    { label: 'Recursos Humanos', value: 82 },
    { label: 'Vendas & Mkt', value: 76 },
    { label: 'Compliance & Fin', value: 58 },
    { label: 'Operações', value: 71 }
  ];

  return (
    <div className="page-container animate-fade-in">
      {/* Title Header */}
      <div style={{ marginBottom: '32px' }}>
        <h3 style={{ fontSize: '14px', color: 'var(--color-primary)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Performance Corporativa {loading && <span style={{ fontSize: '11px', color: 'var(--color-primary)', textTransform: 'none' }}>(atualizando...)</span>}
        </h3>
        <h1 style={{ fontFamily: 'var(--font-heading)', fontSize: '28px', fontWeight: 700, color: 'var(--text-white)' }}>
          Olá, Gestor! Veja as novidades de hoje
        </h1>
      </div>

      {/* KPI Cards Grid */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
        gap: '24px',
        marginBottom: '32px'
      }}>
        {/* Card 1 - Colaboradores */}
        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
          <div style={{
            width: '48px',
            height: '48px',
            borderRadius: 'var(--radius-sm)',
            backgroundColor: 'rgba(99, 102, 241, 0.1)',
            color: 'var(--color-primary)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}>
            <Users size={24} />
          </div>
          <div>
            <div style={{ fontSize: '13px', color: 'var(--text-muted)' }}>Colaboradores Ativos</div>
            <div style={{ fontSize: '24px', fontWeight: 700, color: 'var(--text-white)', marginTop: '4px', fontFamily: 'var(--font-heading)' }}>
              {stats.colaboradoresAtivos}
            </div>
          </div>
        </div>

        {/* Card 2 - Quizzes */}
        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
          <div style={{
            width: '48px',
            height: '48px',
            borderRadius: 'var(--radius-sm)',
            backgroundColor: 'rgba(139, 92, 246, 0.1)',
            color: 'var(--color-accent)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}>
            <BookOpen size={24} />
          </div>
          <div>
            <div style={{ fontSize: '13px', color: 'var(--text-muted)' }}>Quizzes Criados</div>
            <div style={{ fontSize: '24px', fontWeight: 700, color: 'var(--text-white)', marginTop: '4px', fontFamily: 'var(--font-heading)' }}>
              {stats.quizzesCriados}
            </div>
          </div>
        </div>

        {/* Card 3 - DAU/WAU */}
        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
          <div style={{
            width: '48px',
            height: '48px',
            borderRadius: 'var(--radius-sm)',
            backgroundColor: 'rgba(6, 182, 212, 0.1)',
            color: 'var(--color-cyan)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}>
            <Activity size={24} />
          </div>
          <div>
            <div style={{ fontSize: '13px', color: 'var(--text-muted)' }}>Part. Ativa (DAU/WAU)</div>
            <div style={{ fontSize: '24px', fontWeight: 700, color: 'var(--text-white)', marginTop: '4px', fontFamily: 'var(--font-heading)' }}>
              {stats.participacaoAtiva}
            </div>
          </div>
        </div>

        {/* Card 4 - Ranking */}
        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
          <div style={{
            width: '48px',
            height: '48px',
            borderRadius: 'var(--radius-sm)',
            backgroundColor: 'rgba(16, 185, 129, 0.1)',
            color: 'var(--status-success)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}>
            <Trophy size={24} />
          </div>
          <div>
            <div style={{ fontSize: '13px', color: 'var(--text-muted)' }}>Ranking da Empresa</div>
            <div style={{ fontSize: '24px', fontWeight: 700, color: 'var(--status-success)', marginTop: '4px', fontFamily: 'var(--font-heading)' }}>
              {stats.rankingGeral}
            </div>
          </div>
        </div>
      </div>

      {/* Main Section: Charts & Insights */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(350px, 1fr))',
        gap: '24px',
        marginBottom: '32px'
      }}>
        {/* Left Side: Custom Interactive Charts */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          <InteractiveChart
            type="line"
            data={engagementData}
            title="Evolução de Engajamento Semanal (Part. %)"
            suffix="%"
            color="var(--color-primary)"
          />

          <InteractiveChart
            type="bar"
            data={deptPerformanceData}
            title="Taxa de Acertos por Departamento (%)"
            suffix="%"
            color="var(--color-accent)"
            color2="var(--color-primary)"
          />
        </div>

        {/* Right Side: AI Insights and Alerts */}
        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{
            fontFamily: 'var(--font-heading)',
            fontSize: '18px',
            fontWeight: 600,
            color: 'var(--text-white)',
            borderBottom: '1px solid var(--border-color)',
            paddingBottom: '14px',
            display: 'flex',
            alignItems: 'center',
            gap: '8px'
          }}>
            <Activity size={18} color="var(--color-primary)" />
            <span>Central de Insights Automáticos</span>
          </h3>

          {/* Alert 1: Compliance */}
          <div style={{
            display: 'flex',
            gap: '14px',
            padding: '16px',
            borderRadius: 'var(--radius-md)',
            background: 'rgba(239, 68, 68, 0.08)',
            border: '1px solid rgba(239, 68, 68, 0.15)'
          }}>
            <div style={{ color: 'var(--status-error)', flexShrink: 0 }}>
              <ShieldAlert size={20} />
            </div>
            <div>
              <div style={{ fontWeight: 600, fontSize: '14px', color: 'var(--text-white)' }}>Gap Crítico em Compliance</div>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px', lineHeight: '1.4' }}>
                O time de <strong>Compliance & Financeiro</strong> tem uma taxa de erro recorrente de 42% nas questões de LGPD e segurança da informação.
              </p>
            </div>
          </div>

          {/* Alert 2: High Potential */}
          <div style={{
            display: 'flex',
            gap: '14px',
            padding: '16px',
            borderRadius: 'var(--radius-md)',
            background: 'rgba(16, 185, 129, 0.08)',
            border: '1px solid rgba(16, 185, 129, 0.15)'
          }}>
            <div style={{ color: 'var(--status-success)', flexShrink: 0 }}>
              <Award size={20} />
            </div>
            <div>
              <div style={{ fontWeight: 600, fontSize: '14px', color: 'var(--text-white)' }}>Colaborador de Alto Potencial</div>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px', lineHeight: '1.4' }}>
                <strong>João Silva (TI)</strong> completou 12 desafios seguidos sem errar nenhuma pergunta. Potencial multiplicador de conhecimento!
              </p>
            </div>
          </div>

          {/* Alert 3: Drop in Engagement */}
          <div style={{
            display: 'flex',
            gap: '14px',
            padding: '16px',
            borderRadius: 'var(--radius-md)',
            background: 'rgba(245, 158, 11, 0.08)',
            border: '1px solid rgba(245, 158, 11, 0.15)'
          }}>
            <div style={{ color: 'var(--status-warning)', flexShrink: 0 }}>
              <TrendingDown size={20} />
            </div>
            <div>
              <div style={{ fontWeight: 600, fontSize: '14px', color: 'var(--text-white)' }}>Risco de Queda de Engajamento</div>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px', lineHeight: '1.4' }}>
                O <strong>Time Comercial</strong> apresentou uma queda de 18% no número de sessões ativas nesta semana em comparação à semana passada.
              </p>
            </div>
          </div>

          {/* Suggestion: LGPD Challenge */}
          <div style={{
            display: 'flex',
            gap: '14px',
            padding: '16px',
            borderRadius: 'var(--radius-md)',
            background: 'rgba(99, 102, 241, 0.08)',
            border: '1px solid rgba(99, 102, 241, 0.15)'
          }}>
            <div style={{ color: 'var(--color-primary)', flexShrink: 0 }}>
              <Lightbulb size={20} />
            </div>
            <div>
              <div style={{ fontWeight: 600, fontSize: '14px', color: 'var(--text-white)' }}>Sugestão de Ação Imediata</div>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px', lineHeight: '1.4' }}>
                Crie um desafio reforçado focado no tópico <strong>"Políticas de Cookies"</strong> para sanar a maior parte dos erros do mês.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
