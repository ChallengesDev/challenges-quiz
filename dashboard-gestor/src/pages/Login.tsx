import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { Trophy, Mail, Lock, AlertCircle, ArrowRight } from 'lucide-react';

export const Login: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const navigate = useNavigate();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setErrorMsg(null);

    if (!email || !password) {
      setErrorMsg('Preencha todos os campos.');
      setLoading(false);
      return;
    }

    try {
      // 1. Tenta fazer login com o Supabase Auth
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) {
        // Fallback do Desenvolvedor (para facilidade de teste local)
        if (email === 'gestor@challenges.com' && password === 'Challenges@123') {
          // Salva uma sessão mock no localStorage
          localStorage.setItem('challenges_mock_session', JSON.stringify({
            user: {
              id: 'mock-gestor-uuid-12345',
              email: 'gestor@challenges.com',
              user_metadata: { nome: 'Gestor Demonstrativo', nivel_permissao: 'gestor' }
            }
          }));
          navigate('/');
          return;
        }
        throw error;
      }

      if (data?.user) {
        // Verifica o perfil público para checar permissão de gestor ou admin
        const { data: profile } = await supabase
          .from('usuarios')
          .select('nivel_permissao')
          .eq('id', data.user.id)
          .single();

        if (profile && profile.nivel_permissao !== 'gestor' && profile.nivel_permissao !== 'admin') {
          await supabase.auth.signOut();
          setErrorMsg('Acesso negado. Apenas gestores ou administradores podem acessar este painel.');
          setLoading(false);
          return;
        }
      }

      navigate('/');
    } catch (error: any) {
      console.error('Erro de login:', error);
      setErrorMsg(error.message || 'Falha ao autenticar. Verifique suas credenciais.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'radial-gradient(circle at center, #0f1322 0%, #0b0f19 100%)',
      padding: '24px'
    }}>
      <div className="card animate-fade-in" style={{
        width: '100%',
        maxWidth: '420px',
        padding: '40px 32px',
        boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.5), var(--shadow-glow)'
      }}>
        {/* Header Logo */}
        <div style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: '12px',
          marginBottom: '32px',
          textAlign: 'center'
        }}>
          <div style={{
            background: 'linear-gradient(135deg, var(--color-primary), var(--color-accent))',
            width: '48px',
            height: '48px',
            borderRadius: 'var(--radius-md)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: '0 0 20px rgba(99, 102, 241, 0.4)'
          }}>
            <Trophy size={24} color="#fff" />
          </div>
          <div>
            <h1 style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '24px',
              fontWeight: 700,
              color: 'var(--text-white)'
            }}>
              Challenges Quiz
            </h1>
            <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
              Faça login no painel do gestor de sua empresa
            </p>
          </div>
        </div>

        {/* Error Message */}
        {errorMsg && (
          <div style={{
            background: 'rgba(239, 68, 68, 0.1)',
            border: '1px solid rgba(239, 68, 68, 0.2)',
            borderRadius: 'var(--radius-sm)',
            padding: '12px',
            display: 'flex',
            gap: '8px',
            alignItems: 'center',
            color: 'var(--status-error)',
            fontSize: '13px',
            marginBottom: '20px'
          }}>
            <AlertCircle size={18} style={{ flexShrink: 0 }} />
            <span>{errorMsg}</span>
          </div>
        )}

        {/* Login Form */}
        <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div>
            <label style={{
              display: 'block',
              fontSize: '13px',
              fontWeight: 500,
              color: 'var(--text-muted)',
              marginBottom: '8px'
            }}>
              E-mail corporativo
            </label>
            <div style={{ position: 'relative' }}>
              <Mail size={18} style={{
                position: 'absolute',
                left: '12px',
                top: '50%',
                transform: 'translateY(-50%)',
                color: 'var(--text-muted)'
              }} />
              <input
                type="email"
                className="input"
                placeholder="nome@empresa.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                style={{ paddingLeft: '40px' }}
                required
              />
            </div>
          </div>

          <div>
            <label style={{
              display: 'block',
              fontSize: '13px',
              fontWeight: 500,
              color: 'var(--text-muted)',
              marginBottom: '8px'
            }}>
              Senha de acesso
            </label>
            <div style={{ position: 'relative' }}>
              <Lock size={18} style={{
                position: 'absolute',
                left: '12px',
                top: '50%',
                transform: 'translateY(-50%)',
                color: 'var(--text-muted)'
              }} />
              <input
                type="password"
                className="input"
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                style={{ paddingLeft: '40px' }}
                required
              />
            </div>
          </div>

          <button
            type="submit"
            className="btn btn-primary"
            disabled={loading}
            style={{
              padding: '12px',
              fontWeight: 600,
              fontSize: '15px',
              marginTop: '10px'
            }}
          >
            {loading ? 'Entrando...' : (
              <>
                <span>Acessar Painel</span>
                <ArrowRight size={16} />
              </>
            )}
          </button>
        </form>

        {/* Demo Credentials Tip */}
        <div style={{
          marginTop: '24px',
          padding: '12px',
          background: 'rgba(255, 255, 255, 0.02)',
          border: '1px solid var(--border-color)',
          borderRadius: 'var(--radius-sm)',
          fontSize: '11px',
          color: 'var(--text-muted)',
          textAlign: 'center'
        }}>
          <strong style={{ color: 'var(--color-primary)' }}>Modo de Teste:</strong><br />
          E-mail: <code style={{ color: 'var(--text-main)' }}>gestor@challenges.com</code><br />
          Senha: <code style={{ color: 'var(--text-main)' }}>Challenges@123</code>
        </div>
      </div>
    </div>
  );
};
