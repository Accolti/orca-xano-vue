<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import {
  listarMateriaisDev,
  listarLinhasDev,
  listarTiposDev,
  listarNiveisDev,
  listarBordasDev,
  salvarLinha,
  salvarTipo,
  salvarNivel,
  salvarBorda,
} from '@/services/catalogoAdminApi'
import DevNav from '@/components/DevNav.vue'

type Aba = 'linhas' | 'tipos' | 'niveis' | 'bordas'

interface MaterialDev {
  id: number
  nome: string
  ativo?: boolean
}

interface LinhaDev {
  id: number
  nome: string
  material_id: number | null
  material_nome?: string | null
  created_at?: string
}

interface TipoDev {
  id: number
  nome: string
  material_id: number | null
  material_nome?: string | null
  order?: number | null
  created_at?: string
}

interface NivelDev {
  id: number
  nome: string
  descricao?: string | null
  material_id: number | null
  linha_id: number | null
  tipo_id: number | null
  material_nome?: string | null
  linha_nome?: string | null
  tipo_nome?: string | null
  created_at?: string
}

interface BordaDev {
  id: number
  nome: string
  obs?: string | null
  material_id: number | null
  material_nome?: string | null
  valor?: number | null
  unidade?: string | null
  ativo: boolean
  created_at?: string
}

const ABA_TITULOS: Record<Aba, string> = {
  linhas: 'Linhas',
  tipos: 'Tipos',
  niveis: 'Níveis',
  bordas: 'Bordas',
}

const abaAtiva = ref<Aba>('linhas')
const materiais = ref<MaterialDev[]>([])
const linhas = ref<LinhaDev[]>([])
const tipos = ref<TipoDev[]>([])
const niveis = ref<NivelDev[]>([])
const bordas = ref<BordaDev[]>([])

const loading = ref(false)
const erroMsg = ref('')
const salvando = ref(false)
const termoBusca = ref('')
const termoAplicado = ref('')

const formOpen = ref(false)
const editandoId = ref<number | null>(null)

const form = ref({
  nome: '',
  descricao: '',
  material_id: null as number | null,
  linha_id: null as number | null,
  tipo_id: null as number | null,
  order: 0,
  obs: '',
  valor: 0,
  unidade: 'M2',
  ativo: true,
})

const linhasDoMaterial = computed(() =>
  linhas.value.filter((l) => !form.value.material_id || l.material_id === form.value.material_id),
)
const tiposDoMaterial = computed(() =>
  tipos.value.filter((t) => !form.value.material_id || t.material_id === form.value.material_id),
)

watch(
  () => form.value.material_id,
  () => {
    form.value.linha_id = null
    form.value.tipo_id = null
  },
)

function nomeMaterial(id: number | null | undefined): string {
  if (!id) return '—'
  return materiais.value.find((m) => m.id === id)?.nome || `#${id}`
}

const listaAtual = computed<any[]>(() => {
  if (abaAtiva.value === 'linhas') return linhas.value
  if (abaAtiva.value === 'tipos') return tipos.value
  if (abaAtiva.value === 'niveis') return niveis.value
  return bordas.value
})

const resultadosVisiveis = computed(() => {
  const termo = termoAplicado.value.trim().toLowerCase()
  return listaAtual.value.filter((item: any) => {
    if (!termo) return true
    return (
      String(item.id).includes(termo) ||
      (item.nome || '').toLowerCase().includes(termo) ||
      (item.material_nome || '').toLowerCase().includes(termo)
    )
  })
})

function buscar() {
  termoAplicado.value = termoBusca.value
}

function limparBusca() {
  termoBusca.value = ''
  termoAplicado.value = ''
}

async function carregarMateriais() {
  try {
    materiais.value = (await listarMateriaisDev()) ?? []
  } catch {
    /* dropdown opcional */
  }
}

