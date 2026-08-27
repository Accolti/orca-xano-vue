<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { xano } from '@/services/xano'
import { useCatalogoStore } from '@/stores/catalogo'
import DevNav from '@/components/DevNav.vue'

interface FatorDev {
  id: number
  nome: string
  valor: number[]
  larg_base: number
  comp_corte: number
  tam_total: number
  modo_corte: 'lista' | 'passo'
  obs?: string
}

interface AssociacaoDev {
  id: number
  fator_de_corte_id: number | null
  material_id: number | null
  linha_id: number | null
  borda_id: number | null
  material_nome?: string
  linha_nome?: string | null
  borda_nome?: string | null
}

const catalogo = useCatalogoStore()

const fatores = ref<FatorDev[]>([])
const associacoes = ref<AssociacaoDev[]>([])
const loading = ref(false)
const erroMsg = ref('')
const salvando = ref(false)

// Form de fator
const formFatorOpen = ref(false)
const editandoFatorId = ref<number | null>(null)
const formFator = ref<FatorDev>({
  id: 0,
  nome: '',
  valor: [] as number[],
  larg_base: 0,
  comp_corte: 0,
  tam_total: 0,
  modo_corte: 'lista',
  obs: '',
})
const valorListaTexto = ref('')

// Form de associação
const formAssocOpen = ref(false)
const editandoAssocId = ref<number | null>(null)
const formAssoc = ref<AssociacaoDev>({
  id: 0,
  fator_de_corte_id: null,
  material_id: null,
  linha_id: null,
  borda_id: null,
})

const materiais = ref<{ id: number; nome: string; ativo: boolean }[]>([])
const linhasDoMaterial = computed(() =>
  catalogo.allLinhas.filter((l) => l.material_id === formAssoc.value.material_id),
)
const bordasDoMaterial = computed(() =>
  catalogo.allBordas.filter(
    (b) => b.material_id === formAssoc.value.material_id && b.ativo !== false,
  ),
)

async function carregarMateriais() {
  if (materiais.value.length) return
  try {
    const resp = await xano.get('/api:-qqRIakp/materiais_dev_lista')
    materiais.value = ((resp.getBody() as any[]) ?? []).map((m) => ({
      id: m.id,
      nome: m.nome || `#${m.id}`,
      ativo: m.ativo !== false,
    }))
  } catch {
    materiais.value = catalogo.materiais as unknown as {
      id: number
      nome: string
      ativo: boolean
    }[]
  }
}

async function carregar() {
  loading.value = true
  erroMsg.value = ''
  try {
    const resp = await xano.get('/api:-qqRIakp/fatores_corte_dev')
    const body = resp.getBody() as any
    fatores.value = (body?.fatores ?? []) as FatorDev[]
    associacoes.value = (body?.associacoes ?? []) as AssociacaoDev[]
  } catch (err: any) {
    erroMsg.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao listar fatores de corte'
  } finally {
    loading.value = false
  }
}

function nomeFator(id: number | null | undefined): string {
  if (!id) return '—'
  const f = fatores.value.find((x) => x.id === id)
  return f?.nome || `#${id}`
}

function descricaoFator(f: FatorDev): string {
  if (f.modo_corte === 'passo') return `passo ${f.comp_corte}m`
  return f.valor?.length ? `lista: ${f.valor.join(', ')}` : 'lista vazia'
}

function abrirNovoFator() {
  editandoFatorId.value = null
  formFator.value = {
    id: 0,
    nome: '',
    valor: [] as number[],
    larg_base: 0,
    comp_corte: 0,
    tam_total: 0,
    modo_corte: 'lista',
    obs: '',
  }
  valorListaTexto.value = ''
  formFatorOpen.value = true
}

function abrirEdicaoFator(f: FatorDev) {
  editandoFatorId.value = f.id
  formFator.value = { ...f, valor: [...(f.valor ?? [])] }
  valorListaTexto.value = (f.valor ?? []).join(', ')
  formFatorOpen.value = true
}

