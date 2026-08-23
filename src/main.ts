import './assets/main.css'

import { createApp } from 'vue'
import { createPinia } from 'pinia'

import App from './App.vue'
import router from './router'
import { setUnauthorizedHandler } from './services/xano'
import { useAuthStore } from './stores/auth'

const app = createApp(App)

app.use(createPinia())
app.use(router)

// Interceptor global de 401: token expirado/inválido → logout + redireciona para o login.
// Não dispara em rotas guest (login/signup/oauth-callback) para não atrapalhar o fluxo.
const GUEST_ROUTES = ['login', 'signup', 'auth-callback']
setUnauthorizedHandler(() => {
  const route = router.currentRoute.value
  if (route.name && GUEST_ROUTES.includes(route.name as string)) return

  useAuthStore().logout()
  router.replace({ name: 'login', query: { expired: '1' } })
})

app.mount('#app')
