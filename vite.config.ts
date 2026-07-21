import { fileURLToPath, URL } from 'node:url'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    vue(),
    vueDevTools(),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    proxy: {
      '/auth': {
        target: 'https://x8ki-letl-twmt.n7.xano.io',
        changeOrigin: true,
      },
      '/api': {
        target: 'https://x8ki-letl-twmt.n7.xano.io',
        changeOrigin: true,
      },
      '/office': {
        target: 'https://api.cnpja.com',
        changeOrigin: true,
      },
      '/ccc': {
        target: 'https://api.cnpja.com',
        changeOrigin: true,
      },
    },
  },
})
