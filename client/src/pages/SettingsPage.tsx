import React, { useEffect, useRef, useState } from 'react';
import { Save, Server, CheckCircle2, SlidersHorizontal } from 'lucide-react';
import { PageHeader } from '../components/PageHeader';

export const SettingsPage: React.FC = () => {
  const [apiUrl, setApiUrl] = useState<string>('http://localhost:4000/api');
  const [jwtExpiresIn, setJwtExpiresIn] = useState<string>('7d');
  const [maintenanceMode, setMaintenanceMode] = useState<boolean>(false);
  const [guestFirstEnabled, setGuestFirstEnabled] = useState<boolean>(true);
  const [savedSuccess, setSavedSuccess] = useState<boolean>(false);
  const timer = useRef<number | undefined>(undefined);

  useEffect(() => () => window.clearTimeout(timer.current), []);

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    setSavedSuccess(true);
    window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => setSavedSuccess(false), 3000);
  };

  return (
    <div className="page">
      <PageHeader
        title="Settings"
        subtitle="API endpoint, authentication policy and runtime feature toggles."
      />

      <form onSubmit={handleSave} className="stack page-narrow">
        <section className="card">
          <div className="card-header">
            <h2 className="card-title"><Server size={16} /> API and server</h2>
          </div>

          <div className="field">
            <label className="label" htmlFor="api-url">Backend API endpoint</label>
            <input
              id="api-url"
              type="text"
              value={apiUrl}
              onChange={(e) => setApiUrl(e.target.value)}
              className="input"
              spellCheck={false}
              style={{ fontFamily: 'var(--font-mono)', fontSize: '0.8125rem' }}
            />
            <span className="hint">Default target for backend requests (Express server on port 4000).</span>
          </div>

          <div className="field">
            <label className="label" htmlFor="jwt">Token expiration</label>
            <select
              id="jwt"
              value={jwtExpiresIn}
              onChange={(e) => setJwtExpiresIn(e.target.value)}
              className="select"
            >
              <option value="1d">1 day</option>
              <option value="7d">7 days (default)</option>
              <option value="30d">30 days</option>
              <option value="365d">1 year</option>
            </select>
          </div>
        </section>

        <section className="card">
          <div className="card-header">
            <h2 className="card-title"><SlidersHorizontal size={16} /> Feature toggles</h2>
          </div>

          <label className="setting-row">
            <div>
              <div className="setting-title">Guest-first navigation</div>
              <div className="hint">Let readers browse the full Quran without creating an account.</div>
            </div>
            <input
              type="checkbox"
              role="switch"
              className="switch"
              checked={guestFirstEnabled}
              onChange={(e) => setGuestFirstEnabled(e.target.checked)}
            />
          </label>

          <label className="setting-row">
            <div>
              <div className="setting-title">Maintenance mode</div>
              <div className="hint">Temporarily pause mobile API syncing during database upgrades.</div>
            </div>
            <input
              type="checkbox"
              role="switch"
              className="switch"
              checked={maintenanceMode}
              onChange={(e) => setMaintenanceMode(e.target.checked)}
            />
          </label>
        </section>

        <div className="row">
          <button type="submit" className="btn btn-primary btn-lg">
            <Save size={15} />
            <span>Save changes</span>
          </button>
          {savedSuccess && (
            <span className="badge badge-success" role="status">
              <CheckCircle2 size={13} /> Saved
            </span>
          )}
        </div>
      </form>
    </div>
  );
};
