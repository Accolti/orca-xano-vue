<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { xano } from '@/services/xano'
import { useCatalogoStore } from '@/stores/catalogo'
import type { Linha, Tipo, Nivel } from '@/types/orcamento'
import DevNav from '@/components/DevNav.vue'

interface VariacaoDev {
  id?: number | null
  detalhe_id?: number | null
  tipo_variacao_id: number | null
  comp: number
  larg: number
  modelo_id: number | null
  LxC: string
  qtd_kit: number
  valor_custo: number
  cor_id: number | null
  fator_de_corte: number
  fator_de_corte_id: number | null
  ordem: number
  ativo: boolean
}

interface ProdutoDev {
  id: number
  material_id: number
  classificacao_id: number | null
  linha_id: number | null
  tipo_id: number | null
  nivel_id: number | null
  valor: number
  com_medida_exata: boolean
  porcentagem_acrescimo: number
  Unidade: string
  Base_de_Calculo: string
  detalhe_id: number
  fator_de_corte_id: number | null
  ativo: boolean
  descricao: string
  material_nome: string
  linha_nome: string | null
  tipo_nome: string | null
  nivel_nome: string | null
  _variacao: VariacaoDev[]
}

const catalogo = useCatalogoStore()

const produtos = ref<ProdutoDev[]>([])
const loading = ref(false)
const erroMsg = ref('')
const termoBusca = ref('')
const termoAplicado = ref('')
const filtroAtivo = ref<'todos' | 'ativos' | 'inativos'>('todos')
const salvando = ref(false)

// Materiais completos (ativos + inativos) para o dropdown — o catálogo filtra ativos,
// então produtos de materiais inativos não apareceriam no select.
const materiaisCompletos = ref<{ id: number; nome: string; Ordenacao: number; ativo: boolean }[]>(
  [],
)

const formOpen = ref(false)
const editandoId = ref<number | null>(null)

const form = ref({
  material_id: null as number | null,
  classificacao_id: null as number | null,
  linha_id: null as number | null,
  tipo_id: null as number | null,
  nivel_id: null as number | null,
  valor: 0,
  Unidade: 'M2' as string,
  Base_de_Calculo: 'M2' as string,
  tipo_composto: '' as string,
  com_medida_exata: false,
  porcentagem_acrescimo: 0,
  ativo: true,
  fator_de_corte_id: null as number | null,
  variacoes: [] as VariacaoDev[],
})

const classificacoes = ref<{ id: number; nome: string }[]>([])
const tiposVariacao = ref<{ id: number; Descricao: string }[]>([])
const cores = ref<{ id: number; Descricao: string }[]>([])
const modelos = ref<{ id: number; Descricao: string }[]>([])
const fatoresCorte = ref<
  {
    id: number
    nome: string
    valor: number[]
    larg_base: number
    comp_corte: number
    modo_corte: string
  }[]
>([])

