import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import HomeView from '../views/HomeView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'home',
      component: HomeView,
    },
    {
      path: '/clientes',
      name: 'clientes',
      component: () => import('../views/ClientesView.vue'),
    },
    {
      path: '/orcamentos',
      name: 'orcamentos',
      component: () => import('../views/OrcamentosListView.vue'),
    },
    {
      path: '/pedidos',
      name: 'pedidos',
      component: () => import('../views/PedidosView.vue'),
    },
    {
      path: '/pagamentos',
      name: 'pagamentos',
      component: () => import('../views/PagamentosView.vue'),
    },
    {
      path: '/orcamentos/novo',
      name: 'orcamentos-novo',
      component: () => import('../views/OrcamentosView.vue'),
    },
    {
      path: '/orcamentos/:codOrca',
      name: 'orcamentos-editar',
      component: () => import('../views/OrcamentosView.vue'),
    },
    {
      path: '/login',
      name: 'login',
      component: () => import('../views/LoginView.vue'),
    },
    {
      path: '/signup',
      name: 'signup',
      component: () => import('../views/SignupView.vue'),
    },
    {
      path: '/oauth/callback',
      name: 'auth-callback',
      component: () => import('../views/OAuthCallbackView.vue'),
    },
    {
      path: '/dev/produtos',
      name: 'dev-produtos',
      component: () => import('../views/DevProdutosView.vue'),
    },
    {
      path: '/dev/fatores',
      name: 'dev-fatores',
      component: () => import('../views/DevFatoresView.vue'),
    },
    {
      path: '/dev/materiais',
      name: 'dev-materiais',
      component: () => import('../views/DevMateriaisView.vue'),
    },
    {
      path: '/dev/configuracoes',
      name: 'dev-configuracoes',
      component: () => import('../views/DevConfiguracoesView.vue'),
    },
  ],
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  const guestRoutes = ['login', 'signup', 'auth-callback']

  if (guestRoutes.includes(to.name as string) && auth.isAuthenticated) {
    return { name: 'home' }
  }

  if (!guestRoutes.includes(to.name as string) && !auth.isAuthenticated) {
    return { name: 'login' }
  }

  // Ferramentas dev: acessíveis apenas em desenvolvimento
  if (
    (to.name === 'dev-produtos' ||
      to.name === 'dev-fatores' ||
      to.name === 'dev-materiais' ||
      to.name === 'dev-configuracoes') &&
    !import.meta.env.DEV
  ) {
    return { name: 'home' }
  }
})

export default router
