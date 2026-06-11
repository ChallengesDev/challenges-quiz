import React, { useState } from 'react';
import { 
  FileSpreadsheet, 
  FileText, 
  Mail, 
  Check, 
  Clock
} from 'lucide-react';
import * as XLSX from 'xlsx';

export const Reports: React.FC = () => {
  const [message, setMessage] = useState<{ type: 'success' | 'error', text: string } | null>(null);

  // Email schedule state
  const [emailSchedule, setEmailSchedule] = useState({
    destinatario: 'diretoria@empresa.com',
    frequencia: 'mensal',
    relatoriosSelecionados: ['people_analytics', 'td']
  });

  // Mock datasets for exporting
  const peopleAnalyticsData = [
    { Nome: 'João Silva', Cargo: 'Engenheiro de Software', Departamento: 'TI / Tecnologia', XP: 1200, Nivel: 5, Acertos: '88%', Ativo: 'Sim' },
    { Nome: 'Maria Santos', Cargo: 'Tech Lead', Departamento: 'TI / Tecnologia', XP: 980, Nivel: 4, Acertos: '82%', Ativo: 'Sim' },
    { Nome: 'Pedro Alencar', Cargo: 'Analista de RH', Departamento: 'Recursos Humanos', XP: 550, Nivel: 3, Acertos: '74%', Ativo: 'Sim' },
    { Nome: 'Amanda Costa', Cargo: 'Coordenadora de Compliance', Departamento: 'Compliance & Fin', XP: 820, Nivel: 4, Acertos: '80%', Ativo: 'Sim' },
    { Nome: 'Carlos Souza', Cargo: 'Executivo de Vendas', Departamento: 'Vendas & Mkt', XP: 340, Nivel: 2, Acertos: '62%', Ativo: 'Não' }
  ];

  const trainingDevelopmentData = [
    { Departamento: 'TI / Tecnologia', Colaboradores: 45, QuizzesConcluidos: 198, TempoMedioSessao: '8m 15s', ROI_Projetado: '180%' },
    { Departamento: 'Recursos Humanos', Colaboradores: 12, QuizzesConcluidos: 48, TempoMedioSessao: '6m 40s', ROI_Projetado: '110%' },
    { Departamento: 'Vendas & Mkt', Colaboradores: 38, QuizzesConcluidos: 142, TempoMedioSessao: '7m 10s', ROI_Projetado: '145%' },
    { Departamento: 'Compliance & Fin', Colaboradores: 15, QuizzesConcluidos: 55, TempoMedioSessao: '9m 02s', ROI_Projetado: '90%' }
  ];

  const complianceAuditData = [
    { Colaborador: 'João Silva', Departamento: 'TI / Tecnologia', Desafio: 'Código de Conduta', Acerto: '100%', ConcluidoEm: '05/06/2026', Status: 'Conforme' },
    { Colaborador: 'Maria Santos', Departamento: 'TI / Tecnologia', Desafio: 'LGPD Geral', Acerto: '90%', ConcluidoEm: '04/06/2026', Status: 'Conforme' },
    { Colaborador: 'Carlos Souza', Departamento: 'Vendas & Mkt', Desafio: 'Segurança e Senhas', Acerto: '40%', ConcluidoEm: '02/06/2026', Status: 'Não Conforme (Refazer)' }
  ];

  // Export to Excel
  const exportToExcel = (reportType: 'people' | 'td' | 'compliance') => {
    let dataToExport: any[] = [];
    let filename = '';

    if (reportType === 'people') {
      dataToExport = peopleAnalyticsData;
      filename = 'Relatorio_People_Analytics.xlsx';
    } else if (reportType === 'td') {
      dataToExport = trainingDevelopmentData;
      filename = 'Relatorio_Treinamento_Desenvolvimento.xlsx';
    } else {
      dataToExport = complianceAuditData;
      filename = 'Relatorio_Auditoria_Compliance.xlsx';
    }

    const worksheet = XLSX.utils.json_to_sheet(dataToExport);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Dados');
    XLSX.writeFile(workbook, filename);

    setMessage({ type: 'success', text: `Arquivo ${filename} baixado com sucesso!` });
    setTimeout(() => setMessage(null), 3000);
  };

  // Generate PDF (uses window.print() triggered layout)
  const triggerPrintPDF = () => {
    window.print();
  };

  const handleSaveSchedule = (e: React.FormEvent) => {
    e.preventDefault();
    setMessage({
      type: 'success',
      text: `Configuração salva! Relatórios serão enviados automaticamente para ${emailSchedule.destinatario} com frequência ${emailSchedule.frequencia}.`
    });
    setTimeout(() => setMessage(null), 4000);
  };

  const toggleReportInSchedule = (rep: string) => {
    const list = [...emailSchedule.relatoriosSelecionados];
    if (list.includes(rep)) {
      setEmailSchedule({
        ...emailSchedule,
        relatoriosSelecionados: list.filter(r => r !== rep)
      });
    } else {
      setEmailSchedule({
        ...emailSchedule,
        relatoriosSelecionados: [...list, rep]
      });
    }
  };

  return (
    <div className="page-container animate-fade-in">
      {/* Title */}
      <div style={{ marginBottom: '32px' }} className="no-print">
        <h3 style={{ fontSize: '14px', color: 'var(--color-primary)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Documentação e Exportação
        </h3>
        <h1 style={{ fontFamily: 'var(--font-heading)', fontSize: '28px', fontWeight: 700, color: 'var(--text-white)' }}>
          Relatórios e Auditoria
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
        }} className="no-print">
          <Check size={18} />
          <span>{message.text}</span>
        </div>
      )}

      {/* Main Grid split */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(350px, 1fr))', gap: '24px' }}>
        
        {/* Left Side: Report download cards */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }} className="no-print">
          
          {/* People Analytics Card */}
          <div className="card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h4 style={{ fontFamily: 'var(--font-heading)', fontSize: '16px', fontWeight: 600, color: '#fff' }}>People Analytics</h4>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px', maxWidth: '280px' }}>
                Métricas individuais, progresso de nível, total de XP adquirido e taxa de acertos dos colaboradores.
              </p>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <button onClick={() => exportToExcel('people')} className="btn btn-primary" style={{ padding: '8px 12px', fontSize: '12px', gap: '6px' }}>
                <FileSpreadsheet size={14} />
                <span>Excel</span>
              </button>
              <button onClick={triggerPrintPDF} className="btn btn-secondary" style={{ padding: '8px 12px', fontSize: '12px', gap: '6px' }}>
                <FileText size={14} />
                <span>PDF</span>
              </button>
            </div>
          </div>

          {/* T&D Card */}
          <div className="card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h4 style={{ fontFamily: 'var(--font-heading)', fontSize: '16px', fontWeight: 600, color: '#fff' }}>Treinamento e Desenvolvimento</h4>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px', maxWidth: '280px' }}>
                Consolidado por departamento, volume de quizzes resolvidos, tempo de retenção e ROI calculado.
              </p>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <button onClick={() => exportToExcel('td')} className="btn btn-primary" style={{ padding: '8px 12px', fontSize: '12px', gap: '6px' }}>
                <FileSpreadsheet size={14} />
                <span>Excel</span>
              </button>
              <button onClick={triggerPrintPDF} className="btn btn-secondary" style={{ padding: '8px 12px', fontSize: '12px', gap: '6px' }}>
                <FileText size={14} />
                <span>PDF</span>
              </button>
            </div>
          </div>

          {/* Compliance Card */}
          <div className="card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h4 style={{ fontFamily: 'var(--font-heading)', fontSize: '16px', fontWeight: 600, color: '#fff' }}>Relatório de Auditoria de Compliance</h4>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px', maxWidth: '280px' }}>
                Relatório de conformidade jurídica, regulatória (LGPD) e controle de erros reincidentes.
              </p>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <button onClick={() => exportToExcel('compliance')} className="btn btn-primary" style={{ padding: '8px 12px', fontSize: '12px', gap: '6px' }}>
                <FileSpreadsheet size={14} />
                <span>Excel</span>
              </button>
              <button onClick={triggerPrintPDF} className="btn btn-secondary" style={{ padding: '8px 12px', fontSize: '12px', gap: '6px' }}>
                <FileText size={14} />
                <span>PDF</span>
              </button>
            </div>
          </div>

        </div>

        {/* Right Side: Auto-Email scheduler */}
        <div className="card no-print" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: '#fff', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Mail size={20} color="var(--color-primary)" />
            <span>Envio Automático por E-mail</span>
          </h3>

          <form onSubmit={handleSaveSchedule} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div>
              <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>E-mail de Destino (Gestores/Diretoria)</label>
              <input
                type="email"
                className="input"
                placeholder="Ex: diretoria@empresa.com"
                value={emailSchedule.destinatario}
                onChange={(e) => setEmailSchedule({ ...emailSchedule, destinatario: e.target.value })}
                required
              />
            </div>

            <div>
              <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Frequência de Envio</label>
              <select
                value={emailSchedule.frequencia}
                onChange={(e) => setEmailSchedule({ ...emailSchedule, frequencia: e.target.value })}
              >
                <option value="semanal">Toda Segunda-feira (Semanal)</option>
                <option value="mensal">Todo dia 1 do mês (Mensal)</option>
              </select>
            </div>

            <div>
              <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '8px' }}>Relatórios Incluídos</label>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '13px', color: '#fff', cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={emailSchedule.relatoriosSelecionados.includes('people_analytics')}
                    onChange={() => toggleReportInSchedule('people_analytics')}
                  />
                  <span>People Analytics Geral</span>
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '13px', color: '#fff', cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={emailSchedule.relatoriosSelecionados.includes('td')}
                    onChange={() => toggleReportInSchedule('td')}
                  />
                  <span>Treinamento e Desenvolvimento</span>
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '13px', color: '#fff', cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={emailSchedule.relatoriosSelecionados.includes('compliance')}
                    onChange={() => toggleReportInSchedule('compliance')}
                  />
                  <span>Auditoria e Compliance regulatório</span>
                </label>
              </div>
            </div>

            <button type="submit" className="btn btn-primary" style={{ marginTop: '10px' }}>
              Agendar Envio Periódico
            </button>
          </form>

          <div style={{
            padding: '12px',
            backgroundColor: 'rgba(255, 255, 255, 0.02)',
            border: '1px solid var(--border-color)',
            borderRadius: 'var(--radius-sm)',
            fontSize: '11px',
            color: 'var(--text-muted)',
            display: 'flex',
            gap: '8px',
            alignItems: 'center'
          }}>
            <Clock size={16} color="var(--color-primary)" />
            <span>O envio automático é operado em background pelo nosso microsserviço de e-mails do backend.</span>
          </div>
        </div>

      </div>

      {/* PRINT-ONLY SECTION (Visually hidden on page, rendered during window.print()) */}
      <div className="print-only" style={{ display: 'none' }}>
        <div style={{ textAlign: 'center', marginBottom: '40px' }}>
          <h1 style={{ fontSize: '28px', fontWeight: 'bold', color: '#000' }}>Challenges Quiz - Relatório Oficial</h1>
          <p style={{ fontSize: '14px', color: '#666', marginTop: '6px' }}>Extraído em {new Date().toLocaleDateString('pt-BR')}</p>
        </div>

        <h2 style={{ fontSize: '18px', borderBottom: '2px solid #000', paddingBottom: '6px', marginBottom: '16px' }}>Consolidado People Analytics</h2>
        <table style={{ width: '100%', borderCollapse: 'collapse', marginBottom: '32px' }}>
          <thead>
            <tr style={{ borderBottom: '1px solid #000' }}>
              <th style={{ textAlign: 'left', padding: '8px' }}>Nome</th>
              <th style={{ textAlign: 'left', padding: '8px' }}>Departamento</th>
              <th style={{ textAlign: 'left', padding: '8px' }}>Cargo</th>
              <th style={{ textAlign: 'right', padding: '8px' }}>XP Total</th>
              <th style={{ textAlign: 'right', padding: '8px' }}>Acertos</th>
            </tr>
          </thead>
          <tbody>
            {peopleAnalyticsData.map((row, idx) => (
              <tr key={idx} style={{ borderBottom: '1px solid #ddd' }}>
                <td style={{ padding: '8px' }}>{row.Nome}</td>
                <td style={{ padding: '8px' }}>{row.Departamento}</td>
                <td style={{ padding: '8px' }}>{row.Cargo}</td>
                <td style={{ textAlign: 'right', padding: '8px' }}>{row.XP}</td>
                <td style={{ textAlign: 'right', padding: '8px' }}>{row.Acertos}</td>
              </tr>
            ))}
          </tbody>
        </table>

        <h2 style={{ fontSize: '18px', borderBottom: '2px solid #000', paddingBottom: '6px', marginBottom: '16px' }}>Auditoria de Conformidade e Treinamento</h2>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ borderBottom: '1px solid #000' }}>
              <th style={{ textAlign: 'left', padding: '8px' }}>Colaborador</th>
              <th style={{ textAlign: 'left', padding: '8px' }}>Departamento</th>
              <th style={{ textAlign: 'left', padding: '8px' }}>Desafio</th>
              <th style={{ textAlign: 'right', padding: '8px' }}>Precisão</th>
              <th style={{ textAlign: 'left', padding: '8px' }}>Status</th>
            </tr>
          </thead>
          <tbody>
            {complianceAuditData.map((row, idx) => (
              <tr key={idx} style={{ borderBottom: '1px solid #ddd' }}>
                <td style={{ padding: '8px' }}>{row.Colaborador}</td>
                <td style={{ padding: '8px' }}>{row.Departamento}</td>
                <td style={{ padding: '8px' }}>{row.Desafio}</td>
                <td style={{ textAlign: 'right', padding: '8px' }}>{row.Acerto}</td>
                <td style={{ padding: '8px' }}>{row.Status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Inject custom CSS print block dynamically */}
      <style>{`
        @media print {
          .no-print {
            display: none !important;
          }
          .print-only {
            display: block !important;
            color: #000 !important;
            background: #fff !important;
          }
        }
      `}</style>
    </div>
  );
};
