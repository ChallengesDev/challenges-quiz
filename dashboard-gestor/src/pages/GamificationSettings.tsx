import React, { useState } from 'react';
import { 
  Award, 
  Settings, 
  MessageSquareHeart, 
  Trophy, 
  Save, 
  Plus, 
  Check, 
  ToggleLeft, 
  ToggleRight 
} from 'lucide-react';

interface Mission {
  id: string;
  titulo: string;
  requisito: string;
  xp_recompensa: number;
}

export const GamificationSettings: React.FC = () => {
  const [message, setMessage] = useState<string | null>(null);

  // Settings states
  const [xpRules, setXpRules] = useState({
    facil: 50,
    medio: 100,
    dificil: 200,
    streakBonus: 15
  });

  const [rankingsActive, setRankingsActive] = useState(true);

  const [motivationalMessage, setMotivationalMessage] = useState(
    'Excelente trabalho! Cada quiz respondido é um passo rumo à excelência.'
  );

  const [missions, setMissions] = useState<Mission[]>([
    { id: '1', titulo: 'Maratonista de Compliance', requisito: 'Concluir 3 quizzes de Compliance na semana', xp_recompensa: 150 },
    { id: '2', titulo: 'Semana Anti-Phishing', requisito: 'Acertar todas as perguntas de Segurança Digital', xp_recompensa: 300 }
  ]);

  const [newMission, setNewMission] = useState({
    titulo: '',
    requisito: '',
    xp_recompensa: 100
  });

  const handleSaveXpRules = (e: React.FormEvent) => {
    e.preventDefault();
    setMessage('Regras de pontuação salvas com sucesso!');
    setTimeout(() => setMessage(null), 3000);
  };

  const handleCreateMission = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMission.titulo || !newMission.requisito) return;

    const missionRecord: Mission = {
      id: Math.random().toString(36).substring(7),
      titulo: newMission.titulo,
      requisito: newMission.requisito,
      xp_recompensa: newMission.xp_recompensa
    };

    setMissions([...missions, missionRecord]);
    setNewMission({ titulo: '', requisito: '', xp_recompensa: 100 });
    setMessage('Nova missão criada e ativada!');
    setTimeout(() => setMessage(null), 3000);
  };

  const handleSaveMotivMessage = (e: React.FormEvent) => {
    e.preventDefault();
    setMessage('Mensagem motivacional atualizada para o App do Colaborador!');
    setTimeout(() => setMessage(null), 3000);
  };

  return (
    <div className="page-container animate-fade-in">
      {/* Title */}
      <div style={{ marginBottom: '32px' }}>
        <h3 style={{ fontSize: '14px', color: 'var(--color-primary)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Engajamento e Recompensa
        </h3>
        <h1 style={{ fontFamily: 'var(--font-heading)', fontSize: '28px', fontWeight: 700, color: 'var(--text-white)' }}>
          Configurações de Gamificação
        </h1>
      </div>

      {/* Success feedback */}
      {message && (
        <div style={{
          padding: '12px 18px',
          borderRadius: 'var(--radius-sm)',
          fontSize: '14px',
          fontWeight: 500,
          marginBottom: '24px',
          backgroundColor: 'rgba(16, 185, 129, 0.1)',
          border: '1px solid rgba(16, 185, 129, 0.2)',
          color: 'var(--status-success)',
          display: 'flex',
          alignItems: 'center',
          gap: '8px'
        }}>
          <Check size={18} />
          <span>{message}</span>
        </div>
      )}

      {/* Settings Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '24px' }}>
        
        {/* Rules & Rankings Config */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          
          {/* Rules Card */}
          <div className="card">
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: '#fff', marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Settings size={18} color="var(--color-primary)" />
              <span>Regras de Pontuação (XP)</span>
            </h3>

            <form onSubmit={handleSaveXpRules} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Quiz Fácil</label>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <input
                    type="number"
                    className="input"
                    value={xpRules.facil}
                    onChange={(e) => setXpRules({ ...xpRules, facil: parseInt(e.target.value) || 0 })}
                  />
                  <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>XP</span>
                </div>
              </div>

              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Quiz Médio</label>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <input
                    type="number"
                    className="input"
                    value={xpRules.medio}
                    onChange={(e) => setXpRules({ ...xpRules, medio: parseInt(e.target.value) || 0 })}
                  />
                  <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>XP</span>
                </div>
              </div>

              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Quiz Difícil</label>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <input
                    type="number"
                    className="input"
                    value={xpRules.dificil}
                    onChange={(e) => setXpRules({ ...xpRules, dificil: parseInt(e.target.value) || 0 })}
                  />
                  <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>XP</span>
                </div>
              </div>

              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Bônus por Streak Diário</label>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <input
                    type="number"
                    className="input"
                    value={xpRules.streakBonus}
                    onChange={(e) => setXpRules({ ...xpRules, streakBonus: parseInt(e.target.value) || 0 })}
                  />
                  <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>XP/dia</span>
                </div>
              </div>

              <button type="submit" className="btn btn-primary" style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
                <Save size={16} />
                <span>Salvar Regras</span>
              </button>
            </form>
          </div>

          {/* Toggle Rankings Card */}
          <div className="card">
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: '#fff', marginBottom: '14px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Trophy size={18} color="var(--color-accent)" />
              <span>Rankings Corporativos</span>
            </h3>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '20px', lineHeight: '1.4' }}>
              Ao ativar esta chave, os colaboradores poderão ver os rankings geral e por departamento no App móvel. Desative se preferir um modelo focado apenas em aprendizado individual.
            </p>

            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px', background: 'rgba(255, 255, 255, 0.01)', border: '1px solid var(--border-color)', borderRadius: 'var(--radius-sm)' }}>
              <div>
                <div style={{ fontWeight: 600, fontSize: '14px', color: '#fff' }}>Exibição de Rankings</div>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>Geral, times e departamentos</div>
              </div>
              <button
                onClick={() => setRankingsActive(!rankingsActive)}
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: rankingsActive ? 'var(--status-success)' : 'var(--text-muted)' }}
              >
                {rankingsActive ? <ToggleRight size={36} /> : <ToggleLeft size={36} />}
              </button>
            </div>
          </div>
        </div>

        {/* Weekly Missions & Custom Messages */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          
          {/* Weekly Missions Card */}
          <div className="card">
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: '#fff', marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Award size={18} color="var(--color-cyan)" />
              <span>Missões Semanais de Engajamento</span>
            </h3>

            <form onSubmit={handleCreateMission} style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginBottom: '24px' }}>
              <div>
                <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Título da Missão</label>
                <input
                  type="text"
                  className="input"
                  placeholder="Ex: Expert em Privacidade"
                  value={newMission.titulo}
                  onChange={(e) => setNewMission({ ...newMission, titulo: e.target.value })}
                  required
                />
              </div>

              <div>
                <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Requisito / Ação</label>
                <input
                  type="text"
                  className="input"
                  placeholder="Ex: Concluir 5 desafios com 100% de acerto"
                  value={newMission.requisito}
                  onChange={(e) => setNewMission({ ...newMission, requisito: e.target.value })}
                  required
                />
              </div>

              <div>
                <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '4px' }}>Recompensa (XP Extra)</label>
                <input
                  type="number"
                  className="input"
                  value={newMission.xp_recompensa}
                  onChange={(e) => setNewMission({ ...newMission, xp_recompensa: parseInt(e.target.value) || 0 })}
                  min={10}
                  required
                />
              </div>

              <button type="submit" className="btn btn-secondary" style={{ display: 'flex', gap: '6px', justifyContent: 'center', border: '1px solid var(--border-color)' }}>
                <Plus size={16} />
                <span>Adicionar Missão</span>
              </button>
            </form>

            <h4 style={{ fontSize: '13px', color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: '10px' }}>Missões Ativas</h4>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              {missions.map((m) => (
                <div key={m.id} style={{ padding: '10px 14px', border: '1px solid var(--border-color)', borderRadius: 'var(--radius-sm)', background: 'rgba(255, 255, 255, 0.01)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontSize: '13px', fontWeight: 600, color: '#fff' }}>{m.titulo}</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px' }}>{m.requisito}</div>
                  </div>
                  <span className="badge badge-success">{m.xp_recompensa} XP</span>
                </div>
              ))}
            </div>
          </div>

          {/* Motivational Messages Card */}
          <div className="card">
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: '#fff', marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <MessageSquareHeart size={18} color="var(--status-warning)" />
              <span>Mensagens Motivacionais Personalizadas</span>
            </h3>

            <form onSubmit={handleSaveMotivMessage} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Mensagem atual (Exibida na Home do Colaborador)</label>
                <textarea
                  className="input"
                  value={motivationalMessage}
                  onChange={(e) => setMotivationalMessage(e.target.value)}
                  rows={3}
                  required
                />
              </div>

              <button type="submit" className="btn btn-primary" style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
                <Save size={16} />
                <span>Publicar Mensagem</span>
              </button>
            </form>
          </div>

        </div>

      </div>
    </div>
  );
};
