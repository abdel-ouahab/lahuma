import React, { createContext, useContext, useState, useEffect } from 'react';
import type { User, AuthState } from '../types';

/** `notAdmin`: the credentials are right but the account has no admin role. */
export type LoginResult = 'ok' | 'invalid' | 'notAdmin';

interface AuthContextType extends AuthState {
  login: (email: string, pass: string) => Promise<LoginResult>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [authState, setAuthState] = useState<AuthState>({
    user: null,
    token: null,
    isAuthenticated: false,
    isLoading: true,
  });

  useEffect(() => {
    const token = localStorage.getItem('lahuma_admin_token');
    const userStr = localStorage.getItem('lahuma_admin_user');
    if (token && userStr) {
      try {
        const user = JSON.parse(userStr);
        setAuthState({
          user,
          token,
          isAuthenticated: true,
          isLoading: false,
        });
        return;
      } catch {
        // failed parse
      }
    }
    setAuthState({
      user: null,
      token: null,
      isAuthenticated: false,
      isLoading: false,
    });
  }, []);

  const login = async (email: string, pass?: string): Promise<LoginResult> => {
    try {
      // Try real backend login
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password: pass ?? '' }),
      });

      if (res.ok) {
        const data = await res.json();
        // The backend only serves admin routes to ADMIN accounts.
        if (data.user.role !== 'ADMIN') return 'notAdmin';
        const user: User = {
          id: data.user.id,
          email: data.user.email,
          name: data.user.name,
          role: data.user.role,
          status: 'ACTIVE',
          createdAt: data.user.createdAt || new Date().toISOString(),
        };
        const token = data.token;
        localStorage.setItem('lahuma_admin_token', token);
        localStorage.setItem('lahuma_admin_user', JSON.stringify(user));
        setAuthState({
          user,
          token,
          isAuthenticated: true,
          isLoading: false,
        });
        return 'ok';
      }
    } catch {
      // Backend unreachable: treated as a failed login
    }

    return 'invalid';
  };

  const logout = () => {
    localStorage.removeItem('lahuma_admin_token');
    localStorage.removeItem('lahuma_admin_user');
    setAuthState({
      user: null,
      token: null,
      isAuthenticated: false,
      isLoading: false,
    });
  };

  return (
    <AuthContext.Provider value={{ ...authState, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
