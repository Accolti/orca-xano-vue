<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { xano } from '@/services/xano'
import { useOrcamentoStore } from '@/stores/orcamento'
import { useAuthStore } from '@/stores/auth'
import { gerarPdfOrcamento, montarTextoWhatsApp, obterWhatsappCliente, abrirWhatsApp } from '@/services/pdf'
import type { Cliente } from '@/types/cliente'

interface OrcamentoRow {
  id: number
  created_at: number
  cod_orca: string
  cliente_id: number
  nome_fantasia: string
  razao_social: string
  contato: string
  cpf: string
  cnpj: string
  inscricao_estadual: string
  vnd_tot: number
  vnd_B2B_tot: number
  cst_tot: number
  luc_tot: number
  margem: number
  validade: string
  pedido_id: number
}

const router = useRouter()
const orcamentoStore = useOrcamentoStore()
const authStore = useAuthStore()

const termoBusca = ref('')
const resultados = ref<OrcamentoRow[]>([])
const loading = ref(false)
const errorMsg = ref('')
const gerandoPdfDe = ref<number | null>(null)
let debounceTimer: ReturnType<typeof setTimeout> | null = null

const curPage = ref(1)
const perPage = ref(20)
const hasNext = ref(false)
const hasPrev = ref(false)
const jaCarregou = ref(false)

function formatarMoeda(valor: number): string {
  return `R$ ${valor.toFixed(2).replace('.', ',')}`
}

function formatarData(ts: number | string): string {
  if (!ts) return ''
  const d = typeof ts === 'number' ? new Date(ts) : new Date(ts)
  return d.toLocaleDateString('pt-BR')
}

async function buscar() {
  const termo = termoBusca.value.trim()

  loading.value = true
  errorMsg.value = ''
  try {
    const response = await xano.get('/api:-qqRIakp/orca_por_cliente_busca', {
      busca: termo,
      page: curPage.value,
      per_page: perPage.value,
    })
    const body = response.getBody() as any
    const items = (body?.items ?? []) as OrcamentoRow[]
    resultados.value = items
    const itemsReceived = body?.itemsReceived ?? items.length
    hasNext.value = !!body.nextPage && itemsReceived >= perPage.value
    hasPrev.value = !!body.prevPage
    jaCarregou.value = true
  } catch (err: any) {
    console.error('Erro na busca:', err)
    errorMsg.value = 'Erro ao buscar orçamentos'
    resultados.value = []
  } finally {
    loading.value = false
  }
}

function onBuscaInput() {
  if (debounceTimer) clearTimeout(debounceTimer)
  curPage.value = 1
  debounceTimer = setTimeout(buscar, 350)
}

function irPagina(pagina: number) {
  if (pagina < 1) return
  curPage.value = pagina
  buscar()
}

onMounted(() => {
  buscar()
})

function novoOrcamento() {
  router.push('/orcamentos/novo')
}

function editarOrcamento(row: OrcamentoRow) {
  router.push(`/orcamentos/${row.cod_orca}`)
}

async function gerarPdf(row: OrcamentoRow) {
  gerandoPdfDe.value = row.id
  try {
    await orcamentoStore.carregarOrcamento(row.cod_orca)
    const header = orcamentoStore.orcamentoHeader
    const cliente = montarClienteDoHeader(header)
    gerarPdfOrcamento({
      header,
      itens: orcamentoStore.itensInseridos,
      cliente,
      user: authStore.user,
    })
  } catch {
    errorMsg.value = 'Erro ao gerar o PDF'
  } finally {
    gerandoPdfDe.value = null
  }
}

const enviandoWaDe = ref<number | null>(null)

