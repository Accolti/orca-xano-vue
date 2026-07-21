<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
const router = useRouter()

const email = ref('')
const password = ref('')

async function handleSubmit() {
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

        <p v-if="authStore.error" class="error-msg">{{ authStore.error }}</p>

        <button type="submit" class="btn" :disabled="authStore.loading">
          {{ authStore.loading ? 'Entrando…' : 'Entrar' }}
        </button>
      </form>

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
  background: var(--color-background-soft);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  padding: 2.5rem 2rem;
  width: 100%;
  max-width: 400px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
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
}

.field {
  margin-bottom: 1.25rem;
}

.field label {
  display: block;
  margin-bottom: 0.35rem;
  font-weight: 600;
  font-size: 0.875rem;
}

.field input {
  width: 100%;
  padding: 0.6rem 0.75rem;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 1rem;
  background: var(--color-background);
  color: var(--color-text);
  outline: none;
  transition: border-color 0.2s;
}

.field input:focus {
  border-color: #42b883;
}

.error-msg {
  color: #e74c3c;
  font-size: 0.875rem;
  margin-bottom: 0.75rem;
  text-align: center;
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

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.switch-link {
  margin-top: 1.25rem;
  text-align: center;
  font-size: 0.875rem;
}

.switch-link a {
  color: #42b883;
  font-weight: 600;
  text-decoration: none;
}

.switch-link a:hover {
  text-decoration: underline;
}
</style>
