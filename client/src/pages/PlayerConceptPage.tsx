import React from 'react';
import { PageHeader } from '../components/PageHeader';
import { MusicPlayer, type Track } from '../components/ui/music-player-widget';

const TRACKS: Track[] = [
  {
    title: 'Southern Roots Boogie',
    artist: 'Falconer',
    cover: 'https://cdn.21st.dev/assets/mirror/ba/bafb64c13ba4ed85d598cc318a62f9a5129f3abaecee80943d495e7356fd0603.jpg',
    src: 'https://cdn.21st.dev/assets/mirror/ca/cadd2666c5571e12fafdb21697b26aef6f196a5a9c28e708129870167679991d.mp3',
  },
  {
    title: 'Sax Party',
    artist: 'Ofer Koren',
    cover: 'https://cdn.21st.dev/assets/mirror/ca/ca5a0ecf3ecbf81caded68eb892149e9d2f060c50dfbefd6ca1c04792856a049.jpg',
    src: 'https://cdn.21st.dev/assets/mirror/ab/ab5cb08483abe63edd2a2ce4d843ad8f3073fcbb4a738a94f6b7529df3e1b437.mp3',
  },
  {
    title: 'Nonsense',
    artist: 'Raw',
    cover: 'https://cdn.21st.dev/assets/mirror/d0/d0d6fb080fce7745734593c815edf73ac22bbbe5e7b3424324d191af8b058833.jpg',
    src: 'https://cdn.21st.dev/assets/mirror/79/793e6ffda56e28691998b90a55bdaf0f2bccb8950cd8a7ee9ef7421c4ebbafdb.mp3',
  },
];

export const PlayerConceptPage: React.FC = () => (
  <>
    <PageHeader
      title="Player concept"
      subtitle="Audio player design concept. Space play/pause · ←/→ seek · Shift+←/→ prev/next · S shuffle · L loop"
    />
    <MusicPlayer tracks={TRACKS} crossOrigin="anonymous" />
  </>
);
