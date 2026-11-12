import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Users, ShieldCheck, Mic2, Activity, RefreshCw, ArrowUpRight, AlertCircle } from 'lucide-react';
import { StatCard } from '../components/StatCard';
import { StatusBadge } from '../components/StatusBadge';
import { PageHeader } from '../components/PageHeader';
import { getDashboardMetrics, getUsers } from '../services/api';
import type { DashboardMetrics, User } from '../types';

export const DashboardPage: React.FC = () => {
  const [metrics, setMetrics] = useState<DashboardMetrics | null>(null);
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>('');

  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const [m, u] = await Promise.all([getDashboardMetrics(), getUsers()]);
      setMetrics(m);
      setUsers(u);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load the dashboard.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  return (
    <div className="page">
      <PageHeader
        title="Overview"
        subtitle="Accounts, reciters and services at a glance."
        actions={
          <button type="button" onClick={loadData} className="btn btn-secondary" disabled={loading}>
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
            <span>{loading ? 'Refreshing' : 'Refresh'}</span>
          </button>
        }
      />

      {error && (
        <div className="alert alert-danger" role="alert" style={{ marginBottom: 'var(--space-4)' }}>
          <AlertCircle size={16} />
          <span>{error}</span>
        </div>
      )}

      <div className="grid-stats">
        <StatCard
          title="Registered users"
          color="green"
          value={metrics?.totalUsers ?? (error ? '—' : null)}
          icon={Users}
          subtitle="Accounts in the database"
        />
        <StatCard
          title="Administrators"
          color="orange"
          value={metrics?.totalAdmins ?? (error ? '—' : null)}
          icon={ShieldCheck}
          subtitle="Accounts with admin access"
        />
        <StatCard
          title="Reciters"
          color="red"
          value={metrics?.totalReciters ?? (error ? '—' : null)}
          icon={Mic2}
          subtitle={metrics ? `${metrics.uploadedSurahs} Surah recordings uploaded` : 'Surah recordings'}
        />
        <StatCard
          title="API"
          color="blue"
          value={metrics ? (metrics.apiStatus === 'healthy' ? 'Online' : 'Offline') : error ? 'Offline' : null}
          icon={Activity}
          subtitle="Backend health check"
        />
      </div>

      <div>
        <section className="card card-flush" aria-labelledby="recent-users">
          <div className="card-header">
            <h2 className="card-title" id="recent-users">Recent users</h2>
            <Link to="/users" className="btn btn-ghost btn-sm">
              View all <ArrowUpRight size={13} />
            </Link>
          </div>

          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  <th>User</th>
                  <th>Role</th>
                  <th>Joined</th>
                </tr>
              </thead>
              <tbody>
                {loading
                  ? Array.from({ length: 4 }, (_, i) => (
                      <tr key={i}>
                        <td><span className="skeleton" style={{ height: 32, width: '70%' }} /></td>
                        <td><span className="skeleton" style={{ height: 18, width: 56 }} /></td>
                        <td><span className="skeleton" style={{ height: 18, width: 64 }} /></td>
                      </tr>
                    ))
                  : users.slice(0, 4).map((user) => (
                      <tr key={user.id}>
                        <td>
                          <div className="cell-user">
                            <div className="avatar" aria-hidden="true">{user.name.charAt(0)}</div>
                            <div>
                              <div className="cell-title">{user.name}</div>
                              <div className="cell-sub">{user.email}</div>
                            </div>
                          </div>
                        </td>
                        <td><StatusBadge type="role" value={user.role} /></td>
                        <td className="muted tabular">{new Date(user.createdAt).toLocaleDateString()}</td>
                      </tr>
                    ))}
              </tbody>
            </table>
          </div>
        </section>

      </div>
    </div>
  );
};
