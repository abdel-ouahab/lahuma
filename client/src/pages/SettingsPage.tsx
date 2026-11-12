import React, { useEffect, useState } from 'react';
import { Server, RefreshCw, Info } from 'lucide-react';
import { PageHeader } from '../components/PageHeader';
import { checkBackendHealth } from '../services/api';

// Read-only: the server is configured in backend/.env and the root .env on
// the host (see README › Production), not from this panel. Nothing here
// pretends to save a setting it can't change.
export const SettingsPage: React.FC = () => {
  const [online, setOnline] = useState<boolean | null>(null);
  const [checking, setChecking] = useState(false);

  const check = async () => {
    setChecking(true);
    setOnline((await checkBackendHealth()).online);
    setChecking(false);
  };

  useEffect(() => {
    check();
  }, []);

  return (
    <div className="page">
      <PageHeader title="Settings" subtitle="Server status and where its configuration lives." />

      <div className="stack page-narrow">
        <section className="card">
          <div className="card-header">
            <h2 className="card-title"><Server size={16} /> API and server</h2>
            <button type="button" onClick={check} className="btn btn-secondary btn-sm" disabled={checking}>
              <RefreshCw size={13} className={checking ? 'animate-spin' : ''} />
              <span>Check</span>
            </button>
          </div>

          <div className="setting-row">
            <div>
              <div className="setting-title">Backend</div>
              <div className="hint">
                <code>{window.location.origin}/api</code>
              </div>
            </div>
            {online === null ? (
              <span className="skeleton" style={{ height: 20, width: 64 }} aria-label="Checking" />
            ) : (
              <span className={`badge ${online ? 'badge-success' : 'badge-danger'}`} role="status">
                {online ? 'Online' : 'Offline'}
              </span>
            )}
          </div>
        </section>

        <section className="card">
          <div className="card-header">
            <h2 className="card-title"><Info size={16} /> Configuration</h2>
          </div>
          <p className="hint" style={{ margin: 0 }}>
            Token lifetime (<code>JWT_EXPIRES_IN</code>), allowed origin, media origin and database are set
            in <code>backend/.env</code> and the root <code>.env</code> on the server. Restart the stack after
            changing them. Admin access is granted with <code>npm run make-admin -- &lt;email&gt;</code>.
          </p>
        </section>
      </div>
    </div>
  );
};
