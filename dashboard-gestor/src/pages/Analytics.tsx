import React, { useState } from 'react';
import { 
  UserCheck, 
  Clock, 
  Coins, 
  Database
} from 'lucide-react';
import { InteractiveChart } from '../components/InteractiveChart';

interface CollaboratorXP {
  nome: string;
  history: { label: string; value: number }[];
}

export const Analytics: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'analytics' | 'gaps' | 'roi'>('analytics');
  const [selectedColab, setSelectedColab] = useState<string>('João Silva');

  // ROI Calculator States
  const [roiInputs, setRoiInputs] = useState({
    custoTreinamento: 5000,
    numParticipantes: 100,
    horasPoupadasMes: 4,
    custoHoraMedio: 45
  });

  // Calculate ROI
  const ganhoProdutividadeAnual = roiInputs.numParticipantes * roiInputs.horasPoupadasMes * 12 * roiInputs.custoHoraMedio;
  const roiCalculado = roiInputs.custoTreinamento > 0 
    ? ((ganhoProdutividadeAnual - roiInputs.custoTreinamento) / roiInputs.custoTreinamento) * 100
    : 0;

  // Mock data for graphs
  const knowledgeGapData = [
    { label: 'Políticas de Cookies', value: 45 },
    { label: 'Anticorrupção', value: 38 },
    { label: 'Engenharia Social', value: 32 },
    { label: 'Direitos Titulares LGPD', value: 28 },
    { label: 'Backup e Senhas', value: 25 }
  ];

  const deptParticipationData = [
    { label: 'TI / Tecnologia', value: 92 },
    { label: 'RH', value: 85 },
    { label: 'Vendas & Mkt', value: 78 },
    { label: 'Compliance & Fin', value: 64 },
    { label: 'Operações', value: 70 }
  ];

  const wauEvolutionData = [
    { label: 'Sem 1', value: 120 },
    { label: 'Sem 2', value: 128 },
    { label: 'Sem 3', value: 135 },
    { label: 'Sem 4', value: 142 }
  ];

  const retentionData = [
    { label: '30 Dias', value: 94 },
    { label: '60 Dias', value: 88 },
    { label: '90 Dias', value: 82 }
  ];

  // Learning curve mock by collaborator
  const collaboratorCurves: { [key: string]: CollaboratorXP } = {
    'João Silva': {
      nome: 'João Silva',
      history: [
        { label: 'Sem 1', value: 200 },
        { label: 'Sem 2', value: 450 },
        { label: 'Sem 3', value: 800 },
        { label: 'Sem 4', value: 1200 }
      ]
    },
    'Maria Santos': {
      nome: 'Maria Santos',
      history: [
        { label: 'Sem 1', value: 150 },
        { label: 'Sem 2', value: 350 },
        { label: 'Sem 3', value: 680 },
        { label: 'Sem 4', value: 980 }
      ]
    },
    'Pedro Alencar': {
      nome: 'Pedro Alencar',
      history: [
        { label: 'Sem 1', value: 100 },
        { label: 'Sem 2', value: 220 },
        { label: 'Sem 3', value: 400 },
        { label: 'Sem 4', value: 550 }
      ]
    }
  };

  const selectedCurve = collaboratorCurves[selectedColab] || collaboratorCurves['João Silva'];

  return (
    <div className="page-container animate-fade-in">
      {/* Header */}
      <div style={{ marginBottom: '32px' }}>
        <h3 style={{ fontSize: '14px', color: 'var(--color-primary)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Métricas e ROI
        </h3>
        <h1 style={{ fontFamily: 'var(--font-heading)', fontSize: '28px', fontWeight: 700, color: 'var(--text-white)' }}>
          Analytics & Insights Profundos
        </h1>
      </div>

      {/* Tabs Menu */}
      <div style={{
        display: 'flex',
        borderBottom: '1px solid var(--border-color)',
        gap: '24px',
        marginBottom: '24px'
      }}>
        <button
          onClick={() => setActiveTab('analytics')}
          style={{
            background: 'none',
            border: 'none',
            padding: '12px 4px',
            color: activeTab === 'analytics' ? 'var(--color-primary)' : 'var(--text-muted)',
            borderBottom: activeTab === 'analytics' ? '2px solid var(--color-primary)' : '2px solid transparent',
            fontWeight: activeTab === 'analytics' ? 600 : 500,
            fontSize: '14px',
            cursor: 'pointer'
          }}
        >
          Engajamento & Retenção
        </button>
        <button
          onClick={() => setActiveTab('gaps')}
          style={{
            background: 'none',
            border: 'none',
            padding: '12px 4px',
            color: activeTab === 'gaps' ? 'var(--color-primary)' : 'var(--text-muted)',
            borderBottom: activeTab === 'gaps' ? '2px solid var(--color-primary)' : '2px solid transparent',
            fontWeight: activeTab === 'gaps' ? 600 : 500,
            fontSize: '14px',
            cursor: 'pointer'
          }}
        >
          Gaps de Conhecimento
        </button>
        <button
          onClick={() => setActiveTab('roi')}
          style={{
            background: 'none',
            border: 'none',
            padding: '12px 4px',
            color: activeTab === 'roi' ? 'var(--color-primary)' : 'var(--text-muted)',
            borderBottom: activeTab === 'roi' ? '2px solid var(--color-primary)' : '2px solid transparent',
            fontWeight: activeTab === 'roi' ? 600 : 500,
            fontSize: '14px',
            cursor: 'pointer'
          }}
        >
          Calculadora de ROI do Treinamento
        </button>
      </div>

      {/* Tab 1 - General Analytics & Engagement */}
      {activeTab === 'analytics' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          {/* Top Cards (Metrics) */}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
            gap: '24px'
          }}>
            <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
              <div style={{ color: 'var(--color-primary)' }}><Clock size={28} /></div>
              <div>
                <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Tempo Médio de Sessão</div>
                <div style={{ fontSize: '20px', fontWeight: 'bold', color: '#fff', marginTop: '2px' }}>7min 42s</div>
              </div>
            </div>

            <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
              <div style={{ color: 'var(--status-success)' }}><UserCheck size={28} /></div>
              <div>
                <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Média Acertos Semanal</div>
                <div style={{ fontSize: '20px', fontWeight: 'bold', color: '#fff', marginTop: '2px' }}>76.4%</div>
              </div>
            </div>

            <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
              <div style={{ color: 'var(--color-cyan)' }}><Database size={28} /></div>
              <div>
                <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Integridade dos Dados</div>
                <div style={{ fontSize: '20px', fontWeight: 'bold', color: '#fff', marginTop: '2px' }}>98.2%</div>
              </div>
            </div>
          </div>

          {/* Charts Row */}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
            gap: '24px'
          }}>
            <InteractiveChart
              type="line"
              data={wauEvolutionData}
              title="Evolução de Colaboradores Ativos Semanais (WAU)"
              color="var(--color-cyan)"
            />

            <InteractiveChart
              type="bar"
              data={retentionData}
              title="Taxa de Retenção de Aprendizado (%)"
              suffix="%"
              color="var(--color-accent)"
            />
          </div>
        </div>
      )}

      {/* Tab 2 - Knowledge Gaps & Learning Curves */}
      {activeTab === 'gaps' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '24px' }}>
          {/* Knowledge Gap Index */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
            <InteractiveChart
              type="bar"
              data={knowledgeGapData}
              title="Knowledge Gap Index (% de Erros Recorrentes)"
              suffix="%"
              color="var(--status-error)"
              color2="var(--status-warning)"
            />

            {/* Department Participation */}
            <InteractiveChart
              type="doughnut"
              data={deptParticipationData}
              title="Taxa de Participação por Departamento (%)"
              suffix="%"
            />
          </div>

          {/* Learning Curve per Collaborator */}
          <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: '#fff', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px' }}>
              Curva de Aprendizado Individual
            </h3>

            {/* Selector */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>Selecionar Colaborador:</span>
              <select
                value={selectedColab}
                onChange={(e) => setSelectedColab(e.target.value)}
                style={{ maxWidth: '200px' }}
              >
                <option value="João Silva">João Silva</option>
                <option value="Maria Santos">Maria Santos</option>
                <option value="Pedro Alencar">Pedro Alencar</option>
              </select>
            </div>

            {/* Sub chart mapping selected user */}
            <div style={{ flexGrow: 1 }}>
              <InteractiveChart
                type="line"
                data={selectedCurve.history}
                title={`Progresso de XP Acumulado: ${selectedCurve.nome}`}
                color="var(--color-accent)"
                suffix=" XP"
              />
            </div>

            <div style={{
              padding: '12px',
              background: 'rgba(255, 255, 255, 0.02)',
              border: '1px solid var(--border-color)',
              borderRadius: 'var(--radius-sm)',
              fontSize: '12px',
              color: 'var(--text-muted)'
            }}>
              A curva de aprendizado projeta a velocidade de absorção de novos conteúdos baseado no XP adquirido em quizzes corretos versus tempo decorrido.
            </div>
          </div>
        </div>
      )}

      {/* Tab 3 - Training ROI Calculator */}
      {activeTab === 'roi' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '24px' }}>
          {/* Inputs Card */}
          <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: '#fff', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Coins size={20} color="var(--color-primary)" />
              <span>Parâmetros de Investimento</span>
            </h3>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Custo Total do Treinamento (R$)</label>
                <input
                  type="number"
                  className="input"
                  value={roiInputs.custoTreinamento}
                  onChange={(e) => setRoiInputs({ ...roiInputs, custoTreinamento: parseFloat(e.target.value) || 0 })}
                />
              </div>

              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Número de Colaboradores Ativos</label>
                <input
                  type="number"
                  className="input"
                  value={roiInputs.numParticipantes}
                  onChange={(e) => setRoiInputs({ ...roiInputs, numParticipantes: parseInt(e.target.value) || 0 })}
                />
              </div>

              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Horas de Produtividade Salvas / Mês por Pessoa</label>
                <input
                  type="number"
                  className="input"
                  value={roiInputs.horasPoupadasMes}
                  onChange={(e) => setRoiInputs({ ...roiInputs, horasPoupadasMes: parseFloat(e.target.value) || 0 })}
                />
              </div>

              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Custo Médio da Hora do Colaborador (R$)</label>
                <input
                  type="number"
                  className="input"
                  value={roiInputs.custoHoraMedio}
                  onChange={(e) => setRoiInputs({ ...roiInputs, custoHoraMedio: parseFloat(e.target.value) || 0 })}
                />
              </div>
            </div>
          </div>

          {/* Calculation and Results */}
          <div className="card animate-fade-in" style={{
            background: 'linear-gradient(135deg, var(--bg-card) 0%, rgba(99, 102, 241, 0.05) 100%)',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
            textAlign: 'center',
            padding: '40px 24px',
            gap: '16px'
          }}>
            <h4 style={{ fontSize: '14px', textTransform: 'uppercase', color: 'var(--color-primary)', fontWeight: 600, letterSpacing: '0.1em' }}>
              ROI Projetado (Anual)
            </h4>
            <div style={{
              fontSize: '48px',
              fontFamily: 'var(--font-heading)',
              fontWeight: 800,
              color: roiCalculado >= 0 ? 'var(--status-success)' : 'var(--status-error)',
              textShadow: '0 0 15px rgba(16, 185, 129, 0.2)'
            }}>
              {roiCalculado.toFixed(1)}%
            </div>
            
            <div style={{ width: '100%', height: '1px', backgroundColor: 'var(--border-color)', margin: '12px 0' }}></div>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', width: '100%' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
                <span style={{ color: 'var(--text-muted)' }}>Ganho Anual Estimado:</span>
                <strong style={{ color: '#fff' }}>R$ {ganhoProdutividadeAnual.toLocaleString('pt-BR')}</strong>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
                <span style={{ color: 'var(--text-muted)' }}>Investimento Inicial:</span>
                <strong style={{ color: '#fff' }}>R$ {roiInputs.custoTreinamento.toLocaleString('pt-BR')}</strong>
              </div>
            </div>

            <div style={{
              marginTop: '16px',
              padding: '12px',
              backgroundColor: 'rgba(255, 255, 255, 0.02)',
              borderRadius: 'var(--radius-sm)',
              fontSize: '11px',
              color: 'var(--text-muted)',
              lineHeight: '1.4'
            }}>
              Fórmula de ROI: <code>(Ganho de Produtividade - Custo do Treinamento) / Custo do Treinamento * 100</code>. O ganho estima menos horas perdidas por erros técnicos ou operacionais.
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
