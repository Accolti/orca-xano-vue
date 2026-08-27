<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { xano } from '@/services/xano'
import DevNav from '@/components/DevNav.vue'

interface MaterialDev {
  id: number
  nome: string
  Ordenacao: number | null
  created_at?: string
  ativo: boolean
  descricao?: string | null
  garantia?: number | null
  ncm?: string | null
  imp?: number | null
  ipi?: number | null
  peso?: number | null
  regra_fiscal_id?: number | null
  st?: boolean | null
  mva_padrao?: number | null
  aliq_st_interna?: number | null
  nac?: boolean | null
  Observacao?: string | null
  importado?: boolean | null
  organizacao_id?: number | null
  material_pai_id?: number | null
}

const materiais = ref<MaterialDev[]>([])
const organizacoes = ref<{ id: number; nome: string }[]>([])
const loading = ref(false)
const erroMsg = ref('')
const salvando = ref(false)
const termoBusca = ref('')
const termoAplicado = ref('')
const filtroAtivo = ref<'todos' | 'ativos' | 'inativos'>('todos')

const formOpen = ref(false)
const editandoId = ref<number | null>(null)

const form = ref({
  nome: '',
  Ordenacao: null as number | null,
  material_pai_id: null as number | null,
  ativo: true,
  descricao: '',
  garantia: null as number | null,
  ncm: '',
  imp: null as number | null,
  ipi: null as number | null,
  peso: null as number | null,
  regra_fiscal_id: 1,
  st: false,
  mva_padrao: null as number | null,
  aliq_st_interna: null as number | null,
  nac: false,
  Observacao: '',
  importado: false,
  organizacao_id: null as number | null,
})

const resultadosVisiveis = computed(() => {
  const termo = termoAplicado.value.trim().toLowerCase()
  return materiais.value.filter((m) => {
    if (filtroAtivo.value === 'ativos' && !m.ativo) return false
    if (filtroAtivo.value === 'inativos' && m.ativo) return false
    if (!termo) return true
    return (
      String(m.id).includes(termo) ||
      (m.nome || '').toLowerCase().includes(termo) ||
      (m.descricao || '').toLowerCase().includes(termo) ||
      (m.ncm || '').toLowerCase().includes(termo)
    )
  })
})

function nomeMaterialPai(id: number | null | undefined): string {
  if (!id) return '—'
  const m = materiais.value.find((x) => x.id === id)
  return m?.nome || `#${id}`
}

function nomeOrganizacao(id: number | null | undefined): string {
  if (!id) return '—'
  const o = organizacoes.value.find((x) => x.id === id)
  return o?.nome || `#${id}`
}

function buscar() {
  termoAplicado.value = termoBusca.value
}

function limparBusca() {
  termoBusca.value = ''
  termoAplicado.value = ''
}

async function carregarLista() {
  loading.value = true
  erroMsg.value = ''
  try {
    const resp = await xano.get('/api:-qqRIakp/materiais_dev_lista')
    materiais.value = (resp.getBody() as MaterialDev[]) ?? []
  } catch (err: any) {
    erroMsg.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao listar materiais'
  } finally {
    loading.value = false
  }
}

let dropdownsCarregados = false
async function carregarOrganizacoes() {
  if (dropdownsCarregados) return
  dropdownsCarregados = true
  try {
    const o = await xano.get('/api:-qqRIakp/organizacao')
    organizacoes.value = (o.getBody() as any[]) ?? []
  } catch {
    dropdownsCarregados = false
  }
}

function abrirNovo() {
  editandoId.value = null
  form.value = {
    nome: '',
    Ordenacao: null,
    material_pai_id: null,
    ativo: true,
    descricao: '',
    garantia: null,
    ncm: '',
    imp: null,
    ipi: null,
    peso: null,
    regra_fiscal_id: 1,
    st: false,
    mva_padrao: null,
    aliq_st_interna: null,
    nac: false,
    Observacao: '',
    importado: false,
    organizacao_id: null,
  }
  formOpen.value = true
  carregarOrganizacoes()
}

function abrirEdicao(m: MaterialDev) {
  editandoId.value = m.id
  form.value = {
    nome: m.nome || '',
    Ordenacao: m.Ordenacao ?? null,
    material_pai_id: m.material_pai_id ?? null,
    ativo: m.ativo !== false,
    descricao: m.descricao ?? '',
    garantia: m.garantia ?? null,
    ncm: m.ncm ?? '',
    imp: m.imp ?? null,
    ipi: m.ipi ?? null,
    peso: m.peso ?? null,
    regra_fiscal_id: m.regra_fiscal_id ?? 1,
    st: m.st === true,
    mva_padrao: m.mva_padrao ?? null,
    aliq_st_interna: m.aliq_st_interna ?? null,
    nac: m.nac === true,
    Observacao: m.Observacao ?? '',
    importado: m.importado === true,
    organizacao_id: m.organizacao_id ?? null,
  }
  formOpen.value = true
  carregarOrganizacoes()
}

