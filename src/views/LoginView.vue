<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
const router = useRouter()
const route = useRoute()

const sessaoExpirada = ref(route.query.expired === '1')

const email = ref('')
const password = ref('')

async function handleSubmit() {
  sessaoExpirada.value = false
  try {
    await authStore.login(email.value, password.value)
    router.push('/')
  } catch {
    /* error is already in authStore.error */
  }
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <h1>Entrar</h1>

      <form @submit.prevent="handleSubmit">
        <div class="field">
          <label for="email">E-mail</label>
          <input
            id="email"
            v-model="email"
            type="email"
            placeholder="seu@email.com"
            required
            autocomplete="email"
          />
        </div>

        <div class="field">
          <label for="password">Senha</label>
          <input
            id="password"
            v-model="password"
            type="password"
            placeholder="••••••••"
            required
            autocomplete="current-password"
          />
        </div>

        <p v-if="sessaoExpirada" class="info-msg">Sessão expirada. Faça login novamente.</p>

        <p v-if="authStore.error" class="error-msg">{{ authStore.error }}</p>

        <button type="submit" class="btn" :disabled="authStore.loading">
          {{ authStore.loading ? 'Entrando…' : 'Entrar' }}
        </button>
      </form>

      <div class="auth-divider">
        <span>ou</span>
      </div>

      <button
        type="button"
        class="btn btn-google"
        :disabled="authStore.loading"
        @click="authStore.googleLogin()"
      >
        <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true">
          <path
            d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.27-4.74 3.27-8.1z"
            fill="#4285F4"
          />
          <path
            d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
            fill="#34A853"
          />
          <path
            d="M5.84 14.1c-.22-.66-.35-1.36-.35-2.1s.13-1.44.35-2.1V7.06H2.18A10.9 10.9 0 0 0 1 12c0 1.77.43 3.45 1.18 4.94l3.66-2.84z"
            fill="#FBBC05"
          />
          <path
            d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
            fill="#EA4335"
          />
        </svg>
        {{ authStore.loading ? 'Redirecionando…' : 'Entrar com o Google' }}
      </button>

      <p class="switch-link">
        Não tem conta?
        <RouterLink to="/signup">Cadastre-se</RouterLink>
      </p>
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
  box-shadow: var(--shadow-card);
}

@media (max-width: 480px) {
  .auth-card {
    padding: 1.5rem 1.25rem;
  }
}

.auth-card h1 {
  margin-bottom: 1.5rem;
  font-size: 1.5rem;
  text-align: center;
  color: var(--text-primary);
}

.field {
  margin-bottom: 1.25rem;
}

.field label {
  display: block;
  margin-bottom: 0.35rem;
  font-weight: 600;
  font-size: 0.875rem;
  color: var(--text-secondary);
}

.field input {
  width: 100%;
  padding: 0.6rem 0.75rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  font-size: 1rem;
  background: var(--input-bg);
  color: var(--text-primary);
  outline: none;
  transition: border-color 0.2s;
}

.field input:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.18);
}

.error-msg {
  color: var(--danger);
  font-size: 0.875rem;
  margin-bottom: 0.75rem;
  text-align: center;
}

.info-msg {
  color: var(--primary);
  font-size: 0.875rem;
  margin-bottom: 0.75rem;
  text-align: center;
  font-weight: 600;
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

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-google {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.6rem;
  background: var(--card-bg);
  color: var(--text-primary);
  border: 1px solid var(--border-light);
  font-weight: 600;
}

.btn-google:hover {
  background: var(--border-subtle);
  border-color: var(--text-secondary);
}

.auth-divider {
  display: flex;
  align-items: center;
  margin: 1.25rem 0;
  color: var(--text-secondary);
  font-size: 0.8rem;
}

.auth-divider::before,
.auth-divider::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--border-light);
}

.auth-divider span {
  padding: 0 0.75rem;
}

.switch-link {
  margin-top: 1.25rem;
  text-align: center;
  font-size: 0.875rem;
  color: var(--text-secondary);
}

.switch-link a {
  color: var(--primary);
  font-weight: 600;
  text-decoration: none;
}

.switch-link a:hover {
  text-decoration: underline;
}
</style>
