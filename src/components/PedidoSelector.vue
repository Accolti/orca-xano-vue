<script setup lang="ts">
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { buscarListaOrcamentos } from '@/services/orcamentoApi'
import { sugerirPedidosNf } from '@/services/notaFiscalApi'

const props = defineProps<{
  valorSugestao?: number | null
}>()

const emit = defineEmits<{ select: [pedido: any] }>()

const authStore = useAuthStore()

const termo = ref('')
const resultados = ref<any[]>([])
const modo = ref<'busca' | 'sugestao'>('busca')
const carregando = ref(false)
const tolerancia = ref(5)
let buscaTimer: ReturnType<typeof setTimeout> | null = null

const tolerancias = [2, 5, 10, 20]

function moeda(v: number | null | undefined): string {
  return `R$ ${(Number(v) || 0).toLocaleString('pt-BR', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`
}

function nomeCliente(p: any): string {
  return p?.cliente_nome || p?.nome_fantasia || p?.razao_social || ''
}

function rotulo(p: any): string {
  const cod = p?.cod_orca || ''
  const cli = nomeCliente(p)
  return [cod, cli].filter(Boolean).join(' — ')
}

function aoDigitar() {
  modo.value = 'busca'
  if (buscaTimer) clearTimeout(buscaTimer)
  buscaTimer = setTimeout(buscar, 300)
}

async function buscar() {
  const t = termo.value.trim()
  if (t.length < 3) {
    resultados.value = []
    return
  }
  carregando.value = true
  try {
    const { items } = await buscarListaOrcamentos({
      userId: authStore.user?.id,
      busca: t,
      page: 1,
      perPage: 10,
      soPedidos: true,
    })
    resultados.value = items ?? []
  } catch {
    resultados.value = []
  } finally {
    carregando.value = false
  }
}

async function sugerir() {
  if (props.valorSugestao == null) return
  modo.value = 'sugestao'
  carregando.value = true
  try {
    resultados.value = await sugerirPedidosNf(
      props.valorSugestao,
      tolerancia.value,
      authStore.user?.id,
    )
  } catch {
    resultados.value = []
  } finally {
    carregando.value = false
  }
}

function escolher(p: any) {
  emit('select', p)
}
</script>

<template>
  <div class="sel">
    <div class="sel-campos">
      <input
        v-model="termo"
        type="text"
        placeholder="Busque pelo código ou cliente…"
        class="sel-input"
        @input="aoDigitar"
      />
      <button
        v-if="valorSugestao != null"
        type="button"
        class="sel-sugerir"
        :disabled="carregando"
        @click="sugerir"
      >
        Sugerir por valor
      </button>
    </div>

    <div v-if="valorSugestao != null" class="sel-tolerancia">
      <label>Tolerância</label>
      <select v-model.number="tolerancia" @change="modo === 'sugestao' ? sugerir() : undefined">
        <option v-for="t in tolerancias" :key="t" :value="t">±{{ t }}%</option>
      </select>
      <span v-if="modo === 'sugestao'" class="sel-valor">Valor da NF: {{ moeda(valorSugestao) }}</span>
    </div>

    <div v-if="carregando" class="sel-carregando">Buscando…</div>

    <div v-if="resultados.length" class="sel-lista">
      <button
        v-for="p in resultados"
        :key="p.id"
        type="button"
        class="sel-item"
        @click="escolher(p)"
      >
        <span class="sel-item-rotulo">{{ rotulo(p) }}</span>
        <template v-if="modo === 'sugestao'">
          <span class="sel-item-valor">Custo Kapazi: {{ moeda(p.custo_kapazi) }}</span>
          <span
            class="sel-item-dif"
            :class="{ 'sel-item-dif-ok': p.diferenca_abs < 1 }"
          >
            dif: {{ moeda(p.diferenca_abs) }}
          </span>
        </template>
      </button>
    </div>
  </div>
</template>

<style scoped>
.sel {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.sel-campos {
  display: flex;
  gap: 0.5rem;
}

.sel-input {
  flex: 1;
  padding: 0.6rem 0.75rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  font-size: 0.95rem;
  background: var(--card-bg);
  color: var(--text-primary);
  outline: none;
}

.sel-sugerir {
  padding: 0.5rem 0.9rem;
  background: var(--primary);
  color: #fff;
  border: none;
  border-radius: 6px;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
}

.sel-sugerir:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.sel-tolerancia {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.82rem;
  color: var(--text-secondary);
}

.sel-tolerancia select {
  padding: 0.3rem 0.5rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-size: 0.82rem;
}

.sel-valor {
  margin-left: auto;
  font-weight: 600;
  color: var(--text-primary);
}

.sel-carregando {
  font-size: 0.85rem;
  color: var(--text-secondary);
  padding: 0.5rem 0;
}

.sel-lista {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  max-height: 240px;
  overflow-y: auto;
}

.sel-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.6rem 0.75rem;
  border: 1px solid var(--border-light);
  border-radius: 8px;
  background: none;
  cursor: pointer;
  text-align: left;
  transition: background 0.15s;
}

.sel-item:hover {
  background: var(--border-subtle);
}

.sel-item-rotulo {
  flex: 1;
  font-size: 0.88rem;
  color: var(--text-primary);
  font-weight: 600;
}

.sel-item-valor {
  font-size: 0.82rem;
  color: var(--text-secondary);
  white-space: nowrap;
}

.sel-item-dif {
  font-size: 0.82rem;
  color: #dc2626;
  white-space: nowrap;
  font-weight: 600;
}

.sel-item-dif-ok {
  color: #16a34a;
}
</style>