async function salvar() {
  salvando.value = true
  erroMsg.value = ''
  try {
    const payload = {
      material_id: editandoId.value ?? null,
      ...form.value,
    }
    await xano.post('/api:-qqRIakp/material_cadastrar', payload)
    // Limpa o cache do catálogo para o app rebaixar materiais na próxima carga
    localStorage.removeItem('orca_catalogo_materiais_cache')
    formOpen.value = false
    await carregarLista()
  } catch (err: any) {
    erroMsg.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao salvar material'
  } finally {
    salvando.value = false
  }
}

async function alternarAtivo(m: MaterialDev) {
  try {
    await xano.post('/api:-qqRIakp/material_cadastrar', {
      material_id: m.id,
      nome: m.nome,
      Ordenacao: m.Ordenacao ?? null,
      material_pai_id: m.material_pai_id ?? null,
      ativo: !(m.ativo !== false),
      descricao: m.descricao ?? '',
      garantia: m.garantia ?? null,
      ncm: m.ncm ?? '',
      imp: m.imp ?? null,
      ipi: m.ipi ?? null,
      peso: m.peso ?? null,
      regra_fiscal_id: m.regra_fiscal_id ?? 1,
      st: m.st === true,
      mva_padrao: m.mva_padrao ?? null,
      aliq_st_interna: m.aliq_st_interna ?? null,
      nac: m.nac === true,
      Observacao: m.Observacao ?? '',
      importado: m.importado === true,
      organizacao_id: m.organizacao_id ?? null,
    })
    localStorage.removeItem('orca_catalogo_materiais_cache')
    await carregarLista()
  } catch (err: any) {
    erroMsg.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao alterar material'
  }
}

onMounted(async () => {
  await carregarLista()
})
</script>

