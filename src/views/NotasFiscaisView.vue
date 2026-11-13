<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { listarNotasFiscais, salvarNotaFiscal, excluirNotaFiscal } from '@/services/notaFiscalApi'
import { buscarListaOrcamentos } from '@/services/orcamentoApi'
import { parseNfeXml, type NotaFiscalParsed } from '@/utils/nfeParser'
import type { NotaFiscal } from '@/types/notaFiscal'
import NotaFiscalModal from '@/components/NotaFiscalModal.vue'

const authStore = useAuthStore()

const notas = ref<any[]>([])
const carregando = ref(false)
const erroLista = ref<string | null>(null)

const importOpen = ref(false)
const parsed = ref<NotaFiscalParsed | null>(null)
const erroImport = ref<string | null>(null)
const salvando = ref(false)

const termoPedido = ref('')
const pedidosBusca = ref<any[]>([])
const pedidoSelecionado = ref<any | null>(null)
let buscaTimer: ReturnType<typeof setTimeout> | null = null

const modalNotaOpen = ref(false)
const notaVisualizada = ref<NotaFiscal | null>(null)

const fileInput = ref<HTMLInputElement | null>(null)

function moeda(v: number | null | undefined): string {
  return `R$ ${(Number(v) || 0).toLocaleString('pt-BR', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`
}

function dataBR(v: string | null | undefined): string {
  if (!v) return ''
  const [y, m, d] = String(v).slice(0, 10).split('-')
  if (!y || !m || !d) return String(v)
  return `${d}/${m}/${y}`
}

async function carregar() {
  carregando.value = true
  erroLista.value = null
  try {
    notas.value = await listarNotasFiscais(authStore.user?.id)
  } catch (err: any) {
    erroLista.value = err?.message || 'Erro ao carregar notas fiscais'
  } finally {
    carregando.value = false
  }
}

function abrirImport() {
  erroImport.value = null
  parsed.value = null
  pedidoSelecionado.value = null
  termoPedido.value = ''
  pedidosBusca.value = []
  importOpen.value = true
  fileInput.value?.click()
}

async function aoSelecionarArquivo(ev: Event) {
  const file = (ev.target as HTMLInputElement).files?.[0]
  if (!file) return
  try {
    const texto = await file.text()
    parsed.value = parseNfeXml(texto)
    erroImport.value = null
  } catch (err: any) {
    parsed.value = null
    erroImport.value = err?.message || 'Erro ao ler o XML.'
  } finally {
    if (fileInput.value) fileInput.value.value = ''
  }
}

function fecharImport() {
  importOpen.value = false
  parsed.value = null
  erroImport.value = null
  pedidoSelecionado.value = null
  termoPedido.value = ''
  pedidosBusca.value = []
}

function aoDigitarPedido() {
  if (buscaTimer) clearTimeout(buscaTimer)
  buscaTimer = setTimeout(buscarPedidos, 300)
}

async function buscarPedidos() {
  const t = termoPedido.value.trim()
  if (t.length < 3) {
    pedidosBusca.value = []
    return
  }
  try {
    const { items } = await buscarListaOrcamentos({
      userId: authStore.user?.id,
      busca: t,
      page: 1,
      perPage: 10,
      soPedidos: true,
    })
    pedidosBusca.value = items ?? []
  } catch {
    pedidosBusca.value = []
  }
}

function selecionarPedido(p: any) {
  pedidoSelecionado.value = p
  termoPedido.value = p?.cod_orca ?? ''
  pedidosBusca.value = []
}

function nomePedido(p: any): string {
  const cli = p?.nome_fantasia || p?.razao_social || ''
  const cod = p?.cod_orca || ''
  return [cod, cli].filter(Boolean).join(' — ')
}

async function salvar() {
  if (!parsed.value) return
  salvando.value = true
  erroImport.value = null
  try {
    await salvarNotaFiscal(
      {
        ...parsed.value,
        orca_id: pedidoSelecionado.value?.id ?? null,
      },
      authStore.user?.id,
    )
    fecharImport()
    await carregar()
  } catch (err: any) {
    erroImport.value = err?.message || 'Erro ao salvar nota fiscal'
  } finally {
    salvando.value = false
  }
}

function verNota(nota: any) {
  notaVisualizada.value = nota as NotaFiscal
  modalNotaOpen.value = true
}

async function excluir(nota: any) {
  const rotulo = nota.numero ? `Nº ${nota.numero}` : nota.chave
  if (!confirm(`Excluir a nota fiscal ${rotulo}?`)) return
  try {
    await excluirNotaFiscal(nota.id, authStore.user?.id)
    await carregar()
  } catch (err: any) {
    erroLista.value = err?.message || 'Erro ao excluir nota fiscal'
  }
}

onMounted(carregar)
</script>

