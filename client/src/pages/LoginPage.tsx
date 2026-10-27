import React, { useState } from 'react';
import { useNavigate, Navigate } from 'react-router-dom';
import { Lock, Mail, AlertCircle } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export const LoginPage: React.FC = () => {
  const { login, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState<string>('admin@lahuma.app');
  const [password, setPassword] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  if (isAuthenticated) {
    return <Navigate to="/" replace />;
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const result = await login(email, password);
    setLoading(false);
    if (result === 'ok') {
      navigate('/', { replace: true });
    } else if (result === 'notAdmin') {
      setError('This account is not an admin. Ask an admin to grant access.');
    } else {
      setError('Invalid credentials. Please try again.');
    }
  };

  return (
    <div className="auth">
      <div className="card auth-card">
        <div className="auth-brand">
          <div className="brand-mark" aria-hidden="true">ل</div>
          <h1 className="auth-title">Sign in to Lahuma</h1>
          <p className="page-sub" style={{ margin: '4px auto 0' }}>Admin portal</p>
        </div>

        <form onSubmit={handleSubmit} noValidate={false}>
          {error && (
            <div className="alert alert-danger" role="alert" style={{ marginBottom: 'var(--space-4)' }}>
              <AlertCircle size={16} />
              <span>{error}</span>
            </div>
          )}

          <div className="field">
            <label className="label" htmlFor="email">Email</label>
            <div className="input-icon">
              <Mail size={16} />
              <input
                id="email"
                type="email"
                required
                autoComplete="username"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="input"
                placeholder="admin@lahuma.app"
                aria-invalid={error ? true : undefined}
              />
            </div>
          </div>

          <div className="field">
            <label className="label" htmlFor="password">Password</label>
            <div className="input-icon">
              <Lock size={16} />
              <input
                id="password"
                type="password"
                required
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="input"
                aria-invalid={error ? true : undefined}
              />
            </div>
          </div>

          <button
            type="submit"
            className="btn btn-primary btn-lg btn-block"
            disabled={loading}
            style={{ marginTop: 'var(--space-6)' }}
          >
            {loading && <span className="spinner" style={{ borderTopColor: '#fff', borderColor: 'rgba(255,255,255,.4)' }} />}
            <span>{loading ? 'Signing in…' : 'Sign in'}</span>
          </button>
        </form>

        <p className="hint" style={{ textAlign: 'center', marginTop: 'var(--space-6)' }}>
          لهما — قرآنٌ يُتلى، وأجرٌ يُهدى
        </p>
      </div>
    </div>
  );
};