<template>
  <div class="dev-page">
    <DevNav />
    <section class="card header-card">
      <div class="header-top">
        <h2>Dev — Cadastro de Materiais</h2>
        <div class="header-actions">
          <button class="btn btn-outline btn-sm" @click="carregarLista">Recarregar</button>
          <button class="btn btn-primary btn-sm" @click="abrirNovo">+ Novo Material</button>
        </div>
      </div>
      <div class="filtros-row">
        <div class="field busca-field">
          <label>Buscar (ID, nome, descrição, NCM)</label>
          <div class="busca-grupo">
            <input
              v-model="termoBusca"
              placeholder="Digite ID ou parte do nome/descrição..."
              @keyup.enter="buscar"
            />
            <button class="btn btn-primary btn-sm" @click="buscar">Buscar</button>
            <button v-if="termoBusca" class="btn btn-outline btn-sm" @click="limparBusca">
              Limpar
            </button>
          </div>
        </div>
        <div class="field filtro-status">
          <label>Status</label>
          <select v-model="filtroAtivo">
            <option value="todos">Todos</option>
            <option value="ativos">Ativos</option>
            <option value="inativos">Inativos</option>
          </select>
        </div>
      </div>
    </section>

    <p v-if="erroMsg" class="error-msg">{{ erroMsg }}</p>

    <section v-if="loading" class="card loading-card"><p>Carregando...</p></section>

    <section v-else-if="resultadosVisiveis.length" class="card tabela-card">
      <div class="tabela-orcamentos-wrap">
        <table class="tabela-orcamentos">
          <thead>
            <tr>
              <th>ID</th>
              <th>Nome</th>
              <th>Descrição</th>
              <th>NCM</th>
              <th>IPI%</th>
              <th>Ord.</th>
              <th>Material Pai</th>
              <th>Organização</th>
              <th>Status</th>
              <th>Ações</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="m in resultadosVisiveis" :key="m.id">
              <td class="cell-cod">{{ m.id }}</td>
              <td class="cell-cliente">{{ m.nome }}</td>
              <td>{{ m.descricao || '-' }}</td>
              <td>{{ m.ncm || '-' }}</td>
              <td>{{ m.ipi ?? '-' }}</td>
              <td>{{ m.Ordenacao ?? '-' }}</td>
              <td>{{ nomeMaterialPai(m.material_pai_id) }}</td>
              <td>{{ nomeOrganizacao(m.organizacao_id) }}</td>
              <td>
                <span :class="['badge-status', m.ativo ? 'badge-aprovado' : 'badge-recusado']">
                  {{ m.ativo ? 'Ativo' : 'Inativo' }}
                </span>
              </td>
              <td class="cell-acoes">
                <button class="btn-icon" title="Editar" @click="abrirEdicao(m)">
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
                <button
                  class="btn-icon"
                  :title="m.ativo ? 'Desativar' : 'Ativar'"
                  @click="alternarAtivo(m)"
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
                    <rect x="1" y="4" width="22" height="16" rx="2" />
                    <line x1="1" y1="10" x2="23" y2="10" />
                  </svg>
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <section v-else class="card loading-card"><p>Nenhum material encontrado.</p></section>

    <!-- Form de material -->
    <Teleport to="body">
      <div v-if="formOpen" class="modal-overlay">
        <div class="dev-modal">
          <header class="dev-modal-header">
            <h3>{{ editandoId ? `Editar Material #${editandoId}` : 'Novo Material' }}</h3>
            <button class="close-btn" @click="formOpen = false">✕</button>
          </header>

          <div class="dev-modal-body">
            <div class="dev-grid-3">
              <div class="field">
                <label>Nome *</label>
                <input v-model="form.nome" type="text" placeholder="ex.: Vinil" />
              </div>
              <div class="field">
                <label>Ordenação</label>
                <input v-model.number="form.Ordenacao" type="number" step="1" />
              </div>
              <div class="field">
                <label class="checkbox-line">
                  <input v-model="form.ativo" type="checkbox" />
                  Ativo
                </label>
              </div>
            </div>

            <div class="field">
              <label>Descrição</label>
              <input v-model="form.descricao" type="text" />
            </div>

            <div class="dev-grid-3">
              <div class="field">
                <label>Material Pai</label>
                <select v-model="form.material_pai_id">
                  <option :value="null">—</option>
                  <option v-for="m in materiais" :key="m.id" :value="m.id">{{ m.nome }}</option>
                </select>
              </div>
              <div class="field">
                <label>Organização</label>
                <select v-model="form.organizacao_id">
                  <option :value="null">—</option>
                  <option v-for="o in organizacoes" :key="o.id" :value="o.id">
                    {{ o.nome }}
                  </option>
                </select>
              </div>
              <div class="field">
                <label>Regra Fiscal</label>
                <input v-model.number="form.regra_fiscal_id" type="number" step="1" min="1" />
              </div>
            </div>

            <div class="dev-grid-3">
              <div class="field">
                <label>NCM</label>
                <input v-model="form.ncm" type="text" placeholder="ex.: 39259090" />
              </div>
              <div class="field">
                <label>Garantia (meses)</label>
                <input v-model.number="form.garantia" type="number" step="1" min="0" />
              </div>
              <div class="field">
                <label>Peso</label>
                <input v-model.number="form.peso" type="number" step="0.01" />
              </div>
            </div>

            <div class="dev-grid-3">
              <div class="field">
                <label>IPI (%)</label>
                <input v-model.number="form.ipi" type="number" step="0.01" />
              </div>
              <div class="field">
                <label>IMP (%)</label>
                <input v-model.number="form.imp" type="number" step="0.01" />
              </div>
              <div class="field">
                <label>MVA Padrão (%)</label>
                <input v-model.number="form.mva_padrao" type="number" step="0.01" />
              </div>
            </div>

            <div class="dev-grid-3">
              <div class="field">
                <label>Alíq. ST Interna (%)</label>
                <input v-model.number="form.aliq_st_interna" type="number" step="0.01" />
              </div>
              <div class="field">
                <label class="checkbox-line">
                  <input v-model="form.st" type="checkbox" />
                  ST (substituição)
                </label>
              </div>
              <div class="field">
                <label class="checkbox-line">
                  <input v-model="form.importado" type="checkbox" />
                  Importado
                </label>
              </div>
            </div>

            <div class="dev-grid-3">
              <div class="field">
                <label class="checkbox-line">
                  <input v-model="form.nac" type="checkbox" />
                  Nacional
                </label>
              </div>
              <div class="field">
                <label>Observação</label>
                <input v-model="form.Observacao" type="text" />
              </div>
            </div>
          </div>

          <footer class="dev-modal-footer">
            <button class="btn btn-outline" @click="formOpen = false">Cancelar</button>
            <button class="btn btn-primary" :disabled="salvando || !form.nome" @click="salvar">
              {{ salvando ? 'Salvando...' : 'Salvar Material' }}
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
.filtros-row {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
  align-items: flex-end;
  margin-top: 0.75rem;
}
.busca-field {
  flex: 1;
  min-width: 220px;
}
.busca-grupo {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}
.busca-grupo input {
  flex: 1;
}
.filtro-status {
  width: 180px;
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
  overflow-x: auto;
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
.checkbox-line {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-weight: 500;
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
  max-width: 760px;
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
@media (max-width: 640px) {
  .dev-grid-3 {
    grid-template-columns: 1fr;
  }
}
</style>
