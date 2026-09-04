<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useUiStore } from '@/stores/ui'
import { pendenciasPerfil } from '@/utils/perfil'

const authStore = useAuthStore()
const uiStore = useUiStore()
const router = useRouter()

const pendentes = computed(() => pendenciasPerfil(authStore.user))
const criticas = computed(() => pendentes.value.filter((p) => p.critico))
const recomendacoes = computed(() => pendentes.value.filter((p) => !p.critico))

function abrirMeusDados() {
  uiStore.perfilOpen = true
}

function irParaOnboarding() {
  router.push('/onboarding')
}
</script>

<template>
  <div
    v-if="pendentes.length"
    class="ppb"
    :class="{ 'ppb-critico': criticas.length > 0 }"
    role="alert"
  >
    <div class="ppb-texto">
      <span v-if="criticas.length" class="ppb-titulo">
        <strong>Cadastro incompleto</strong> — sem
        {{ criticas.map((c) => c.rotulo).join(' e ') }}, o orçamento pode ser calculado
        incorretamente.
      </span>
      <span v-else class="ppb-titulo">
        Cadastro incompleto — complete os dados abaixo para emitir os documentos corretamente.
      </span>
      <span v-if="recomendacoes.length" class="ppb-sugestao">
        Ajuste também: {{ recomendacoes.map((r) => r.rotulo).join(' · ') }}
      </span>
    </div>
    <div class="ppb-acoes">
      <button type="button" class="btn btn-sm btn-accent" @click="abrirMeusDados">
        Abrir Meus Dados
      </button>
      <button type="button" class="btn btn-sm btn-outline" @click="irParaOnboarding">
        Preencher cadastro
      </button>
    </div>
  </div>
</template>

<style scoped>
.ppb {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.6rem 1rem;
  padding: 0.65rem 0.9rem;
  border-radius: 10px;
  border: 1px solid var(--border-light);
  background: var(--card-bg);
  margin-bottom: 1rem;
}

.ppb-critico {
  border-color: var(--danger);
  background: var(--danger-soft);
}

.ppb-texto {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  min-width: 0;
}

.ppb-titulo {
  font-size: 0.85rem;
  color: var(--text-primary);
}

.ppb-critico .ppb-titulo {
  color: var(--danger);
}

.ppb-sugestao {
  font-size: 0.78rem;
  color: var(--text-secondary);
}

.ppb-acoes {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}
</style>
