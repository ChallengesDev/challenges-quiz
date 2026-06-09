import React, { useState, useEffect } from 'react';
import { supabase } from './lib/supabase';
import * as XLSX from 'xlsx';
import { 
  Building2, 
  Users, 
  LayoutDashboard, 
  PlusCircle, 
  UploadCloud, 
  Download, 
  LogOut, 
  AlertTriangle, 
  CheckCircle, 
  Shield, 
  Mail, 
  Lock, 
  Briefcase,
  ToggleLeft,
  ToggleRight,
  TrendingUp,
  Award,
  BookOpen
} from 'lucide-react';

const API_URL = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';

type Screen = 'dashboard' | 'companies' | 'new-company' | 'users' | 'users-by-company';

interface Company {
  id: string;
  nome: string;
  plano: string;
  ativo: boolean;
  criado_em: string;
}

interface UserProfile {
  id: string;
  nome: string;
  email: string;
  cargo: string;
  departamento: string;
  nivel_permissao: 'colaborador' | 'gestor' | 'admin';
  ativo: boolean;
  primeiro_acesso: boolean;
  empresas?: { nome: string } | null;
  empresa_id?: string;
  criado_em: string;
}

export default function App() {
  const [session, setSession] = useState<any>(null);
  const [currentScreen, setCurrentScreen] = useState<Screen>('dashboard');
  const [loading, setLoading] = useState<boolean>(false);
  const [errorMsg, setErrorMsg] = useState<string>('');
  const [successMsg, setSuccessMsg] = useState<string>('');

  // Auth States
  const [loginEmail, setLoginEmail] = useState('');
  const [loginPassword, setLoginPassword] = useState('');

  // App Global Data
  const [companies, setCompanies] = useState<Company[]>([]);
  const [users, setUsers] = useState<UserProfile[]>([]);

  // Company Form State
  const [newCompName, setNewCompName] = useState('');
  const [newCompPlano, setNewCompPlano] = useState('premium');
  const [newCompAtivo, setNewCompAtivo] = useState(true);

  // User Form State (Manual Creation)
  const [userNome, setUserNome] = useState('');
  const [userEmail, setUserEmail] = useState('');
  const [userCargo, setUserCargo] = useState('');
  const [userDept, setUserDept] = useState('');
  const [userPerm, setUserPerm] = useState<'colaborador' | 'gestor' | 'admin'>('colaborador');
  const [userEmpresaId, setUserEmpresaId] = useState('');

  // Users filter state for screen 'users-by-company'
  const [filterEmpresaId, setFilterEmpresaId] = useState('');

  // Upload Excel States
  const [uploadErrors, setUploadErrors] = useState<{ line: number; email: string; error: string }[]>([]);
  const [parsedUsers, setParsedUsers] = useState<any[]>([]);
  const [uploadSuccessMessage, setUploadSuccessMessage] = useState('');
  const [uploadEmpresaId, setUploadEmpresaId] = useState('');

  useEffect(() => {
    // Escuta estado de sessão
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
    });

    return () => subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (session) {
      fetchCompanies();
      fetchUsers();
    }
  }, [session]);

  const clearMessages = () => {
    setErrorMsg('');
    setSuccessMsg('');
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setErrorMsg('');
    try {
      const { error } = await supabase.auth.signInWithPassword({
        email: loginEmail,
        password: loginPassword,
      });
      if (error) throw error;
      setSuccessMsg('Login efetuado com sucesso!');
    } catch (err: any) {
      setErrorMsg(err.message || 'Erro ao realizar login.');
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    setSession(null);
  };

  // Fetch Companies
  const fetchCompanies = async () => {
    try {
      const res = await fetch(`${API_URL}/api/empresas`);
      if (!res.ok) throw new Error('Erro ao buscar empresas');
      const data = await res.json();
      setCompanies(data);
      if (data.length > 0) {
        setUserEmpresaId(data[0].id);
        setFilterEmpresaId(data[0].id);
        setUploadEmpresaId(data[0].id);
      }
    } catch (err: any) {
      console.error(err);
    }
  };

  // Fetch Users
  const fetchUsers = async (empId?: string) => {
    try {
      let url = `${API_URL}/api/usuarios`;
      if (empId) url += `?empresa_id=${empId}`;
      const res = await fetch(url);
      if (!res.ok) throw new Error('Erro ao buscar usuários');
      const data = await res.json();
      setUsers(data);
    } catch (err: any) {
      console.error(err);
    }
  };

  // Create Company
  const handleCreateCompany = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    clearMessages();
    try {
      const res = await fetch(`${API_URL}/api/empresas`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          nome: newCompName,
          plano: newCompPlano,
          ativo: newCompAtivo
        })
      });
      if (!res.ok) {
        const errData = await res.json();
        throw new Error(errData.detail || 'Erro ao salvar nova empresa.');
      }
      setSuccessMsg('Empresa cadastrada com sucesso!');
      setNewCompName('');
      fetchCompanies();
      setCurrentScreen('companies');
    } catch (err: any) {
      setErrorMsg(err.message);
    } finally {
      setLoading(false);
    }
  };

  // Create User Manually
  const handleCreateUserManual = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    clearMessages();
    try {
      const res = await fetch(`${API_URL}/api/usuarios`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          nome: userNome,
          email: userEmail,
          cargo: userCargo,
          departamento: userDept,
          nivel_permissao: userPerm,
          empresa_id: userEmpresaId || null
        })
      });
      if (!res.ok) {
        const errData = await res.json();
        throw new Error(errData.detail || 'Erro ao criar usuário.');
      }
      setSuccessMsg('Usuário criado com sucesso!');
      setUserNome('');
      setUserEmail('');
      setUserCargo('');
      setUserDept('');
      fetchUsers();
    } catch (err: any) {
      setErrorMsg(err.message);
    } finally {
      setLoading(false);
    }
  };

  // Download Excel Template
  const downloadTemplate = () => {
    const data = [
      {
        "Nome": "Carlos Henrique",
        "Email": "carlos.henrique@empresa.com",
        "Cargo": "Analista Financeiro",
        "Departamento": "Financeiro",
        "NivelPermissao": "colaborador"
      },
      {
        "Nome": "Mariana Souza",
        "Email": "mariana.souza@empresa.com",
        "Cargo": "Gerente de Marketing",
        "Departamento": "Marketing",
        "NivelPermissao": "gestor"
      },
      {
        "Nome": "Juliana Santos",
        "Email": "juliana.santos@empresa.com",
        "Cargo": "Administradora do Sistema",
        "Departamento": "Tecnologia",
        "NivelPermissao": "admin"
      }
    ];

    const worksheet = XLSX.utils.json_to_sheet(data);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, "Template Importação");
    
    // Auto-ajuste de largura de colunas
    const max_widths = [
      { wch: 20 }, // Nome
      { wch: 30 }, // Email
      { wch: 20 }, // Cargo
      { wch: 20 }, // Departamento
      { wch: 15 }  // NivelPermissao
    ];
    worksheet['!cols'] = max_widths;

    XLSX.writeFile(workbook, "template_usuarios_desafios.xlsx");
  };

  // Handle Excel/CSV File Upload and Parsing
  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploadErrors([]);
    setParsedUsers([]);
    setUploadSuccessMessage('');
    clearMessages();

    const reader = new FileReader();
    reader.onload = (evt) => {
      try {
        const bstr = evt.target?.result;
        const workbook = XLSX.read(bstr, { type: 'binary' });
        const sheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[sheetName];
        const rawJson = XLSX.utils.sheet_to_json<any>(worksheet);

        if (rawJson.length === 0) {
          setUploadErrors([{ line: 1, email: 'Planilha', error: 'O arquivo está vazio.' }]);
          return;
        }

        const newErrors: { line: number; email: string; error: string }[] = [];
        const validRows: any[] = [];

        rawJson.forEach((row, index) => {
          const lineNum = index + 2; // Linha 1 são os cabeçalhos
          const nome = row.Nome || row.nome || row.NOME;
          const email = row.Email || row.email || row.EMAIL;
          const cargo = row.Cargo || row.cargo || row.CARGO || '';
          const departamento = row.Departamento || row.departamento || row.DEPARTAMENTO || '';
          let nivelPermissao = (row.NivelPermissao || row.nivelpermissao || row.nivel_permissao || row.NIVEL_PERMISSAO || 'colaborador')
            .toString()
            .toLowerCase()
            .trim();

          if (!nome) {
            newErrors.push({ line: lineNum, email: email || 'Desconhecido', error: 'Nome está em branco ou ausente.' });
            return;
          }
          if (!email || !/\S+@\S+\.\S+/.test(email)) {
            newErrors.push({ line: lineNum, email: email || 'N/A', error: 'E-mail inválido ou em branco.' });
            return;
          }
          if (!['colaborador', 'gestor', 'admin'].includes(nivelPermissao)) {
            newErrors.push({ 
              line: lineNum, 
              email, 
              error: `Nível de permissão inválido: '${nivelPermissao}'. Deve ser 'colaborador', 'gestor' ou 'admin'.` 
            });
            return;
          }

          validRows.push({
            nome,
            email,
            cargo,
            departamento,
            nivel_permissao: nivelPermissao,
            empresa_id: uploadEmpresaId
          });
        });

        setUploadErrors(newErrors);
        setParsedUsers(validRows);
        
        if (newErrors.length === 0) {
          setUploadSuccessMessage(`Planilha validada com sucesso! ${validRows.length} usuários prontos para salvar.`);
        } else {
          setUploadSuccessMessage(`Validação concluída com erros: ${newErrors.length} erros detectados. Corrija o arquivo ou salve apenas as ${validRows.length} linhas válidas.`);
        }
      } catch (err: any) {
        setUploadErrors([{ line: 0, email: 'Arquivo', error: `Erro ao processar arquivo: ${err.message}` }]);
      }
    };
    reader.readAsBinaryString(file);
  };

  // Submit Bulk Users to Backend
  const handleSaveBulkUsers = async () => {
    if (parsedUsers.length === 0) return;
    setLoading(true);
    clearMessages();
    try {
      const res = await fetch(`${API_URL}/api/usuarios/bulk`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(parsedUsers)
      });
      const data = await res.json();
      
      if (!res.ok) {
        throw new Error(data.detail || 'Erro ao processar importação em lote.');
      }

      if (data.errors && data.errors.length > 0) {
        const errorList = data.errors.map((e: any) => `Linha ${e.linha} (${e.email}): ${e.erro}`).join('; ');
        setErrorMsg(`Importado parcialmente com erros: ${errorList}`);
        setUploadSuccessMessage(`Importados com sucesso: ${data.success_count}. Falharam: ${data.errors.length}`);
      } else {
        setSuccessMsg(`Sucesso! Todos os ${data.success_count} usuários foram importados e cadastrados com sucesso.`);
        setParsedUsers([]);
        setUploadSuccessMessage('');
      }

      fetchUsers();
    } catch (err: any) {
      setErrorMsg(err.message);
    } finally {
      setLoading(false);
    }
  };

  // Change active status of company
  const toggleCompanyStatus = async (company: Company) => {
    try {
      // API call to toggle could be made here, for now local simulation or database update via service key
      const { error } = await supabase.from("empresas").update({ ativo: !company.ativo }).eq("id", company.id);
      if (error) throw error;
      fetchCompanies();
      setSuccessMsg(`Status da empresa '${company.nome}' atualizado com sucesso!`);
      setTimeout(clearMessages, 4000);
    } catch (err: any) {
      setErrorMsg(err.message);
    }
  };

  // RENDER LOGIN SCREEN
  if (!session) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: '100vh', padding: '16px' }}>
        <div className="card animate-fade-in" style={{ width: '100%', maxWidth: '440px', padding: '40px' }}>
          <div style={{ textAlign: 'center', marginBottom: '32px' }}>
            <div style={{ 
              display: 'inline-flex', 
              padding: '16px', 
              borderRadius: '50%', 
              background: 'rgba(99, 102, 241, 0.1)', 
              color: 'var(--color-primary)', 
              marginBottom: '16px' 
            }}>
              <Shield size={36} />
            </div>
            <h2 style={{ fontFamily: 'var(--font-heading)', fontSize: '28px', fontWeight: 'bold' }}>Challenges Quiz</h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '14px', marginTop: '4px' }}>Painel Administrativo Geral</p>
          </div>

          {errorMsg && (
            <div style={{ 
              background: 'rgba(239, 68, 68, 0.1)', 
              border: '1px solid rgba(239, 68, 68, 0.2)', 
              color: 'var(--status-error)', 
              padding: '12px', 
              borderRadius: 'var(--radius-sm)', 
              marginBottom: '20px',
              fontSize: '14px',
              display: 'flex',
              alignItems: 'center',
              gap: '8px'
            }}>
              <AlertTriangle size={18} />
              <span>{errorMsg}</span>
            </div>
          )}

          <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '13px', fontWeight: '500', color: 'var(--text-muted)', marginBottom: '8px' }}>E-mail corporativo</label>
              <div style={{ position: 'relative' }}>
                <Mail size={18} style={{ position: 'absolute', left: '12px', top: '12px', color: 'var(--text-muted)' }} />
                <input 
                  type="email" 
                  className="input" 
                  style={{ paddingLeft: '40px' }} 
                  placeholder="admin@challenges.com" 
                  value={loginEmail}
                  onChange={(e) => setLoginEmail(e.target.value)}
                  required
                />
              </div>
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '13px', fontWeight: '500', color: 'var(--text-muted)', marginBottom: '8px' }}>Senha</label>
              <div style={{ position: 'relative' }}>
                <Lock size={18} style={{ position: 'absolute', left: '12px', top: '12px', color: 'var(--text-muted)' }} />
                <input 
                  type="password" 
                  className="input" 
                  style={{ paddingLeft: '40px' }} 
                  placeholder="••••••••" 
                  value={loginPassword}
                  onChange={(e) => setLoginPassword(e.target.value)}
                  required
                />
              </div>
            </div>

            <button type="submit" className="btn btn-primary" style={{ width: '100%', padding: '12px' }} disabled={loading}>
              {loading ? 'Entrando...' : 'Entrar no painel'}
            </button>
          </form>
        </div>
      </div>
    );
  }

  // RENDER PRINCIPAL LAYOUT WITH SIDEBAR
  return (
    <div className="admin-layout">
      {/* SIDEBAR NAVIGATION */}
      <aside className="sidebar">
        <div style={{ padding: '24px', borderBottom: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', gap: '12px' }}>
          <Shield size={24} style={{ color: 'var(--color-primary)' }} />
          <div>
            <h1 style={{ fontSize: '18px', fontWeight: 'bold', margin: 0, fontFamily: 'var(--font-heading)', letterSpacing: 'normal' }}>Challenges ADM</h1>
            <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>Módulo Geral</span>
          </div>
        </div>

        <nav style={{ padding: '24px 16px', display: 'flex', flexDirection: 'column', gap: '8px', flexGrow: 1 }}>
          <button 
            className={`btn ${currentScreen === 'dashboard' ? 'btn-primary' : 'btn-secondary'}`} 
            style={{ justifyContent: 'flex-start', width: '100%' }}
            onClick={() => { setCurrentScreen('dashboard'); clearMessages(); }}
          >
            <LayoutDashboard size={18} />
            <span>Dashboard</span>
          </button>

          <button 
            className={`btn ${currentScreen === 'companies' ? 'btn-primary' : 'btn-secondary'}`} 
            style={{ justifyContent: 'flex-start', width: '100%' }}
            onClick={() => { setCurrentScreen('companies'); clearMessages(); fetchCompanies(); }}
          >
            <Building2 size={18} />
            <span>Empresas</span>
          </button>

          <button 
            className={`btn ${currentScreen === 'new-company' ? 'btn-primary' : 'btn-secondary'}`} 
            style={{ justifyContent: 'flex-start', width: '100%' }}
            onClick={() => { setCurrentScreen('new-company'); clearMessages(); }}
          >
            <PlusCircle size={18} />
            <span>Cadastrar Empresa</span>
          </button>

          <button 
            className={`btn ${currentScreen === 'users' ? 'btn-primary' : 'btn-secondary'}`} 
            style={{ justifyContent: 'flex-start', width: '100%' }}
            onClick={() => { setCurrentScreen('users'); clearMessages(); fetchUsers(); }}
          >
            <Users size={18} />
            <span>Usuários e Lote</span>
          </button>

          <button 
            className={`btn ${currentScreen === 'users-by-company' ? 'btn-primary' : 'btn-secondary'}`} 
            style={{ justifyContent: 'flex-start', width: '100%' }}
            onClick={() => { setCurrentScreen('users-by-company'); clearMessages(); fetchUsers(filterEmpresaId); }}
          >
            <Users size={18} />
            <span>Filtro por Empresa</span>
          </button>
        </nav>

        {/* LOGOUT FOOTER */}
        <div style={{ padding: '24px 16px', borderTop: '1px solid var(--border-color)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px', padding: '0 8px' }}>
            <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: 'var(--color-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontWeight: 'bold' }}>
              A
            </div>
            <div style={{ overflow: 'hidden' }}>
              <p style={{ fontSize: '13px', fontWeight: '600', textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }}>{session.user.email}</p>
              <p style={{ fontSize: '11px', color: 'var(--text-muted)' }}>Administrador Geral</p>
            </div>
          </div>
          <button onClick={handleLogout} className="btn btn-secondary" style={{ width: '100%', justifyContent: 'center', gap: '8px' }}>
            <LogOut size={16} />
            <span>Sair</span>
          </button>
        </div>
      </aside>

      {/* MAIN CONTAINER */}
      <main className="main-content">
        {/* TOPBAR */}
        <header className="topbar">
          <h2 style={{ fontFamily: 'var(--font-heading)', fontWeight: '600', margin: 0, textTransform: 'capitalize' }}>
            {currentScreen.replace('-', ' ')}
          </h2>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span className="badge badge-success">Servidor API Online</span>
          </div>
        </header>

        {/* CONTENT VIEW */}
        <div className="page-container">
          {/* Notifications */}
          {errorMsg && (
            <div className="animate-fade-in" style={{ 
              background: 'rgba(239, 68, 68, 0.1)', 
              border: '1px solid rgba(239, 68, 68, 0.2)', 
              color: 'var(--status-error)', 
              padding: '16px', 
              borderRadius: 'var(--radius-md)', 
              marginBottom: '24px',
              fontSize: '14px',
              display: 'flex',
              alignItems: 'center',
              gap: '12px'
            }}>
              <AlertTriangle size={20} />
              <span>{errorMsg}</span>
            </div>
          )}

          {successMsg && (
            <div className="animate-fade-in" style={{ 
              background: 'rgba(16, 185, 129, 0.1)', 
              border: '1px solid rgba(16, 185, 129, 0.2)', 
              color: 'var(--status-success)', 
              padding: '16px', 
              borderRadius: 'var(--radius-md)', 
              marginBottom: '24px',
              fontSize: '14px',
              display: 'flex',
              alignItems: 'center',
              gap: '12px'
            }}>
              <CheckCircle size={20} />
              <span>{successMsg}</span>
            </div>
          )}

          {/* 1. SCREEN: DASHBOARD PRINCIPAL */}
          {currentScreen === 'dashboard' && (
            <div className="animate-fade-in" style={{ display: 'flex', flexDirection: 'column', gap: '32px' }}>
              {/* Widgets Stats */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '24px' }}>
                <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
                  <div style={{ padding: '12px', borderRadius: 'var(--radius-sm)', background: 'rgba(99, 102, 241, 0.1)', color: 'var(--color-primary)' }}>
                    <Building2 size={24} />
                  </div>
                  <div>
                    <span style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block' }}>Empresas Cadastradas</span>
                    <strong style={{ fontSize: '28px', color: 'var(--text-white)', fontWeight: '800' }}>{companies.length}</strong>
                  </div>
                </div>

                <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
                  <div style={{ padding: '12px', borderRadius: 'var(--radius-sm)', background: 'rgba(139, 92, 246, 0.1)', color: 'var(--color-accent)' }}>
                    <Users size={24} />
                  </div>
                  <div>
                    <span style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block' }}>Total de Usuários</span>
                    <strong style={{ fontSize: '28px', color: 'var(--text-white)', fontWeight: '800' }}>{users.length}</strong>
                  </div>
                </div>

                <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
                  <div style={{ padding: '12px', borderRadius: 'var(--radius-sm)', background: 'rgba(16, 185, 129, 0.1)', color: 'var(--status-success)' }}>
                    <TrendingUp size={24} />
                  </div>
                  <div>
                    <span style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block' }}>Planos Premium Ativos</span>
                    <strong style={{ fontSize: '28px', color: 'var(--text-white)', fontWeight: '800' }}>
                      {companies.filter(c => c.plano === 'premium' && c.ativo).length}
                    </strong>
                  </div>
                </div>

                <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
                  <div style={{ padding: '12px', borderRadius: 'var(--radius-sm)', background: 'rgba(245, 158, 11, 0.1)', color: 'var(--status-warning)' }}>
                    <Shield size={24} />
                  </div>
                  <div>
                    <span style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'block' }}>Administradores</span>
                    <strong style={{ fontSize: '28px', color: 'var(--text-white)', fontWeight: '800' }}>
                      {users.filter(u => u.nivel_permissao === 'admin').length}
                    </strong>
                  </div>
                </div>
              </div>

              {/* Informational area */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(400px, 1fr))', gap: '24px' }}>
                <div className="card">
                  <h3 style={{ fontSize: '18px', fontWeight: '700', marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Award size={18} style={{ color: 'var(--color-primary)' }} />
                    Visão Geral do Sistema
                  </h3>
                  <p style={{ color: 'var(--text-muted)', fontSize: '14px', lineHeight: '1.6', marginBottom: '12px' }}>
                    Este é o painel de controle administrativo mestre para o **Challenges Quiz**. Como administrador global, você tem autoridade para supervisionar o provisionamento de novas empresas clientes, definir seus planos (Premium vs Básico) e realizar a importação ou cadastro de novos usuários administradores das empresas.
                  </p>
                  <div style={{ display: 'flex', gap: '12px', marginTop: '20px' }}>
                    <button onClick={() => setCurrentScreen('new-company')} className="btn btn-primary">
                      Cadastrar Empresa
                    </button>
                    <button onClick={() => setCurrentScreen('users')} className="btn btn-secondary">
                      Gerenciar Usuários
                    </button>
                  </div>
                </div>

                <div className="card">
                  <h3 style={{ fontSize: '18px', fontWeight: '700', marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <BookOpen size={18} style={{ color: 'var(--color-accent)' }} />
                    Estrutura de Conteúdo
                  </h3>
                  <div style={{ fontSize: '14px', color: 'var(--text-muted)' }}>
                    <p style={{ marginBottom: '8px' }}>Cada empresa cliente criada no sistema possui total isolamento de dados no banco e pode conter:</p>
                    <ul style={{ paddingLeft: '20px', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                      <li>Departamentos e Equipes próprias</li>
                      <li>Categorias, Tópicos e Desafios de Quizzes</li>
                      <li>Leaderboards e Rankings exclusivos por empresa e equipe</li>
                      <li>Histórico de sessões de resposta individuais de colaboradores</li>
                    </ul>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* 2. SCREEN: LISTAGEM DE EMPRESAS */}
          {currentScreen === 'companies' && (
            <div className="animate-fade-in card">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
                <h3 style={{ fontSize: '18px', fontWeight: '700' }}>Empresas Clientes</h3>
                <button onClick={() => setCurrentScreen('new-company')} className="btn btn-primary">
                  <PlusCircle size={16} />
                  Nova Empresa
                </button>
              </div>

              {companies.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>
                  Nenhuma empresa cadastrada no momento.
                </div>
              ) : (
                <div className="table-container">
                  <table className="table">
                    <thead>
                      <tr>
                        <th>Nome</th>
                        <th>Plano</th>
                        <th>Status</th>
                        <th>Data de Cadastro</th>
                        <th style={{ textAlign: 'right' }}>Ações</th>
                      </tr>
                    </thead>
                    <tbody>
                      {companies.map((company) => (
                        <tr key={company.id}>
                          <td style={{ fontWeight: '600', color: '#fff' }}>{company.nome}</td>
                          <td>
                            <span className={`badge ${company.plano === 'premium' ? 'badge-info' : 'badge-warning'}`}>
                              {company.plano}
                            </span>
                          </td>
                          <td>
                            <span className={`badge ${company.ativo ? 'badge-success' : 'badge-danger'}`}>
                              {company.ativo ? 'Ativa' : 'Inativa'}
                            </span>
                          </td>
                          <td>{new Date(company.criado_em).toLocaleDateString('pt-BR')}</td>
                          <td style={{ textAlign: 'right' }}>
                            <button 
                              onClick={() => toggleCompanyStatus(company)} 
                              className="btn btn-secondary" 
                              style={{ padding: '6px 12px', fontSize: '12px' }}
                            >
                              {company.ativo ? <ToggleRight size={18} style={{ color: 'var(--status-success)' }} /> : <ToggleLeft size={18} style={{ color: 'var(--status-error)' }} />}
                              {company.ativo ? 'Desativar' : 'Ativar'}
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

          {/* 3. SCREEN: CADASTRO DE NOVA EMPRESA */}
          {currentScreen === 'new-company' && (
            <div className="animate-fade-in card" style={{ maxWidth: '600px', margin: '0 auto' }}>
              <h3 style={{ fontSize: '18px', fontWeight: '700', marginBottom: '24px' }}>Cadastrar Nova Empresa Cliente</h3>
              <form onSubmit={handleCreateCompany} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '13px', fontWeight: '500', color: 'var(--text-muted)', marginBottom: '8px' }}>Nome da Empresa</label>
                  <input 
                    type="text" 
                    className="input" 
                    placeholder="Ex: ACME Corp" 
                    value={newCompName}
                    onChange={(e) => setNewCompName(e.target.value)}
                    required
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '13px', fontWeight: '500', color: 'var(--text-muted)', marginBottom: '8px' }}>Plano da Assinatura</label>
                  <select 
                    className="input" 
                    value={newCompPlano}
                    onChange={(e) => setNewCompPlano(e.target.value)}
                  >
                    <option value="free">Básico / Gratuito</option>
                    <option value="premium">Premium</option>
                    <option value="enterprise">Enterprise</option>
                  </select>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginTop: '10px' }}>
                  <input 
                    type="checkbox" 
                    id="company-active" 
                    checked={newCompAtivo}
                    onChange={(e) => setNewCompAtivo(e.target.checked)}
                    style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                  />
                  <label htmlFor="company-active" style={{ fontSize: '14px', color: 'var(--text-main)', cursor: 'pointer' }}>Empresa ativa após criação</label>
                </div>

                <div style={{ display: 'flex', gap: '12px', marginTop: '16px' }}>
                  <button type="submit" className="btn btn-primary" style={{ flexGrow: 1 }} disabled={loading}>
                    {loading ? 'Cadastrando...' : 'Salvar Empresa'}
                  </button>
                  <button 
                    type="button" 
                    onClick={() => setCurrentScreen('companies')} 
                    className="btn btn-secondary"
                  >
                    Cancelar
                  </button>
                </div>
              </form>
            </div>
          )}

          {/* 4. SCREEN: GESTÃO DE USUÁRIOS E IMPORTAÇÃO EM LOTE */}
          {currentScreen === 'users' && (
            <div className="animate-fade-in" style={{ display: 'flex', flexDirection: 'column', gap: '32px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '32px', alignItems: 'start' }}>
                
                {/* A. Cadastro Manual */}
                <div className="card">
                  <h3 style={{ fontSize: '18px', fontWeight: '700', marginBottom: '24px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <PlusCircle size={18} style={{ color: 'var(--color-primary)' }} />
                    Cadastro Individual de Usuário
                  </h3>

                  <form onSubmit={handleCreateUserManual} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                    <div>
                      <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '6px' }}>Empresa Vinculada</label>
                      <select 
                        className="input" 
                        value={userEmpresaId} 
                        onChange={(e) => setUserEmpresaId(e.target.value)}
                        required
                      >
                        <option value="">Selecione uma Empresa</option>
                        {companies.map(c => (
                          <option key={c.id} value={c.id}>{c.nome}</option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '6px' }}>Nome Completo</label>
                      <input 
                        type="text" 
                        className="input" 
                        placeholder="Ex: João da Silva" 
                        value={userNome}
                        onChange={(e) => setUserNome(e.target.value)}
                        required
                      />
                    </div>

                    <div>
                      <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '6px' }}>E-mail</label>
                      <input 
                        type="email" 
                        className="input" 
                        placeholder="joao@empresa.com" 
                        value={userEmail}
                        onChange={(e) => setUserEmail(e.target.value)}
                        required
                      />
                    </div>

                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                      <div>
                        <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '6px' }}>Cargo</label>
                        <input 
                          type="text" 
                          className="input" 
                          placeholder="Analista" 
                          value={userCargo}
                          onChange={(e) => setUserCargo(e.target.value)}
                        />
                      </div>
                      <div>
                        <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '6px' }}>Departamento</label>
                        <input 
                          type="text" 
                          className="input" 
                          placeholder="TI" 
                          value={userDept}
                          onChange={(e) => setUserDept(e.target.value)}
                        />
                      </div>
                    </div>

                    <div>
                      <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '6px' }}>Nível de Permissão</label>
                      <select 
                        className="input" 
                        value={userPerm}
                        onChange={(e) => setUserPerm(e.target.value as any)}
                      >
                        <option value="colaborador">Colaborador (Responder Quizzes)</option>
                        <option value="gestor">Gestor (Acompanhar Equipe)</option>
                        <option value="admin">Administrador da Empresa</option>
                      </select>
                    </div>

                    <button type="submit" className="btn btn-primary" style={{ width: '100%', marginTop: '8px' }} disabled={loading}>
                      {loading ? 'Adicionando...' : 'Salvar Usuário'}
                    </button>
                  </form>
                </div>

                {/* B. Importação em Massa */}
                <div className="card">
                  <h3 style={{ fontSize: '18px', fontWeight: '700', marginBottom: '8px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <UploadCloud size={18} style={{ color: 'var(--color-accent)' }} />
                    Importação em Lote
                  </h3>
                  <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '24px' }}>
                    Cadastre múltiplos colaboradores enviando uma planilha Excel ou arquivo CSV.
                  </p>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'rgba(255,255,255,0.02)', padding: '12px', border: '1px solid var(--border-color)', borderRadius: 'var(--radius-sm)' }}>
                      <div>
                        <strong style={{ fontSize: '13px', display: 'block' }}>Modelo de Planilha</strong>
                        <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>Use a estrutura com as colunas corretas</span>
                      </div>
                      <button onClick={downloadTemplate} className="btn btn-secondary" style={{ padding: '8px 12px', fontSize: '12px' }}>
                        <Download size={14} />
                        Baixar Template
                      </button>
                    </div>

                    <div>
                      <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '8px' }}>1. Selecione a Empresa para Vincular os Usuários</label>
                      <select 
                        className="input" 
                        value={uploadEmpresaId} 
                        onChange={(e) => setUploadEmpresaId(e.target.value)}
                        required
                      >
                        {companies.map(c => (
                          <option key={c.id} value={c.id}>{c.nome}</option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '8px' }}>2. Selecione o arquivo (.xlsx ou .csv)</label>
                      <input 
                        type="file" 
                        accept=".xlsx, .csv" 
                        onChange={handleFileUpload} 
                        className="input"
                        style={{ padding: '8px' }}
                      />
                    </div>

                    {uploadSuccessMessage && (
                      <div style={{ color: 'var(--status-success)', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <CheckCircle size={16} />
                        <span>{uploadSuccessMessage}</span>
                      </div>
                    )}

                    {parsedUsers.length > 0 && (
                      <button 
                        onClick={handleSaveBulkUsers} 
                        className="btn btn-primary" 
                        style={{ width: '100%', background: 'var(--color-accent)' }}
                        disabled={loading}
                      >
                        {loading ? 'Salvando...' : `Importar e Salvar ${parsedUsers.length} Usuários no Banco`}
                      </button>
                    )}
                  </div>
                </div>
              </div>

              {/* Tabela de Erros de Validação da Planilha */}
              {uploadErrors.length > 0 && (
                <div className="card animate-fade-in" style={{ border: '1px solid var(--status-error)' }}>
                  <h4 style={{ color: 'var(--status-error)', fontSize: '15px', fontWeight: 'bold', marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <AlertTriangle size={18} />
                    Erros Detectados na Planilha (Corrija antes de importar ou prossiga com os válidos)
                  </h4>
                  <div className="table-container">
                    <table className="table">
                      <thead>
                        <tr>
                          <th>Linha</th>
                          <th>E-mail</th>
                          <th>Erro Encontrado</th>
                        </tr>
                      </thead>
                      <tbody>
                        {uploadErrors.map((err, idx) => (
                          <tr key={idx}>
                            <td style={{ color: 'var(--status-error)', fontWeight: 'bold' }}>{err.line}</td>
                            <td>{err.email}</td>
                            <td style={{ color: 'var(--text-muted)' }}>{err.error}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {/* Lista Geral de Usuários do Sistema */}
              <div className="card">
                <h3 style={{ fontSize: '18px', fontWeight: '700', marginBottom: '24px' }}>Lista Completa de Usuários Cadastrados</h3>
                {users.length === 0 ? (
                  <p style={{ color: 'var(--text-muted)', fontSize: '14px', textAlign: 'center' }}>Nenhum usuário cadastrado.</p>
                ) : (
                  <div className="table-container">
                    <table className="table">
                      <thead>
                        <tr>
                          <th>Nome</th>
                          <th>E-mail</th>
                          <th>Empresa</th>
                          <th>Cargo / Depto</th>
                          <th>Permissão</th>
                          <th>Criação</th>
                        </tr>
                      </thead>
                      <tbody>
                        {users.map((user) => (
                          <tr key={user.id}>
                            <td style={{ fontWeight: '600', color: '#fff' }}>{user.nome}</td>
                            <td>{user.email}</td>
                            <td>{user.empresas?.nome || 'Nenhuma'}</td>
                            <td>
                              {user.cargo ? (
                                <span style={{ display: 'flex', gap: '4px', alignItems: 'center' }}>
                                  <Briefcase size={12} style={{ color: 'var(--text-muted)' }} />
                                  {user.cargo} {user.departamento && `(${user.departamento})`}
                                </span>
                              ) : 'N/A'}
                            </td>
                            <td>
                              <span className={`badge ${
                                user.nivel_permissao === 'admin' ? 'badge-danger' : 
                                user.nivel_permissao === 'gestor' ? 'badge-warning' : 'badge-success'
                              }`}>
                                {user.nivel_permissao}
                              </span>
                            </td>
                            <td>{new Date(user.criado_em).toLocaleDateString('pt-BR')}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* 5. SCREEN: LISTAGEM DE USUÁRIOS POR EMPRESA */}
          {currentScreen === 'users-by-company' && (
            <div className="animate-fade-in card">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', gap: '20px' }}>
                <h3 style={{ fontSize: '18px', fontWeight: '700' }}>Filtrar Colaboradores</h3>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px', width: '300px' }}>
                  <label style={{ fontSize: '13px', color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>Selecione a Empresa:</label>
                  <select 
                    className="input" 
                    value={filterEmpresaId}
                    onChange={(e) => {
                      setFilterEmpresaId(e.target.value);
                      fetchUsers(e.target.value);
                    }}
                  >
                    {companies.map(c => (
                      <option key={c.id} value={c.id}>{c.nome}</option>
                    ))}
                  </select>
                </div>
              </div>

              {users.filter(u => u.empresa_id === filterEmpresaId).length === 0 ? (
                <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>
                  Nenhum usuário encontrado cadastrado nesta empresa.
                </div>
              ) : (
                <div className="table-container">
                  <table className="table">
                    <thead>
                      <tr>
                        <th>Nome</th>
                        <th>E-mail</th>
                        <th>Cargo</th>
                        <th>Departamento</th>
                        <th>Permissão</th>
                        <th>Primeiro Acesso</th>
                      </tr>
                    </thead>
                    <tbody>
                      {users.filter(u => u.empresa_id === filterEmpresaId).map((user) => (
                        <tr key={user.id}>
                          <td style={{ fontWeight: '600', color: '#fff' }}>{user.nome}</td>
                          <td>{user.email}</td>
                          <td>{user.cargo || 'N/A'}</td>
                          <td>{user.departamento || 'N/A'}</td>
                          <td>
                            <span className={`badge ${
                              user.nivel_permissao === 'admin' ? 'badge-danger' : 
                              user.nivel_permissao === 'gestor' ? 'badge-warning' : 'badge-success'
                            }`}>
                              {user.nivel_permissao}
                            </span>
                          </td>
                          <td>
                            <span className={`badge ${user.primeiro_acesso ? 'badge-warning' : 'badge-success'}`}>
                              {user.primeiro_acesso ? 'Pendente' : 'Realizado'}
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
