<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { xano } from '@/services/xano'
import { XanoRequestError } from '@xano/js-sdk'
import PeriodoBar, { type PeriodoOpcao } from '@/components/PeriodoBar.vue'
import ConfigComissoesBanner from '@/components/ConfigComissoesBanner.vue'

const authStore = useAuthStore()

interface LinhaComissao {
  id: number
  user_id: number
  vendedor: string
  cod_orca: string
  orca_id: number
  percentual: number
  base: number
  tipo: 'vendedor' | 'override'
  valor: number
  status: 'calculada' | 'paga'
  data_pagamento: string | null
  data: string
}

const periodo = ref<PeriodoOpcao>('todos')
const mesInicio = ref(mesAtualISO())
const linhas = ref<LinhaComissao[]>([])
const totais = ref<{
  calculada: { qtd: number; total: number }
  paga: { qtd: number; total: number }
}>({ calculada: { qtd: 0, total: 0 }, paga: { qtd: 0, total: 0 } })

const loading = ref(false)
const erro = ref<string | null>(null)
const pagandoId = ref<number | null>(null)
const podePagar = computed(() => authStore.isAdminGeral || authStore.isAdmin)

function mesAtualISO(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

function getErrorMessage(err: unknown): string {
  if (err instanceof XanoRequestError) {
    try {
      const body = err.getResponse().getBody()
      if (typeof body === 'string') return body
      if (body?.message) return body.message
      if (body?.error?.message) return body.error.message
    } catch {
      /* ignore */
    }
  }
  return (err as Error).message || 'Erro inesperado'
}

async function carregar() {
  loading.value = true
  erro.value = null
  try {
    const params = new URLSearchParams({ periodo: periodo.value, mes_inicio: mesInicio.value })
    const resp = await xano.get(`/api:-qqRIakp/comissoes?${params.toString()}`)
    const d = resp.getBody() ?? {}
    linhas.value = (d?.linhas as LinhaComissao[]) ?? []
    totais.value = d?.totais ?? { calculada: { qtd: 0, total: 0 }, paga: { qtd: 0, total: 0 } }
  } catch (err) {
    erro.value = getErrorMessage(err)
  } finally {
    loading.value = false
  }
}

async function marcarPaga(l: LinhaComissao) {
  if (pagandoId.value) return
  if (!confirm(`Marcar a comissão de ${l.cod_orca} (${l.vendedor}) como paga?`)) return
  pagandoId.value = l.id
  erro.value = null
  try {
    await xano.post('/api:-qqRIakp/comissao_pagar', { comissao_id: l.id })
    await carregar()
  } catch (err) {
    erro.value = getErrorMessage(err)
  } finally {
    pagandoId.value = null
  }
}

function fmtMoeda(n: number | string | null | undefined): string {
  return `R$ ${(Number(n) || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

function fmtPct(n: number | string | null | undefined): string {
  return `${(Number(n) || 0).toLocaleString('pt-BR', { maximumFractionDigits: 2 })}%`
}

function papelLabel(tipo: string): string {
  return tipo === 'override' ? 'Override (Master)' : 'Ponta'
}

function fmtData(d: string | null): string {
  if (!d) return '—'
  const [ano, mes, dia] = String(d).slice(0, 10).split('-')
  return dia ? `${dia}/${mes}/${ano}` : '—'
}

onMounted(carregar)
</script>

<template>
  <main class="com">
    <header class="com-head">
      <h1>Comissões</h1>
      <p class="subtitle">
        Comissão lançada quando o pedido é 100% pago — base = venda (`vnd_tot`) na faixa do Master;
        sem faixas, sobre o lucro real × % negociado.
      </p>
    </header>

    <ConfigComissoesBanner />

    <PeriodoBar v-model:periodo="periodo" v-model:mesInicio="mesInicio" @mudou="carregar" />

    <p v-if="loading" class="status"><span class="spinner" /> Carregando...</p>
    <p v-if="erro" class="erro" role="alert">{{ erro }}</p>

    <template v-else>
      <div class="totais-grid">
        <div class="tot-item">
          <span class="tot-label">A pagar (calculadas)</span>
          <span class="tot-valor tot-alerta">{{ fmtMoeda(totais.calculada.total) }}</span>
          <span class="tot-sub">{{ totais.calculada.qtd }} comissão(ões)</span>
        </div>
        <div class="tot-item">
          <span class="tot-label">Pagas</span>
          <span class="tot-valor tot-ok">{{ fmtMoeda(totais.paga.total) }}</span>
          <span class="tot-sub">{{ totais.paga.qtd }} comissão(ões)</span>
        </div>
      </div>

      <div v-if="!linhas.length && !loading" class="vazio">Nenhuma comissão no período.</div>

      <div v-else-if="linhas.length" class="tabela-wrapper">
        <table class="tabela">
          <thead>
            <tr>
              <th>Vendedor</th>
              <th>Orçamento</th>
              <th>Data</th>
              <th class="td-dir">Base (Venda)</th>
              <th class="td-dir">%</th>
              <th class="td-dir">Comissão</th>
              <th>Status</th>
              <th>Ações</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="l in linhas" :key="l.id">
              <td>
                {{ l.vendedor }}
                <span class="badge-role" :class="{ override: l.tipo === 'override' }">
                  {{ papelLabel(l.tipo) }}
                </span>
              </td>
              <td>{{ l.cod_orca }}</td>
              <td>{{ fmtData(l.data) }}</td>
              <td class="td-dir">{{ fmtMoeda(l.base) }}</td>
              <td class="td-dir">{{ fmtPct(l.percentual) }}</td>
              <td class="td-dir td-valor">{{ fmtMoeda(l.valor) }}</td>
              <td>
                <span
                  :class="['badge-status', l.status === 'paga' ? 'badge-aprovado' : 'badge-alerta']"
                >
                  {{ l.status === 'paga' ? 'Paga' : 'A pagar' }}
                </span>
              </td>
              <td>
                <button
                  v-if="l.status === 'calculada' && podePagar"
                  class="btn btn-sm btn-primary"
                  :disabled="pagandoId === l.id"
                  @click="marcarPaga(l)"
                >
                  {{ pagandoId === l.id ? '…' : 'Marcar paga' }}
                </button>
                <span v-else-if="l.status === 'calculada'" class="muted">aguardando pagamento</span>
                <span v-else class="muted">{{ fmtData(l.data_pagamento) }}</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </main>
</template>

<style scoped>
.com {
  padding: 1.5rem;
  max-width: 1100px;
  margin: 0 auto;
}

.com-head {
  margin-bottom: 1rem;
}

.com-head h1 {
  font-size: 1.45rem;
  margin-bottom: 0.15rem;
}

.subtitle {
  color: var(--text-secondary);
  font-size: 0.9rem;
  margin: 0;
}

.status {
  color: var(--text-secondary);
  display: flex;
  align-items: center;
  gap: 0.5rem;
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

.vazio {
  color: var(--text-secondary);
  font-size: 0.85rem;
  padding: 0.5rem 0;
}

.muted {
  color: var(--text-secondary);
  font-size: 0.8rem;
}

.badge-role {
  display: inline-block;
  margin-left: 0.35rem;
  padding: 0.12rem 0.4rem;
  border-radius: 999px;
  font-size: 0.68rem;
  font-weight: 600;
  background: var(--primary-soft, #eff6ff);
  color: var(--primary-light);
}

.badge-role.override {
  background: #fef3c7;
  color: #b45309;
}

.totais-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 0.8rem;
  margin-bottom: 1rem;
}

.tot-item {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  padding: 0.7rem 0.9rem;
  border-radius: 10px;
  border: 1px solid var(--border-subtle);
  background: var(--card-bg);
}

.tot-label {
  font-size: 0.75rem;
  color: var(--text-secondary);
  font-weight: 500;
}

.tot-valor {
  font-size: 1.15rem;
  font-weight: 700;
  color: var(--text-primary);
}

.tot-ok {
  color: #16a34a;
}

.tot-alerta {
  color: #d97706;
}

.tot-sub {
  font-size: 0.75rem;
  color: var(--text-secondary);
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

.td-dir {
  text-align: right;
}

@media (max-width: 639px) {
  .com {
    padding: 1rem;
  }
}
</style>
