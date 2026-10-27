import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Users, BookOpen, Bookmark, Activity, RefreshCw, ArrowUpRight } from 'lucide-react';
import { StatCard } from '../components/StatCard';
import { StatusBadge } from '../components/StatusBadge';
import { PageHeader } from '../components/PageHeader';
import { EmptyState } from '../components/EmptyState';
import { getDashboardMetrics, getUsers, getActivityLogs } from '../services/api';
import type { DashboardMetrics, User, ActivityLog } from '../types';

export const DashboardPage: React.FC = () => {
  const [metrics, setMetrics] = useState<DashboardMetrics | null>(null);
  const [users, setUsers] = useState<User[]>([]);
  const [logs, setLogs] = useState<ActivityLog[]>([]);
  const [loading, setLoading] = useState<boolean>(true);

  const loadData = async () => {
    setLoading(true);
    const [m, u, l] = await Promise.all([getDashboardMetrics(), getUsers(), getActivityLogs()]);
    setMetrics(m);
    setUsers(u);
    setLogs(l);
    setLoading(false);
  };

  useEffect(() => {
    loadData();
  }, []);

  return (
    <div className="page">
      <PageHeader
        title="Overview"
        subtitle="Platform activity, accounts and services at a glance."
        actions={
          <button type="button" onClick={loadData} className="btn btn-secondary" disabled={loading}>
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
            <span>{loading ? 'Refreshing' : 'Refresh'}</span>
          </button>
        }
      />

      <div className="grid-stats">
        <StatCard
          title="Registered users"
          color="green"
          value={metrics?.totalUsers ?? null}
          icon={Users}
          subtitle="Registered accounts"
        />
        <StatCard
          title="Active readers today"
          color="orange"
          value={metrics?.activeToday ?? null}
          icon={Activity}
          subtitle="Guest and signed-in readers"
        />
        <StatCard
          title="Bookmarks"
          color="red"
          value={metrics?.totalBookmarks.toLocaleString() ?? null}
          icon={Bookmark}
          subtitle="Saved locally and synced"
        />
        <StatCard
          title="Quran catalog"
          color="blue"
          value={metrics ? `${metrics.totalSurahs} Surahs` : null}
          icon={BookOpen}
          subtitle="Full dataset available"
        />
      </div>

      <div className="grid-2">
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
                  <th>Status</th>
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
                        <td><StatusBadge type="status" value={user.status} /></td>
                      </tr>
                    ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className="card card-flush" aria-labelledby="activity">
          <div className="card-header">
            <h2 className="card-title" id="activity">Activity</h2>
          </div>

          {!loading && logs.length === 0 ? (
            <EmptyState icon={Activity} title="No activity yet" message="System events will show up here." />
          ) : (
            <ul className="activity">
              {loading
                ? Array.from({ length: 4 }, (_, i) => (
                    <li key={i}><span className="skeleton" style={{ height: 34, width: '100%' }} /></li>
                  ))
                : logs.map((log) => (
                    <li key={log.id}>
                      <span className={`dot ${log.type}`} aria-hidden="true" />
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontWeight: 500 }}>{log.action}</div>
                        <div className="row-between cell-sub">
                          <span>{log.user}</span>
                          <span>{log.timestamp}</span>
                        </div>
                      </div>
                    </li>
                  ))}
            </ul>
          )}
        </section>
      </div>
    </div>
  );
};
