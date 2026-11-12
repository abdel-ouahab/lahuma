import React, { useEffect, useState } from 'react';
import { UserPlus, Search, Users as UsersIcon, AlertCircle } from 'lucide-react';
import { getUsers, createUser } from '../services/api';
import type { User, UserRole } from '../types';
import { StatusBadge } from '../components/StatusBadge';
import { PageHeader } from '../components/PageHeader';
import { EmptyState } from '../components/EmptyState';
import { Modal } from '../components/Modal';

const ROLE_FILTERS: { value: string; label: string }[] = [
  { value: 'ALL', label: 'All' },
  { value: 'ADMIN', label: 'Admins' },
  { value: 'MODERATOR', label: 'Moderators' },
  { value: 'USER', label: 'Users' },
];

export const UsersPage: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [roleFilter, setRoleFilter] = useState<string>('ALL');
  const [loading, setLoading] = useState<boolean>(true);
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);
  const [showAddModal, setShowAddModal] = useState<boolean>(false);
  const [error, setError] = useState<string>('');
  const [formError, setFormError] = useState<string>('');

  // Form State
  const [newEmail, setNewEmail] = useState<string>('');
  const [newName, setNewName] = useState<string>('');
  const [newPassword, setNewPassword] = useState<string>('');
  const [newRole, setNewRole] = useState<UserRole>('USER');

  useEffect(() => {
    getUsers()
      .then(setUsers)
      .catch((err) => setError(err instanceof Error ? err.message : 'Could not load users.'))
      .finally(() => setLoading(false));
  }, []);

  const filteredUsers = users.filter((u) => {
    const matchesSearch =
      u.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      u.email.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesRole = roleFilter === 'ALL' || u.role === roleFilter;
    return matchesSearch && matchesRole;
  });

  const handleAddUser = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newEmail || !newName || !newPassword || isSubmitting) return;

    setIsSubmitting(true);
    setFormError('');
    try {
      const created = await createUser({
        email: newEmail,
        name: newName,
        password: newPassword,
        role: newRole,
      });

      setUsers((prev) => [created, ...prev]);
      setNewEmail('');
      setNewName('');
      setNewPassword('');
      setShowAddModal(false);
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Could not create the user.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="page">
      <PageHeader
        title="Users"
        subtitle="Accounts and roles."
        actions={
          <button type="button" onClick={() => setShowAddModal(true)} className="btn btn-primary">
            <UserPlus size={15} />
            <span>Add user</span>
          </button>
        }
      />

      {error && (
        <div className="alert alert-danger" role="alert" style={{ marginBottom: 'var(--space-4)' }}>
          <AlertCircle size={16} />
          <span>{error}</span>
        </div>
      )}

      <div className="toolbar">
        <div className="input-icon">
          <Search size={15} />
          <input
            type="search"
            aria-label="Search users"
            placeholder="Search by name or email"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="input"
          />
        </div>

        <div className="segmented" role="group" aria-label="Filter by role">
          {ROLE_FILTERS.map((f) => (
            <button
              key={f.value}
              type="button"
              aria-pressed={roleFilter === f.value}
              onClick={() => setRoleFilter(f.value)}
            >
              {f.label}
            </button>
          ))}
        </div>
      </div>

      <div className="card card-flush">
        <div className="table-wrap">
          <table className="table">
            <thead>
              <tr>
                <th>User</th>
                <th>Role</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                Array.from({ length: 5 }, (_, i) => (
                  <tr key={i}>
                    <td><span className="skeleton" style={{ height: 32, width: 200 }} /></td>
                    <td><span className="skeleton" style={{ height: 18, width: 60 }} /></td>
                    <td><span className="skeleton" style={{ height: 14, width: 70 }} /></td>
                  </tr>
                ))
              ) : filteredUsers.length === 0 ? (
                <tr>
                  <td colSpan={3}>
                    <EmptyState
                      icon={UsersIcon}
                      title="No users found"
                      message="Try a different search or role filter."
                    />
                  </td>
                </tr>
              ) : (
                filteredUsers.map((user) => (
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
                ))
              )}
            </tbody>
          </table>
        </div>
        {!loading && filteredUsers.length > 0 && (
          <div className="table-footer">
            {filteredUsers.length} of {users.length} {users.length === 1 ? 'user' : 'users'}
          </div>
        )}
      </div>

      {showAddModal && (
        <Modal
          title="Add user"
          description="Create an account and choose its role."
          onClose={() => setShowAddModal(false)}
        >
          <form onSubmit={handleAddUser}>
            {formError && (
              <div className="alert alert-danger" role="alert" style={{ marginBottom: 'var(--space-4)' }}>
                <AlertCircle size={16} />
                <span>{formError}</span>
              </div>
            )}
            <div className="field">
              <label className="label" htmlFor="new-name">Full name</label>
              <input
                id="new-name"
                type="text"
                required
                placeholder="Tariq Ibn Ziyad"
                value={newName}
                onChange={(e) => setNewName(e.target.value)}
                className="input"
              />
            </div>

            <div className="field">
              <label className="label" htmlFor="new-email">Email</label>
              <input
                id="new-email"
                type="email"
                required
                placeholder="tariq@example.com"
                value={newEmail}
                onChange={(e) => setNewEmail(e.target.value)}
                className="input"
              />
            </div>

            <div className="field">
              <label className="label" htmlFor="new-password">Password</label>
              <input
                id="new-password"
                type="password"
                required
                minLength={8}
                maxLength={72}
                autoComplete="new-password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                className="input"
              />
              <span className="hint">At least 8 characters. Share it with the person privately.</span>
            </div>

            <div className="field">
              <label className="label" htmlFor="new-role">Role</label>
              <select
                id="new-role"
                value={newRole}
                onChange={(e) => setNewRole(e.target.value as UserRole)}
                className="select"
              >
                <option value="USER">User</option>
                <option value="MODERATOR">Moderator</option>
                <option value="ADMIN">Administrator</option>
              </select>
            </div>

            <div className="modal-actions">
              <button type="button" onClick={() => setShowAddModal(false)} className="btn btn-secondary">
                Cancel
              </button>
              <button type="submit" className="btn btn-primary" disabled={isSubmitting}>
                {isSubmitting ? 'Saving…' : 'Add user'}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
};