<template>
  <div class="nf-page">
    <header class="nf-topo">
      <h1>Notas Fiscais</h1>
      <button class="btn btn-accent" @click="abrirImport">＋ Importar XML</button>
      <input
        ref="fileInput"
        type="file"
        accept=".xml,text/xml,application/xml"
        style="display: none"
        @change="aoSelecionarArquivo"
      />
    </header>

    <p v-if="!authStore.isAdmin" class="nf-aviso">
      Apenas administradores gerenciam notas fiscais.
    </p>

    <p v-if="erroLista" class="nf-erro">{{ erroLista }}</p>

    <div v-if="carregando" class="nf-loading">Carregando notas fiscais…</div>

    <div v-else-if="!notas.length" class="nf-empty">
      Nenhuma nota fiscal importada ainda. Clique em "Importar XML".
    </div>

    <div v-else class="nf-lista">
      <div v-for="nota in notas" :key="nota.id" class="nf-item">
        <div class="nf-item-main">
          <strong class="nf-item-titulo">NF {{ nota.numero || '—' }}</strong>
          <span class="nf-item-chave mono">{{ nota.chave }}</span>
          <span class="nf-item-meta">
            {{ dataBR(nota.data_emissao) || '—' }} · {{ nota.emitente_nome || '—' }} ·
            {{ moeda(nota.valor_total) }}
          </span>
          <span class="nf-item-pedido">
            <template v-if="nota.cod_orca">Pedido {{ nota.cod_orca }}</template>
            <template v-else class="sem-vinculo">Sem vínculo com pedido</template>
          </span>
        </div>
        <div class="nf-item-acoes">
          <button class="btn btn-sm btn-outline" @click="verNota(nota)">Ver</button>
          <button class="btn btn-sm btn-danger" @click="excluir(nota)">Excluir</button>
        </div>
      </div>
    </div>

    <!-- Modal de importação (prévia + vínculo com pedido) -->
    <Teleport to="body">
      <Transition name="modal">
        <div v-if="importOpen" class="nf-overlay" @click.self="fecharImport">
          <div class="nf-card nf-card-import">
            <header class="nf-header">
              <h2>Importar Nota Fiscal</h2>
              <button class="nf-close" @click="fecharImport" aria-label="Fechar">&times;</button>
            </header>

            <div class="nf-body">
              <div v-if="erroImport" class="nf-erro">{{ erroImport }}</div>

              <template v-if="parsed">
                <section class="nf-section">
                  <h3>Dados extraídos do XML</h3>
                  <div class="nf-grid">
                    <div class="nf-field">
                      <label>Chave</label>
                      <span class="mono">{{ parsed.chave }}</span>
                    </div>
                    <div class="nf-field">
                      <label>Nº / Série</label>
                      <span>{{ parsed.numero }} / {{ parsed.serie || '—' }}</span>
                    </div>
                    <div class="nf-field">
                      <label>Emissão</label>
                      <span>{{ dataBR(parsed.data_emissao) }}</span>
                    </div>
                    <div class="nf-field">
                      <label>Total</label>
                      <span>{{ moeda(parsed.valor_total) }}</span>
                    </div>
                  </div>
                  <p class="nf-natop">
                    <strong>Emitente:</strong> {{ parsed.emitente_nome || '—' }} ({{ parsed.emitente_cnpj || '—' }})
                    · <strong>Destinatário:</strong> {{ parsed.destinatario_nome || '—' }} ({{
                      parsed.destinatario_cnpj || '—'
                    }})
                    · {{ parsed.itens.length }} item(ns)
                  </p>
                </section>

                <section class="nf-section">
                  <h3>Vincular a um pedido (opcional)</h3>
                  <input
                    v-model="termoPedido"
                    type="text"
                    placeholder="Busque pelo código ou cliente do pedido…"
                    class="nf-input"
                    @input="aoDigitarPedido"
                  />
                  <div v-if="pedidosBusca.length" class="nf-pedidos">
                    <button
                      v-for="p in pedidosBusca"
                      :key="p.id"
                      type="button"
                      class="nf-pedido-opt"
                      @click="selecionarPedido(p)"
                    >
                      {{ nomePedido(p) }}
                    </button>
                  </div>
                  <p v-if="pedidoSelecionado" class="nf-natop">
                    <strong>Pedido vinculado:</strong> {{ nomePedido(pedidoSelecionado) }}
                  </p>
                </section>
              </template>
              <p v-else class="nf-empty">Selecione um arquivo XML de NF-e.</p>
            </div>

            <footer class="nf-footer">
              <button type="button" class="btn btn-cancel" @click="fecharImport">Cancelar</button>
              <button
                type="button"
                class="btn btn-accent"
                :disabled="!parsed || salvando"
                @click="salvar"
              >
                {{ salvando ? 'Salvando…' : 'Salvar' }}
              </button>
            </footer>
          </div>
        </div>
      </Transition>
    </Teleport>

    <NotaFiscalModal v-model="modalNotaOpen" :nota="notaVisualizada" />
  </div>
