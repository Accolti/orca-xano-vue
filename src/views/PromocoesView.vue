<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useCatalogoStore } from '@/stores/catalogo'
import {
  listarPromocoes,
  salvarPromocao,
  excluirPromocao,
  type Promocao,
  type PromocaoItem,
} from '@/services/promocaoApi'

const authStore = useAuthStore()
const catalogo = useCatalogoStore()

const podeGerenciar = computed(() => authStore.isAdminGeral)

const promocoes = ref<Promocao[]>([])
const carregando = ref(false)
const salvando = ref(false)
const erro = ref<string | null>(null)
const okMsg = ref<string | null>(null)

const form = reactive({
  id: null as number | null,
  nome: '',
  data_inicio: '',
  data_fim: '',
  ativo: true,
  itens: [] as PromocaoItem[],
})

function getErrorMessage(err: unknown): string {
  return (err as Error)?.message || 'Erro inesperado'
}

function avisarOk(msg: string) {
  okMsg.value = msg
  setTimeout(() => (okMsg.value = null), 3500)
}

async function carregar() {
  if (!podeGerenciar.value) return
  carregando.value = true
  erro.value = null
  try {
    await catalogo.fetchCatalogo()
    promocoes.value = await listarPromocoes(authStore.user?.id)
  } catch (err) {
    erro.value = getErrorMessage(err)
  } finally {
    carregando.value = false
  }
}

function resetarForm() {
  form.id = null
  form.nome = ''
  form.data_inicio = ''
  form.data_fim = ''
  form.ativo = true
  form.itens = []
}

function novo() {
  resetarForm()
}

function editar(p: Promocao) {
  form.id = p.id
  form.nome = p.nome
  form.data_inicio = String(p.data_inicio || '').slice(0, 10)
  form.data_fim = String(p.data_fim || '').slice(0, 10)
  form.ativo = p.ativo !== false
  form.itens = (p.itens ?? []).map((i) => ({
    produto_id: i.produto_id ?? null,
    variacao_id: i.variacao_id ?? null,
    borda_id: i.borda_id ?? null,
    tipo: i.tipo ?? 'PERCENTUAL',
    valor: Number(i.valor) || 0,
  }))
}

function nomeDoProduto(produtoId: number | null): string {
  if (!produtoId) return ''
  const p = catalogo.allProdutos.find((x) => x.produto_id === produtoId)
  if (!p) return `Produto ${produtoId}`
  return [p.material_nome, p.linha_nome, p.tipo_nome, p.nivel_nome].filter(Boolean).join(' ')
}

function variacoesDoProduto(produtoId: number | null) {
  if (!produtoId) return []
  const p = catalogo.allProdutos.find((x) => x.produto_id === produtoId)
  return p?._variacao ?? []
}

function nomeDaVariacao(variacaoId: number | null): string {
  if (!variacaoId) return ''
  for (const p of catalogo.allProdutos) {
    const v = p._variacao?.find((x) => x.id === variacaoId)
    if (v) return v.descricao || v.variacao || v.modelo || v.LxC || `Variação ${variacaoId}`
  }
  return `Variação ${variacaoId}`
}

function nomeDaBorda(bordaId: number | null): string {
  if (!bordaId) return ''
  const b = catalogo.allBordas.find((x) => x.id === bordaId)
  if (!b) return `Borda ${bordaId}`
  const material = nomeDoMaterial(b.material_id)
  return material ? `${b.nome} (${material})` : b.nome
}

function nomeDoMaterial(materialId: number | null): string {
  if (!materialId) return ''
  return catalogo.allMaterials.find((m) => m.id === materialId)?.nome ?? ''
}

function bordasDoProduto(produtoId: number | null) {
  if (!produtoId) return catalogo.allBordas.filter((b) => b.ativo !== false)
  const p = catalogo.allProdutos.find((x) => x.produto_id === produtoId)
  if (!p) return []
  return catalogo.allBordas.filter((b) => b.material_id === p.material_id && b.ativo !== false)
}

function aoEscolherProduto(item: PromocaoItem) {
  if (!form.nome.trim()) form.nome = nomeDoProduto(item.produto_id)
  item.variacao_id = null
  item.borda_id = null
  // Produto COMPOSTO (Playkap) só aceita percentual: o custo é montado dos componentes.
  if (ehCompostoProduto(item.produto_id)) item.tipo = 'PERCENTUAL'
}