function montarClienteDoHeader(header: any): Cliente | null {
  const c = header?._cliente
  if (!c) return null
  return {
    id: c.id,
    razao_social: c.razao_social || '',
    nome_fantasia: c.nome_fantasia || '',
    contato: c.contato || '',
    cpf: c.cpf || '',
    nome_cpf: c.nome_cpf || '',
    cnpj: c.cnpj || '',
    inscricao_estadual: c.inscricao_estadual || '',
    'e-mail': c['e-mail'] || '',
    contribui_icms: c.contribui_icms ?? false,
    isento: c.isento ?? false,
    observacao: c.observacao || '',
    user_id: c.user_id ?? 0,
    beneficio_fiscal_id: c.beneficio_fiscal_id ?? null,
    mercado_id: c.mercado_id ?? null,
    ramo_id: c.ramo_id ?? null,
    regime_id: c.regime_id ?? null,
    created_at: c.created_at ?? 0,
    _enderecos: c._enderecos ?? [],
    _telefone_cliente_of_cliente: c._telefone_cliente_of_cliente ?? [],
  }
}

async function enviarWhatsApp(row: OrcamentoRow) {
  enviandoWaDe.value = row.id
  try {
    await orcamentoStore.carregarOrcamento(row.cod_orca)
    const header = orcamentoStore.orcamentoHeader
    const cliente = montarClienteDoHeader(header)
    const telefone = obterWhatsappCliente(cliente)
    if (!telefone) {
      errorMsg.value = `Cliente sem telefone cadastrado (tipo 1) em ${row.cod_orca}`
      return
    }
    const mensagem = montarTextoWhatsApp({
      header,
      itens: orcamentoStore.itensInseridos,
      cliente,
    })
    abrirWhatsApp(telefone, mensagem)
  } catch {
    errorMsg.value = 'Erro ao gerar o WhatsApp'
  } finally {
    enviandoWaDe.value = null
  }
}

async function excluirOrcamento(row: OrcamentoRow) {
  if (!confirm(`Excluir orçamento ${row.cod_orca}?`)) return
  try {
    await orcamentoStore.deleteOrcamento(row.id)
    resultados.value = resultados.value.filter((r) => r.id !== row.id)
  } catch {
    errorMsg.value = 'Erro ao excluir orçamento'
  }
}
</script>

