<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
const router = useRouter()

const name_first = ref('')
const name_last = ref('')
const email = ref('')
const password = ref('')

async function handleSubmit() {
  try {
    await authStore.signup(email.value, password.value, name_first.value, name_last.value)
    router.push('/')
  } catch {
    /* error is already in authStore.error */
  }
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <h1>Criar Conta</h1>

      <form @submit.prevent="handleSubmit">
        <div class="field-row">
          <div class="field">
            <label for="name_first">Nome</label>
            <input
              id="name_first"
              v-model="name_first"
              type="text"
              placeholder="Seu nome"
              required
              autocomplete="given-name"
            />
          </div>

          <div class="field">
            <label for="name_last">Sobrenome</label>
            <input
              id="name_last"
              v-model="name_last"
              type="text"
              placeholder="Seu sobrenome"
              required
              autocomplete="family-name"
            />
          </div>
        </div>

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
            autocomplete="new-password"
          />
        </div>

        <p v-if="authStore.error" class="error-msg">{{ authStore.error }}</p>

        <button type="submit" class="btn" :disabled="authStore.loading">
          {{ authStore.loading ? 'Cadastrando…' : 'Cadastrar' }}
        </button>
      </form>

      <p class="switch-link">
        Já tem conta?
        <RouterLink to="/login">Entre</RouterLink>
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
  max-width: 420px;
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

.field-row {
  display: flex;
  gap: 0.75rem;
}

.field-row .field {
  flex: 1;
}

@media (max-width: 480px) {
  .field-row {
    flex-direction: column;
    gap: 0;
  }
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
