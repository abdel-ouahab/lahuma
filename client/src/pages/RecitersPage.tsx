import React, { useEffect, useRef, useState } from 'react';
import { Mic2, Plus, Trash2, Upload, ChevronDown, ChevronUp, CheckCircle2, AlertCircle } from 'lucide-react';
import { getReciters, createReciter, uploadReciterAudio, deleteReciter, getSurahs } from '../services/api';
import type { Reciter, Surah } from '../types';
import { PageHeader } from '../components/PageHeader';
import { EmptyState } from '../components/EmptyState';
import { Modal } from '../components/Modal';
import { CardShell, type CardColor } from '../components/ui/course-design-cards';

const CARD_COLORS: CardColor[] = ['green', 'orange', 'red', 'blue'];

const AUDIO_EXT = /\.(mp3|wav|m4a|ogg)$/i;

// "001.mp3", "Surah 36.mp3", "36_yasin.mp3" -> 1 / 36 / 36
function surahFromFileName(name: string): number | null {
  const m = name.match(/\d+/);
  const n = m ? parseInt(m[0], 10) : NaN;
  return n >= 1 && n <= 114 ? n : null;
}

export const RecitersPage: React.FC = () => {
  const [reciters, setReciters] = useState<Reciter[]>([]);
  const [loaded, setLoaded] = useState(false);
  const [surahNames, setSurahNames] = useState<Record<number, string>>({});
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [pendingDelete, setPendingDelete] = useState<Reciter | null>(null);
  const [deleting, setDeleting] = useState(false);

  const [name, setName] = useState('');
  const [nameAr, setNameAr] = useState('');
  const [files, setFiles] = useState<File[]>([]);
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState('');
  const [error, setError] = useState('');

  const surahPicker = useRef<HTMLInputElement>(null);
  const pickerTarget = useRef<{ reciterId: string; surahNumber: number } | null>(null);

  useEffect(() => {
    getReciters()
      .then(setReciters)
      .catch((e) => setError(e.message))
      .finally(() => setLoaded(true));
    getSurahs().then((list: Surah[]) =>
      setSurahNames(Object.fromEntries(list.map((s) => [s.number, s.englishName])))
    );
  }, []);

  const replaceReciter = (updated: Reciter) =>
    setReciters((prev) => prev.map((r) => (r.id === updated.id ? updated : r)));

  const matched = files
    .filter((f) => AUDIO_EXT.test(f.name))
    .map((f) => ({ file: f, surah: surahFromFileName(f.name) }));
  const unmatched = files.length - matched.filter((m) => m.surah !== null).length;

  const handleAdd = async (e: React.FormEvent) => {
    e.preventDefault();
    if (busy) return;
    setBusy(true);
    setError('');
    let reciter: Reciter | null = null;
    try {
      reciter = await createReciter({ name, nameAr: nameAr || undefined });
      setReciters((prev) => [reciter!, ...prev]);

      const uploads = matched.filter((m) => m.surah !== null);
      let failed = 0;
      for (let i = 0; i < uploads.length; i++) {
        setProgress(`Uploading ${i + 1} / ${uploads.length}: ${uploads[i].file.name}`);
        try {
          reciter = await uploadReciterAudio(reciter.id, uploads[i].surah!, uploads[i].file);
          replaceReciter(reciter);
        } catch {
          failed++;
        }
      }
      if (failed) setError(`${failed} file(s) failed to upload. Add them from the reciter's Surah list.`);
      setName('');
      setNameAr('');
      setFiles([]);
      setExpandedId(reciter.id);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to add reciter.');
    } finally {
      setProgress('');
      setBusy(false);
    }
  };

  const handleSurahFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    const target = pickerTarget.current;
    e.target.value = '';
    if (!file || !target) return;
    setError('');
    setProgress(`Uploading Surah ${target.surahNumber}…`);
    try {
      replaceReciter(await uploadReciterAudio(target.reciterId, target.surahNumber, file));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Upload failed.');
    } finally {
      setProgress('');
    }
  };

  const confirmDelete = async () => {
    const r = pendingDelete;
    if (!r) return;
    setDeleting(true);
    try {
      await deleteReciter(r.id);
      setReciters((prev) => prev.filter((x) => x.id !== r.id));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Delete failed.');
    } finally {
      setDeleting(false);
      setPendingDelete(null);
    }
  };

  return (
    <div className="page">
      <PageHeader
        title="Reciters"
        subtitle="Add a reciter and upload their recitation of each of the 114 Surahs."
      />

      {error && (
        <div className="alert alert-danger" role="alert" style={{ marginBottom: 'var(--space-4)' }}>
          <AlertCircle size={16} />
          <span>{error}</span>
        </div>
      )}

      <form onSubmit={handleAdd} className="card" style={{ marginBottom: 'var(--space-6)' }}>
        <div className="card-header">
          <h2 className="card-title"><Mic2 size={16} /> Add reciter</h2>
        </div>

        <div className="form-grid">
          <div className="field">
            <label className="label" htmlFor="r-name">Name (English)</label>
            <input
              id="r-name"
              className="input"
              required
              minLength={2}
              placeholder="Ahmed bin Ali Al-Ajmi"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </div>
          <div className="field" style={{ marginTop: 0 }}>
            <label className="label" htmlFor="r-name-ar">Name (Arabic)</label>
            <input
              id="r-name-ar"
              className="input arabic"
              dir="rtl"
              placeholder="أحمد بن علي العجمي"
              value={nameAr}
              onChange={(e) => setNameAr(e.target.value)}
            />
          </div>
        </div>

        <div className="field">
          <label className="label" htmlFor="r-files">Recordings <span className="muted" style={{ fontWeight: 400 }}>(optional)</span></label>
          <input
            id="r-files"
            className="input"
            type="file"
            multiple
            accept=".mp3,.wav,.m4a,.ogg,audio/*"
            onChange={(e) => setFiles(Array.from(e.target.files ?? []))}
          />
          <span className="hint">
            Each file is matched to a Surah by the number in its name (001.mp3 = Al-Fatihah, 114.mp3 = An-Nas).
            You can add or replace recordings later, one Surah at a time.
          </span>
          {files.length > 0 && (
            <span className="hint" style={{ color: 'var(--text-secondary)' }}>
              {matched.filter((m) => m.surah !== null).length} file(s) matched to Surahs
              {unmatched > 0 && (
                <span style={{ color: 'var(--warning)' }}>
                  {' '}— {unmatched} will be skipped (no Surah number 1–114, or not audio)
                </span>
              )}
            </span>
          )}
        </div>

        <div className="row" style={{ marginTop: 'var(--space-5)' }}>
          <button className="btn btn-primary" type="submit" disabled={busy}>
            {busy ? <span className="spinner" style={{ borderTopColor: '#fff', borderColor: 'rgba(255,255,255,.4)' }} /> : <Plus size={15} />}
            <span>{busy ? 'Saving…' : 'Add reciter'}</span>
          </button>
          {progress && <span className="hint" role="status">{progress}</span>}
        </div>
      </form>

      <input ref={surahPicker} type="file" accept=".mp3,.wav,.m4a,.ogg,audio/*" hidden onChange={handleSurahFile} />

      <div className="stack" style={{ gap: 'var(--space-3)' }}>
        {!loaded && <div className="card"><span className="skeleton" style={{ height: 40, width: '60%' }} /></div>}
        {loaded && reciters.length === 0 && (
          <div className="card">
            <EmptyState icon={Mic2} title="No reciters yet" message="Add your first reciter above." />
          </div>
        )}
        {reciters.map((r, idx) => {
          const open = expandedId === r.id;
          return (
            <CardShell
              key={r.id}
              color={CARD_COLORS[idx % CARD_COLORS.length]}
              eyebrow={`${r.uploadedCount} / 114 recorded`}
              action={
                <button
                  type="button"
                  className="btn-icon"
                  onClick={() => setPendingDelete(r)}
                  aria-label={`Delete ${r.name}`}
                  title="Delete reciter"
                  style={{ color: 'var(--danger)' }}
                >
                  <Trash2 size={16} />
                </button>
              }
              progress={(r.uploadedCount / 114) * 100}
              progressLabel={`${r.uploadedCount} / 114`}
              footer={
                <>
                  <span>{r.nameAr ? <span className="cdc-arabic" style={{ fontSize: '1.125rem' }}>{r.nameAr}</span> : null}</span>
                  <button
                    type="button"
                    className="btn btn-secondary btn-sm"
                    aria-expanded={open}
                    onClick={() => setExpandedId(open ? null : r.id)}
                  >
                    {open ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
                    <span>Surahs</span>
                  </button>
                </>
              }
            >
              <h3>{r.name}</h3>

              {open && (
                <div
                  className="grid-cards"
                  style={{
                    marginTop: 'var(--space-4)',
                    paddingTop: 'var(--space-4)',
                    borderTop: "1px solid rgba(255,255,255,0.1)",
                    gridTemplateColumns: 'repeat(auto-fill, minmax(min(100%, 210px), 1fr))',
                    gap: 'var(--space-2)',
                  }}
                >
                  {r.surahs.map((s) => (
                    <div key={s.surahNumber} className={`surah-chip ${s.audioUrl ? 'has-audio' : ''}`}>
                      <span className="row" style={{ gap: 6, minWidth: 0 }}>
                        {s.audioUrl && <CheckCircle2 size={14} color="var(--accent)" aria-label="Recorded" />}
                        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {s.surahNumber}. {surahNames[s.surahNumber] ?? ''}
                        </span>
                      </span>
                      <button
                        type="button"
                        className="btn-icon"
                        style={{ width: 26, height: 26 }}
                        title={s.audioUrl ? 'Replace recording' : 'Upload recording'}
                        aria-label={`${s.audioUrl ? 'Replace' : 'Upload'} recording for Surah ${s.surahNumber}`}
                        onClick={() => {
                          pickerTarget.current = { reciterId: r.id, surahNumber: s.surahNumber };
                          surahPicker.current?.click();
                        }}
                      >
                        <Upload size={13} />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </CardShell>
          );
        })}
      </div>

      {pendingDelete && (
        <Modal
          title={`Delete ${pendingDelete.name}?`}
          description="This permanently removes the reciter and all of their recordings. This can't be undone."
          onClose={() => !deleting && setPendingDelete(null)}
        >
          <div className="modal-actions" style={{ marginTop: 0 }}>
            <button type="button" className="btn btn-secondary" onClick={() => setPendingDelete(null)} disabled={deleting}>
              Cancel
            </button>
            <button type="button" className="btn btn-danger-solid" onClick={confirmDelete} disabled={deleting}>
              {deleting ? 'Deleting…' : 'Delete'}
            </button>
          </div>
        </Modal>
      )}
    </div>
  );
};
