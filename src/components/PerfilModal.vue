<script setup lang="ts">
import { ref, reactive, watch, computed } from 'vue'
import { xano } from '@/services/xano'
import { XanoRequestError } from '@xano/js-sdk'
import { useAuthStore } from '@/stores/auth'
import { regimeMap } from '@/data/mappings'

const props = defineProps<{ modelValue: boolean }>()
const emit = defineEmits<{ 'update:modelValue': [value: boolean] }>()

const authStore = useAuthStore()

const form = reactive({
  name_first: '',
  name_last: '',
  email: '',
  razao: '',
  fantasia: '',
  cnpj: '',
  ie: '',
  cpf: '',
  isPJ: true,
  uf: '',
  regime_id: 0,
  organizacao_id: 0,
  frtB2B: 0,
  margem: 0,
  DiasVencimentoOrcamento: 0,
})

const carregando = ref(false)
const salvando = ref(false)
const erroSalvar = ref<string | null>(null)
const salvoMsg = ref<string | null>(null)
let salvoTimer: ReturnType<typeof setTimeout> | null = null
const regimes = ref<Array<{ id: number; descricao: string; slug: string }>>([])
const organizacoes = ref<Array<{ id: number; nome: string; uf: string }>>([])
const regimeAntigo = ref<number | null>(null)
const confirmandoRegime = ref(false)

// Arraste do modal (reposiciona via transform — mantém o centralizado como base)
const dragOffset = ref({ x: 0, y: 0 })
let arrastando = false
let arrasteInicio = { x: 0, y: 0 }

function iniciarArraste(e: MouseEvent) {
  if ((e.target as HTMLElement).closest('button, input, select, textarea, a')) return
  arrastando = true
  arrasteInicio = {
    x: e.clientX - dragOffset.value.x,
    y: e.clientY - dragOffset.value.y,
  }
  window.addEventListener('mousemove', moverArraste)
  window.addEventListener('mouseup', pararArraste)
}

function moverArraste(e: MouseEvent) {
  if (!arrastando) return
  dragOffset.value = {
    x: e.clientX - arrasteInicio.x,
    y: e.clientY - arrasteInicio.y,
  }
}

function pararArraste() {
  arrastando = false
  window.removeEventListener('mousemove', moverArraste)
  window.removeEventListener('mouseup', pararArraste)
}

const UFS = [
  'AC',
  'AL',
  'AP',
  'AM',
  'BA',
  'CE',
  'DF',
  'ES',
  'GO',
  'MA',
  'MT',
  'MS',
  'MG',
  'PA',
  'PB',
  'PR',
  'PE',
  'PI',
  'RJ',
  'RN',
  'RS',
  'RO',
  'RR',
  'SC',
  'SP',
  'SE',
  'TO',
]

const ehGoogle = computed(() => !!(authStore.user as any)?.google_oauth)

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

function close() {
  if (salvando.value) return
  confirmandoRegime.value = false
  emit('update:modelValue', false)
}

function preencherForm() {
  const u = authStore.user as any
  if (!u) return
  form.name_first = u.name_first ?? ''
  form.name_last = u.name_last ?? ''
  form.email = u.email ?? ''
  form.razao = u.razao ?? ''
  form.fantasia = u.fantasia ?? ''
  form.cnpj = u.cnpj ?? ''
  form.ie = u.ie ?? ''
  form.cpf = u.cpf ?? ''
  form.isPJ = u.isPJ !== false
  form.uf = u.uf ?? ''
  form.regime_id = u.regime_id ?? 0
  form.organizacao_id = Number(u.organizacao_id) || 0
  form.frtB2B = u.frtB2B ?? 0
  form.margem = u.margem ?? 0
  form.DiasVencimentoOrcamento = u.DiasVencimentoOrcamento ?? 15
  regimeAntigo.value = u.regime_id ?? 0
}

async function carregarRegimes() {
  try {
    const resp = await xano.get('/api:-qqRIakp/regime')
    const lista = resp.getBody() as any[]
    if (Array.isArray(lista) && lista.length) {
      regimes.value = lista
      return
    }
  } catch {
    /* fallback abaixo */
  }
  // Fallback: mapa fixo
  regimes.value = Object.entries(regimeMap).map(([descricao, id]) => ({
    id,
    descricao,
    slug: descricao,
  }))
}

watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return
    dragOffset.value = { x: 0, y: 0 }
    erroSalvar.value = null
    salvoMsg.value = null
    if (salvoTimer) clearTimeout(salvoTimer)
    confirmandoRegime.value = false
    carregando.value = true
    try {
      if (!authStore.user) await authStore.fetchMe()
    } catch {
      /* sessão inválida — já tratado no store */
    }
    preencherForm()
    await carregarRegimes()
    await carregarOrganizacoes()
    carregando.value = false
  },
)

async function carregarOrganizacoes() {
  try {
    const resp = await xano.get('/api:-qqRIakp/organizacao')
    const lista = resp.getBody() as any
    if (Array.isArray(lista)) {
      organizacoes.value = lista
        .map((o: any) => ({
          id: Number(o.id) || 0,
          nome: o.nome || `Organização ${o.id}`,
          uf: (o.uf || '').toUpperCase(),
        }))
        .filter((o) => o.id > 0)
    }
  } catch {
    organizacoes.value = []
  }
}

function confirmarRegime(): boolean {
  if (form.regime_id !== regimeAntigo.value) {
    confirmandoRegime.value = true
    return false
  }
  return true
}

function aceitarMudancaRegime() {
  confirmandoRegime.value = false
  submit(true)
}

function submit(ignoraConfirmacaoRegime = false) {
  if (salvando.value) return
  if (!form.uf) {
    erroSalvar.value = 'UF é obrigatória.'
    return
  }
  if (!form.regime_id) {
    erroSalvar.value = 'Regime Tributário é obrigatório.'
    return
  }
  if (!form.organizacao_id) {
    erroSalvar.value = 'Fornecedor (Organização) é obrigatório.'
    return
  }
  if (
    form.margem === null ||
    form.margem === undefined ||
    Number(form.margem) <= 0 ||
    form.DiasVencimentoOrcamento === null ||
    form.DiasVencimentoOrcamento === undefined
  ) {
    erroSalvar.value = 'Margem deve ser maior que zero e Dias de validade são obrigatórios.'
    return
  }
  if (!ignoraConfirmacaoRegime && !confirmarRegime()) return

  salvando.value = true
  erroSalvar.value = null
  salvoMsg.value = null
  if (salvoTimer) clearTimeout(salvoTimer)
  const userId = authStore.user?.id
  if (!userId) {
    erroSalvar.value = 'Usuário não identificado.'
    salvando.value = false
    return
  }

  xano
    .post(`/api:-qqRIakp/user/${userId}`, {
      name:
        [form.name_first, form.name_last].filter(Boolean).join(' ').trim() ||
        authStore.user?.name ||
        '',
      name_first: form.name_first,
      name_last: form.name_last,
      email: form.email,
      razao: form.razao,
      fantasia: form.fantasia,
      cnpj: form.cnpj,
      ie: form.ie,
      cpf: form.cpf,
      isPJ: form.isPJ,
      uf: form.uf,
      regime_id: form.regime_id || undefined,
      organizacao_id: form.organizacao_id || undefined,
      frtB2B: form.frtB2B,
      margem: form.margem,
      DiasVencimentoOrcamento: form.DiasVencimentoOrcamento,
    })
    .then(async () => {
      regimeAntigo.value = form.regime_id
      try {
        await authStore.fetchMe()
      } catch {
        /* ignora falha de refresh */
      }
      salvoMsg.value = 'Dados salvos com sucesso!'
      if (salvoTimer) clearTimeout(salvoTimer)
      salvoTimer = setTimeout(() => {
        salvoMsg.value = null
      }, 3000)
    })
    .catch((err) => {
      erroSalvar.value = getErrorMessage(err)
    })
    .finally(() => {
      salvando.value = false
    })
}

