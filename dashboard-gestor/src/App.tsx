import React, { useEffect, useState } from 'react';
import { BrowserRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { supabase } from './lib/supabase';
import { Sidebar } from './components/Sidebar';
import { Topbar } from './components/Topbar';

// Pages
import { Login } from './pages/Login';
import { DashboardOverview } from './pages/DashboardOverview';
import { UserManagement } from './pages/UserManagement';
import { ContentManagement } from './pages/ContentManagement';
import { Analytics } from './pages/Analytics';
import { GamificationSettings } from './pages/GamificationSettings';
import { Reports } from './pages/Reports';
import { Notifications } from './pages/Notifications';
import { ModoSalaGestor } from './pages/ModoSalaGestor';

const LayoutWrapper: React.FC<{ children: React.ReactNode; companyName: string; userName: string; userEmail: string }> = ({
  children,
  companyName,
  userName,
  userEmail
}) => {
  const location = useLocation();

  // Mapping paths to titles
  const getPageTitle = (pathname: string) => {
    switch (pathname) {
      case '/':
        return 'Visão Geral do Gestor';
      case '/usuarios':
        return 'Gestão de Colaboradores e Equipes';
      case '/conteudo':
        return 'Gestão Acadêmica e de Quizzes';
      case '/analytics':
        return 'Analytics & ROI de Treinamento';
      case '/gamificacao':
        return 'Configurações de Gamificação';
      case '/notificacoes':
        return 'Notificações da Empresa';
      case '/modo-sala':
        return 'Modo Sala ao Vivo (Multiplayer)';
      case '/relatorios':
        return 'Relatórios e Auditoria';
      default:
        return 'Painel de Controle';
    }
  };

  return (
    <div className="admin-layout">
      <Sidebar companyName={companyName} />
      <main className="main-content">
        <Topbar 
          title={getPageTitle(location.pathname)} 
          userName={userName} 
          userEmail={userEmail} 
        />
        {children}
      </main>
    </div>
  );
};

export default function App() {
  const [session, setSession] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [companyName, setCompanyName] = useState('Challenges Quiz Corp');
  const [userName, setUserName] = useState('Gestor Geral');
  const [userEmail, setUserEmail] = useState('gestor@challenges.com');

  // Load session from Supabase or mock localStorage fallback
  const checkAuth = async () => {
    try {
      setLoading(true);

      // Check mock session first (offline mode compatibility)
      const mockSessionStr = localStorage.getItem('challenges_mock_session');
      if (mockSessionStr) {
        const mockSess = JSON.parse(mockSessionStr);
        setSession(mockSess);
        setUserName(mockSess.user.user_metadata?.nome || 'Gestor Demonstrativo');
        setUserEmail(mockSess.user.email);
        setCompanyName('Challenges Quiz Corp (Demonstração)');
        setLoading(false);
        return;
      }

      // Check real Supabase session
      const { data: { session: realSession } } = await supabase.auth.getSession();
      if (realSession) {
        setSession(realSession);
        
        // Fetch user metadata & profile details
        const userId = realSession.user.id;
        const { data: profile } = await supabase
          .from('usuarios')
          .select('*, empresas(nome)')
          .eq('id', userId)
          .single();

        if (profile) {
          setUserName(profile.nome || 'Gestor');
          setUserEmail(profile.email);
          if (profile.empresas && profile.empresas.nome) {
            setCompanyName(profile.empresas.nome);
          }
        }
      } else {
        setSession(null);
      }
    } catch (e) {
      console.error('Erro ao verificar sessão:', e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    checkAuth();

    // Listen to real auth state changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, newSession) => {
      if (event === 'SIGNED_IN' && newSession) {
        setSession(newSession);
        checkAuth();
      } else if (event === 'SIGNED_OUT') {
        localStorage.removeItem('challenges_mock_session');
        setSession(null);
      }
    });

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  if (loading) {
    return (
      <div style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: 'var(--bg-main)',
        color: 'var(--text-muted)',
        fontFamily: 'var(--font-sans)',
        fontSize: '15px'
      }}>
        Carregando painel do gestor...
      </div>
    );
  }

  // Routing
  return (
    <BrowserRouter>
      <Routes>
        {/* Public route */}
        <Route 
          path="/login" 
          element={session ? <Navigate to="/" replace /> : <Login />} 
        />

        {/* Protected routes wrapped in Layout */}
        <Route
          path="/"
          element={
            session ? (
              <LayoutWrapper companyName={companyName} userName={userName} userEmail={userEmail}>
                <DashboardOverview />
              </LayoutWrapper>
            ) : (
              <Navigate to="/login" replace />
            )
          }
        />

        <Route
          path="/usuarios"
          element={
            session ? (
              <LayoutWrapper companyName={companyName} userName={userName} userEmail={userEmail}>
                <UserManagement />
              </LayoutWrapper>
            ) : (
              <Navigate to="/login" replace />
            )
          }
        />

        <Route
          path="/conteudo"
          element={
            session ? (
              <LayoutWrapper companyName={companyName} userName={userName} userEmail={userEmail}>
                <ContentManagement />
              </LayoutWrapper>
            ) : (
              <Navigate to="/login" replace />
            )
          }
        />

        <Route
          path="/analytics"
          element={
            session ? (
              <LayoutWrapper companyName={companyName} userName={userName} userEmail={userEmail}>
                <Analytics />
              </LayoutWrapper>
            ) : (
              <Navigate to="/login" replace />
            )
          }
        />

        <Route
          path="/gamificacao"
          element={
            session ? (
              <LayoutWrapper companyName={companyName} userName={userName} userEmail={userEmail}>
                <GamificationSettings />
              </LayoutWrapper>
            ) : (
              <Navigate to="/login" replace />
            )
          }
        />

        <Route
          path="/notificacoes"
          element={
            session ? (
              <LayoutWrapper companyName={companyName} userName={userName} userEmail={userEmail}>
                <Notifications />
              </LayoutWrapper>
            ) : (
              <Navigate to="/login" replace />
            )
          }
        />

        <Route
          path="/relatorios"
          element={
            session ? (
              <LayoutWrapper companyName={companyName} userName={userName} userEmail={userEmail}>
                <Reports />
              </LayoutWrapper>
            ) : (
              <Navigate to="/login" replace />
            )
          }
        />

        <Route
          path="/modo-sala"
          element={
            session ? (
              <LayoutWrapper companyName={companyName} userName={userName} userEmail={userEmail}>
                <ModoSalaGestor />
              </LayoutWrapper>
            ) : (
              <Navigate to="/login" replace />
            )
          }
        />

        {/* Fallback route */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
