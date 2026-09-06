<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { xano } from '@/services/xano'
import { XanoRequestError } from '@xano/js-sdk'
import { nomeForma } from '@/utils/pagamentos'
import PeriodoBar from '@/components/PeriodoBar.vue'

type PeriodoOpcao = 'todos' | 'mensal' | 'trimestral' | 'semestral' | 'anual'

interface LinhaFinanceiro {
  orca_id: number
  cod_orca: string
  cliente: string
  data: string
  custo_kapazi: number
  perc_desconto: number
  desconto_kapazi: number
  frete_efetivo: number
  venda: number
  lucro_real: number
  margem_real: number
}

interface TotaisFinanceiro {
  custo_kapazi: number
  desconto_kapazi: number
  frete_efetivo: number
  venda: number
  lucro_real: number
  margem_real: number
}

interface LinhaRecebido {
  id: number
  orca_id: number
  cod_orca: string
  vencimento: string
  data_pagamento: string
  valor: number
  forma_pagamento_id: number
}

interface Transicao {
  de: string
  para: string
  qtde: number
}

const periodo = ref<PeriodoOpcao>('todos')
const mesInicio = ref(mesAtualISO())

function mesAtualISO(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

const loading = ref(true)
const error = ref<string | null>(null)

const financeiroPedidos = ref<LinhaFinanceiro[]>([])
const financeiroTotais = ref<TotaisFinanceiro | null>(null)
const recebidos = ref<LinhaRecebido[]>([])
const recebidosTotal = ref(0)
const recebidosQtde = ref(0)
const transicoes = ref<Transicao[]>([])
const aprovacoes = ref(0)
const mediaDiasAprov = ref(0)
const orcamentosJanela = ref(0)
const conversao = ref(0)

async function carregar() {
  loading.value = true
  error.value = null
  try {
    const params = new URLSearchParams({ periodo: periodo.value, mes_inicio: mesInicio.value })
    const resp = await xano.get(`/api:-qqRIakp/relatorio?${params.toString()}`)
    const d = resp.getBody() ?? {}

    financeiroPedidos.value = d?.financeiro?.pedidos ?? []
    financeiroTotais.value = d?.financeiro?.totais ?? null

    recebidos.value = d?.recebidos?.linhas ?? []
    recebidosTotal.value = Number(d?.recebidos?.totais?.total) || 0
    recebidosQtde.value = Number(d?.recebidos?.totais?.qtde) || 0

    transicoes.value = d?.funil?.transicoes ?? []
    aprovacoes.value = Number(d?.funil?.aprovacoes) || 0
    mediaDiasAprov.value = Number(d?.funil?.media_dias_aprovacao) || 0
    orcamentosJanela.value = Number(d?.funil?.orcamentos_janela) || 0
    conversao.value = Number(d?.funil?.conversao) || 0
  } catch (err) {
    const body = (err as XanoRequestError)?.getResponse?.()?.getBody?.()
    error.value = body?.message || (err as Error).message || 'Erro ao carregar os relatórios.'
  } finally {
    loading.value = false
  }
}

function fmtMoeda(n: number | string | null | undefined): string {
  return `R$ ${(Number(n) || 0).toLocaleString('pt-BR', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`
}

function fmtPct(n: number | string | null | undefined): string {
  return `${(Number(n) || 0).toLocaleString('pt-BR', {
    maximumFractionDigits: 2,
  })}%`
}

function fmtData(d: string): string {
  if (!d) return '—'
  const [ano, mes, dia] = d.split('-')
  return dia ? `${dia}/${mes}/${ano}` : `${mes}/${ano}`
}

onMounted(carregar)
</script>

<template>
  <main class="relat">
    <header class="relat-head">
      <h1>Relatórios</h1>
      <p class="subtitle">Financeiro de pedidos, recebidos e funil de status.</p>
    </header>

    <PeriodoBar
      v-model:periodo="periodo"
      v-model:mesInicio="mesInicio"
      @mudou="carregar"
    />

    <p v-if="loading" class="status"><span class="spinner" /> Carregando...</p>

    <div v-else-if="error" class="erro-bloco">
      <p class="erro">{{ error }}</p>
      <button class="btn-retry" @click="carregar">Tentar novamente</button>
    </div>

    <template v-else>
      <section class="sec">
        <h2>Financeiro (Pedidos)</h2>
        <div v-if="financeiroTotais" class="totais-grid">
          <div class="tot-item">
            <span class="tot-label">Custo Kapazi</span>
            <span class="tot-valor">{{ fmtMoeda(financeiroTotais.custo_kapazi) }}</span>
          </div>
          <div class="tot-item">
            <span class="tot-label">Desconto Kapazi</span>
            <span class="tot-valor tot-ok">{{ fmtMoeda(financeiroTotais.desconto_kapazi) }}</span>
          </div>
          <div class="tot-item">
            <span class="tot-label">Frete Efetivo</span>
            <span class="tot-valor">{{ fmtMoeda(financeiroTotais.frete_efetivo) }}</span>
          </div>
          <div class="tot-item">
            <span class="tot-label">Vendas</span>
            <span class="tot-valor">{{ fmtMoeda(financeiroTotais.venda) }}</span>
          </div>
          <div class="tot-item">
            <span class="tot-label">Lucro Real</span>
            <span class="tot-valor tot-ok">{{ fmtMoeda(financeiroTotais.lucro_real) }}</span>
          </div>
          <div class="tot-item">
            <span class="tot-label">Margem Real</span>
            <span class="tot-valor">{{ fmtPct(financeiroTotais.margem_real) }}</span>
          </div>
        </div>

        <div v-if="financeiroPedidos.length" class="tabela-wrapper">
          <table class="tabela">
            <thead>
              <tr>
                <th>Orçamento</th>
                <th>Cliente</th>
                <th>Data</th>
                <th class="td-dir">Custo Kapazi</th>
                <th class="td-dir">Desconto</th>
                <th class="td-dir">Frete efetivo</th>
                <th class="td-dir">Venda</th>
                <th class="td-dir">Lucro Real</th>
                <th class="td-dir">Margem</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="p in financeiroPedidos" :key="p.orca_id">
                <td>{{ p.cod_orca }}</td>
                <td>{{ p.cliente || '—' }}</td>
                <td>{{ fmtData(p.data) }}</td>
                <td class="td-dir">{{ fmtMoeda(p.custo_kapazi) }}</td>
                <td class="td-dir">
                  {{ fmtMoeda(p.desconto_kapazi) }}
                  <span v-if="p.perc_desconto" class="td-sub">({{ p.perc_desconto }}%)</span>
                </td>
                <td class="td-dir">{{ fmtMoeda(p.frete_efetivo) }}</td>
                <td class="td-dir">{{ fmtMoeda(p.venda) }}</td>
                <td class="td-dir td-valor">{{ fmtMoeda(p.lucro_real) }}</td>
                <td class="td-dir">{{ fmtPct(p.margem_real) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-else class="vazio">Nenhum pedido convertido no período.</p>
      </section>

      <section class="sec">
        <h2>Recebidos no período</h2>
        <div class="totais-grid">
          <div class="tot-item">
            <span class="tot-label">Recebido</span>
            <span class="tot-valor tot-ok">{{ fmtMoeda(recebidosTotal) }}</span>
          </div>
          <div class="tot-item">
            <span class="tot-label">Parcelas pagas</span>
            <span class="tot-valor">{{ recebidosQtde }}</span>
          </div>
        </div>

        <div v-if="recebidos.length" class="tabela-wrapper">
          <table class="tabela">
            <thead>
              <tr>
                <th>Orçamento</th>
                <th>Vencimento</th>
                <th>Data do pagamento</th>
                <th class="td-dir">Valor</th>
                <th>Forma</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in recebidos" :key="r.id">
                <td>{{ r.cod_orca }}</td>
                <td>{{ fmtData(r.vencimento) }}</td>
                <td>{{ fmtData(r.data_pagamento) }}</td>
                <td class="td-dir td-valor">{{ fmtMoeda(r.valor) }}</td>
                <td>{{ nomeForma(r.forma_pagamento_id) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-else class="vazio">Nenhum recebimento no período.</p>
      </section>

      <section class="sec">
        <h2>Funil de status</h2>
        <div class="totais-grid">
          <div class="tot-item">
            <span class="tot-label">Orçamentos na janela</span>
            <span class="tot-valor">{{ orcamentosJanela }}</span>
          </div>
          <div class="tot-item">
            <span class="tot-label">Aprovações</span>
            <span class="tot-valor">{{ aprovacoes }}</span>
          </div>
          <div class="tot-item">
            <span class="tot-label">Conversão → Aprovado</span>
            <span class="tot-valor">{{ fmtPct(conversao) }}</span>
          </div>
          <div class="tot-item">
            <span class="tot-label">Tempo médio até Aprovado</span>
            <span class="tot-valor">{{ mediaDiasAprov }} dia(s)</span>
          </div>
        </div>

        <div v-if="transicoes.length" class="tabela-wrapper">
          <table class="tabela">
            <thead>
              <tr>
                <th>De</th>
                <th>Para</th>
                <th class="td-dir">Transições</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(t, idx) in transicoes" :key="idx">
                <td>{{ t.de }}</td>
                <td>{{ t.para }}</td>
                <td class="td-dir">{{ t.qtde }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-else class="vazio">Nenhuma transição de status no período.</p>
      </section>
    </template>
  </main>
</template>

<style scoped>
.relat {
  padding: 1.5rem;
  max-width: 1180px;
  margin: 0 auto;
}

.relat-head {
  margin-bottom: 1.25rem;
}

.relat-head h1 {
  font-size: 1.45rem;
  margin-bottom: 0.15rem;
}

.subtitle {
  color: var(--text-secondary);
  font-size: 0.95rem;
  margin: 0;
}

.periodo-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.6rem 0.9rem;
  margin-bottom: 1.4rem;
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
  font-family: inherit;
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

.sec {
  margin-bottom: 1.75rem;
}

.sec h2 {
  font-size: 1.05rem;
  margin-bottom: 0.75rem;
  color: var(--text-primary);
}

.totais-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 0.8rem;
  margin-bottom: 1rem;
}

.tot-item {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
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
  font-size: 1.1rem;
  font-weight: 700;
  color: var(--text-primary);
}

.tot-ok {
  color: #16a34a;
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

.td-sub {
  font-size: 0.72rem;
  color: var(--text-secondary);
  font-weight: 400;
}

.vazio {
  color: var(--text-secondary);
  font-size: 0.85rem;
  padding: 0.5rem 0;
}

@media (max-width: 639px) {
  .relat {
    padding: 1rem;
  }
}
</style>
