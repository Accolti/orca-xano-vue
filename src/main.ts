import './assets/main.css'

import { createApp } from 'vue'
import { createPinia } from 'pinia'

import App from './App.vue'
import router from './router'
import { supabase } from './services/supabase'
import { useAuthStore } from './stores/auth'

const app = createApp(App)
const pinia = createPinia()
app.use(pinia)
app.use(router)

const GUEST_ROUTES = ['login', 'signup', 'auth-callback', 'reset-password']

// Sessão expirada/deslogado (refresh token inválido) → logout + redireciona para o login.
// Não dispara em rotas guest para não atrapalhar o fluxo de login.
supabase?.auth.onAuthStateChange((event) => {
  if (event !== 'SIGNED_OUT') return
  const route = router.currentRoute.value
  if (route.name && GUEST_ROUTES.includes(route.name as string)) return
  router.replace({ name: 'login', query: { expired: '1' } })
})

async function bootstrap() {
  // Restaura a sessão (Supabase Auth) antes da primeira navegação, para o router
  // guard já enxergar o usuário logado.
  await useAuthStore().init()
  app.mount('#app')
}

bootstrap()
