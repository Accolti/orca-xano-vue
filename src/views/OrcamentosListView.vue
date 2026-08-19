<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { xano } from '@/services/xano'
import { useOrcamentoStore } from '@/stores/orcamento'
import { useAuthStore } from '@/stores/auth'
import { gerarPdfOrcamento, montarTextoWhatsApp, obterWhatsappCliente, copiarEabrirWhatsApp } from '@/services/pdf'
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
  status?: string
}

const STATUS_LABELS: Record<string, string> = {
  RASCUNHO: 'Rascunho',
  ENVIADO: 'Enviado',
  AGUARDANDO_RETORNO: 'Aguardando retorno',
  APROVADO: 'Aprovado',
  FATURADO: 'Faturado',
  RECUSADO: 'Recusado',
  CANCELADO: 'Cancelado',
}

function statusLabel(status?: string): string {
  return STATUS_LABELS[status ?? ''] ?? status ?? 'Rascunho'
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

// Toast temporário (rodapé) para avisos de clipboard/WhatsApp
const toastMsg = ref('')
let toastTimer: ReturnType<typeof setTimeout> | null = null
function mostrarToast(msg: string) {
  toastMsg.value = msg
  if (toastTimer) clearTimeout(toastTimer)
  toastTimer = setTimeout(() => {
    toastMsg.value = ''
  }, 4000)
}

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
    const [buscaRes, statusRes] = await Promise.all([
      xano.get('/api:-qqRIakp/orca_por_cliente_busca', {
        busca: termo,
        page: curPage.value,
        per_page: perPage.value,
      }),
      xano.get('/api:-qqRIakp/orcamento_status_lista'),
    ])
    const body = buscaRes.getBody() as any
    const statusMap = new Map<number, string>()
    const statusList = (statusRes.getBody() as any[]) ?? []
    statusList.forEach((o: any) => {
      if (o?.id != null && o?.status) statusMap.set(Number(o.id), o.status)
    })
    const items = ((body?.items ?? []) as OrcamentoRow[]).map((row) => ({
      ...row,
      status: statusMap.get(Number(row.id)) ?? row.status ?? 'RASCUNHO',
    }))
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
    const status = await copiarEabrirWhatsApp(telefone, mensagem)
    if (status === 'shared') {
      mostrarToast('Mensagem enviada para compartilhamento. Escolha o WhatsApp.')
    } else if (status === 'copied') {
      mostrarToast('Mensagem copiada! Cole na conversa do WhatsApp (Ctrl+V / segure o campo).')
    } else {
      mostrarToast('Não foi possível copiar. A mensagem foi aberta no WhatsApp.')
    }
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
              <th>Status</th>
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
              <td class="cell-status">
                <span class="badge-status" :class="`badge-${(row.status ?? 'RASCUNHO').toLowerCase()}`">
                  {{ statusLabel(row.status) }}
                </span>
              </td>
              <td class="cell-acoes">
                <template v-if="row.pedido_id === 0">
                  <button class="btn-icon" title="Editar orçamento" @click="editarOrcamento(row)">
                    <svg
                      width="16"
                      height="16"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    >
                      <path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z" />
                      <path d="m15 5 4 4" />
                    </svg>
                  </button>
                  <button
                    class="btn-icon btn-icon-pdf"
                    :disabled="gerandoPdfDe === row.id"
                    title="Baixar PDF"
                    @click="gerarPdf(row)"
                  >
                    <svg
                      width="16"
                      height="16"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    >
                      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                      <path d="M14 2v6h6" />
                      <path d="M9 13h6" />
                      <path d="M9 17h6" />
                    </svg>
                  </button>
                  <button
                    class="btn-icon btn-icon-whatsapp"
                    :disabled="enviandoWaDe === row.id"
                    title="Enviar via WhatsApp"
                    @click="enviarWhatsApp(row)"
                  >
                    <svg
                      width="16"
                      height="16"
                      viewBox="0 0 24 24"
                      fill="currentColor"
                    >
                      <path
                        d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 0 1-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 0 1-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 0 1 2.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0 0 12.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 0 0 5.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 0 0-3.48-8.413Z"
                      />
                    </svg>
                  </button>
                  <button
                    class="btn-icon btn-icon-danger"
                    title="Excluir orçamento"
                    @click="excluirOrcamento(row)"
                  >
                    <svg
                      width="16"
                      height="16"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    >
                      <path d="M3 6h18" />
                      <path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6" />
                      <path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2" />
                      <line x1="10" x2="10" y1="11" y2="17" />
                      <line x1="14" x2="14" y1="11" y2="17" />
                    </svg>
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
          <div class="orc-card-status">
            <span
              class="badge-status"
              :class="`badge-${(row.status ?? 'RASCUNHO').toLowerCase()}`"
            >
              {{ statusLabel(row.status) }}
            </span>
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
              <button class="btn-icon" title="Editar orçamento" @click="editarOrcamento(row)">
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z" />
                  <path d="m15 5 4 4" />
                </svg>
              </button>
              <button
                class="btn-icon btn-icon-pdf"
                :disabled="gerandoPdfDe === row.id"
                title="Baixar PDF"
                @click="gerarPdf(row)"
              >
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                  <path d="M14 2v6h6" />
                  <path d="M9 13h6" />
                  <path d="M9 17h6" />
                </svg>
              </button>
              <button
                class="btn-icon btn-icon-whatsapp"
                :disabled="enviandoWaDe === row.id"
                title="Enviar via WhatsApp"
                @click="enviarWhatsApp(row)"
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                  <path
                    d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 0 1-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 0 1-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 0 1 2.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0 0 12.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 0 0 5.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 0 0-3.48-8.413Z"
                  />
                </svg>
              </button>
              <button
                class="btn-icon btn-icon-danger"
                title="Excluir orçamento"
                @click="excluirOrcamento(row)"
              >
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M3 6h18" />
                  <path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6" />
                  <path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2" />
                  <line x1="10" x2="10" y1="11" y2="17" />
                  <line x1="14" x2="14" y1="11" y2="17" />
                </svg>
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

    <Transition name="toast-fade">
      <div v-if="toastMsg" class="app-toast">{{ toastMsg }}</div>
    </Transition>
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

.btn-icon {
  width: 28px;
  height: 28px;
  flex-shrink: 0;
  border: none;
  border-radius: 50%;
  background: transparent;
  color: var(--secondary, #6b7280);
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transition:
    background 0.15s,
    color 0.15s;
}

.btn-icon:hover:not(:disabled) {
  background: #f3f4f6;
  color: var(--primary);
}

.btn-icon:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.btn-icon svg {
  width: 16px;
  height: 16px;
}

.btn-icon-pdf:hover:not(:disabled) {
  color: #dc2626;
}

.btn-icon-whatsapp {
  color: #25d366;
}

.btn-icon-whatsapp:hover:not(:disabled) {
  background: #ecfdf5;
  color: #1fb959;
}

.btn-icon-danger:hover:not(:disabled) {
  background: #fef2f2;
  color: var(--danger, #dc2626);
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

.badge-status {
  display: inline-flex;
  align-items: center;
  padding: 0.2rem 0.55rem;
  border-radius: 999px;
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  white-space: nowrap;
}

.badge-rascunho {
  background: #f3f4f6;
  color: #374151;
}

.badge-enviado,
.badge-aguardando_retorno {
  background: #fef3c7;
  color: #92400e;
}

.badge-aprovado {
  background: #dcfce7;
  color: #166534;
}

.badge-faturado {
  background: #dbeafe;
  color: #1e40af;
}

.badge-recusado {
  background: #fee2e2;
  color: #991b1b;
}

.badge-cancelado {
  background: #e5e7eb;
  color: #374151;
}

.orc-card-status {
  margin-top: 0.35rem;
}

.cell-status {
  white-space: nowrap;
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
  align-items: center;
  gap: 0.15rem;
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
  align-items: center;
  justify-content: flex-end;
  gap: 0.15rem;
  flex-wrap: wrap;
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

.app-toast {
  position: fixed;
  bottom: 1.25rem;
  left: 50%;
  transform: translateX(-50%);
  max-width: min(90vw, 520px);
  padding: 0.75rem 1.1rem;
  background: #1f4e79;
  color: #fff;
  border-radius: 8px;
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.25);
  font-size: 0.9rem;
  text-align: center;
  z-index: 1200;
}

.toast-fade-enter-active,
.toast-fade-leave-active {
  transition: opacity 0.25s ease, transform 0.25s ease;
}

.toast-fade-enter-from,
.toast-fade-leave-to {
  opacity: 0;
  transform: translateX(-50%) translateY(10px);
}
</style>
