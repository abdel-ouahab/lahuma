import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    // Expose on the local network (access from phone / other devices)
    host: true,
    port: 5173,
    proxy: {
      // Forward /api/* → http://localhost:4000/api/*
      '/api': {
        target: 'http://localhost:4000',
        changeOrigin: true,
      },
      // Forward /health → http://localhost:4000/health
      '/health': {
        target: 'http://localhost:4000',
        changeOrigin: true,
      },
    },
  },
})

