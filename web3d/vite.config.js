import { defineConfig } from 'vite';

export default defineConfig({
  base: './',
  server: {
    host: '0.0.0.0',
    port: 5173,
    allowedHosts: true,
  },
  preview: {
    host: '0.0.0.0',
    port: 4173,
    allowedHosts: true,
  },
  build: {
    outDir: '../android/app/src/main/assets/web3d',
    emptyOutDir: true,
    assetsInlineLimit: 0,
    target: 'es2020',
  },
});