async function carregarListas() {
  loading.value = true
  erroMsg.value = ''
  try {
    const [l, t, n, b] = await Promise.all([
      listarLinhasDev(),
      listarTiposDev(),
      listarNiveisDev(),
      listarBordasDev(),
    ])
    linhas.value = l ?? []
    tipos.value = t ?? []
    niveis.value = n ?? []
    bordas.value = b ?? []
  } catch (err) {
    erroMsg.value = (err as Error)?.message || 'Erro ao listar dados'
  } finally {
    loading.value = false
  }
}

function abrirNovo() {
  editandoId.value = null
  form.value = {
    nome: '',
    descricao: '',
    material_id: null,
    linha_id: null,
    tipo_id: null,
    order: 0,
    obs: '',
    valor: 0,
    unidade: 'M2',
    ativo: true,
  }
  formOpen.value = true
}

function abrirEdicao(item: any) {
  editandoId.value = item.id
  form.value = {
    nome: item.nome || '',
    descricao: item.descricao ?? '',
    material_id: item.material_id ?? null,
    linha_id: item.linha_id ?? null,
    tipo_id: item.tipo_id ?? null,
    order: item.order ?? 0,
    obs: item.obs ?? '',
    valor: item.valor ?? 0,
    unidade: item.unidade ?? 'M2',
    ativo: item.ativo !== false,
  }
  formOpen.value = true
}

function limparCacheMateriais() {
  localStorage.removeItem('orca_catalogo_materiais_cache')
}

async function salvar() {
  if (!form.value.nome.trim()) {
    erroMsg.value = 'Informe o nome.'
    return
  }
  salvando.value = true
  erroMsg.value = ''
  try {
    const base = {
      nome: form.value.nome,
      material_id: form.value.material_id,
    }
    if (abaAtiva.value === 'linhas') {
      await salvarLinha({ ...base, linha_id: editandoId.value ?? null })
    } else if (abaAtiva.value === 'tipos') {
      await salvarTipo({ ...base, tipo_id: editandoId.value ?? null, order: form.value.order })
    } else if (abaAtiva.value === 'niveis') {
      await salvarNivel({
        ...base,
        nivel_id: editandoId.value ?? null,
        descricao: form.value.descricao,
        linha_id: form.value.linha_id,
        tipo_id: form.value.tipo_id,
      })
    } else {
      await salvarBorda({
        ...base,
        borda_id: editandoId.value ?? null,
        obs: form.value.obs,
        valor: form.value.valor,
        unidade: form.value.unidade,
        ativo: form.value.ativo,
      })
    }
    limparCacheMateriais()
    formOpen.value = false
    await carregarListas()
  } catch (err) {
    erroMsg.value = (err as Error)?.message || 'Erro ao salvar'
  } finally {
    salvando.value = false
  }
}

async function excluir(item: any) {
  if (!window.confirm(`Excluir "${item.nome}" (#${item.id})?`)) return
  salvando.value = true
  erroMsg.value = ''
  try {
    if (abaAtiva.value === 'linhas') {
      await salvarLinha({ linha_id: item.id, excluir: true })
    } else if (abaAtiva.value === 'tipos') {
      await salvarTipo({ tipo_id: item.id, excluir: true })
    } else if (abaAtiva.value === 'niveis') {
      await salvarNivel({ nivel_id: item.id, excluir: true })
    } else {
      await salvarBorda({ borda_id: item.id, excluir: true })
    }
    limparCacheMateriais()
    await carregarListas()
  } catch (err) {
    erroMsg.value = (err as Error)?.message || 'Erro ao excluir'
  } finally {
    salvando.value = false
  }
}

function trocarAba(aba: Aba) {
  abaAtiva.value = aba
  termoBusca.value = ''
  termoAplicado.value = ''
  erroMsg.value = ''
}

onMounted(async () => {
  await carregarMateriais()
  await carregarListas()
})
</script>

