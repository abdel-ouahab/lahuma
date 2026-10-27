import React, { useEffect, useState } from 'react';
import { Search, RefreshCw, BookOpen } from 'lucide-react';
import { getSurahs } from '../services/api';
import type { Surah } from '../types';
import { PageHeader } from '../components/PageHeader';
import { EmptyState } from '../components/EmptyState';
import { CardShell } from '../components/ui/course-design-cards';

const TYPE_FILTERS = [
  { value: 'ALL', label: 'All' },
  { value: 'Meccan', label: 'Meccan' },
  { value: 'Medinan', label: 'Medinan' },
];

export const QuranPage: React.FC = () => {
  const [surahs, setSurahs] = useState<Surah[]>([]);
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [filterType, setFilterType] = useState<string>('ALL');
  const [loading, setLoading] = useState<boolean>(true);

  useEffect(() => {
    getSurahs().then((data) => {
      setSurahs(data);
      setLoading(false);
    });
  }, []);

  const sync = async () => {
    setLoading(true);
    setSurahs(await getSurahs());
    setLoading(false);
  };

  const filteredSurahs = surahs.filter((s) => {
    const matchesSearch =
      s.englishName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      s.englishNameTranslation.toLowerCase().includes(searchQuery.toLowerCase()) ||
      s.name.includes(searchQuery) ||
      s.number.toString() === searchQuery;
    const matchesFilter = filterType === 'ALL' || s.revelationType === filterType;
    return matchesSearch && matchesFilter;
  });

  return (
    <div className="page">
      <PageHeader
        title="Quran content"
        subtitle="Browse the Surahs in the Lahuma Quran database."
        actions={
          <button type="button" className="btn btn-secondary" onClick={sync} disabled={loading}>
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
            <span>Sync catalog</span>
          </button>
        }
      />

      <div className="toolbar">
        <div className="input-icon">
          <Search size={15} />
          <input
            type="search"
            aria-label="Search Surahs"
            placeholder="Search by name or number — Al-Fatihah, يس, 36"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="input"
          />
        </div>

        <div className="segmented" role="group" aria-label="Filter by revelation type">
          {TYPE_FILTERS.map((f) => (
            <button
              key={f.value}
              type="button"
              aria-pressed={filterType === f.value}
              onClick={() => setFilterType(f.value)}
            >
              {f.label}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="grid-cards">
          {Array.from({ length: 8 }, (_, i) => (
            <div key={i} className="card">
              <span className="skeleton" style={{ height: 96, width: '100%' }} />
            </div>
          ))}
        </div>
      ) : filteredSurahs.length === 0 ? (
        <div className="card">
          <EmptyState icon={BookOpen} title="No Surahs found" message="Try a different search or filter." />
        </div>
      ) : (
        <div className="grid-cards">
          {filteredSurahs.map((surah) => (
            <CardShell
              key={surah.number}
              as="article"
              interactive
              color={surah.revelationType === 'Meccan' ? 'orange' : 'green'}
              eyebrow={<span className="cdc-num">{surah.number}</span>}
              action={<span className="cdc-arabic">{surah.name}</span>}
              footer={
                <>
                  <span className="tabular">{surah.numberOfAyahs} verses</span>
                  <span className="cdc-btn-countdown">{surah.revelationType}</span>
                </>
              }
            >
              <h3>{surah.englishName}</h3>
              <p>{surah.englishNameTranslation}</p>
            </CardShell>
          ))}
        </div>
      )}
    </div>
  );
};