async function salvarFator() {
  salvando.value = true
  erroMsg.value = ''
  try {
    const valor = valorListaTexto.value
      .split(',')
      .map((s) => Number(s.trim().replace(',', '.')))
      .filter((n) => !isNaN(n) && n > 0)
    const payload = {
      fator_de_corte_id: editandoFatorId.value ?? null,
      nome: formFator.value.nome,
      valor,
      larg_base: formFator.value.larg_base || null,
      comp_corte: formFator.value.comp_corte || null,
      tam_total: formFator.value.tam_total || null,
      modo_corte: formFator.value.modo_corte,
      obs: formFator.value.obs || null,
    }
    await xano.post('/api:-qqRIakp/fator_corte_cadastrar', payload)
    formFatorOpen.value = false
    await carregar()
  } catch (err: any) {
    erroMsg.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao salvar fator'
  } finally {
    salvando.value = false
  }
}

async function excluirFator(f: FatorDev) {
  if (!confirm(`Excluir o fator "${f.nome}"?`)) return
  erroMsg.value = ''
  try {
    await xano.delete('/api:-qqRIakp/fator_corte_excluir', {
      fator_de_corte_id: f.id,
    })
    await carregar()
  } catch (err: any) {
    erroMsg.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao excluir fator'
  }
}

function abrirNovaAssoc() {
  editandoAssocId.value = null
  formAssoc.value = {
    id: 0,
    fator_de_corte_id: null,
    material_id: null,
    linha_id: null,
    borda_id: null,
  }
  formAssocOpen.value = true
}

function abrirEdicaoAssoc(a: AssociacaoDev) {
  editandoAssocId.value = a.id
  formAssoc.value = { ...a }
  formAssocOpen.value = true
}

async function salvarAssoc() {
  salvando.value = true
  erroMsg.value = ''
  try {
    await xano.post('/api:-qqRIakp/tipo_fator_cadastrar', {
      tipo_fator_id: editandoAssocId.value ?? null,
      material_id: formAssoc.value.material_id,
      linha_id: formAssoc.value.linha_id ?? null,
      borda_id: formAssoc.value.borda_id ?? null,
      fator_de_corte_id: formAssoc.value.fator_de_corte_id,
      excluir: false,
    })
    formAssocOpen.value = false
    await carregar()
  } catch (err: any) {
    erroMsg.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao salvar associação'
  } finally {
    salvando.value = false
  }
}

async function excluirAssoc(a: AssociacaoDev) {
  if (!confirm('Remover esta associação Tipo_Fator?')) return
  erroMsg.value = ''
  try {
    await xano.post('/api:-qqRIakp/tipo_fator_cadastrar', {
      tipo_fator_id: a.id,
      excluir: true,
    })
    await carregar()
  } catch (err: any) {
    erroMsg.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao remover associação'
  }
}

onMounted(async () => {
  await catalogo.fetchCatalogo()
  await Promise.all([carregar(), carregarMateriais()])
})
</script>

