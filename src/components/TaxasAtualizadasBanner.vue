<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useCatalogoStore } from '@/stores/catalogo'

// Banner (admins/empresas): avisa que as taxas de cartão foram atualizadas pela
// coleta automática. Aparece quando a `versao_taxas_banco` muda em relação à última
// versão vista neste navegador. O botão baixa as taxas novas (sem recarregar a página).
const authStore = useAuthStore()
const catalogo = useCatalogoStore()

const mostrar = ref(false)
const atualizando = ref(false)

const podeVer = computed(() => !!authStore.user && authStore.isAdmin)

function vistoKey(): string {
  return `orca_taxas_versao_vista_${authStore.user?.id ?? 0}`
}

const dataTexto = computed(() => {
  const ts = catalogo.taxasAtualizadoEm
  if (!ts) return ''
  const d = new Date(ts)
  return isNaN(d.getTime()) ? '' : d.toLocaleDateString('pt-BR')
})

function avaliar() {
  if (!podeVer.value || catalogo.versaoTaxasBanco == null) {
    mostrar.value = false
    return
  }
  const v = catalogo.versaoTaxasBanco
  let raw: string | null = null
  try {
    raw = localStorage.getItem(vistoKey())
  } catch {
    raw = null
  }
  if (raw == null) {
    // Primeira vez: exibe se já houve alguma atualização registrada; senão só marca.
    if (catalogo.taxasAtualizadoEm) {
      mostrar.value = true
    } else {
      try {
        localStorage.setItem(vistoKey(), String(v))
      } catch {
        /* ignore */
      }
      mostrar.value = false
    }
    return
  }
  mostrar.value = Number(raw) !== Number(v)
}

function marcarVisto() {
  try {
    localStorage.setItem(vistoKey(), String(catalogo.versaoTaxasBanco ?? 0))
  } catch {
    /* ignore */
  }
  mostrar.value = false
}

async function atualizar() {
  if (atualizando.value) return
  atualizando.value = true
  try {
    await catalogo.carregarConfiguracoes()
    await catalogo.recarregarTaxas()
    marcarVisto()
  } catch {
    /* mantém o banner para tentar de novo */
  } finally {
    atualizando.value = false
  }
}

watch(
  [() => catalogo.versaoTaxasBanco, () => catalogo.taxasAtualizadoEm, () => authStore.user?.id],
  avaliar,
  { immediate: true },
)

onMounted(() => {
  if (catalogo.versaoTaxasBanco == null) {
    catalogo
      .carregarConfiguracoes()
      .then(avaliar)
      .catch(() => {})
  }
})
</script>

<template>
  <div v-if="mostrar && podeVer" class="tab" role="status">
    <span class="tab-icon">🔄</span>
    <span class="tab-texto">
      As taxas de cartão foram atualizadas<template v-if="dataTexto"> em {{ dataTexto }}</template
      >. Atualize para baixar as novas taxas.
    </span>
    <div class="tab-acoes">
      <button
        type="button"
        class="btn btn-sm btn-accent"
        :disabled="atualizando"
        @click="atualizar"
      >
        {{ atualizando ? 'Atualizando…' : 'Atualizar agora' }}
      </button>
      <button type="button" class="tab-close" title="Dispensar" @click="marcarVisto">✕</button>
    </div>
  </div>
</template>

<style scoped>
.tab {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.6rem 1rem;
  padding: 0.6rem 0.9rem;
  border-radius: 10px;
  border: 1px solid var(--primary, #3b82f6);
  background: var(--primary-soft, #eff6ff);
  margin: 0.5rem 0.75rem;
}

.tab-icon {
  font-size: 1rem;
}

.tab-texto {
  flex: 1;
  min-width: 0;
  font-size: 0.85rem;
  color: var(--text-primary);
}

.tab-acoes {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.tab-close {
  background: none;
  border: none;
  cursor: pointer;
  color: var(--text-secondary);
  font-size: 1rem;
  line-height: 1;
  padding: 0.15rem 0.35rem;
  border-radius: 6px;
}

.tab-close:hover {
  background: var(--border-subtle, rgba(0, 0, 0, 0.06));
  color: var(--text-primary);
}
</style>
