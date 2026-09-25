import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

// base './' permite publicar el build en cualquier subruta (p. ej. GitHub Pages)
export default defineConfig({
  base: './',
  plugins: [react()],
  test: {
    environment: 'node',
  },
});