function ehCompostoProduto(produtoId: number | null): boolean {
  if (!produtoId) return false
  const p = catalogo.allProdutos.find((x) => x.produto_id === produtoId)
  return (p?.Base_de_Calculo || '').toUpperCase() === 'COMPOSTO'
}

function adicionarItem() {
  form.itens.push({
    produto_id: null,
    variacao_id: null,
    borda_id: null,
    tipo: 'PERCENTUAL',
    valor: 0,
  })
}

function removerItem(idx: number) {
  form.itens.splice(idx, 1)
}

function valorFormatado(valor: number, tipo: string): string {
  if (tipo === 'VALOR_FIXO') return `R$ ${(Number(valor) || 0).toFixed(2).replace('.', ',')}`
  return `${Number(valor) || 0}%`
}

function descricaoItem(i: PromocaoItem): string {
  const alvo = [nomeDoProduto(i.produto_id), nomeDaVariacao(i.variacao_id), nomeDaBorda(i.borda_id)]
    .filter(Boolean)
    .join(' · ')
  const valor = valorFormatado(i.valor, i.tipo)
  return `${alvo || 'Item sem alvo'} — ${valor}`
}

async function salvar() {
  if (salvando.value) return
  if (!form.nome.trim()) {
    erro.value = 'Informe o nome da promoção.'
    return
  }
  if (!form.data_inicio || !form.data_fim) {
    erro.value = 'Informe as datas de início e fim.'
    return
  }
  if (form.data_fim < form.data_inicio) {
    erro.value = 'A data final deve ser maior ou igual à inicial.'
    return
  }
  if (!form.itens.length) {
    erro.value = 'Adicione ao menos um item (produto/variação/borda).'
    return
  }
  for (const i of form.itens) {
    if (!i.produto_id && !i.variacao_id && !i.borda_id) {
      erro.value = 'Cada item precisa de ao menos um alvo (produto, variação ou borda).'
      return
    }
    if (!(Number(i.valor) > 0)) {
      erro.value = 'Cada item precisa de um valor/desconto maior que zero.'
      return
    }
  }
  salvando.value = true
  erro.value = null
  try {
    await salvarPromocao(authStore.user?.id, {
      id: form.id,
      nome: form.nome.trim(),
      data_inicio: form.data_inicio,
      data_fim: form.data_fim,
      ativo: form.ativo,
      itens: form.itens,
    })
    avisarOk(form.id ? 'Promoção atualizada.' : 'Promoção criada.')
    resetarForm()
    await carregar()
  } catch (err) {
    erro.value = getErrorMessage(err)
  } finally {
    salvando.value = false
  }
}

async function excluir(p: Promocao) {
  if (!confirm(`Excluir a promoção "${p.nome}"?`)) return
  try {
    await excluirPromocao(authStore.user?.id, p.id)
    avisarOk('Promoção excluída.')
    await carregar()
  } catch (err) {
    erro.value = getErrorMessage(err)
  }
}

function fmtData(d?: string): string {
  if (!d) return '—'
  const [ano, mes, dia] = String(d).slice(0, 10).split('-')
  return dia ? `${dia}/${mes}/${ano}` : String(d)
}

onMounted(carregar)
</script>

