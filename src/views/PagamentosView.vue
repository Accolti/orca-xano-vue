<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { usePagamentoStore, type PagamentoRow } from '@/stores/pagamentos'
import { nomeForma } from '@/utils/pagamentos'

const pagamentoStore = usePagamentoStore()
const router = useRouter()

type Aba = 'todos' | 'em_aberto' | 'a_vencer' | 'vencido' | 'pago'
const aba = ref<Aba>('todos')
const baixandoId = ref<number | null>(null)

type Periodo = 'todos' | 'mensal' | 'trimestral' | 'semestral' | 'anual'
const periodo = ref<Periodo>('todos')
const mesInicio = ref(mesAtualISO())

function hoje(): Date {
  const d = new Date()
  d.setHours(0, 0, 0, 0)
  return d
}

function mesAtualISO(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

const MESES_PERIODO: Record<Exclude<Periodo, 'todos'>, number> = {
  mensal: 1,
  trimestral: 3,
  semestral: 6,
  anual: 12,
}

// Fim (exclusivo) da janela de vencimento a partir do 1º dia do mês escolhido.
// Sem limite inferior: parcelas já vencidas aparecem em qualquer período.
function limitePeriodo(): Date | null {
  if (periodo.value === 'todos') return null
  const [ano, mes] = mesInicio.value.split('-').map(Number)
  if (!ano || !mes) return null
  return new Date(ano, mes - 1 + MESES_PERIODO[periodo.value], 1)
}

function dataNormalizada(v?: string): Date | null {
  if (!v) return null
  const d = new Date(`${v.slice(0, 10)}T00:00:00`)
  return isNaN(d.getTime()) ? null : d
}

function statusParcela(p: PagamentoRow): 'pago' | 'vencido' | 'a_vencer' | 'em_aberto' {
  if (p.pagamento) return 'pago'
  const venc = dataNormalizada(p.vencimento)
  if (!venc) return 'em_aberto'
  if (venc < hoje()) return 'vencido'
  const limite = new Date(hoje())
  limite.setDate(limite.getDate() + 30)
  if (venc <= limite) return 'a_vencer'
  return 'em_aberto'
}

const abas: { id: Aba; label: string }[] = [
  { id: 'todos', label: 'Todos' },
  { id: 'em_aberto', label: 'Em aberto' },
  { id: 'a_vencer', label: 'A vencer' },
  { id: 'vencido', label: 'Vencidos' },
  { id: 'pago', label: 'Pagos' },
]

const periodos: { id: Periodo; label: string }[] = [
  { id: 'todos', label: 'Todos os períodos' },
  { id: 'mensal', label: 'Mensal' },
  { id: 'trimestral', label: 'Trimestral' },
  { id: 'semestral', label: 'Semestral' },
  { id: 'anual', label: 'Anual' },
]

const visiveis = computed(() => {
  let lista = pagamentoStore.parcelas
  if (aba.value === 'em_aberto') {
    lista = lista.filter((p) => !p.pagamento)
  } else if (aba.value !== 'todos') {
    lista = lista.filter((p) => statusParcela(p) === aba.value)
  }
  const limite = limitePeriodo()
  if (limite) {
    lista = lista.filter((p) => {
      const v = dataNormalizada(p.vencimento)
      return v !== null && v < limite
    })
  }
  return lista
})

const totalGeral = computed(() =>
  visiveis.value.reduce((s, p) => s + (Number(p.valor) || 0), 0),
)

function formatarMoeda(valor: number | string | null | undefined): string {
  return `R$ ${(Number(valor) || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

function formatarData(v?: string | null): string {
  if (!v) return '—'
  const d = new Date(`${v.slice(0, 10)}T00:00:00`)
  if (isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('pt-BR')
}

function corStatus(status: string): string {
  switch (status) {
    case 'pago':
      return 'badge-ok'
    case 'vencido':
      return 'badge-recusado'
    case 'a_vencer':
      return 'badge-alerta'
    default:
      return 'badge-info'
  }
}

function labelStatus(status: string): string {
  switch (status) {
    case 'pago':
      return 'Pago'
    case 'vencido':
      return 'Vencido'
    case 'a_vencer':
      return 'A vencer'
    default:
      return 'Em aberto'
  }
}

function irOrcamento(codOrca?: string | null) {
  if (codOrca) router.push(`/orcamentos/${codOrca}`)
}

async function baixar(p: PagamentoRow) {
  if (!confirm(`Confirmar recebimento de ${formatarMoeda(p.valor)}?`)) return
  baixandoId.value = p.id
  try {
    await pagamentoStore.baixar(p.id)
    await pagamentoStore.carregar()
  } catch (err: any) {
    alert(err?.message || 'Erro ao baixar a parcela.')
  } finally {
    baixandoId.value = null
  }
}

async function estornar(p: PagamentoRow) {
  if (!confirm('Desfazer a baixa desta parcela?')) return
  try {
    await pagamentoStore.estornar(p.id)
    await pagamentoStore.carregar()
  } catch (err: any) {
    alert(err?.message || 'Erro ao estornar a baixa.')
  }
}

async function excluir(p: PagamentoRow) {
  if (!confirm('Excluir esta parcela?')) return
  try {
    await pagamentoStore.excluir(p.id)
    await pagamentoStore.carregar()
  } catch (err: any) {
    alert(err?.message || 'Erro ao excluir a parcela.')
  }
}

onMounted(() => {
  pagamentoStore.carregar()
})
</script>

<template>
  <main class="container">
    <div class="topo">
      <h2>Controle Financeiro</h2>
    </div>

    <div class="periodo-bar">
      <label class="periodo-label">
        Período a partir de
        <input v-model="mesInicio" type="month" class="periodo-input" />
      </label>
      <div class="periodo-chips">
        <button
          v-for="p in periodos"
          :key="p.id"
          class="aba"
          :class="{ active: periodo === p.id }"
          @click="periodo = p.id"
        >
          {{ p.label }}
        </button>
      </div>
    </div>

    <div class="abas">
      <button
        v-for="t in abas"
        :key="t.id"
        class="aba"
        :class="{ active: aba === t.id }"
        @click="aba = t.id"
      >
        {{ t.label }}
      </button>
    </div>

    <p v-if="pagamentoStore.loading" class="status"><span class="spinner" /> Carregando...</p>

    <div v-else-if="pagamentoStore.error" class="erro-bloco">
      <p class="erro">{{ pagamentoStore.error }}</p>
      <button class="btn-retry" @click="pagamentoStore.carregar()">Tentar novamente</button>
    </div>

    <p v-else-if="visiveis.length === 0" class="status vazio">
      Nenhuma parcela neste filtro. Gerencie as parcelas pelo botão "Financeiro" dentro do orçamento.
    </p>

    <template v-else>
      <div class="tabela-wrapper">
        <table class="tabela">
          <thead>
            <tr>
              <th>Orçamento</th>
              <th>Método</th>
              <th>Valor</th>
              <th>Vencimento</th>
              <th>Pagamento</th>
              <th>Status</th>
              <th class="th-acoes">Ações</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in visiveis" :key="p.id">
              <td>
                <button class="link-orca" @click="irOrcamento(p.cod_orca)">
                  #{{ p.cod_orca || p.orca_id }}<template v-if="p.eh_pedido"> (Pedido)</template>
                </button>
              </td>
              <td>{{ p.forma || nomeForma(p.forma_pagamento_id) }}</td>
              <td class="td-valor">{{ formatarMoeda(p.valor) }}</td>
              <td>{{ formatarData(p.vencimento) }}</td>
              <td>{{ formatarData(p.pagamento) }}</td>
              <td>
                <span class="badge" :class="corStatus(statusParcela(p))">
                  {{ labelStatus(statusParcela(p)) }}
                </span>
              </td>
              <td class="td-acoes">
                <button
                  v-if="!p.pagamento"
                  class="btn-icon"
                  title="Baixar (receber)"
                  :disabled="baixandoId === p.id"
                  @click="baixar(p)"
                >
                  ✓
                </button>
                <button v-else class="btn-icon" title="Estornar baixa" @click="estornar(p)">
                  ↩
                </button>
                <button class="btn-icon btn-icon-danger" title="Excluir" @click="excluir(p)">
                  ✕
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <p class="total-geral">
        Total no filtro: <strong>{{ formatarMoeda(totalGeral) }}</strong>
      </p>
    </template>
  </main>
</template>

<style scoped>
.container {
  padding: 1rem;
  max-width: 1100px;
  margin: 0 auto;
}

.topo {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1rem;
}

.topo h2 {
  font-size: 1.35rem;
}

.abas {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  margin-bottom: 1rem;
}

.periodo-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.6rem 0.9rem;
  margin-bottom: 1rem;
}

.periodo-label {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  font-size: 0.85rem;
  color: var(--text-secondary);
}

.periodo-input {
  padding: 0.35rem 0.5rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 0.85rem;
}

.periodo-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.aba {
  padding: 0.4rem 0.9rem;
  border-radius: 999px;
  border: 1px solid var(--border-light);
  background: var(--card-bg);
  font-size: 0.85rem;
  color: var(--text-secondary);
  cursor: pointer;
  transition: background 0.15s;
}

.aba:hover {
  background: var(--table-hover);
}

.aba.active {
  background: var(--primary);
  color: #fff;
  border-color: var(--primary);
}

.status {
  color: var(--text-secondary);
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.vazio {
  padding: 1.5rem 0;
}

.spinner {
  display: inline-block;
  width: 16px;
  height: 16px;
  border: 2px solid var(--border-light);
  border-top-color: var(--primary-light);
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.erro {
  color: var(--danger);
}

.erro-bloco {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.75rem;
}

.btn-retry {
  padding: 0.4rem 0.9rem;
  background: var(--danger-soft);
  color: var(--danger);
  border: 1px solid var(--danger-soft);
  border-radius: 6px;
  font-size: 0.85rem;
  cursor: pointer;
}

.tabela-wrapper {
  overflow-x: auto;
}

.tabela {
  width: 100%;
  border-collapse: collapse;
  font-family: var(--font-body, sans-serif);
  box-shadow: var(--shadow-card);
  border-radius: 10px;
  overflow: hidden;
}

.tabela th,
.tabela td {
  padding: 10px 12px;
  text-align: left;
  border-bottom: 1px solid var(--border-light);
  white-space: nowrap;
}

.tabela th {
  background-color: var(--primary);
  color: white;
  font-weight: 600;
}

.tabela tr:hover {
  background-color: var(--table-hover);
}

.td-valor {
  font-weight: 600;
  color: var(--text-primary);
}

.th-acoes {
  width: 90px;
  text-align: center;
}

.td-acoes {
  text-align: center;
  white-space: nowrap;
}

.link-orca {
  background: none;
  border: none;
  padding: 0;
  color: var(--primary-light);
  font-weight: 600;
  cursor: pointer;
  font-family: inherit;
}

.link-orca:hover {
  text-decoration: underline;
}

.badge {
  display: inline-block;
  padding: 0.2rem 0.55rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 600;
}

.badge-ok {
  background: var(--ok-soft, #dcfce7);
  color: #16a34a;
}

.badge-alerta {
  background: var(--danger-soft, #fef3c7);
  color: #d97706;
}

.badge-recusado {
  background: var(--danger-soft, #fee2e2);
  color: #dc2626;
}

.badge-info {
  background: var(--border-subtle, #e5e7eb);
  color: var(--text-secondary);
}

.btn-icon {
  background: none;
  border: 1px solid var(--border-light);
  cursor: pointer;
  width: 32px;
  height: 32px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
  color: var(--text-secondary);
  transition: background 0.15s, color 0.15s;
}

.btn-icon:hover {
  background: var(--border-subtle);
  color: var(--primary-light);
}

.btn-icon:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-icon-danger:hover {
  color: #dc2626;
}

.total-geral {
  margin-top: 1rem;
  text-align: right;
  color: var(--text-secondary);
  font-size: 0.95rem;
}

.total-geral strong {
  color: var(--text-primary);
}
</style>