<template>
  <div class="orc-list-page">
    <section class="card header-card">
      <div class="header-top">
        <h2>Orçamentos</h2>
        <button class="btn btn-primary" @click="novoOrcamento">+ Novo Orçamento</button>
      </div>
      <div class="field busca-field">
        <label>Buscar por código, cliente, contato, CPF, CNPJ, IE...</label>
        <input
          v-model="termoBusca"
          placeholder="Digite pelo menos 3 caracteres..."
          @input="onBuscaInput"
        />
      </div>
    </section>

    <section v-if="loading" class="card loading-card">
      <p>Buscando...</p>
    </section>

    <section v-if="errorMsg" class="card">
      <p class="error-msg">{{ errorMsg }}</p>
    </section>

    <section v-if="!loading && resultados.length" class="card tabela-card">
      <div class="tabela-orcamentos-wrap">
        <table class="tabela-orcamentos">
          <thead>
            <tr>
              <th>Código</th>
              <th>Cliente</th>
              <th>Contato</th>
              <th>CNPJ/CPF</th>
              <th>Total Venda</th>
              <th>Data</th>
              <th>Ações</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in resultados" :key="row.id">
              <td class="cell-cod">{{ row.cod_orca }}</td>
              <td class="cell-cliente">{{ row.nome_fantasia || row.razao_social }}</td>
              <td class="cell-contato">{{ row.contato }}</td>
              <td class="cell-doc">{{ row.cnpj || row.cpf || '-' }}</td>
              <td class="cell-valor">{{ formatarMoeda(row.vnd_tot) }}</td>
              <td class="cell-data">{{ formatarData(row.created_at) }}</td>
              <td class="cell-acoes">
                <template v-if="row.pedido_id === 0">
                  <button class="btn btn-sm btn-outline" @click="editarOrcamento(row)">
                    Editar
                  </button>
                  <button
                    class="btn btn-sm btn-outline"
                    :disabled="gerandoPdfDe === row.id"
                    @click="gerarPdf(row)"
                  >
                    {{ gerandoPdfDe === row.id ? 'Gerando…' : 'PDF' }}
                  </button>
                  <button
                    class="btn btn-sm btn-whatsapp"
                    :disabled="enviandoWaDe === row.id"
                    @click="enviarWhatsApp(row)"
                  >
                    {{ enviandoWaDe === row.id ? 'Enviando…' : 'WhatsApp' }}
                  </button>
                  <button class="btn btn-sm btn-danger-outline" @click="excluirOrcamento(row)">
                    Excluir
                  </button>
                </template>
                <span v-else class="badge-pedido">Vinculado</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Cards mobile -->
      <div class="orc-cards-mobile">
        <div v-for="row in resultados" :key="row.id" class="orc-card-mobile">
          <div class="orc-card-header">
            <span class="orc-card-cod">{{ row.cod_orca }}</span>
            <span class="orc-card-data">{{ formatarData(row.created_at) }}</span>
          </div>
          <div class="orc-card-body">
            <div class="orc-card-field">
              <span class="orc-card-label">Cliente</span>
              <span class="orc-card-value">{{ row.nome_fantasia || row.razao_social }}</span>
            </div>
            <div class="orc-card-field">
              <span class="orc-card-label">Contato</span>
              <span class="orc-card-value">{{ row.contato }}</span>
            </div>
            <div class="orc-card-field">
              <span class="orc-card-label">CNPJ/CPF</span>
              <span class="orc-card-value">{{ row.cnpj || row.cpf || '-' }}</span>
            </div>
            <div class="orc-card-field">
              <span class="orc-card-label">Total</span>
              <span class="orc-card-value">{{ formatarMoeda(row.vnd_tot) }}</span>
            </div>
          </div>
          <div class="orc-card-actions">
            <template v-if="row.pedido_id === 0">
              <button class="btn btn-sm btn-outline" @click="editarOrcamento(row)">Editar</button>
              <button
                class="btn btn-sm btn-outline"
                :disabled="gerandoPdfDe === row.id"
                @click="gerarPdf(row)"
              >
                {{ gerandoPdfDe === row.id ? 'Gerando…' : 'PDF' }}
              </button>
              <button
                class="btn btn-sm btn-whatsapp"
                :disabled="enviandoWaDe === row.id"
                @click="enviarWhatsApp(row)"
              >
                {{ enviandoWaDe === row.id ? 'Enviando…' : 'WhatsApp' }}
              </button>
              <button class="btn btn-sm btn-danger-outline" @click="excluirOrcamento(row)">
                Excluir
              </button>
            </template>
            <span v-else class="badge-pedido">Vinculado</span>
          </div>
        </div>
      </div>

      <div v-if="hasNext || hasPrev" class="pagination">
        <button v-if="hasPrev" class="btn btn-sm btn-outline" @click="irPagina(curPage - 1)">
          ← Anterior
        </button>
        <span class="page-info">Página {{ curPage }}</span>
        <button v-if="hasNext" class="btn btn-sm btn-outline" @click="irPagina(curPage + 1)">
          Próxima →
        </button>
      </div>
    </section>

    <section v-if="!loading && termoBusca.length >= 3 && !resultados.length" class="card">
      <p class="empty-msg">Nenhum orçamento encontrado para "{{ termoBusca }}"</p>
    </section>

    <section v-if="!loading && !jaCarregou" class="card hint-card">
      <p class="hint-msg">
        Digite ao menos 3 caracteres para filtrar, ou veja os últimos orçamentos acima.
      </p>
    </section>
  </div>
</template>