<template>
  <main class="prm">
    <header class="prm-head">
      <h1>Promoções</h1>
      <p class="subtitle">Descontos temporários de custo (fábrica) — aplicados no cálculo do orçamento.</p>
    </header>

    <p v-if="!podeGerenciar" class="restrito">Acesso restrito ao administrador geral.</p>

    <template v-else>
      <p v-if="carregando" class="status"><span class="spinner" /> Carregando...</p>
      <p v-if="erro" class="erro" role="alert">{{ erro }}</p>
      <p v-if="okMsg" class="ok" role="status">{{ okMsg }}</p>

      <section class="form-card">
        <h2>{{ form.id ? 'Editar promoção' : 'Nova promoção' }}</h2>
        <div class="grid">
          <div class="field">
            <label for="prm-nome">Nome</label>
            <input
              id="prm-nome"
              v-model="form.nome"
              placeholder="Ex.: Vinil Gold Vulcanizado Nivel 1"
            />
          </div>
          <div class="field">
            <label for="prm-ini">Data início</label>
            <input id="prm-ini" v-model="form.data_inicio" type="date" />
          </div>
          <div class="field">
            <label for="prm-fim">Data fim</label>
            <input id="prm-fim" v-model="form.data_fim" type="date" />
          </div>
          <div class="field field-check">
            <label class="check">
              <input v-model="form.ativo" type="checkbox" />
              Ativa
            </label>
          </div>
        </div>

        <h3 class="itens-title">Itens da promoção</h3>
        <div v-if="form.itens.length" class="itens-list">
          <div v-for="(item, idx) in form.itens" :key="idx" class="item-row">
            <div class="field">
              <label>Produto</label>
              <select v-model="item.produto_id" @change="aoEscolherProduto(item)">
                <option :value="null">— Produto —</option>
                <option v-for="p in catalogo.allProdutos" :key="p.produto_id" :value="p.produto_id">
                  {{ [p.material_nome, p.linha_nome, p.tipo_nome, p.nivel_nome].filter(Boolean).join(' ') }}
                </option>
              </select>
            </div>
            <div class="field">
              <label>Variação</label>
              <select v-model="item.variacao_id" :disabled="!item.produto_id">
                <option :value="null">— Todas —</option>
                <option v-for="v in variacoesDoProduto(item.produto_id)" :key="v.id" :value="v.id">
                  {{ v.descricao || v.variacao || v.modelo || v.LxC || `Variação ${v.id}` }}
                </option>
              </select>
            </div>
            <div class="field">
              <label>Borda</label>
              <select v-model="item.borda_id">
                <option :value="null">— Nenhuma —</option>
                <option v-for="b in bordasDoProduto(item.produto_id)" :key="b.id" :value="b.id">
                  {{ b.nome }}<template v-if="!item.produto_id"> · {{ nomeDoMaterial(b.material_id) }}</template>
                </option>
              </select>
            </div>
            <div class="field field-tipo">
              <label>Tipo</label>
              <select v-model="item.tipo">
                <option value="VALOR_FIXO">Valor fixo (R$)</option>
                <option value="PERCENTUAL">Percentual (%)</option>
              </select>
            </div>
            <div class="field field-valor">
              <label>{{ item.tipo === 'VALOR_FIXO' ? 'Custo (R$)' : 'Desconto (%)' }}</label>
              <input v-model.number="item.valor" type="number" min="0" step="0.01" placeholder="0" />
            </div>
            <button class="btn-remove" title="Remover item" @click="removerItem(idx)">✕</button>
          </div>
        </div>
        <p v-else class="vazio">Nenhum item. Adicione produto/variação/borda abaixo.</p>
        <button class="btn-add" @click="adicionarItem">+ Adicionar item</button>

        <div class="acoes">
          <button v-if="form.id" class="btn btn-outline" @click="novo">Cancelar</button>
          <button class="btn btn-primary" :disabled="salvando" @click="salvar">
            {{ salvando ? 'Salvando…' : 'Salvar promoção' }}
          </button>
        </div>
      </section>

      <section class="lista">
        <h2>Promoções ({{ promocoes.length }})</h2>
        <div v-if="!promocoes.length" class="vazio">Nenhuma promoção cadastrada.</div>
        <div v-else class="tabela-wrapper">
          <table class="tabela">
            <thead>
              <tr>
                <th>Nome</th>
                <th>Período</th>
                <th>Status</th>
                <th>Itens</th>
                <th>Ações</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="p in promocoes" :key="p.id">
                <td>{{ p.nome }}</td>
                <td>{{ fmtData(p.data_inicio) }} → {{ fmtData(p.data_fim) }}</td>
                <td>
                  <span class="badge" :class="p.ativo ? 'badge-on' : 'badge-off'">
                    {{ p.ativo ? 'Ativa' : 'Inativa' }}
                  </span>
                </td>
                <td class="td-itens">
                  <div v-for="(i, idx) in p.itens" :key="idx" class="linha-item">
                    {{ descricaoItem(i) }}
                  </div>
                </td>
                <td class="cell-acoes">
                  <button class="btn btn-sm btn-outline" @click="editar(p)">Editar</button>
                  <button class="btn btn-sm btn-outline btn-danger" @click="excluir(p)">✕</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.prm {
  padding: 1.5rem;
  max-width: 1100px;
  margin: 0 auto;
}