</template>

<style scoped>
.nf-page {
  max-width: 900px;
  margin: 0 auto;
  padding: 1rem;
}

.nf-topo {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1.25rem;
}

.nf-topo h1 {
  font-size: 1.4rem;
  color: var(--text-primary);
  margin: 0;
}

.nf-aviso,
.nf-erro {
  color: var(--danger, #dc2626);
  font-size: 0.9rem;
  margin-bottom: 0.75rem;
}

.nf-loading,
.nf-empty {
  color: var(--text-secondary);
  text-align: center;
  padding: 2rem 0;
}

.nf-lista {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.nf-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem;
  border: 1px solid var(--border-light);
  border-radius: 10px;
  background: var(--card-bg);
}

.nf-item-main {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  min-width: 0;
}

.nf-item-titulo {
  font-size: 1rem;
  color: var(--text-primary);
}

.nf-item-chave {
  font-size: 0.75rem;
  color: var(--text-secondary);
  word-break: break-all;
}

.nf-item-meta {
  font-size: 0.85rem;
  color: var(--text-secondary);
}

.nf-item-pedido {
  font-size: 0.8rem;
  color: var(--primary);
  font-weight: 600;
}

.nf-item-acoes {
  display: flex;
  gap: 0.5rem;
  flex-shrink: 0;
}

.mono {
  font-family: monospace;
}

.btn {
  padding: 0.55rem 1.1rem;
  border-radius: 6px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  border: none;
}

.btn-accent {
  background: var(--accent);
  color: #fff;
}

.btn-accent:hover {
  background: var(--accent-hover);
}

.btn-cancel {
  background: var(--border-subtle);
  color: var(--text-secondary);
}

.btn-outline {
  background: none;
  border: 1px solid var(--border-light);
  color: var(--text-secondary);
}

.btn-danger {
  background: none;
  border: 1px solid #fecaca;
  color: #dc2626;
}

.btn-sm {
  padding: 0.35rem 0.7rem;
  font-size: 0.82rem;
}

.nf-overlay {
  position: fixed;
  inset: 0;
  z-index: 2000;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: 2rem 1rem;
  overflow-y: auto;
}

.nf-card {
  background: var(--card-bg);
  border-radius: 14px;
  width: 100%;
  max-width: 620px;
  margin: auto;
  display: flex;
  flex-direction: column;
  max-height: 90vh;
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.15);
}

.nf-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--border-light);
  flex-shrink: 0;
}

.nf-header h2 {
  font-size: 1.15rem;
  font-weight: 700;
  color: var(--text-primary);
  margin: 0;
}

.nf-close {
  background: none;
  border: none;
  font-size: 1.5rem;
  color: var(--text-secondary);
  cursor: pointer;
  width: 32px;
  height: 32px;
  border-radius: 6px;
}

.nf-body {
  padding: 1.25rem 1.5rem;
  overflow-y: auto;
  flex: 1;
}

.nf-section {
  margin-bottom: 1.5rem;
}

.nf-section h3 {
  font-size: 0.8rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--text-secondary);
  margin-bottom: 0.75rem;
}

.nf-grid {
  display: grid;
  grid-template-columns: 2fr 1fr 1fr 1fr;
  gap: 0.75rem;
}

.nf-field {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.nf-field label {
  font-size: 0.72rem;
  font-weight: 600;
  color: var(--text-secondary);
}

.nf-field span {
  font-size: 0.88rem;
  color: var(--text-primary);
  word-break: break-word;
}

.nf-natop {
  margin-top: 0.75rem;
  font-size: 0.85rem;
  color: var(--text-secondary);
}

.nf-input {
  width: 100%;
  padding: 0.6rem 0.75rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  font-size: 0.95rem;
  background: var(--card-bg);
  color: var(--text-primary);
  outline: none;
}

.nf-pedidos {
  margin-top: 0.5rem;
  border: 1px solid var(--border-light);
  border-radius: 8px;
  max-height: 180px;
  overflow-y: auto;
}

.nf-pedido-opt {
  display: block;
  width: 100%;
  text-align: left;
  padding: 0.6rem 0.75rem;
  background: none;
  border: none;
  border-bottom: 1px solid var(--border-light);
  font-size: 0.9rem;
  color: var(--text-primary);
  cursor: pointer;
}

.nf-pedido-opt:hover {
  background: var(--border-subtle);
}

.nf-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 1rem 1.5rem;
  border-top: 1px solid var(--border-light);
  flex-shrink: 0;
}

.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.2s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

@media (max-width: 639px) {
  .nf-grid {
    grid-template-columns: 1fr 1fr;
  }

  .nf-item {
    flex-direction: column;
    align-items: stretch;
  }

  .nf-item-acoes {
    justify-content: flex-end;
  }
}
</style>
