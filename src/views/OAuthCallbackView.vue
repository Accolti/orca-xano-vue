<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const processando = ref(true)
const erro = ref<string | null>(null)

onMounted(async () => {
  const code = (route.query.code as string) || ''
  // SEMPRE usa o redirect_uri idêntico ao do init (ignora query p/ evitar mismatch de encoding)
  const redirectUri = `${window.location.origin}/oauth/callback`

  if (!code) {
    erro.value = 'Falha na autenticação: código ausente na resposta do Google.'
    processando.value = false
    return
  }

  // Limpa o code da URL p/ não reutilizar num refresh (o code do Google é one-time)
  await router.replace({ path: '/oauth/callback', query: {} })

  try {
    await authStore.googleCallback(code, redirectUri)
    router.replace('/')
  } catch (err) {
    erro.value =
      authStore.error ||
      'Acesso restrito a usuários previamente autorizados. Entre em contato com o suporte.'
    processando.value = false
  }
})

function voltarLogin() {
  router.replace('/login')
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <h1>Autenticação</h1>

      <p v-if="processando" class="callback-status">
        <span class="spinner" aria-hidden="true"></span>
        Processando login com o Google…
      </p>

      <template v-else>
        <p class="error-msg">{{ erro }}</p>
        <button class="btn" @click="voltarLogin">Voltar para o Login</button>
      </template>
    </div>
  </div>
</template>

<style scoped>
.auth-page {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 60vh;
}

.auth-card {
  background: var(--color-background-soft);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  padding: 2.5rem 2rem;
  width: 100%;
  max-width: 400px;
  text-align: center;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
}

.auth-card h1 {
  margin-bottom: 1.5rem;
  font-size: 1.5rem;
}

.callback-status {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  color: #4b5563;
  font-size: 0.95rem;
}

.spinner {
  width: 18px;
  height: 18px;
  border: 2px solid #d1d5db;
  border-top-color: #3366cc;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.error-msg {
  color: #e74c3c;
  font-size: 0.875rem;
  margin-bottom: 1.25rem;
}

.btn {
  width: 100%;
  padding: 0.7rem;
  background: #42b883;
  color: #fff;
  border: none;
  border-radius: 6px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.2s;
}

.btn:hover {
  background: #38a071;
}
</style>