.prm-head {
  margin-bottom: 1.25rem;
}

.prm-head h1 {
  font-size: 1.45rem;
  margin-bottom: 0.15rem;
}

.subtitle {
  color: var(--text-secondary);
  font-size: 0.95rem;
  margin: 0;
}

.restrito {
  color: var(--danger);
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

.ok {
  color: #16a34a;
}

.form-card,
.lista {
  padding: 1rem 1.1rem;
  border-radius: 12px;
  border: 1px solid var(--border-subtle);
  background: var(--card-bg);
  box-shadow: var(--shadow-card);
  margin-bottom: 1.25rem;
}

.form-card h2,
.lista h2 {
  font-size: 1rem;
  margin: 0 0 0.75rem;
}

.grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 0.75rem;
}

.field {
  margin-bottom: 0.75rem;
}

.field label {
  display: block;
  font-size: 0.83rem;
  font-weight: 600;
  margin-bottom: 0.25rem;
  color: var(--text-primary);
}

.field input,
.field select {
  width: 100%;
  padding: 0.45rem 0.55rem;
  border: 1px solid var(--border-light);
  border-radius: 8px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 0.9rem;
}

.field input:focus,
.field select:focus {
  outline: none;
  border-color: var(--primary);
}

.field-check {
  align-self: end;
}

.check {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.85rem;
  font-weight: 500;
}

.check input {
  width: auto;
}

.itens-title {
  font-size: 0.9rem;
  margin: 1rem 0 0.5rem;
}

.itens-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.item-row {
  display: flex;
  align-items: flex-end;
  gap: 0.6rem;
  padding: 0.6rem;
  border: 1px solid var(--border-light);
  border-radius: 8px;
  flex-wrap: wrap;
}

.item-row .field {
  flex: 1;
  min-width: 130px;
  margin-bottom: 0;
}

.item-row .field-tipo {
  flex: 0 0 140px;
}

.item-row .field-valor {
  flex: 0 0 120px;
}

.btn-remove {
  background: none;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  color: var(--text-secondary);
  cursor: pointer;
  width: 32px;
  height: 32px;
  flex-shrink: 0;
}

.btn-remove:hover {
  color: var(--danger);
  border-color: var(--danger);
}

.btn-add {
  background: none;
  border: 1px dashed var(--border-light);
  border-radius: 6px;
  padding: 0.4rem 1rem;
  color: var(--primary-light);
  cursor: pointer;
  font-size: 0.85rem;
}

.btn-add:hover {
  background: var(--primary-soft);
}

.acoes {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
  margin-top: 1rem;
}

.btn {
  padding: 0.5rem 1rem;
  border-radius: 8px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  border: none;
}

.btn-primary {
  background: var(--primary);
  color: #fff;
}

.btn-outline {
  background: var(--card-bg);
  border: 1px solid var(--border-light);
  color: var(--text-secondary);
}

.btn-sm {
  padding: 0.3rem 0.6rem;
  font-size: 0.8rem;
}

.btn-danger:hover {
  color: var(--danger);
  border-color: var(--danger);
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.vazio {
  color: var(--text-secondary);
  font-size: 0.85rem;
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
  vertical-align: top;
}

.tabela th {
  background-color: var(--primary);
  color: white;
  font-weight: 600;
}

.tabela tr:hover {
  background-color: var(--table-hover);
}

.badge {
  display: inline-block;
  padding: 0.15rem 0.5rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 600;
}

.badge-on {
  background: #dcfce7;
  color: #15803d;
}

.badge-off {
  background: var(--neutral-soft, #f3f4f6);
  color: var(--text-secondary);
}

.td-itens {
  font-size: 0.8rem;
  color: var(--text-secondary);
}

.linha-item {
  white-space: nowrap;
}

.cell-acoes {
  display: flex;
  gap: 0.4rem;
}

@media (max-width: 639px) {
  .prm {
    padding: 1rem;
  }
  .item-row {
    flex-direction: column;
    align-items: stretch;
  }
  .item-row .field,
  .item-row .field-tipo,
  .item-row .field-valor {
    flex: 1;
    min-width: 0;
  }
}
</style>
