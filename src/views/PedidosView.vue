<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { useOrcamentoStore } from '@/stores/orcamento'
import {
  useOrcamentosListActions,
  STATUS_PEDIDO_FILTRO,
  statusLabel,
  formatarMoeda,
  formatarData,
  type OrcamentoRow,
} from '@/utils/orcamentosList'

const orcamentoStore = useOrcamentoStore()

const termoBusca = ref('')
const filtroStatus = ref<string>('')
const resultados = ref<OrcamentoRow[]>([])
const loading = ref(false)
const errorMsg = ref('')
let debounceTimer: ReturnType<typeof setTimeout> | null = null

const {
  gerandoPdfDe,
  enviandoWaDe,
  toastMsg,
  editarOrcamento,
  gerarPdf,
  enviarWhatsApp,
  buscarLista,
} = useOrcamentosListActions()

const curPage = ref(1)
const perPage = ref(20)
const hasNext = ref(false)
const hasPrev = ref(false)

// Filtro de status client-side sobre o status mesclado
const resultadosVisiveis = computed(() =>
  filtroStatus.value
    ? resultados.value.filter((r) => r.status === filtroStatus.value)
    : resultados.value,
)

async function buscar() {
  const termo = termoBusca.value.trim()
  loading.value = true
  errorMsg.value = ''
  try {
    const res = await buscarLista(termo, curPage.value, perPage.value, true)
    resultados.value = res.items
    hasNext.value = res.hasNext
    hasPrev.value = res.hasPrev
  } catch (err: any) {
    console.error('Erro na busca de pedidos:', err)
    errorMsg.value = 'Erro ao buscar pedidos'
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

watch(filtroStatus, () => {
  curPage.value = 1
})

onMounted(() => {
  buscar()
})

function verPedido(row: OrcamentoRow) {
  editarOrcamento(row, 'pedidos')
}
</script>

<template>
  <div class="orc-list-page">
    <section class="card header-card">
      <div class="header-top">
        <h2>Pedidos</h2>
      </div>
      <div class="filtros-row">
        <div class="field busca-field">
          <label>Buscar por código, cliente, contato, CPF, CNPJ...</label>
          <input
            v-model="termoBusca"
            placeholder="Digite pelo menos 3 caracteres..."
            @input="onBuscaInput"
          />
        </div>
        <div class="field filtro-status">
          <label>Status</label>
          <select v-model="filtroStatus">
            <option value="">Todos</option>
            <option v-for="s in STATUS_PEDIDO_FILTRO" :key="s" :value="s">
              {{ statusLabel(s) }}
            </option>
          </select>
        </div>
      </div>
    </section>

    <section v-if="loading" class="card loading-card">
      <p>Buscando...</p>
    </section>

    <section v-if="errorMsg" class="card">
      <p class="error-msg">{{ errorMsg }}</p>
    </section>

    <section v-if="!loading && resultadosVisiveis.length" class="card tabela-card">
      <div class="tabela-orcamentos-wrap">
        <table class="tabela-orcamentos">
          <thead>
            <tr>
              <th>Código</th>
              <th>Cliente</th>
              <th>Contato</th>
              <th>CNPJ/CPF</th>
              <th>Total Venda</th>
              <th>Total c/ B2C</th>
              <th>Data Envio</th>
              <th>Status</th>
              <th>Ações</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in resultadosVisiveis" :key="row.id">
              <td class="cell-cod">{{ row.cod_orca }}</td>
              <td class="cell-cliente">{{ row.nome_fantasia || row.razao_social }}</td>
              <td class="cell-contato">{{ row.contato }}</td>
              <td class="cell-doc">{{ row.cnpj || row.cpf || '-' }}</td>
              <td class="cell-valor">{{ formatarMoeda(row.vnd_tot) }}</td>
              <td class="cell-valor">{{ formatarMoeda(row.vnd_B2B_B2C_tot) }}</td>
              <td class="cell-data">{{ formatarData(row.data_envio) }}</td>
              <td class="cell-status">
                <span
                  class="badge-status"
                  :class="`badge-${(row.status ?? 'RASCUNHO').toLowerCase()}`"
                >
                  {{ statusLabel(row.status) }}
                </span>
              </td>
              <td class="cell-acoes">
                <button class="btn-icon" title="Ver pedido" @click="verPedido(row)">
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
                    <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z" />
                    <circle cx="12" cy="12" r="3" />
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
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Cards mobile -->
      <div class="orc-cards-mobile">
        <div v-for="row in resultadosVisiveis" :key="row.id" class="orc-card-mobile">
          <div class="orc-card-header">
            <span class="orc-card-cod">{{ row.cod_orca }}</span>
            <span class="orc-card-data">{{ formatarData(row.created_at) }}</span>
          </div>
          <div class="orc-card-status">
            <span class="badge-status" :class="`badge-${(row.status ?? 'RASCUNHO').toLowerCase()}`">
              {{ statusLabel(row.status) }}
            </span>
          </div>
          <div class="orc-card-body">
            <div class="orc-card-field">
              <span class="orc-card-label">Cliente</span>
              <span class="orc-card-value">{{ row.nome_fantasia || row.razao_social }}</span>
            </div>
            <div class="orc-card-field">
              <span class="orc-card-label">Total</span>
              <span class="orc-card-value">{{ formatarMoeda(row.vnd_tot) }}</span>
            </div>
            <div class="orc-card-field">
              <span class="orc-card-label">Total c/ B2C</span>
              <span class="orc-card-value">{{ formatarMoeda(row.vnd_B2B_B2C_tot) }}</span>
            </div>
            <div class="orc-card-field">
              <span class="orc-card-label">Data Envio</span>
              <span class="orc-card-value">{{ formatarData(row.data_envio) }}</span>
            </div>
          </div>
          <div class="orc-card-actions">
            <button class="btn-icon" title="Ver pedido" @click="verPedido(row)">
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
                <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z" />
                <circle cx="12" cy="12" r="3" />
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

    <section v-if="!loading && !resultadosVisiveis.length" class="card">
      <p class="empty-msg">Nenhum pedido encontrado.</p>
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

.filtros-row {
  display: flex;
  gap: 1rem;
  align-items: flex-end;
}

.filtros-row .busca-field {
  flex: 1;
}

.filtro-status {
  min-width: 220px;
}

.filtro-status select {
  width: 100%;
  padding: 0.5rem 0.7rem;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 0.9rem;
  color: #1f2937;
  outline: none;
  background: #fff;
}

.field label {
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

.btn-outline {
  border-color: #d1d5db;
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

.badge-aguardando_faturamento {
  background: #ede9fe;
  color: #6d28d9;
}

.badge-entregue {
  background: #ccfbf1;
  color: #0f766e;
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

.empty-msg {
  text-align: center;
  color: var(--secondary);
  margin: 0;
  font-size: 0.9rem;
}

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
  .filtros-row {
    flex-direction: column;
  }
  .filtro-status {
    min-width: 100%;
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
  transition:
    opacity 0.25s ease,
    transform 0.25s ease;
}

.toast-fade-enter-from,
.toast-fade-leave-to {
  opacity: 0;
  transform: translateX(-50%) translateY(10px);
}
</style>
