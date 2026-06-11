import React, { useState } from 'react';
import { Bell, ShieldAlert, Award, TrendingDown, Lightbulb } from 'lucide-react';

interface TopbarProps {
  title: string;
  userName: string;
  userEmail: string;
}

export const Topbar: React.FC<TopbarProps> = ({ title, userName, userEmail }) => {
  const [showNotifications, setShowNotifications] = useState(false);

  // Mocked automated insights as notifications
  const alerts = [
    {
      id: 1,
      type: 'critical',
      message: 'Este time tem gap crítico em Compliance',
      icon: ShieldAlert,
      color: 'var(--status-error)'
    },
    {
      id: 2,
      type: 'success',
      message: 'Colaborador João Silva tem alto potencial identificado',
      icon: Award,
      color: 'var(--status-success)'
    },
    {
      id: 3,
      type: 'warning',
      message: 'Risco de queda de engajamento no Time Comercial',
      icon: TrendingDown,
      color: 'var(--status-warning)'
    },
    {
      id: 4,
      type: 'info',
      message: 'Sugestão: Crie um desafio reforçado para o tópico LGPD',
      icon: Lightbulb,
      color: 'var(--color-primary)'
    }
  ];

  return (
    <header className="topbar no-print">
      <div>
        <h2 style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '20px',
          fontWeight: 600,
          color: 'var(--text-white)'
        }}>
          {title}
        </h2>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: '24px' }}>
        {/* Notifications Icon with count */}
        <div style={{ position: 'relative' }}>
          <button
            onClick={() => setShowNotifications(!showNotifications)}
            style={{
              background: 'none',
              border: 'none',
              color: 'var(--text-muted)',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '6px',
              borderRadius: '50%',
              transition: 'background 0.2s',
            }}
            onMouseEnter={(e) => e.currentTarget.style.backgroundColor = 'var(--bg-hover)'}
            onMouseLeave={(e) => e.currentTarget.style.backgroundColor = 'transparent'}
          >
            <Bell size={20} />
            <span style={{
              position: 'absolute',
              top: '2px',
              right: '2px',
              backgroundColor: 'var(--status-error)',
              color: '#fff',
              fontSize: '9px',
              fontWeight: 'bold',
              borderRadius: '50%',
              width: '15px',
              height: '15px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              {alerts.length}
            </span>
          </button>

          {/* Notifications Dropdown */}
          {showNotifications && (
            <div style={{
              position: 'absolute',
              top: '40px',
              right: '0',
              width: '320px',
              backgroundColor: 'var(--bg-card)',
              border: '1px solid var(--border-color)',
              borderRadius: 'var(--radius-md)',
              boxShadow: 'var(--shadow-lg)',
              zIndex: 100,
              padding: '8px 0',
              animation: 'fadeIn 0.2s ease-out'
            }}>
              <div style={{
                padding: '12px 16px',
                borderBottom: '1px solid var(--border-color)',
                fontWeight: 600,
                fontSize: '14px',
                color: 'var(--text-white)'
              }}>
                Insights Automáticos e Alertas ({alerts.length})
              </div>
              <div style={{ maxHeight: '280px', overflowY: 'auto' }}>
                {alerts.map((alert) => {
                  const AlertIcon = alert.icon;
                  return (
                    <div
                      key={alert.id}
                      style={{
                        padding: '12px 16px',
                        borderBottom: '1px solid var(--border-color)',
                        display: 'flex',
                        gap: '12px',
                        cursor: 'pointer',
                        transition: 'background-color 0.2s'
                      }}
                      onMouseEnter={(e) => e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.02)'}
                      onMouseLeave={(e) => e.currentTarget.style.backgroundColor = 'transparent'}
                    >
                      <div style={{ color: alert.color, flexShrink: 0, marginTop: '2px' }}>
                        <AlertIcon size={16} />
                      </div>
                      <div style={{ fontSize: '12px', color: 'var(--text-main)', lineHeight: '1.4' }}>
                        {alert.message}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        {/* Vertical Separator */}
        <div style={{ width: '1px', height: '24px', backgroundColor: 'var(--border-color)' }}></div>

        {/* User Profile Info */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{
            width: '36px',
            height: '36px',
            borderRadius: '50%',
            backgroundColor: 'var(--color-primary)',
            color: '#fff',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontWeight: 600,
            fontSize: '14px',
            boxShadow: 'var(--shadow-glow)'
          }}>
            {userName ? userName.charAt(0).toUpperCase() : 'G'}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-white)' }}>
              {userName || 'Gestor'}
            </span>
            <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
              {userEmail || 'gestor@empresa.com'}
            </span>
          </div>
        </div>
      </div>
    </header>
  );
};