<template>
  <div class="dev-page">
    <DevNav />
    <section class="card header-card">
      <div class="header-top">
        <h2>Dev — Fatores de Corte</h2>
        <div class="header-actions">
          <button class="btn btn-outline btn-sm" @click="carregar">Recarregar</button>
          <button class="btn btn-primary btn-sm" @click="abrirNovoFator">+ Novo Fator</button>
        </div>
      </div>
      <p class="field-hint">
        O fator de corte é definido pelo fornecedor (Kapazi). Modo <strong>lista</strong> usa
        múltiplos fixos (ex.: Vinil); modo <strong>passo</strong> arredonda sempre ao múltiplo do
        passo (ex.: 0,5m → 1,23 vira 1,50). A associação Tipo_Fator liga material+linha+borda ao
        fator (fallback do M2).
      </p>
    </section>

    <p v-if="erroMsg" class="error-msg">{{ erroMsg }}</p>

    <section v-if="loading" class="card loading-card"><p>Carregando...</p></section>

    <template v-else>
      <!-- Fatores de Corte -->
      <section class="card tabela-card">
        <h3 class="dev-section-title">Fatores de Corte ({{ fatores.length }})</h3>
        <div v-if="!fatores.length" class="dev-empty">Nenhum fator cadastrado.</div>
        <div class="tabela-orcamentos-wrap">
          <table v-if="fatores.length" class="tabela-orcamentos">
            <thead>
              <tr>
                <th>ID</th>
                <th>Nome</th>
                <th>Modo</th>
                <th>Descrição</th>
                <th>Larg. base</th>
                <th>Tam. rolo</th>
                <th>Ações</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="f in fatores" :key="f.id">
                <td class="cell-cod">{{ f.id }}</td>
                <td class="cell-cliente">{{ f.nome }}</td>
                <td>
                  <span :class="['badge-status', f.modo_corte === 'passo' ? 'badge-aprovado' : '']">
                    {{ f.modo_corte }}
                  </span>
                </td>
                <td>{{ descricaoFator(f) }}</td>
                <td>{{ f.larg_base || '-' }}</td>
                <td>{{ f.tam_total || '-' }}</td>
                <td class="cell-acoes">
                  <button class="btn-icon" title="Editar" @click="abrirEdicaoFator(f)">
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
                      <path d="M17 3a2.8 2.8 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z" />
                    </svg>
                  </button>
                  <button class="btn-icon" title="Excluir" @click="excluirFator(f)">
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
                      <path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
                      <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6" />
                    </svg>
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <!-- Associações Tipo_Fator -->
      <section class="card tabela-card">
        <div class="dev-section-header">
          <h3 class="dev-section-title">
            Associações Tipo_Fator (material+linha+borda) ({{ associacoes.length }})
          </h3>
          <button class="btn btn-primary btn-sm" @click="abrirNovaAssoc">+ Nova Associação</button>
        </div>
        <div v-if="!associacoes.length" class="dev-empty">Nenhuma associação.</div>
        <div class="tabela-orcamentos-wrap">
          <table v-if="associacoes.length" class="tabela-orcamentos">
            <thead>
              <tr>
                <th>ID</th>
                <th>Material</th>
                <th>Linha</th>
                <th>Borda</th>
                <th>Fator</th>
                <th>Ações</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="a in associacoes" :key="a.id">
                <td class="cell-cod">{{ a.id }}</td>
                <td>{{ a.material_nome || '—' }}</td>
                <td>{{ a.linha_nome || '—' }}</td>
                <td>{{ a.borda_nome || '—' }}</td>
                <td>{{ nomeFator(a.fator_de_corte_id) }}</td>
                <td class="cell-acoes">
                  <button class="btn-icon" title="Editar" @click="abrirEdicaoAssoc(a)">
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
                      <path d="M17 3a2.8 2.8 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z" />
                    </svg>
                  </button>
                  <button class="btn-icon" title="Remover" @click="excluirAssoc(a)">
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
                      <path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
                      <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6" />
                    </svg>
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </template>

    <!-- Modal Fator -->
    <Teleport to="body">
      <div v-if="formFatorOpen" class="modal-overlay">
        <div class="dev-modal">
          <header class="dev-modal-header">
            <h3>
              {{ editandoFatorId ? `Editar Fator #${editandoFatorId}` : 'Novo Fator de Corte' }}
            </h3>
            <button class="close-btn" @click="formFatorOpen = false">✕</button>
          </header>
          <div class="dev-modal-body">
            <div class="field">
              <label>Nome *</label>
              <input v-model="formFator.nome" type="text" placeholder="ex.: Grama múltiplo 2,5" />
            </div>
            <div class="field">
              <label>Modo</label>
              <select v-model="formFator.modo_corte">
                <option value="lista">Lista (múltiplos fixos)</option>
                <option value="passo">Passo (arredonda sempre)</option>
              </select>
            </div>
            <div v-if="formFator.modo_corte === 'lista'" class="field">
              <label>Valores da lista (separados por vírgula)</label>
              <input v-model="valorListaTexto" type="text" placeholder="ex.: 0.4, 0.6, 0.8, 1.2" />
            </div>
            <div v-else class="field">
              <label>Passo (m) *</label>
              <input
                v-model.number="formFator.comp_corte"
                type="number"
                step="0.1"
                min="0.1"
                placeholder="ex.: 0.5"
              />
            </div>
            <div class="dev-grid-3">
              <div class="field">
                <label>Largura base (m)</label>
                <input v-model.number="formFator.larg_base" type="number" step="0.01" />
              </div>
              <div class="field">
                <label>Tamanho rolo (m)</label>
                <input v-model.number="formFator.tam_total" type="number" step="0.01" />
              </div>
              <div class="field">
                <label>Obs</label>
                <input v-model="formFator.obs" type="text" />
              </div>
            </div>
          </div>
          <footer class="dev-modal-footer">
            <button class="btn btn-outline" @click="formFatorOpen = false">Cancelar</button>
            <button
              class="btn btn-primary"
              :disabled="salvando || !formFator.nome"
              @click="salvarFator"
            >
              {{ salvando ? 'Salvando...' : 'Salvar' }}
            </button>
          </footer>
        </div>
      </div>
    </Teleport>

    <!-- Modal Associação -->
    <Teleport to="body">
      <div v-if="formAssocOpen" class="modal-overlay">
        <div class="dev-modal">
          <header class="dev-modal-header">
            <h3>
              {{ editandoAssocId ? `Editar Associação #${editandoAssocId}` : 'Nova Associação' }}
            </h3>
            <button class="close-btn" @click="formAssocOpen = false">✕</button>
          </header>
          <div class="dev-modal-body">
            <div class="field">
              <label>Material *</label>
              <select v-model="formAssoc.material_id">
                <option :value="null">Selecione...</option>
                <option v-for="m in materiais" :key="m.id" :value="m.id">
                  {{ m.nome }}{{ m.ativo === false ? ' (inativo)' : '' }}
                </option>
              </select>
            </div>
            <div class="field">
              <label>Linha</label>
              <select v-model="formAssoc.linha_id">
                <option :value="null">—</option>
                <option v-for="l in linhasDoMaterial" :key="l.id" :value="l.id">
                  {{ l.nome }}
                </option>
              </select>
            </div>
            <div class="field">
              <label>Borda</label>
              <select v-model="formAssoc.borda_id">
                <option :value="null">—</option>
                <option v-for="b in bordasDoMaterial" :key="b.id" :value="b.id">
                  {{ b.nome }}
                </option>
              </select>
            </div>
            <div class="field">
              <label>Fator de Corte *</label>
              <select v-model="formAssoc.fator_de_corte_id">
                <option :value="null">Selecione...</option>
                <option v-for="f in fatores" :key="f.id" :value="f.id">
                  {{ f.nome }} ({{ descricaoFator(f) }})
                </option>
              </select>
            </div>
          </div>
          <footer class="dev-modal-footer">
            <button class="btn btn-outline" @click="formAssocOpen = false">Cancelar</button>
            <button
              class="btn btn-primary"
              :disabled="salvando || !formAssoc.material_id || !formAssoc.fator_de_corte_id"
              @click="salvarAssoc"
            >
              {{ salvando ? 'Salvando...' : 'Salvar' }}
            </button>
          </footer>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.dev-page {
  max-width: 1100px;
  margin: 0 auto;
  padding: 0 1rem;
}
.header-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  flex-wrap: wrap;
}
.header-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}
.header-actions a.btn {
  text-decoration: none;
}
.error-msg {
  color: var(--danger, #dc2626);
  margin: 0.75rem 0;
}
.loading-card {
  padding: 1.5rem;
  text-align: center;
  color: var(--text-secondary);
}
.tabela-card {
  margin-top: 1rem;
  padding: 1rem;
  overflow-x: auto;
}
.dev-section-title {
  margin: 0 0 0.75rem;
}
.dev-section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  flex-wrap: wrap;
}
.dev-empty {
  color: var(--text-secondary);
  font-size: 0.85rem;
  padding: 0.5rem 0;
}
.cell-acoes {
  display: flex;
  gap: 0.5rem;
}
.dev-grid-3 {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.75rem;
  margin-top: 0.5rem;
}
.modal-overlay {
  position: fixed;
  inset: 0;
  z-index: 1100;
  background: rgba(0, 0, 0, 0.45);
  display: flex;
  align-items: flex-start;
  justify-content: center;
  overflow-y: auto;
  padding: 2rem 1rem;
}
.dev-modal {
  width: 100%;
  max-width: 720px;
  background: var(--card-bg);
  border-radius: 12px;
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.3);
}
.dev-modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--border-light);
}
.dev-modal-header h3 {
  margin: 0;
}
.close-btn {
  background: none;
  border: none;
  cursor: pointer;
  font-size: 1.1rem;
  color: var(--text-secondary);
}
.dev-modal-body {
  padding: 1.25rem;
  max-height: 70vh;
  overflow-y: auto;
}
.dev-modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 1rem 1.25rem;
  border-top: 1px solid var(--border-light);
}
.field-hint {
  font-size: 0.85rem;
  color: var(--text-secondary);
  margin-top: 0.5rem;
}
@media (max-width: 640px) {
  .dev-grid-3 {
    grid-template-columns: 1fr;
  }
}
</style>
