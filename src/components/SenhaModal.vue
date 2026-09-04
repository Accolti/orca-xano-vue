<script setup lang="ts">
import { ref, computed } from 'vue'
import { xano } from '@/services/xano'
import { XanoRequestError } from '@xano/js-sdk'
import { useAuthStore } from '@/stores/auth'

const props = defineProps<{ modelValue: boolean }>()
const emit = defineEmits<{ 'update:modelValue': [value: boolean] }>()

const authStore = useAuthStore()

const atual = ref('')
const nova = ref('')
const confirmar = ref('')
const salvando = ref(false)
const erro = ref<string | null>(null)
const okMsg = ref<string | null>(null)

const aberto = computed({
  get: () => props.modelValue,
  set: (v: boolean) => emit('update:modelValue', v),
})

function close() {
  if (salvando.value) return
  emit('update:modelValue', false)
}

function resetar() {
  atual.value = ''
  nova.value = ''
  confirmar.value = ''
  erro.value = null
  okMsg.value = null
}

function extrairMensagem(err: unknown): string | null {
  const xErr = err as XanoRequestError
  const raw = xErr?.getResponse?.()?.getBody?.()
  let body: any = raw
  if (typeof raw === 'string') {
    const texto = raw.trim()
    if (!texto) return null
    try {
      body = JSON.parse(raw)
    } catch {
      return texto
    }
  }
  if (body && typeof body === 'object') {
    if (typeof body.message === 'string' && body.message.trim()) return body.message.trim()
    if (body.payload && typeof body.payload.message === 'string') {
      return body.payload.message.trim()
    }
    if (body.error && typeof body.error.message === 'string') return body.error.message.trim()
  }
  const fallback = (err as Error)?.message
  if (fallback && !/error with your request/i.test(fallback)) return fallback
  return null
}

function getErrorMessage(err: unknown): string {
  return extrairMensagem(err) || 'Não foi possível trocar a senha. Verifique a senha atual e tente novamente.'
}

function validar(): string | null {
  if (!atual.value) return 'Informe a senha atual.'
  if (nova.value.length < 8) return 'A nova senha deve ter pelo menos 8 caracteres.'
  if (!/[a-zA-Z]/.test(nova.value)) return 'A nova senha deve conter ao menos uma letra.'
  if (!/\d/.test(nova.value)) return 'A nova senha deve conter ao menos um número.'
  if (nova.value !== confirmar.value) return 'A confirmação não confere com a nova senha.'
  return null
}

async function salvar() {
  if (salvando.value) return
  const msg = validar()
  if (msg) {
    erro.value = msg
    return
  }
  salvando.value = true
  erro.value = null
  okMsg.value = null
  try {
    await xano.post('/api:-qqRIakp/auth/change_password', {
      current_password: atual.value,
      new_password: nova.value,
    })
    okMsg.value = 'Senha alterada com sucesso! Faça login novamente.'
    setTimeout(() => {
      emit('update:modelValue', false)
      authStore.logout()
      window.location.href = '/login'
    }, 1500)
  } catch (err: unknown) {
    erro.value = getErrorMessage(err)
  } finally {
    salvando.value = false
  }
}
</script>

<template>
  <Teleport to="body">
    <Transition name="senha-fade">
      <div v-if="aberto" class="sm-overlay" @click.self="close">
        <div class="sm-card" role="dialog" aria-modal="true" aria-label="Trocar senha">
          <header class="sm-head">
            <h2>Trocar senha</h2>
            <button class="sm-close" type="button" aria-label="Fechar" @click="close">✕</button>
          </header>

          <p v-if="okMsg" class="sm-ok" role="status">{{ okMsg }}</p>

          <form v-else @submit.prevent="salvar">
            <div class="field">
              <label for="sm-atual">Senha atual</label>
              <input
                id="sm-atual"
                v-model="atual"
                type="password"
                autocomplete="current-password"
                placeholder="Senha atual"
              />
            </div>
            <div class="field">
              <label for="sm-nova">Nova senha</label>
              <input
                id="sm-nova"
                v-model="nova"
                type="password"
                autocomplete="new-password"
                placeholder="Mín. 8 caracteres, com letra e número"
              />
            </div>
            <div class="field">
              <label for="sm-confirmar">Confirmar nova senha</label>
              <input
                id="sm-confirmar"
                v-model="confirmar"
                type="password"
                autocomplete="new-password"
                placeholder="Repita a nova senha"
              />
            </div>

            <p v-if="erro" class="sm-erro" role="alert">{{ erro }}</p>

            <footer class="sm-actions">
              <button type="button" class="btn btn-outline" :disabled="salvando" @click="close">
                Cancelar
              </button>
              <button type="submit" class="btn btn-primary" :disabled="salvando">
                {{ salvando ? 'Salvando…' : 'Salvar nova senha' }}
              </button>
            </footer>
          </form>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.sm-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
}

.sm-card {
  width: 100%;
  max-width: 400px;
  border-radius: 14px;
  background: var(--card-bg);
  box-shadow: var(--shadow-card);
  padding: 1.2rem 1.3rem 1.3rem;
}

.sm-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1rem;
}

.sm-head h2 {
  font-size: 1.1rem;
  margin: 0;
}

.sm-close {
  background: none;
  border: none;
  font-size: 1rem;
  cursor: pointer;
  color: var(--text-secondary);
}

.field {
  margin-bottom: 0.8rem;
}

.field label {
  display: block;
  font-size: 0.85rem;
  font-weight: 600;
  margin-bottom: 0.3rem;
  color: var(--text-primary);
}

.field input {
  width: 100%;
  padding: 0.5rem 0.6rem;
  border: 1px solid var(--border-light);
  border-radius: 8px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 0.9rem;
}

.field input:focus {
  outline: none;
  border-color: var(--primary);
}

.sm-erro {
  color: var(--danger);
  font-size: 0.85rem;
  margin: 0.5rem 0 0;
}

.sm-ok {
  color: #16a34a;
  font-size: 0.9rem;
  margin: 0.5rem 0 1rem;
}

.sm-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.6rem;
  margin-top: 1rem;
}

.senha-fade-enter-active,
.senha-fade-leave-active {
  transition: opacity 0.15s ease;
}

.senha-fade-enter-from,
.senha-fade-leave-to {
  opacity: 0;
}
</style>