const resultadosVisiveis = computed(() => {
  const termo = termoAplicado.value.trim().toLowerCase()
  return produtos.value.filter((p) => {
    if (filtroAtivo.value === 'ativos' && !p.ativo) return false
    if (filtroAtivo.value === 'inativos' && p.ativo) return false
    if (!termo) return true
    return (
      String(p.id).includes(termo) ||
      (p.descricao || '').toLowerCase().includes(termo) ||
      (p.material_nome || '').toLowerCase().includes(termo)
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

function nomeFatorCorte(id: number | null | undefined): string {
  if (!id) return '—'
  const f = fatoresCorte.value.find((x) => x.id === id)
  return f?.nome || `#${id}`
}

async function carregarLista() {
  loading.value = true
  erroMsg.value = ''
  try {
    const resp = await xano.get('/api:-qqRIakp/produtos_dev_lista')
    produtos.value = (resp.getBody() as ProdutoDev[]) ?? []
  } catch (err: any) {
    erroMsg.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao listar produtos'
  } finally {
    loading.value = false
  }
}

async function carregarMateriaisCompletos() {
  if (materiaisCompletos.value.length) return
  try {
    const resp = await xano.get('/api:-qqRIakp/materiais_dev_lista')
    materiaisCompletos.value = ((resp.getBody() as any[]) ?? []).map((m) => ({
      id: m.id,
      nome: m.nome || `#${m.id}`,
      Ordenacao: m.Ordenacao ?? 0,
      ativo: m.ativo !== false,
    }))
  } catch {
    // fallback silencioso: catálogo ativo continua disponível
  }
}

let dropdownsCarregados = false
async function carregarDropdowns() {
  if (dropdownsCarregados) return
  dropdownsCarregados = true
  try {
    const [c, tv, cor, mod, fc] = await Promise.all([
      xano.get('/api:-qqRIakp/classificacao'),
      xano.get('/api:-qqRIakp/tipo_variacao'),
      xano.get('/api:-qqRIakp/cor'),
      xano.get('/api:-qqRIakp/modelo'),
      xano.get('/api:-qqRIakp/fatordecorte'),
    ])
    classificacoes.value = (c.getBody() as any[]) ?? []
    tiposVariacao.value = (tv.getBody() as any[]) ?? []
    cores.value = (cor.getBody() as any[]) ?? []
    modelos.value = (mod.getBody() as any[]) ?? []
    fatoresCorte.value = (fc.getBody() as any[]) ?? []
  } catch {
    dropdownsCarregados = false
  }
}

function abrirNovo() {
  editandoId.value = null
  form.value = {
    material_id: null,
    classificacao_id: null,
    linha_id: null,
    tipo_id: null,
    nivel_id: null,
    valor: 0,
    Unidade: 'M2',
    Base_de_Calculo: 'M2',
    tipo_composto: '',
    com_medida_exata: false,
    porcentagem_acrescimo: 0,
    ativo: true,
    fator_de_corte_id: null,
    variacoes: [],
  }
  formOpen.value = true
  carregarDropdowns()
}

function abrirEdicao(p: ProdutoDev) {
  editandoId.value = p.id
  form.value = {
    material_id: p.material_id,
    classificacao_id: p.classificacao_id ?? null,
    linha_id: p.linha_id ?? null,
    tipo_id: p.tipo_id ?? null,
    nivel_id: p.nivel_id ?? null,
    valor: p.valor ?? 0,
    Unidade: p.Unidade || 'M2',
    Base_de_Calculo: p.Base_de_Calculo || 'M2',
    tipo_composto: (p as any).tipo_composto ?? '',
    com_medida_exata: p.com_medida_exata === true,
    porcentagem_acrescimo: p.porcentagem_acrescimo ?? 0,
    ativo: p.ativo !== false,
    fator_de_corte_id: p.fator_de_corte_id ?? null,
    variacoes: (p._variacao ?? []).map((v) => ({
      id: v.id,
      detalhe_id: v.detalhe_id,
      tipo_variacao_id: v.tipo_variacao_id ?? null,
      comp: v.comp ?? 0,
      larg: v.larg ?? 0,
      modelo_id: v.modelo_id ?? null,
      LxC: v.LxC ?? '',
      qtd_kit: v.qtd_kit ?? 1,
      valor_custo: v.valor_custo ?? 0,
      cor_id: v.cor_id ?? null,
      fator_de_corte: v.fator_de_corte ?? 0,
      fator_de_corte_id: v.fator_de_corte_id ?? null,
      ordem: v.ordem ?? 0,
      ativo: v.ativo !== false,
    })),
  }
  formOpen.value = true
  carregarDropdowns()
}

async function salvar() {
  salvando.value = true
  erroMsg.value = ''
  try {
    const payload = {
      produto_id: editandoId.value ?? null,
      ...form.value,
    }
    await xano.post('/api:-qqRIakp/produto_cadastrar', payload)
    // Limpa o cache do catálogo para o app rebaixar produtos na próxima carga
    localStorage.removeItem('orca_catalogo_produtos_cache')
    formOpen.value = false
    await carregarLista()
  } catch (err: any) {
    erroMsg.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao salvar produto'
  } finally {
    salvando.value = false
  }
}

async function alternarAtivo(p: ProdutoDev) {
  try {
    await xano.post('/api:-qqRIakp/produto_cadastrar', {
      produto_id: p.id,
      material_id: p.material_id,
      classificacao_id: p.classificacao_id ?? null,
      linha_id: p.linha_id ?? null,
      tipo_id: p.tipo_id ?? null,
      nivel_id: p.nivel_id ?? null,
      valor: p.valor ?? 0,
      Unidade: p.Unidade || 'M2',
      Base_de_Calculo: p.Base_de_Calculo || 'M2',
      tipo_composto: (p as any).tipo_composto ?? '',
      com_medida_exata: p.com_medida_exata === true,
      porcentagem_acrescimo: p.porcentagem_acrescimo ?? 0,
      ativo: !(p.ativo !== false),
      fator_de_corte_id: p.fator_de_corte_id ?? null,
      variacoes: (p._variacao ?? []).map((v) => ({ ...v })),
    })
    localStorage.removeItem('orca_catalogo_produtos_cache')
    await carregarLista()
  } catch (err: any) {
    erroMsg.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao alterar produto'
  }
}

function novaVariacao() {
  form.value.variacoes.push({
    id: null,
    detalhe_id: null,
    tipo_variacao_id: null,
    comp: 0,
    larg: 0,
    modelo_id: null,
    LxC: '',
    qtd_kit: 1,
    valor_custo: 0,
    cor_id: null,
    fator_de_corte: 0,
    fator_de_corte_id: null,
    ordem: form.value.variacoes.length + 1,
    ativo: true,
  })
}

function removerVariacao(idx: number) {
  form.value.variacoes.splice(idx, 1)
}

const linhasDoMaterial = computed(() =>
  catalogo.allLinhas.filter((l) => l.material_id === form.value.material_id),
)
const tiposDoMaterial = computed(() =>
  catalogo.allTipos.filter((t) => t.material_id === form.value.material_id),
)
const niveisDoMaterial = computed(() =>
  catalogo.allNiveis.filter((n) => n.material_id === form.value.material_id),
)

// Labels compostos: só o que diferencia a opção dentro do material selecionado.
function nomeLinha(l: Linha): string {
  const sufixo = l._material?.nome ? ` — ${l._material.nome}` : ''
  return `${l.nome}${sufixo}`
}
function nomeTipo(t: Tipo): string {
  const sufixo = t._material?.nome ? ` — ${t._material.nome}` : ''
  return `${t.nome}${sufixo}`
}
function nomeNivel(n: Nivel): string {
  const partes = [n._linha?.nome, n._tipo?.nome].filter(Boolean)
  const sufixo = partes.length ? ` — ${partes.join(' | ')}` : ''
  return `${n.nome}${sufixo}`
}

onMounted(async () => {
  await catalogo.fetchCatalogo()
  await Promise.all([carregarLista(), carregarMateriaisCompletos()])
})
</script>

<template>
  <div class="dev-page">
    <DevNav />
    <section class="card header-card">
      <div class="header-top">
        <h2>Dev — Cadastro de Produtos</h2>
        <div class="header-actions">
          <button class="btn btn-outline btn-sm" @click="carregarLista">Recarregar</button>
          <button class="btn btn-primary btn-sm" @click="abrirNovo">+ Novo Produto</button>
        </div>
      </div>
      <div class="filtros-row">
        <div class="field busca-field">
          <label>Buscar (ID, material, descrição)</label>
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
              <th>Descrição</th>
              <th>Material</th>
              <th>Linha</th>
              <th>Tipo</th>
              <th>Nível</th>
              <th>Custo</th>
              <th>Base</th>
              <th>Fator</th>
              <th>Variação</th>
              <th>Status</th>
              <th>Ações</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in resultadosVisiveis" :key="p.id">
              <td class="cell-cod">{{ p.id }}</td>
              <td class="cell-cliente">{{ p.descricao }}</td>
              <td>{{ p.material_nome }}</td>
              <td>{{ p.linha_nome || '-' }}</td>
              <td>{{ p.tipo_nome || '-' }}</td>
              <td>{{ p.nivel_nome || '-' }}</td>
              <td class="cell-valor">R$ {{ (Number(p.valor) || 0).toFixed(2) }}</td>
              <td>{{ p.Base_de_Calculo }}</td>
              <td>
                <span v-if="p.fator_de_corte_id" class="badge-status badge-aprovado">
                  {{ nomeFatorCorte(p.fator_de_corte_id) }}
                </span>
                <span v-else class="badge-status">—</span>
              </td>
              <td>
                <span :class="['badge-status', p._variacao?.length ? 'badge-aprovado' : '']">
                  {{ p._variacao?.length ? `${p._variacao.length} var.` : 'sem' }}
                </span>
              </td>
              <td>
                <span :class="['badge-status', p.ativo ? 'badge-aprovado' : 'badge-recusado']">
                  {{ p.ativo ? 'Ativo' : 'Inativo' }}
                </span>
              </td>
              <td class="cell-acoes">
                <button class="btn-icon" title="Editar" @click="abrirEdicao(p)">
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
                  :title="p.ativo ? 'Desativar' : 'Ativar'"
                  @click="alternarAtivo(p)"
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

    <section v-else class="card loading-card"><p>Nenhum produto encontrado.</p></section>

    <!-- Form de produto -->
    <Teleport to="body">
      <div v-if="formOpen" class="modal-overlay">
        <div class="dev-modal">
          <header class="dev-modal-header">
            <h3>{{ editandoId ? `Editar Produto #${editandoId}` : 'Novo Produto' }}</h3>
            <button class="close-btn" @click="formOpen = false">✕</button>
          </header>

          <div class="dev-modal-body">
            <div class="field">
              <label>Material *</label>
              <select v-model="form.material_id">
                <option :value="null">Selecione...</option>
                <option
                  v-for="m in materiaisCompletos.length ? materiaisCompletos : catalogo.materiais"
                  :key="m.id"
                  :value="m.id"
                >
                  {{ m.nome }}{{ m.ativo === false ? ' (inativo)' : '' }}
                </option>
              </select>
            </div>

            <div class="field">
              <label>Classificação</label>
              <select v-model="form.classificacao_id">
                <option :value="null">—</option>
                <option v-for="c in classificacoes" :key="c.id" :value="c.id">{{ c.nome }}</option>
              </select>
            </div>

            <div class="dev-grid-3">
              <div class="field">
                <label>Linha</label>
                <select v-model="form.linha_id">
                  <option :value="null">—</option>
                  <option v-for="l in linhasDoMaterial" :key="l.id" :value="l.id">
                    {{ nomeLinha(l) }}
                  </option>
                </select>
              </div>
              <div class="field">
                <label>Tipo</label>
                <select v-model="form.tipo_id">
                  <option :value="null">—</option>
                  <option v-for="t in tiposDoMaterial" :key="t.id" :value="t.id">
                    {{ nomeTipo(t) }}
                  </option>
                </select>
              </div>
              <div class="field">
                <label>Nível-T</label>
                <select v-model="form.nivel_id">
                  <option :value="null">—</option>
                  <option v-for="n in niveisDoMaterial" :key="n.id" :value="n.id">
                    {{ nomeNivel(n) }}
                  </option>
                </select>
              </div>
            </div>

            <div class="dev-grid-3">
              <div class="field">
                <label>Custo matéria-prima (R$)</label>
                <input v-model.number="form.valor" type="number" step="0.01" />
              </div>
              <div class="field">
                <label>Unidade</label>
                <select v-model="form.Unidade">
                  <option value="M2">M2</option>
                  <option value="ML">ML</option>
                  <option value="Und">Und</option>
                  <option value="Kit">Kit</option>
                </select>
              </div>
              <div class="field">
                <label>Base de Cálculo</label>
                <select v-model="form.Base_de_Calculo">
                  <option value="M2">M2</option>
                  <option value="ML">ML</option>
                  <option value="KIT">KIT</option>
                  <option value="UND">UND</option>
                  <option value="COMPOSTO">COMPOSTO</option>
                </select>
              </div>
              <div class="field">
                <label>Tipo Composto (se COMPOSTO)</label>
                <input v-model="form.tipo_composto" type="text" placeholder="ex.: playkap" />
              </div>
            </div>

            <div class="dev-grid-3">
              <div class="field">
                <label class="checkbox-line">
                  <input v-model="form.com_medida_exata" type="checkbox" />
                  Medida exata
                </label>
              </div>
              <div class="field">
                <label>Acréscimo (%)</label>
                <input
                  v-model.number="form.porcentagem_acrescimo"
                  type="number"
                  step="0.01"
                  min="0"
                />
              </div>
              <div class="field">
                <label class="checkbox-line">
                  <input v-model="form.ativo" type="checkbox" />
                  Ativo
                </label>
              </div>
            </div>

            <div class="field">
              <label>Fator de Corte (fixo — prioridade 1 no M2)</label>
              <select v-model="form.fator_de_corte_id">
                <option :value="null">— (usar Tipo_Fator material+linha+borda)</option>
                <option v-for="f in fatoresCorte" :key="f.id" :value="f.id">
                  {{ f.nome }}
                  {{
                    f.modo_corte === 'passo'
                      ? `(passo ${f.comp_corte})`
                      : `(lista: ${f.valor?.[0] ?? ''}...)`
                  }}
                </option>
              </select>
              <p class="field-hint">
                Preenchido → o cálculo M2 usa direto esse fator (ex.: passo 0,5). Vazio → cai no
                Tipo_Fator.
              </p>
            </div>

            <div class="dev-section">
              <div class="dev-section-header">
                <h4>Variações ({{ form.variacoes.length }})</h4>
                <button class="btn btn-outline btn-sm" @click="novaVariacao">
                  + Adicionar variação
                </button>
              </div>

              <div v-if="!form.variacoes.length" class="dev-empty">
                Produto sem variação (detalhe_id = 0).
              </div>

              <div v-for="(v, idx) in form.variacoes" :key="idx" class="dev-var-card">
                <div class="dev-var-grid">
                  <div class="field">
                    <label>Tipo Variação</label>
                    <select v-model="v.tipo_variacao_id">
                      <option :value="null">—</option>
                      <option v-for="t in tiposVariacao" :key="t.id" :value="t.id">
                        {{ t.Descricao }}
                      </option>
                    </select>
                  </div>
                  <div class="field">
                    <label>Cor</label>
                    <select v-model="v.cor_id">
                      <option :value="null">—</option>
                      <option v-for="c in cores" :key="c.id" :value="c.id">
                        {{ c.Descricao }}
                      </option>
                    </select>
                  </div>
                  <div class="field">
                    <label>Modelo</label>
                    <select v-model="v.modelo_id">
                      <option :value="null">—</option>
                      <option v-for="m in modelos" :key="m.id" :value="m.id">
                        {{ m.Descricao }}
                      </option>
                    </select>
                  </div>
                  <div class="field">
                    <label>Fator de Corte</label>
                    <select v-model="v.fator_de_corte_id">
                      <option :value="null">—</option>
                      <option v-for="f in fatoresCorte" :key="f.id" :value="f.id">
                        {{ f.nome }} ({{ f.valor?.[0] ?? '' }})
                      </option>
                    </select>
                  </div>
                  <div class="field">
                    <label>LxC</label>
                    <input v-model="v.LxC" type="text" placeholder="ex.: 1,00 x 0,50" />
                  </div>
                  <div class="field">
                    <label>Comp (m)</label>
                    <input v-model.number="v.comp" type="number" step="0.01" />
                  </div>
                  <div class="field">
                    <label>Larg (m)</label>
                    <input v-model.number="v.larg" type="number" step="0.01" />
                  </div>
                  <div class="field">
                    <label>Qtd Kit</label>
                    <input v-model.number="v.qtd_kit" type="number" step="1" min="1" />
                  </div>
                  <div class="field">
                    <label>Custo (R$)</label>
                    <input v-model.number="v.valor_custo" type="number" step="0.01" />
                  </div>
                  <div class="field">
                    <label>Ordem</label>
                    <input v-model.number="v.ordem" type="number" step="1" />
                  </div>
                  <div class="field">
                    <label class="checkbox-line">
                      <input v-model="v.ativo" type="checkbox" />
                      Ativo
                    </label>
                  </div>
                  <div class="field">
                    <button class="btn btn-danger-outline btn-sm" @click="removerVariacao(idx)">
                      Remover
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <footer class="dev-modal-footer">
            <button class="btn btn-outline" @click="formOpen = false">Cancelar</button>
            <button
              class="btn btn-primary"
              :disabled="salvando || !form.material_id"
              @click="salvar"
            >
              {{ salvando ? 'Salvando...' : 'Salvar Produto' }}
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
.dev-section {
  margin-top: 1rem;
  border-top: 1px solid var(--border-light);
  padding-top: 0.75rem;
}
.dev-section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}
.dev-section-header h4 {
  margin: 0;
}
.dev-empty {
  color: var(--text-secondary);
  font-size: 0.85rem;
  padding: 0.5rem 0;
}
.dev-var-card {
  border: 1px solid var(--border-light);
  border-radius: 8px;
  padding: 0.75rem;
  margin-bottom: 0.75rem;
  background: var(--card-bg);
}
.dev-var-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 0.5rem;
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
  max-width: 880px;
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
  .dev-grid-3,
  .dev-var-grid {
    grid-template-columns: 1fr;
  }
}
</style>
