<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useCatalogoStore } from '@/stores/catalogo'

interface DevConta {
  nome: string
  email: string
  senha: string
}

const STORAGE_KEY = 'orca_dev_usuarios'

const authStore = useAuthStore()
const catalogoStore = useCatalogoStore()
const router = useRouter()

function lerContas(): DevConta[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    const arr = raw ? JSON.parse(raw) : []
    return Array.isArray(arr) ? arr : []
  } catch {
    return []
  }
}

const contas = ref<DevConta[]>(lerContas())
const novoNome = ref('')
const novoEmail = ref('')
const novaSenha = ref('')
const erroLogin = ref<string | null>(null)
const entrando = ref<string | null>(null)

function salvarContas() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(contas.value))
}

function adicionarConta() {
  if (!novoEmail.value || !novaSenha.value) return
  contas.value.push({
    nome: novoNome.value.trim() || novoEmail.value,
    email: novoEmail.value.trim(),
    senha: novaSenha.value,
  })
  salvarContas()
  novoNome.value = ''
  novoEmail.value = ''
  novaSenha.value = ''
}

function removerConta(email: string) {
  contas.value = contas.value.filter((c) => c.email !== email)
  salvarContas()
}

async function entrar(email: string, senha: string) {
  erroLogin.value = null
  entrando.value = email
  try {
    await authStore.login(email, senha)
    router.push('/')
  } catch {
    erroLogin.value = authStore.error || 'Falha ao entrar com a conta de teste.'
  } finally {
    entrando.value = null
  }
}

function sair() {
  authStore.logout()
  router.push('/login')
}

const usuarioAtivo = computed(() => authStore.user?.email ?? '')
const nomeAtivo = computed(
  () => authStore.user?.name || authStore.user?.fantasia || authStore.user?.email || '',
)
</script>

<template>
  <div class="dev-user-switcher">
    <div class="dus-title">Trocar usuário <small>(dev)</small></div>

    <div v-if="authStore.user" class="dus-ativo">
      <strong>{{ nomeAtivo }}</strong>
      <span>{{ usuarioAtivo }}</span>
    </div>
    <button type="button" class="dus-sair" @click="sair">Sair do aplicativo</button>

    <div v-if="contas.length" class="dus-lista">
      <div
        v-for="c in contas"
        :key="c.email"
        class="dus-conta"
        :class="{ ativo: c.email === usuarioAtivo }"
      >
        <div class="dus-info">
          <strong>{{ c.nome }}</strong>
          <span>{{ c.email }}</span>
        </div>
        <button
          type="button"
          class="dus-entrar"
          :disabled="entrando === c.email"
          @click="entrar(c.email, c.senha)"
        >
          {{ entrando === c.email ? 'Entrando…' : 'Entrar' }}
        </button>
        <button type="button" class="dus-rm" title="Remover" @click="removerConta(c.email)">
          ×
        </button>
      </div>
    </div>
    <p v-else class="dus-empty">Nenhuma conta de teste salva.</p>

    <form class="dus-form" @submit.prevent="adicionarConta">
      <input v-model="novoNome" placeholder="Nome (opcional)" />
      <input v-model="novoEmail" type="email" placeholder="E-mail" required />
      <input v-model="novaSenha" type="password" placeholder="Senha" required />
      <button type="submit" class="dus-add">Adicionar conta</button>
    </form>

    <p v-if="erroLogin" class="dus-erro">{{ erroLogin }}</p>
  </div>
</template>

<style scoped>
.dev-user-switcher {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  min-width: 260px;
}

.dus-title {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-secondary, #6b7280);
  margin-bottom: 0.1rem;
  padding-bottom: 0.4rem;
  border-bottom: 1px solid var(--border-subtle, #f3f4f6);
}

.dus-title small {
  font-weight: 400;
  text-transform: none;
  color: #9ca3af;
}

.dus-ativo {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
  padding: 0.4rem 0.5rem;
  border-radius: 8px;
  background: var(--bg-subtle, #f3f4f6);
  font-size: 0.82rem;
  color: var(--text-primary, #1f2937);
}

.dus-ativo span {
  color: var(--text-secondary, #6b7280);
  font-size: 0.75rem;
}

.dus-sair {
  padding: 0.4rem 0.5rem;
  border-radius: 6px;
  border: 1px solid var(--border-light, #e5e7eb);
  background: none;
  color: var(--danger, #dc2626);
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
}

.dus-sair:hover {
  background: var(--bg-subtle, #f3f4f6);
}

.dus-lista {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  max-height: 220px;
  overflow-y: auto;
}

.dus-conta {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 0.5rem;
  border-radius: 8px;
  border: 1px solid var(--border-subtle, #f3f4f6);
}

.dus-conta.ativo {
  border-color: var(--primary, #3366cc);
  background: rgba(51, 102, 204, 0.06);
}

.dus-info {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-width: 0;
  font-size: 0.8rem;
  color: var(--text-primary, #1f2937);
}

.dus-info span {
  color: var(--text-secondary, #6b7280);
  font-size: 0.72rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.dus-entrar {
  padding: 0.25rem 0.6rem;
  border-radius: 6px;
  border: none;
  background: var(--primary, #3366cc);
  color: #fff;
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
  flex-shrink: 0;
}

.dus-entrar:hover:not(:disabled) {
  filter: brightness(1.1);
}

.dus-entrar:disabled {
  opacity: 0.6;
  cursor: default;
}

.dus-rm {
  border: none;
  background: none;
  color: var(--text-secondary, #9ca3af);
  font-size: 1rem;
  cursor: pointer;
  padding: 0 0.2rem;
  flex-shrink: 0;
}

.dus-rm:hover {
  color: var(--danger, #dc2626);
}

.dus-empty {
  margin: 0;
  font-size: 0.8rem;
  color: var(--text-secondary, #9ca3af);
  text-align: center;
  padding: 0.3rem 0;
}

.dus-form {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  padding-top: 0.4rem;
  border-top: 1px solid var(--border-subtle, #f3f4f6);
}

.dus-form input {
  padding: 0.4rem 0.55rem;
  border: 1px solid var(--border-light, #e5e7eb);
  border-radius: 6px;
  font-size: 0.8rem;
  color: var(--text-primary, #1f2937);
  background: var(--card-bg, #fff);
}

.dus-form input:focus {
  outline: none;
  border-color: var(--primary, #3366cc);
}

.dus-add {
  padding: 0.4rem 0.5rem;
  border-radius: 6px;
  border: none;
  background: var(--border-subtle, #e5e7eb);
  color: var(--text-primary, #1f2937);
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
}

.dus-add:hover {
  background: var(--border-light, #d1d5db);
}

.dus-erro {
  margin: 0;
  font-size: 0.78rem;
  color: var(--danger, #dc2626);
}
</style>
