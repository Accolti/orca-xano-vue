<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/services/supabase'

const router = useRouter()
const authStore = useAuthStore()

const processando = ref(true)
const erro = ref<string | null>(null)

onMounted(async () => {
  try {
    if (!supabase) throw new Error('Supabase não configurado')
    // detectSessionInUrl (fluxo implícito) já estabelece a sessão a partir da URL.
    const { data } = await supabase.auth.getSession()
    if (!data.session) throw new Error('Sessão não estabelecida.')
    await authStore.fetchMe()
    router.replace('/')
  } catch {
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
  background: var(--card-bg);
  border: 1px solid var(--border-light);
  border-radius: 12px;
  padding: 2.5rem 2rem;
  width: 100%;
  max-width: 400px;
  text-align: center;
  box-shadow: var(--shadow-card);
}

.auth-card h1 {
  margin-bottom: 1.5rem;
  font-size: 1.5rem;
  color: var(--text-primary);
}

.callback-status {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  color: var(--text-secondary);
  font-size: 0.95rem;
}

.spinner {
  width: 18px;
  height: 18px;
  border: 2px solid var(--border-light);
  border-top-color: var(--primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.error-msg {
  color: var(--danger);
  font-size: 0.875rem;
  margin-bottom: 1.25rem;
}

.btn {
  width: 100%;
  padding: 0.7rem;
  background: var(--primary);
  color: #fff;
  border: none;
  border-radius: 6px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.2s;
}

.btn:hover {
  background: var(--primary-hover);
}
</style>
