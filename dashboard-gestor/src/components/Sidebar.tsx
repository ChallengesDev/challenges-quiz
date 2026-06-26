import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { 
  LayoutDashboard, 
  Users, 
  BookOpen, 
  TrendingUp, 
  Award, 
  Download, 
  LogOut,
  Trophy,
  Bell,
  Tv
} from 'lucide-react';
import { supabase } from '../lib/supabase';

interface SidebarProps {
  companyName: string;
}

export const Sidebar: React.FC<SidebarProps> = ({ companyName }) => {
  const navigate = useNavigate();

  const handleLogout = async () => {
    await supabase.auth.signOut();
    navigate('/login');
  };

  const navItems = [
    { to: '/', label: 'Visão Geral', icon: LayoutDashboard },
    { to: '/usuarios', label: 'Colaboradores', icon: Users },
    { to: '/conteudo', label: 'Quizzes e Conteúdo', icon: BookOpen },
    { to: '/modo-sala', label: 'Modo Sala', icon: Tv },
    { to: '/analytics', label: 'Analytics & ROI', icon: TrendingUp },
    { to: '/gamificacao', label: 'Gamificação', icon: Award },
    { to: '/notificacoes', label: 'Notificações', icon: Bell },
    { to: '/relatorios', label: 'Relatórios', icon: Download },
  ];

  return (
    <aside className="sidebar no-print">
      {/* Logo Area */}
      <div style={{
        padding: '24px',
        borderBottom: '1px solid var(--border-color)',
        display: 'flex',
        alignItems: 'center',
        gap: '12px'
      }}>
        <div style={{
          background: 'linear-gradient(135deg, var(--color-primary), var(--color-accent))',
          width: '36px',
          height: '36px',
          borderRadius: 'var(--radius-sm)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          boxShadow: 'var(--shadow-glow)'
        }}>
          <Trophy size={20} color="#fff" />
        </div>
        <div>
          <h1 style={{
            fontFamily: 'var(--font-heading)',
            fontSize: '18px',
            fontWeight: 700,
            background: 'linear-gradient(to right, #fff, #94a3b8)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent'
          }}>
            Challenges Quiz
          </h1>
          <span style={{ fontSize: '11px', color: 'var(--color-primary)', fontWeight: 600 }}>
            Painel do Gestor
          </span>
        </div>
      </div>

      {/* Company Tag */}
      <div style={{ padding: '16px 24px 8px 24px' }}>
        <div style={{
          background: 'rgba(99, 102, 241, 0.05)',
          border: '1px solid rgba(99, 102, 241, 0.15)',
          borderRadius: 'var(--radius-sm)',
          padding: '10px 14px',
          fontSize: '13px'
        }}>
          <div style={{ color: 'var(--text-muted)', fontSize: '10px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Empresa Ativa
          </div>
          <div style={{ fontWeight: 600, color: 'var(--text-main)', textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }}>
            {companyName || 'Carregando...'}
          </div>
        </div>
      </div>

      {/* Navigation Links */}
      <nav style={{ flexGrow: 1, padding: '16px 12px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
        {navItems.map((item) => {
          const Icon = item.icon;
          return (
            <NavLink
              key={item.to}
              to={item.to}
              style={({ isActive }) => ({
                display: 'flex',
                alignItems: 'center',
                gap: '12px',
                padding: '12px 16px',
                borderRadius: 'var(--radius-sm)',
                color: isActive ? 'var(--text-white)' : 'var(--text-muted)',
                backgroundColor: isActive ? 'rgba(99, 102, 241, 0.15)' : 'transparent',
                borderLeft: isActive ? '3px solid var(--color-primary)' : '3px solid transparent',
                textDecoration: 'none',
                fontWeight: isActive ? 600 : 500,
                fontSize: '14px',
                transition: 'all 0.2s ease',
              })}
              className={({ isActive }) => isActive ? 'nav-active' : ''}
            >
              <Icon size={18} />
              <span>{item.label}</span>
            </NavLink>
          );
        })}
      </nav>

      {/* Logout Button */}
      <div style={{ padding: '16px', borderTop: '1px solid var(--border-color)' }}>
        <button
          onClick={handleLogout}
          className="btn btn-secondary"
          style={{ width: '100%', justifyContent: 'center', display: 'flex', gap: '8px' }}
        >
          <LogOut size={16} />
          <span>Sair</span>
        </button>
      </div>
    </aside>
  );
};
