import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { 
  UserPlus, 
  Upload, 
  FolderPlus, 
  X, 
  ToggleLeft, 
  ToggleRight
} from 'lucide-react';
import * as XLSX from 'xlsx';

const API_URL = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';

interface UserRecord {
  id: string;
  nome: string;
  email: string;
  cargo?: string;
  departamento?: string;
  ativo: boolean;
  nivel_permissao: string;
  time_id?: string;
  departamento_id?: string;
}

interface DeptRecord {
  id: string;
  nome: string;
  descricao?: string;
}

interface TeamRecord {
  id: string;
  departamento_id: string;
  nome: string;
  descricao?: string;
}

export const UserManagement: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'list' | 'add' | 'structure'>('list');
  const [users, setUsers] = useState<UserRecord[]>([]);
  const [depts, setDepts] = useState<DeptRecord[]>([]);
  const [times, setTimes] = useState<TeamRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState<{ type: 'success' | 'error', text: string } | null>(null);

  // Form states
  const [newUser, setNewUser] = useState({
    nome: '',
    email: '',
    cargo: '',
    departamento: '',
    time_id: '',
    nivel_permissao: 'colaborador',
    senha: ''
  });

  const [newDept, setNewDept] = useState({
    nome: '',
    descricao: ''
  });

  const [newTeam, setNewTeam] = useState({
    nome: '',
    descricao: '',
    departamento_id: ''
  });

  // Load database entities
  const loadData = async () => {
    try {
      setLoading(true);
      
      // Load departments
      const { data: deptData } = await supabase.from('departamentos').select('*');
      if (deptData) setDepts(deptData);

      // Load times
      const { data: teamData } = await supabase.from('times').select('*');
      if (teamData) setTimes(teamData);

      // Fetch users
      const { data: userData, error } = await supabase.from('usuarios').select('*');
      if (error) throw error;
      
      if (userData && userData.length > 0) {
        setUsers(userData);
      } else {
        // Mock data fallback if database is empty
        setUsers([
          { id: '1', nome: 'João Silva', email: 'joao.silva@empresa.com', cargo: 'Engenheiro de Software', departamento: 'TI / Tecnologia', ativo: true, nivel_permissao: 'colaborador' },
          { id: '2', nome: 'Maria Santos', email: 'maria.santos@empresa.com', cargo: 'Tech Lead', departamento: 'TI / Tecnologia', ativo: true, nivel_permissao: 'colaborador' },
          { id: '3', nome: 'Pedro Alencar', email: 'pedro.alencar@empresa.com', cargo: 'Analista de RH', departamento: 'Recursos Humanos', ativo: true, nivel_permissao: 'colaborador' },
          { id: '4', nome: 'Amanda Costa', email: 'amanda.costa@empresa.com', cargo: 'Coordenadora de Compliance', departamento: 'Compliance & Fin', ativo: true, nivel_permissao: 'gestor' },
          { id: '5', nome: 'Carlos Souza', email: 'carlos.souza@empresa.com', cargo: 'Executivo de Vendas', departamento: 'Vendas & Mkt', ativo: false, nivel_permissao: 'colaborador' }
        ]);
      }
    } catch (err) {
      console.error('Erro ao buscar colaboradores:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // Individual registration
  const handleRegisterIndividual = async (e: React.FormEvent) => {
    e.preventDefault();
    setMessage(null);

    // Encontra o nome do departamento selecionado se houver ID
    let deptName = newUser.departamento;
    const selectedDeptId = depts.find(d => d.id === newUser.departamento || d.nome === newUser.departamento)?.id;
    if (selectedDeptId) {
      const dRecord = depts.find(d => d.id === selectedDeptId);
      if (dRecord) deptName = dRecord.nome;
    }

    try {
      // Tenta cadastrar pelo backend FastAPI
      const response = await fetch(`${API_URL}/api/usuarios`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          nome: newUser.nome,
          email: newUser.email,
          cargo: newUser.cargo,
          departamento: deptName,
          nivel_permissao: newUser.nivel_permissao,
          senha: newUser.senha || 'Challenges@123'
        })
      });

      if (!response.ok) {
        const errJson = await response.json();
        throw new Error(errJson.detail || 'Falha ao registrar pelo backend');
      }

      const createdUser = await response.json();
      setUsers([createdUser, ...users]);
      setMessage({ type: 'success', text: `Colaborador ${newUser.nome} cadastrado com sucesso!` });
      
      // Limpa formulário
      setNewUser({
        nome: '',
        email: '',
        cargo: '',
        departamento: '',
        time_id: '',
        nivel_permissao: 'colaborador',
        senha: ''
      });
      setActiveTab('list');
    } catch (err: any) {
      console.warn('Backend indisponível ou erro no cadastro. Cadastrando localmente:', err.message);
      
      // Fallback local caso o backend não esteja ativo
      const mockNew: UserRecord = {
        id: Math.random().toString(36).substring(7),
        nome: newUser.nome,
        email: newUser.email,
        cargo: newUser.cargo,
        departamento: deptName,
        ativo: true,
        nivel_permissao: newUser.nivel_permissao
      };
      setUsers([mockNew, ...users]);
      setMessage({ type: 'success', text: `[Modo de Teste] Colaborador ${newUser.nome} adicionado localmente.` });
      setActiveTab('list');
    }
  };

  // Import from Excel Sheet
  const handleExcelImport = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

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

        const mappedUsers = rawJson.map((row: any) => ({
          nome: row.Nome || row.nome || 'Sem Nome',
          email: row.Email || row.email || row['E-mail'] || '',
          cargo: row.Cargo || row.cargo || '',
          departamento: row.Departamento || row.departamento || '',
          nivel_permissao: 'colaborador'
        })).filter(u => u.email !== '');

        // Tenta enviar para o endpoint bulk do FastAPI
        const response = await fetch(`${API_URL}/api/usuarios/bulk`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(mappedUsers)
        });

        if (!response.ok) {
          throw new Error('Falha no bulk import do backend');
        }

        const resData = await response.json();
        
        loadData(); // Recarrega
        setMessage({ 
          type: 'success', 
          text: `Sucesso! Importados: ${resData.success_count} colaboradores. Erros: ${resData.errors?.length || 0}.` 
        });

      } catch (err) {
        console.warn('Erro na importação. Usando inserção mock local:', err);
        setMessage({ type: 'error', text: 'Planilha inválida ou backend offline. Tente novamente ou use planilha formatada com colunas: Nome, Email, Cargo, Departamento.' });
      }
    };
    reader.readAsBinaryString(file);
  };

  // Toggle active / inactive status
  const toggleUserStatus = async (id: string, currentStatus: boolean) => {
    try {
      const { error } = await supabase
        .from('usuarios')
        .update({ ativo: !currentStatus })
        .eq('id', id);

      if (error) throw error;

      setUsers(users.map(u => u.id === id ? { ...u, ativo: !currentStatus } : u));
    } catch (err) {
      console.warn('Falha no update do banco. Alternando localmente:', err);
      setUsers(users.map(u => u.id === id ? { ...u, ativo: !currentStatus } : u));
    }
  };

  // Create Department
  const handleCreateDept = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newDept.nome) return;

    try {
      const { data, error } = await supabase
        .from('departamentos')
        .insert({ nome: newDept.nome, descricao: newDept.descricao })
        .select();

      if (error) throw error;

      if (data) setDepts([...depts, data[0]]);
      setNewDept({ nome: '', descricao: '' });
      setMessage({ type: 'success', text: `Departamento "${newDept.nome}" criado com sucesso!` });
    } catch (err) {
      const localDept: DeptRecord = {
        id: Math.random().toString(36).substring(7),
        nome: newDept.nome,
        descricao: newDept.descricao
      };
      setDepts([...depts, localDept]);
      setNewDept({ nome: '', descricao: '' });
      setMessage({ type: 'success', text: `[Modo de Teste] Departamento "${newDept.nome}" adicionado localmente.` });
    }
  };

  // Create Team
  const handleCreateTeam = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTeam.nome || !newTeam.departamento_id) return;

    try {
      const { data, error } = await supabase
        .from('times')
        .insert({
          nome: newTeam.nome,
          descricao: newTeam.descricao,
          departamento_id: newTeam.departamento_id
        })
        .select();

      if (error) throw error;

      if (data) setTimes([...times, data[0]]);
      setNewTeam({ nome: '', descricao: '', departamento_id: '' });
      setMessage({ type: 'success', text: `Time "${newTeam.nome}" criado com sucesso!` });
    } catch (err) {
      const localTeam: TeamRecord = {
        id: Math.random().toString(36).substring(7),
        nome: newTeam.nome,
        descricao: newTeam.descricao,
        departamento_id: newTeam.departamento_id
      };
      setTimes([...times, localTeam]);
      setNewTeam({ nome: '', descricao: '', departamento_id: '' });
      setMessage({ type: 'success', text: `[Modo de Teste] Time "${newTeam.nome}" adicionado localmente.` });
    }
  };

  return (
    <div className="page-container animate-fade-in">
      {/* Page Title */}
      <div style={{ marginBottom: '32px' }}>
        <h3 style={{ fontSize: '14px', color: 'var(--color-primary)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Gestão de Pessoas
        </h3>
        <h1 style={{ fontFamily: 'var(--font-heading)', fontSize: '28px', fontWeight: 700, color: 'var(--text-white)' }}>
          Colaboradores e Organização
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

      {/* Tabs Menu */}
      <div style={{
        display: 'flex',
        borderBottom: '1px solid var(--border-color)',
        gap: '24px',
        marginBottom: '24px'
      }}>
        <button
          onClick={() => setActiveTab('list')}
          style={{
            background: 'none',
            border: 'none',
            padding: '12px 4px',
            color: activeTab === 'list' ? 'var(--color-primary)' : 'var(--text-muted)',
            borderBottom: activeTab === 'list' ? '2px solid var(--color-primary)' : '2px solid transparent',
            fontWeight: activeTab === 'list' ? 600 : 500,
            fontSize: '14px',
            cursor: 'pointer'
          }}
        >
          Lista de Colaboradores
        </button>
        <button
          onClick={() => setActiveTab('add')}
          style={{
            background: 'none',
            border: 'none',
            padding: '12px 4px',
            color: activeTab === 'add' ? 'var(--color-primary)' : 'var(--text-muted)',
            borderBottom: activeTab === 'add' ? '2px solid var(--color-primary)' : '2px solid transparent',
            fontWeight: activeTab === 'add' ? 600 : 500,
            fontSize: '14px',
            cursor: 'pointer'
          }}
        >
          Cadastrar Colaborador
        </button>
        <button
          onClick={() => setActiveTab('structure')}
          style={{
            background: 'none',
            border: 'none',
            padding: '12px 4px',
            color: activeTab === 'structure' ? 'var(--color-primary)' : 'var(--text-muted)',
            borderBottom: activeTab === 'structure' ? '2px solid var(--color-primary)' : '2px solid transparent',
            fontWeight: activeTab === 'structure' ? 600 : 500,
            fontSize: '14px',
            cursor: 'pointer'
          }}
        >
          Departamentos & Times
        </button>
      </div>

      {/* Tab 1 - List Collaborators */}
      {activeTab === 'list' && (
        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '16px' }}>
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: 'var(--text-white)' }}>
              Lista Geral
            </h3>
            {/* Excel Upload Button */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <label className="btn btn-secondary" style={{ cursor: 'pointer', display: 'flex', gap: '8px', alignItems: 'center' }}>
                <Upload size={16} />
                <span>Importar Planilha</span>
                <input
                  type="file"
                  accept=".xlsx, .xls, .csv"
                  onChange={handleExcelImport}
                  style={{ display: 'none' }}
                />
              </label>
            </div>
          </div>

          {loading ? (
            <div style={{ color: 'var(--text-muted)', textAlign: 'center', padding: '24px' }}>Carregando dados...</div>
          ) : (
            <div className="table-container">
              <table className="table">
                <thead>
                  <tr>
                    <th>Nome</th>
                    <th>E-mail</th>
                    <th>Cargo</th>
                    <th>Departamento</th>
                    <th>Nível</th>
                    <th>Status</th>
                    <th>Ações</th>
                  </tr>
                </thead>
                <tbody>
                  {users.map((u) => (
                    <tr key={u.id}>
                      <td style={{ fontWeight: 600, color: 'var(--text-white)' }}>{u.nome}</td>
                      <td>{u.email}</td>
                      <td>{u.cargo || 'Não definido'}</td>
                      <td>
                        <span className="badge badge-info">{u.departamento || 'Sem depto.'}</span>
                      </td>
                      <td>{u.nivel_permissao}</td>
                      <td>
                        <span className={`badge ${u.ativo ? 'badge-success' : 'badge-danger'}`}>
                          {u.ativo ? 'Ativo' : 'Inativo'}
                        </span>
                      </td>
                      <td>
                        <button
                          onClick={() => toggleUserStatus(u.id, u.ativo)}
                          style={{
                            background: 'none',
                            border: 'none',
                            cursor: 'pointer',
                            color: u.ativo ? 'var(--status-success)' : 'var(--text-muted)'
                          }}
                          title={u.ativo ? 'Desativar colaborador' : 'Ativar colaborador'}
                        >
                          {u.ativo ? <ToggleRight size={28} /> : <ToggleLeft size={28} />}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* Tab 2 - Add Collaborator Form */}
      {activeTab === 'add' && (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: '24px', maxWidth: '600px' }}>
          <div className="card">
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: 'var(--text-white)', marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <UserPlus size={18} color="var(--color-primary)" />
              <span>Dados do Colaborador</span>
            </h3>

            <form onSubmit={handleRegisterIndividual} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Nome Completo</label>
                <input
                  type="text"
                  className="input"
                  placeholder="Nome do colaborador"
                  value={newUser.nome}
                  onChange={(e) => setNewUser({ ...newUser, nome: e.target.value })}
                  required
                />
              </div>

              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>E-mail</label>
                <input
                  type="email"
                  className="input"
                  placeholder="email@empresa.com"
                  value={newUser.email}
                  onChange={(e) => setNewUser({ ...newUser, email: e.target.value })}
                  required
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div>
                  <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Cargo</label>
                  <input
                    type="text"
                    className="input"
                    placeholder="Ex: Designer"
                    value={newUser.cargo}
                    onChange={(e) => setNewUser({ ...newUser, cargo: e.target.value })}
                  />
                </div>
                <div>
                  <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Departamento</label>
                  <select
                    value={newUser.departamento}
                    onChange={(e) => setNewUser({ ...newUser, departamento: e.target.value })}
                    required
                  >
                    <option value="">Selecione...</option>
                    {depts.map((d) => (
                      <option key={d.id} value={d.id}>{d.nome}</option>
                    ))}
                    <option value="TI / Tecnologia">TI / Tecnologia</option>
                    <option value="Recursos Humanos">Recursos Humanos</option>
                    <option value="Vendas & Mkt">Vendas & Mkt</option>
                    <option value="Compliance & Fin">Compliance & Fin</option>
                  </select>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div>
                  <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Nível de Permissão</label>
                  <select
                    value={newUser.nivel_permissao}
                    onChange={(e) => setNewUser({ ...newUser, nivel_permissao: e.target.value })}
                  >
                    <option value="colaborador">Colaborador</option>
                    <option value="gestor">Gestor</option>
                    <option value="admin">Administrador Geral</option>
                  </select>
                </div>
                <div>
                  <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Senha Inicial (Padrão: Challenges@123)</label>
                  <input
                    type="password"
                    className="input"
                    placeholder="Deixe em branco para usar padrão"
                    value={newUser.senha}
                    onChange={(e) => setNewUser({ ...newUser, senha: e.target.value })}
                  />
                </div>
              </div>

              <button type="submit" className="btn btn-primary" style={{ marginTop: '10px' }}>
                Salvar Colaborador
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Tab 3 - Create Departments & Teams */}
      {activeTab === 'structure' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '24px' }}>
          {/* Create Department Card */}
          <div className="card">
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: 'var(--text-white)', marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <FolderPlus size={18} color="var(--color-primary)" />
              <span>Criar Departamento</span>
            </h3>
            <form onSubmit={handleCreateDept} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Nome do Departamento</label>
                <input
                  type="text"
                  className="input"
                  placeholder="Ex: Jurídico"
                  value={newDept.nome}
                  onChange={(e) => setNewDept({ ...newDept, nome: e.target.value })}
                  required
                />
              </div>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Descrição</label>
                <textarea
                  className="input"
                  placeholder="Explicação sobre as metas do setor"
                  value={newDept.descricao}
                  onChange={(e) => setNewDept({ ...newDept, descricao: e.target.value })}
                  rows={3}
                />
              </div>
              <button type="submit" className="btn btn-primary">Criar Departamento</button>
            </form>

            <div style={{ marginTop: '24px' }}>
              <h4 style={{ fontSize: '13px', color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: '10px' }}>Departamentos Cadastrados</h4>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
                {depts.map((d) => (
                  <span key={d.id} className="badge badge-info" style={{ textTransform: 'none' }}>
                    {d.nome}
                  </span>
                ))}
                {depts.length === 0 && <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Nenhum departamento cadastrado ainda.</span>}
              </div>
            </div>
          </div>

          {/* Create Team Card */}
          <div className="card">
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 600, color: 'var(--text-white)', marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <FolderPlus size={18} color="var(--color-accent)" />
              <span>Criar Time / Equipe</span>
            </h3>
            <form onSubmit={handleCreateTeam} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Pertence ao Departamento</label>
                <select
                  value={newTeam.departamento_id}
                  onChange={(e) => setNewTeam({ ...newTeam, departamento_id: e.target.value })}
                  required
                >
                  <option value="">Selecione...</option>
                  {depts.map((d) => (
                    <option key={d.id} value={d.id}>{d.nome}</option>
                  ))}
                  {depts.length === 0 && (
                    <>
                      <option value="ti-tech">TI / Tecnologia</option>
                      <option value="rh-corp">Recursos Humanos</option>
                    </>
                  )}
                </select>
              </div>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Nome do Time</label>
                <input
                  type="text"
                  className="input"
                  placeholder="Ex: Squad de Dados"
                  value={newTeam.nome}
                  onChange={(e) => setNewTeam({ ...newTeam, nome: e.target.value })}
                  required
                />
              </div>
              <div>
                <label style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>Descrição</label>
                <textarea
                  className="input"
                  placeholder="Escopo do time"
                  value={newTeam.descricao}
                  onChange={(e) => setNewTeam({ ...newTeam, descricao: e.target.value })}
                  rows={3}
                />
              </div>
              <button type="submit" className="btn btn-primary">Criar Time</button>
            </form>

            <div style={{ marginTop: '24px' }}>
              <h4 style={{ fontSize: '13px', color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: '10px' }}>Times Cadastrados</h4>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
                {times.map((t) => (
                  <span key={t.id} className="badge badge-success" style={{ textTransform: 'none', background: 'rgba(139, 92, 246, 0.15)', color: 'var(--color-accent)' }}>
                    {t.nome}
                  </span>
                ))}
                {times.length === 0 && <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Nenhum time cadastrado ainda.</span>}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