<template>
  <div class="dev-page">
    <DevNav />
    <section class="card header-card">
      <div class="header-top">
        <h2>Dev — Estrutura do Catálogo</h2>
        <div class="header-actions">
          <button class="btn btn-outline btn-sm" @click="carregarListas">Recarregar</button>
          <button class="btn btn-primary btn-sm" @click="abrirNovo">+ Novo(a) {{ ABA_TITULOS[abaAtiva] }}</button>
        </div>
      </div>
      <div class="dev-tabs" role="tablist">
        <button
          v-for="(titulo, key) in ABA_TITULOS"
          :key="key"
          class="dev-tab"
          :class="{ 'dev-tab-active': abaAtiva === key }"
          @click="trocarAba(key as Aba)"
        >
          {{ titulo }}
        </button>
      </div>
      <div class="filtros-row">
        <div class="field busca-field">
          <label>Buscar (ID, nome, material)</label>
          <div class="busca-grupo">
            <input v-model="termoBusca" placeholder="Digite ID ou parte do nome..." @keyup.enter="buscar" />
            <button class="btn btn-primary btn-sm" @click="buscar">Buscar</button>
            <button v-if="termoBusca" class="btn btn-outline btn-sm" @click="limparBusca">Limpar</button>
          </div>
        </div>
      </div>
    </section>

    <p v-if="erroMsg" class="error-msg">{{ erroMsg }}</p>

    <section v-if="loading" class="card loading-card"><p>Carregando...</p></section>

    <section v-else-if="resultadosVisiveis.length" class="card tabela-card">
      <div class="tabela-orcamentos-wrap">
        <table class="tabela-orcamentos">
          <thead>
            <tr v-if="abaAtiva === 'linhas'">
              <th>ID</th>
              <th>Nome</th>
              <th>Material</th>
              <th>Ações</th>
            </tr>
            <tr v-else-if="abaAtiva === 'tipos'">
              <th>ID</th>
              <th>Nome</th>
              <th>Material</th>
              <th>Ordem</th>
              <th>Ações</th>
            </tr>
            <tr v-else-if="abaAtiva === 'niveis'">
              <th>ID</th>
              <th>Nome</th>
              <th>Descrição</th>
              <th>Material</th>
              <th>Linha</th>
              <th>Tipo</th>
              <th>Ações</th>
            </tr>
            <tr v-else>
              <th>ID</th>
              <th>Nome</th>
              <th>Material</th>
              <th>Valor</th>
              <th>Unid.</th>
              <th>Status</th>
              <th>Ações</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in resultadosVisiveis" :key="item.id">
              <template v-if="abaAtiva === 'linhas'">
                <td class="cell-cod">{{ item.id }}</td>
                <td class="cell-cliente">{{ item.nome }}</td>
                <td>{{ item.material_nome || nomeMaterial(item.material_id) }}</td>
              </template>
              <template v-else-if="abaAtiva === 'tipos'">
                <td class="cell-cod">{{ item.id }}</td>
                <td class="cell-cliente">{{ item.nome }}</td>
                <td>{{ item.material_nome || nomeMaterial(item.material_id) }}</td>
                <td>{{ item.order ?? 0 }}</td>
              </template>
              <template v-else-if="abaAtiva === 'niveis'">
                <td class="cell-cod">{{ item.id }}</td>
                <td class="cell-cliente">{{ item.nome }}</td>
                <td>{{ item.descricao || '-' }}</td>
                <td>{{ item.material_nome || nomeMaterial(item.material_id) }}</td>
                <td>{{ item.linha_nome || (item.linha_id ? '#' + item.linha_id : '—') }}</td>
                <td>{{ item.tipo_nome || (item.tipo_id ? '#' + item.tipo_id : '—') }}</td>
              </template>
              <template v-else>
                <td class="cell-cod">{{ item.id }}</td>
                <td class="cell-cliente">{{ item.nome }}</td>
                <td>{{ item.material_nome || nomeMaterial(item.material_id) }}</td>
                <td>{{ item.valor ?? 0 }}</td>
                <td>{{ item.unidade || '-' }}</td>
                <td>
                  <span :class="['badge-status', item.ativo ? 'badge-aprovado' : 'badge-recusado']">
                    {{ item.ativo ? 'Ativo' : 'Inativo' }}
                  </span>
                </td>
              </template>
              <td class="cell-acoes">
                <button class="btn-icon" title="Editar" @click="abrirEdicao(item)">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M17 3a2.8 2.8 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z" />
                  </svg>
                </button>
                <button class="btn-icon" title="Excluir" @click="excluir(item)">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
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

    <section v-else class="card loading-card"><p>Nenhum registro encontrado.</p></section>

    <!-- Form -->
    <Teleport to="body">
      <div v-if="formOpen" class="modal-overlay">
        <div class="dev-modal">
          <header class="dev-modal-header">
            <h3>
              {{ editandoId ? `Editar ${ABA_TITULOS[abaAtiva]} #${editandoId}` : `Novo(a) ${ABA_TITULOS[abaAtiva]}` }}
            </h3>
            <button class="close-btn" @click="formOpen = false">✕</button>
          </header>

          <div class="dev-modal-body">
            <div class="field">
              <label>Nome *</label>
              <input v-model="form.nome" type="text" />
            </div>

            <div v-if="abaAtiva === 'niveis'" class="field">
              <label>Descrição</label>
              <input v-model="form.descricao" type="text" />
            </div>

            <div v-if="abaAtiva === 'bordas'" class="field">
              <label>Observação</label>
              <input v-model="form.obs" type="text" />
            </div>

            <div class="dev-grid-3">
              <div class="field">
                <label>Material</label>
                <select v-model="form.material_id">
                  <option :value="null">—</option>
                  <option v-for="m in materiais" :key="m.id" :value="m.id">{{ m.nome }}</option>
                </select>
              </div>

              <div v-if="abaAtiva === 'niveis'" class="field">
                <label>Linha</label>
                <select v-model="form.linha_id">
                  <option :value="null">—</option>
                  <option v-for="l in linhasDoMaterial" :key="l.id" :value="l.id">{{ l.nome }}</option>
                </select>
              </div>

              <div v-if="abaAtiva === 'niveis'" class="field">
                <label>Tipo</label>
                <select v-model="form.tipo_id">
                  <option :value="null">—</option>
                  <option v-for="t in tiposDoMaterial" :key="t.id" :value="t.id">{{ t.nome }}</option>
                </select>
              </div>

              <div v-if="abaAtiva === 'tipos'" class="field">
                <label>Ordem</label>
                <input v-model.number="form.order" type="number" step="1" />
              </div>

              <template v-if="abaAtiva === 'bordas'">
                <div class="field">
                  <label>Valor</label>
                  <input v-model.number="form.valor" type="number" step="0.01" />
                </div>
                <div class="field">
                  <label>Unidade</label>
                  <input v-model="form.unidade" type="text" placeholder="M2 / ML" />
                </div>
                <div class="field">
                  <label class="checkbox-line">
                    <input v-model="form.ativo" type="checkbox" />
                    Ativo
                  </label>
                </div>
              </template>
            </div>
          </div>

          <footer class="dev-modal-footer">
            <button class="btn btn-outline" @click="formOpen = false">Cancelar</button>
            <button class="btn btn-primary" :disabled="salvando || !form.nome" @click="salvar">
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
.dev-tabs {
  display: flex;
  gap: 0.4rem;
  flex-wrap: wrap;
  margin-top: 0.75rem;
}
.dev-tab {
  padding: 0.4rem 0.9rem;
  border-radius: 8px;
  border: 1px solid var(--border-light);
  background: var(--bg-subtle, #f3f4f6);
  color: var(--text-secondary, #4b5563);
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
}
.dev-tab-active {
  background: var(--primary, #3366cc);
  color: #fff;
  border-color: var(--primary, #3366cc);
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
  max-width: 640px;
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