function descricaoRegime(id: number): string {
  const r = regimes.value.find((r) => r.id === id)
  return r?.descricao || String(id)
}
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div v-if="modelValue" class="modal-overlay">
        <div
          class="modal-card"
          :style="{ transform: `translate(${dragOffset.x}px, ${dragOffset.y}px)` }"
        >
          <header class="modal-header" @mousedown="iniciarArraste">
            <h2>Meus Dados</h2>
            <button class="modal-close" aria-label="Fechar" @click="close">&times;</button>
          </header>

          <div class="modal-body">
            <p v-if="carregando" class="loading-msg">Carregando...</p>

            <template v-else>
              <section class="form-section">
                <h3>Identificação</h3>
                <div class="row-2">
                  <div class="field">
                    <label for="pf-nome">Nome</label>
                    <input id="pf-nome" v-model="form.name_first" placeholder="Nome" />
                  </div>
                  <div class="field">
                    <label for="pf-sobrenome">Sobrenome</label>
                    <input id="pf-sobrenome" v-model="form.name_last" placeholder="Sobrenome" />
                  </div>
                </div>
                <div class="field">
                  <label for="pf-email">Email</label>
                  <input
                    id="pf-email"
                    :value="form.email"
                    disabled
                    placeholder="email@exemplo.com"
                  />
                  <small v-if="ehGoogle" class="field-hint"
                    >Conectado via Google — email gerenciado pelo Google.</small
                  >
                  <small v-else class="field-hint"
                    >O email de login não pode ser alterado por aqui.</small
                  >
                </div>
              </section>

              <section class="form-section">
                <h3>Empresa</h3>
                <div class="field">
                  <label for="pf-razao">Razão Social</label>
                  <input id="pf-razao" v-model="form.razao" placeholder="Razão Social" />
                </div>
                <div class="field">
                  <label for="pf-fantasia">Nome Fantasia</label>
                  <input id="pf-fantasia" v-model="form.fantasia" placeholder="Nome Fantasia" />
                </div>
                <div class="row-2">
                  <div class="field">
                    <label for="pf-cnpj">CNPJ</label>
                    <input id="pf-cnpj" v-model="form.cnpj" placeholder="CNPJ" />
                  </div>
                  <div class="field">
                    <label for="pf-ie">Inscrição Estadual (IE)</label>
                    <input id="pf-ie" v-model="form.ie" placeholder="IE" />
                  </div>
                </div>
                <div class="row-2">
                  <div class="field">
                    <label for="pf-cpf">CPF</label>
                    <input id="pf-cpf" v-model="form.cpf" placeholder="CPF" />
                  </div>
                  <div class="field">
                    <label for="pf-pj">Tipo</label>
                    <select id="pf-pj" v-model="form.isPJ">
                      <option :value="true">Pessoa Jurídica</option>
                      <option :value="false">Pessoa Física</option>
                    </select>
                  </div>
                </div>
              </section>

              <section class="form-section">
                <h3>Precificação</h3>
                <div class="row-2">
                  <div class="field">
                    <label for="pf-uf">UF (destino da venda) *</label>
                    <select id="pf-uf" v-model="form.uf">
                      <option value="" disabled>Selecione a UF</option>
                      <option v-for="uf in UFS" :key="uf" :value="uf">{{ uf }}</option>
                    </select>
                  </div>
                  <div class="field">
                    <label for="pf-regime">Regime Tributário</label>
                    <select id="pf-regime" v-model.number="form.regime_id">
                      <option :value="0" disabled>Selecione o regime</option>
                      <option v-for="r in regimes" :key="r.id" :value="r.id">
                        {{ r.descricao }}
                      </option>
                    </select>
                    <small class="field-hint">Mudar o regime só vale para novos orçamentos.</small>
                  </div>
                </div>
                <div class="field">
                  <label for="pf-org">Fornecedor (Organização) *</label>
                  <select id="pf-org" v-model.number="form.organizacao_id">
                    <option :value="0" disabled>Selecione o fornecedor</option>
                    <option v-for="o in organizacoes" :key="o.id" :value="o.id">
                      {{ o.nome }} — {{ o.uf }}
                    </option>
                  </select>
                  <small class="field-hint"
                    >Organização que fornece a mercadoria (ex.: Kapazi — PR). Vale para novos
                    orçamentos.</small
                  >
                </div>
                <div class="row-2">
                  <div class="field">
                    <label for="pf-frete">Frete B2B mínimo (R$)</label>
                    <input id="pf-frete" v-model.number="form.frtB2B" type="number" step="0.01" />
                  </div>
                  <div class="field">
                    <label for="pf-margem">Margem (%) *</label>
                    <input
                      id="pf-margem"
                      v-model.number="form.margem"
                      type="number"
                      min="0.01"
                      step="0.01"
                      placeholder="Ex.: 50 a 120"
                    />
                    <small class="field-hint"
                      >Valor percentual (markup) sobre o custo — ex.: 50 a 120.</small
                    >
                  </div>
                </div>
                <div class="field">
                  <label for="pf-dias">Dias de validade do orçamento *</label>
                  <input
                    id="pf-dias"
                    v-model.number="form.DiasVencimentoOrcamento"
                    type="number"
                    min="1"
                  />
                </div>
              </section>

              <p v-if="erroSalvar" class="error-msg">{{ erroSalvar }}</p>
              <p v-if="salvoMsg" class="success-msg">{{ salvoMsg }}</p>
            </template>
          </div>

          <footer class="modal-footer">
            <button type="button" class="btn btn-cancel" :disabled="salvando" @click="close">
              Cancelar
            </button>
            <button
              type="button"
              class="btn btn-accent"
              :disabled="salvando || carregando"
              @click="submit()"
            >
              {{ salvando ? 'Salvando…' : 'Salvar' }}
            </button>
          </footer>

          <div
            v-if="confirmandoRegime"
            class="modal-overlay confirm-overlay"
            @click.self="confirmandoRegime = false"
          >
            <div class="modal-card confirm-card">
              <header class="modal-header">
                <h2>Confirmar mudança de regime</h2>
              </header>
              <div class="modal-body">
                <p class="confirm-msg">
                  Os orçamentos <strong>anteriores</strong> mantêm o cálculo fiscal de quando foram
                  feitos (regime <strong>{{ descricaoRegime(regimeAntigo ?? 0) }}</strong
                  >). A mudança para <strong>{{ descricaoRegime(form.regime_id) }}</strong> vale
                  <strong>apenas para novos orçamentos</strong>. Deseja continuar?
                </p>
              </div>
              <footer class="modal-footer">
                <button type="button" class="btn btn-cancel" @click="confirmandoRegime = false">
                  Cancelar
                </button>
                <button
                  type="button"
                  class="btn btn-accent"
                  :disabled="salvando"
                  @click="aceitarMudancaRegime"
                >
                  {{ salvando ? 'Salvando…' : 'Sim, continuar' }}
                </button>
              </footer>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.modal-overlay {
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

.modal-card {
  background: var(--card-bg);
  border-radius: 14px;
  width: 100%;
  max-width: 600px;
  margin: auto;
  display: flex;
  flex-direction: column;
  max-height: 90vh;
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.15);
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--border-light);
  flex-shrink: 0;
  cursor: grab;
  user-select: none;
  touch-action: none;
}

