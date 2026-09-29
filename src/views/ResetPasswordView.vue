<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/services/supabase'

const authStore = useAuthStore()
const router = useRouter()

const senha = ref('')
const confirmacao = ref('')
const pronto = ref(false)
const erro = ref<string | null>(null)

onMounted(async () => {
  // Detecta a sessão de recuperação trazida no link (#access_token=...&type=recovery)
  if (!supabase) return
  await supabase.auth.getSession()
})

async function salvar() {
  erro.value = null
  if (!senha.value || senha.value.length < 8) {
    erro.value = 'A senha deve ter pelo menos 8 caracteres.'
    return
  }
  if (senha.value !== confirmacao.value) {
    erro.value = 'As senhas não conferem.'
    return
  }
  try {
    await authStore.updatePassword(senha.value)
    pronto.value = true
    setTimeout(() => router.replace('/login'), 1500)
  } catch (err: any) {
    erro.value = err?.message || 'Erro ao redefinir a senha.'
  }
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <h1>Definir nova senha</h1>

      <template v-if="!pronto">
        <form @submit.prevent="salvar">
          <div class="field">
            <label for="senha">Nova senha</label>
            <input
              id="senha"
              v-model="senha"
              type="password"
              placeholder="••••••••"
              required
              autocomplete="new-password"
            />
          </div>

          <div class="field">
            <label for="confirmacao">Confirmar senha</label>
            <input
              id="confirmacao"
              v-model="confirmacao"
              type="password"
              placeholder="••••••••"
              required
              autocomplete="new-password"
            />
          </div>

          <p v-if="erro" class="error-msg">{{ erro }}</p>

          <button type="submit" class="btn" :disabled="authStore.loading">
            {{ authStore.loading ? 'Salvando…' : 'Salvar senha' }}
          </button>
        </form>
      </template>

      <p v-else class="info-msg">Senha redefinida! Redirecionando para o login…</p>
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
  font-size: 0.95rem;
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
</style>