<style scoped>
.orc-list-page {
  padding: 1rem;
  max-width: 1100px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.card {
  background: var(--card-bg, #fff);
  border-radius: 10px;
  padding: 1.25rem;
  box-shadow:
    0 1px 3px rgba(0, 0, 0, 0.06),
    0 1px 2px rgba(0, 0, 0, 0.04);
}

.header-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.header-top h2 {
  font-size: 1.2rem;
  margin: 0;
}

.busca-field label {
  display: block;
  font-size: 0.8rem;
  font-weight: 600;
  color: #374151;
  margin-bottom: 0.25rem;
}

.busca-field input {
  width: 100%;
  padding: 0.5rem 0.7rem;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 0.9rem;
  color: #1f2937;
  outline: none;
  transition: border-color 0.15s;
}

.busca-field input:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 2px rgba(51, 102, 204, 0.12);
}

.btn {
  padding: 0.55rem 1.25rem;
  border-radius: 8px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  border: none;
  transition:
    background 0.2s,
    transform 0.15s;
}

.btn:active {
  transform: scale(0.97);
}

.btn-primary {
  background: var(--primary);
  color: #fff;
}

.btn-primary:hover {
  background: #2a52a3;
}

.btn-sm {
  padding: 0.35rem 0.7rem;
  font-size: 0.8rem;
  border-radius: 5px;
  font-weight: 500;
  cursor: pointer;
  border: 1px solid #d1d5db;
  background: #fff;
  color: #374151;
  transition: background 0.15s;
}

.btn-sm:hover {
  background: #f3f4f6;
}

.btn-outline {
  border-color: #d1d5db;
}

.btn-danger-outline {
  border-color: #fecaca;
  color: var(--danger, #dc2626);
}

.btn-danger-outline:hover {
  background: #fef2f2;
}

.btn-whatsapp {
  background: #25d366;
  border-color: #25d366;
  color: #fff;
}

.btn-whatsapp:hover:not(:disabled) {
  background: #1fb959;
  border-color: #1fb959;
  color: #fff;
}

.badge-pedido {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  background: #fef3c7;
  color: #92400e;
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
  display: inline-block;
}

.loading-card p {
  text-align: center;
  color: var(--secondary);
  margin: 0;
}

.error-msg {
  color: var(--danger);
  font-size: 0.85rem;
  margin: 0;
}

.empty-msg,
.hint-msg {
  text-align: center;
  color: var(--secondary);
  margin: 0;
  font-size: 0.9rem;
}

/* Table */
.tabela-orcamentos-wrap {
  overflow-x: auto;
}

.tabela-orcamentos {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.85rem;
}

.tabela-orcamentos th,
.tabela-orcamentos td {
  padding: 0.6rem 0.5rem;
  text-align: left;
  border-bottom: 1px solid #f3f4f6;
  white-space: nowrap;
}

.tabela-orcamentos th {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--secondary);
  border-bottom: 1px solid #e5e7eb;
}

.tabela-orcamentos tbody tr:hover {
  background: #f9fafb;
}

.cell-cliente {
  max-width: 220px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.cell-cod {
  font-weight: 700;
  color: var(--primary);
}

.cell-valor {
  font-weight: 700;
  text-align: right;
}

.cell-acoes {
  display: flex;
  gap: 0.35rem;
}

/* Pagination */
.pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  margin-top: 1rem;
  padding-top: 0.75rem;
  border-top: 1px solid #f3f4f6;
}

.page-info {
  font-size: 0.85rem;
  color: var(--secondary);
  font-weight: 600;
}

/* Mobile cards */
.orc-cards-mobile {
  display: none;
  flex-direction: column;
  gap: 0.75rem;
}

.orc-card-mobile {
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  padding: 0.75rem;
  background: #fafafa;
}

.orc-card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
}

.orc-card-cod {
  font-weight: 700;
  color: var(--primary);
}

.orc-card-data {
  font-size: 0.8rem;
  color: var(--secondary);
}

.orc-card-body {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  margin-bottom: 0.5rem;
}

.orc-card-field {
  display: flex;
  justify-content: space-between;
  font-size: 0.8rem;
}

.orc-card-label {
  color: var(--secondary);
  font-weight: 600;
}

.orc-card-value {
  color: #1f2937;
  text-align: right;
  max-width: 60%;
  overflow: hidden;
  text-overflow: ellipsis;
}

.orc-card-actions {
  display: flex;
  gap: 0.5rem;
}

@media (max-width: 767px) {
  .tabela-orcamentos-wrap {
    display: none;
  }
  .orc-cards-mobile {
    display: flex;
  }
  .header-top {
    flex-direction: column;
    align-items: stretch;
    gap: 0.75rem;
  }
  .orc-list-page {
    padding: 0.75rem;
  }
}

@media (min-width: 768px) {
  .tabela-orcamentos-wrap {
    display: block;
  }
  .orc-cards-mobile {
    display: none;
  }
}
</style>