.modal-header:active {
  cursor: grabbing;
}

.modal-header h2 {
  font-size: 1.15rem;
  font-weight: 700;
  color: var(--text-primary);
  margin: 0;
}

.modal-close {
  background: none;
  border: none;
  font-size: 1.5rem;
  line-height: 1;
  color: var(--text-secondary);
  cursor: pointer;
}

.modal-body {
  padding: 1.25rem 1.5rem;
  overflow-y: auto;
}

.loading-msg {
  text-align: center;
  color: var(--secondary);
}

.form-section {
  margin-bottom: 1.25rem;
}

.form-section h3 {
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--secondary);
  margin: 0 0 0.6rem;
  padding-bottom: 0.35rem;
  border-bottom: 1px solid var(--border-subtle);
}

.row-2 {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  margin-bottom: 0.6rem;
}

.field label {
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--text-secondary);
}

.field input,
.field select {
  padding: 0.5rem 0.65rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  font-size: 0.9rem;
  color: var(--text-primary);
  background: var(--card-bg);
}

.field input:focus,
.field select:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: 0 0 0 2px rgba(51, 102, 204, 0.12);
}

.field input:disabled {
  background: var(--border-subtle);
  color: var(--text-secondary);
}

.field-hint {
  font-size: 0.72rem;
  color: #9ca3af;
}

.error-msg {
  color: var(--danger, #dc2626);
  font-size: 0.85rem;
  margin: 0.5rem 0 0;
}

.success-msg {
  color: #16a34a;
  font-size: 0.85rem;
  font-weight: 600;
  margin: 0.5rem 0 0;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 1rem 1.5rem;
  border-top: 1px solid var(--border-light);
  flex-shrink: 0;
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

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-primary {
  background: var(--primary);
  color: #fff;
}

.btn-accent {
  background: var(--accent);
  color: #fff;
}

.btn-accent:hover:not(:disabled) {
  background: var(--accent-hover);
}

.btn-cancel {
  background: var(--border-subtle);
  color: var(--text-secondary);
}

.confirm-overlay {
  align-items: center;
  padding: 1rem;
}

.confirm-card {
  max-width: 460px;
}

.confirm-msg {
  font-size: 0.95rem;
  color: var(--text-primary);
  line-height: 1.5;
  margin: 0;
}

.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.2s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.modal-enter-active .modal-card,
.modal-leave-active .modal-card {
  transition: transform 0.2s ease;
}

.modal-enter-from .modal-card,
.modal-leave-to .modal-card {
  transform: translateY(12px);
}

@media (max-width: 520px) {
  .row-2 {
    grid-template-columns: 1fr;
  }
}
</style>
