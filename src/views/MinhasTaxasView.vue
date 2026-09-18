<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useCatalogoStore } from '@/stores/catalogo'
import { xano } from '@/services/xano'
import { XanoRequestError } from '@xano/js-sdk'
import { CANAIS_CARTAO } from '@/utils/taxasBanco'

interface TaxaRow {
  id: number | null
  provedor_id: number | null
  provedor?: string | null
  parcelas: number | null
  cc_taxa: number | null
  canal: string | null
  origem: string | null
  ativo: boolean
}

interface ProvedorRow {
  id: number
  nome: string
}

const authStore = useAuthStore()
const catalogo = useCatalogoStore()

const taxas = ref<TaxaRow[]>([])
const taxasGlobais = ref<TaxaRow[]>([])
const provedores = ref<ProvedorRow[]>([])
const empresas = ref<{ id: number; nome: string }[]>([])
const empresaSelecionada = ref<number | null>(null)
const loading = ref(false)
const erro = ref<string | null>(null)
const okMsg = ref<string | null>(null)
const salvandoId = ref<number | string | null>(null)
const importando = ref(false)

const novoProvedorNome = ref('')

const podeGerenciar = computed(() => authStore.isAdmin || authStore.isAdminGeral)

// Aba: null = genérico (vale para todos os canais)
const abaCanal = ref<string | null>('cartao_link')

function canalDe(t: TaxaRow): string | null {
  return t.canal ? String(t.canal) : null
}

// A aba "Genérico (todos)" só aparece se houver alguma taxa genérica (empresa ou global)
const temGenerico = computed(
  () =>
    taxas.value.some((t) => canalDe(t) === null) ||
    taxasGlobais.value.some((t) => canalDe(t) === null),
)
const abas = computed<{ id: string | null; label: string }[]>(() => {
  const lista = CANAIS_CARTAO.map((c) => ({ id: c.id as string | null, label: c.label }))
  if (temGenerico.value) lista.unshift({ id: null, label: 'Genérico (todos)' })
  return lista
})

// Se a aba ativa deixar de existir (ex.: Genérico sumiu), cai para o primeiro canal
watch(abas, (lista) => {
  if (!lista.some((a) => a.id === abaCanal.value)) {
    abaCanal.value = lista[0]?.id ?? 'cartao_link'
  }
})

const taxasFiltradas = computed(() => taxas.value.filter((t) => canalDe(t) === abaCanal.value))

// Taxas globais (padrão/fallback) do canal atual — somente leitura
const globaisFiltradas = computed(() =>
  taxasGlobais.value.filter((t) => canalDe(t) === abaCanal.value),
)

function getErrorMessage(err: unknown): string {
  if (err instanceof XanoRequestError) {
    try {
      const raw = err.getResponse().getBody()
      let body: any = raw
      if (typeof raw === 'string') {
        try {
          body = JSON.parse(raw)
        } catch {
          const texto = raw.trim()
          return texto || 'Erro ao salvar.'
        }
      }
      if (body && typeof body === 'object') {
        if (typeof body.message === 'string' && body.message.trim()) return body.message.trim()
        if (body.payload && typeof body.payload.message === 'string') {
          return body.payload.message.trim()
        }
        if (body.error && typeof body.error.message === 'string') return body.error.message.trim()
      }
    } catch {
      /* segue para fallback */
    }
  }
  const msg = (err as Error)?.message
  if (msg && !/error with your request/i.test(msg)) return msg
  return 'Erro ao salvar. Verifique os dados e tente novamente.'
}

function avisarOk(msg: string) {
  okMsg.value = msg
  setTimeout(() => (okMsg.value = null), 3500)
}

async function carregarEmpresas() {
  if (!authStore.isAdminGeral) return
  try {
    const resp = await xano.get('/api:-qqRIakp/equipe')
    const lista = (resp.getBody() as any[]) ?? []
    empresas.value = lista
      .filter((u) => u.role !== 'vendedor' && u.role !== 'vendedor_master')
      .map((u) => ({ id: Number(u.id), nome: u.name_first || u.name || `#${u.id}` }))
    if (empresas.value.length && !empresaSelecionada.value) {
      empresaSelecionada.value = empresas.value[0]?.id ?? null
    }
  } catch {
    empresas.value = []
  }
}

async function carregar() {
  if (!podeGerenciar.value) return
  loading.value = true
  erro.value = null
  try {
    const params = new URLSearchParams()
    if (authStore.isAdminGeral && empresaSelecionada.value) {
      params.set('user_id', String(empresaSelecionada.value))
    }
    const qs = params.toString()
    const resp = await xano.get(`/api:-qqRIakp/taxas_banco_gerenciar${qs ? `?${qs}` : ''}`)
    const d = resp.getBody() ?? {}
    const mapTaxa = (t: any): TaxaRow => ({
      id: t.id ?? null,
      provedor_id: t.provedor_id != null ? Number(t.provedor_id) : null,
      provedor: t.provedor ?? null,
      parcelas: t.parcelas != null ? Number(t.parcelas) : null,
      cc_taxa: t.cc_taxa != null ? Number(t.cc_taxa) : null,
      canal: t.canal ? String(t.canal) : null,
      origem: t.origem ?? null,
      ativo: t.ativo !== false,
    })
    taxas.value = ((d?.taxas ?? []) as any[]).map(mapTaxa)
    taxasGlobais.value = ((d?.taxas_globais ?? []) as any[]).map(mapTaxa)
    provedores.value = ((d?.provedores ?? []) as any[]).map((p) => ({
      id: Number(p.id),
      nome: p.nome || `#${p.id}`,
    }))
  } catch (err) {
    erro.value = getErrorMessage(err)
  } finally {
    loading.value = false
  }
}

function trocarEmpresa() {
  carregar()
}

function novaTaxa() {
  taxas.value.push({
    id: null,
    provedor_id: provedores.value[0]?.id ?? null,
    parcelas: null,
    cc_taxa: null,
    canal: abaCanal.value,
    origem: 'manual',
    ativo: true,
  })
}

async function salvar(f: TaxaRow) {
  if (salvandoId.value) return
  if (f.parcelas == null || f.parcelas <= 0 || f.cc_taxa == null) {
    erro.value = 'Preencha o número de parcelas e a taxa (%).'
    return
  }
  salvandoId.value = f.id ?? 'novo'
  erro.value = null
  try {
    const payload: Record<string, unknown> = {
      provedor_id: f.provedor_id,
      parcelas: f.parcelas,
      cc_taxa: f.cc_taxa,
      canal: f.canal,
      ativo: f.ativo,
    }
    if (f.id != null) payload.id = f.id
    if (authStore.isAdminGeral && empresaSelecionada.value) {
      payload.user_id = empresaSelecionada.value
    }
    await xano.post('/api:-qqRIakp/taxa_banco_salvar', payload)
    avisarOk('Taxa salva.')
    await carregar()
    await catalogo.recarregarTaxas()
  } catch (err) {
    erro.value = getErrorMessage(err)
  } finally {
    salvandoId.value = null
  }
}

async function excluir(f: TaxaRow) {
  if (f.id == null) {
    taxas.value = taxas.value.filter((t) => t !== f)
    return
  }
  if (!confirm('Excluir esta taxa?')) return
  erro.value = null
  try {
    await xano.post('/api:-qqRIakp/taxa_banco_excluir', { id: f.id })
    avisarOk('Taxa excluída.')
    await carregar()
    await catalogo.recarregarTaxas()
  } catch (err) {
    erro.value = getErrorMessage(err)
  }
}

// Copia as taxas globais (padrão) do canal atual para a empresa, tornando-as
// editáveis e com precedência sobre o padrão.
async function importarPadrao() {
  const globais = globaisFiltradas.value
  if (!globais.length || importando.value) return
  if (!confirm(`Importar ${globais.length} taxa(s) padrão para a sua empresa neste canal?`)) return
  importando.value = true
  erro.value = null
  try {
    for (const g of globais) {
      const payload: Record<string, unknown> = {
        provedor_id: g.provedor_id,
        parcelas: g.parcelas,
        cc_taxa: g.cc_taxa,
        canal: abaCanal.value,
        ativo: true,
      }
      if (authStore.isAdminGeral && empresaSelecionada.value) {
        payload.user_id = empresaSelecionada.value
      }
      await xano.post('/api:-qqRIakp/taxa_banco_salvar', payload)
    }
    avisarOk('Taxas padrão importadas.')
    await carregar()
    await catalogo.recarregarTaxas()
  } catch (err) {
    erro.value = getErrorMessage(err)
  } finally {
    importando.value = false
  }
}

async function adicionarProvedor() {
  const nome = novoProvedorNome.value.trim()
  if (!nome) return
  erro.value = null
  try {
    await xano.post('/api:-qqRIakp/provedor_salvar', { nome })
    novoProvedorNome.value = ''
    avisarOk('Provedor cadastrado.')
    await carregar()
  } catch (err) {
    erro.value = getErrorMessage(err)
  }
}

onMounted(async () => {
  await carregarEmpresas()
  await carregar()
})
</script>

<template>
  <main class="mt">
    <header class="mt-head">
      <h1>Minhas taxas de cartão</h1>
      <p class="subtitle">
        Cadastre as taxas da sua empresa por <strong>canal de cobrança</strong> (link de pagamento,
        cartão pelo celular e maquininha). O canal genérico vale para todos. As taxas valem para a
        sua equipe (vendedores herdam da empresa). Enquanto a empresa não tiver taxa própria no
        canal, são usadas as <strong>taxas padrão da Orca</strong>.
      </p>
    </header>

    <p v-if="!podeGerenciar" class="restrito">Acesso restrito a administradores.</p>

    <template v-else>
      <div v-if="authStore.isAdminGeral && empresas.length" class="mt-owner">
        <label for="mt-empresa">Empresa</label>
        <select id="mt-empresa" v-model.number="empresaSelecionada" @change="trocarEmpresa">
          <option v-for="e in empresas" :key="e.id" :value="e.id">{{ e.nome }}</option>
        </select>
      </div>

      <p v-if="loading" class="status"><span class="spinner" /> Carregando...</p>
      <p v-if="erro" class="erro" role="alert">{{ erro }}</p>
      <p v-if="okMsg" class="ok" role="status">{{ okMsg }}</p>

      <div class="mt-provedores">
        <label for="mt-provedor">Provedores (bancos)</label>
        <div class="mt-provedor-add">
          <input
            id="mt-provedor"
            v-model="novoProvedorNome"
            type="text"
            placeholder="Ex.: Cielo, Stone, Mercado Pago"
            @keyup.enter="adicionarProvedor"
          />
          <button
            class="btn btn-sm btn-outline"
            :disabled="!novoProvedorNome.trim()"
            @click="adicionarProvedor"
          >
            + Adicionar
          </button>
        </div>
      </div>

      <div class="mt-tabs">
        <button
          v-for="a in abas"
          :key="a.id ?? 'generico'"
          type="button"
          class="mt-tab"
          :class="{ active: abaCanal === a.id }"
          @click="abaCanal = a.id"
        >
          {{ a.label }}
        </button>
      </div>

      <p v-if="!taxasFiltradas.length" class="mt-vazio">
        <template v-if="globaisFiltradas.length">
          Sua empresa ainda não cadastrou taxa neste canal — serão usadas as taxas padrão abaixo.
        </template>
        <template v-else>
          Nenhuma taxa cadastrada neste canal. Clique em <strong>+ Nova taxa</strong> para
          adicionar.
        </template>
      </p>

      <div class="mt-lista">
        <div v-for="f in taxasFiltradas" :key="f.id ?? 'novo'" class="mt-card">
          <div class="mt-card-grid">
            <div class="field">
              <label>Provedor</label>
              <select v-model.number="f.provedor_id">
                <option :value="null">—</option>
                <option v-for="p in provedores" :key="p.id" :value="p.id">{{ p.nome }}</option>
              </select>
            </div>
            <div class="field">
              <label>Parcelas</label>
              <input v-model.number="f.parcelas" type="number" min="1" step="1" placeholder="3" />
            </div>
            <div class="field">
              <label>Taxa (%)</label>
              <input v-model.number="f.cc_taxa" type="number" step="0.01" placeholder="4.99" />
            </div>
            <label class="mt-ativo">
              <input v-model="f.ativo" type="checkbox" />
              Ativo
            </label>
          </div>
          <div class="mt-card-acoes">
            <span v-if="f.origem" class="mt-origem" :class="`origem-${f.origem}`">
              {{ f.origem }}
            </span>
            <button
              v-if="f.id != null"
              class="btn btn-sm btn-outline"
              :disabled="salvandoId != null"
              @click="excluir(f)"
            >
              Excluir
            </button>
            <button
              class="btn btn-sm btn-primary"
              :disabled="salvandoId != null"
              @click="salvar(f)"
            >
              {{ salvandoId === (f.id ?? 'novo') ? '…' : 'Salvar' }}
            </button>
          </div>
        </div>
      </div>

      <section v-if="globaisFiltradas.length" class="mt-globais">
        <div class="mt-globais-head">
          <div>
            <h2 class="mt-globais-title">
              Taxas padrão da Orca (globais) — não são da sua empresa
            </h2>
            <p class="mt-globais-hint">
              Estas são as taxas globais do sistema. Sua empresa usa estas
              <strong>somente enquanto não cadastrar uma taxa própria</strong> neste canal. Elas não
              podem ser editadas aqui.
            </p>
          </div>
          <button class="btn btn-sm btn-outline" :disabled="importando" @click="importarPadrao">
            {{ importando ? 'Importando…' : 'Importar taxas padrão' }}
          </button>
        </div>
        <div class="mt-lista">
          <div v-for="g in globaisFiltradas" :key="`g-${g.id}`" class="mt-card mt-card-readonly">
            <div class="mt-card-grid">
              <div class="field">
                <label>Provedor</label>
                <div class="mt-ro-valor">{{ g.provedor || '—' }}</div>
              </div>
              <div class="field">
                <label>Parcelas</label>
                <div class="mt-ro-valor">{{ g.parcelas }}x</div>
              </div>
              <div class="field">
                <label>Taxa (%)</label>
                <div class="mt-ro-valor">{{ g.cc_taxa }}</div>
              </div>
              <span class="mt-badge-padrao">padrão</span>
            </div>
          </div>
        </div>
      </section>

      <div class="mt-rodape">
        <button class="btn btn-primary" @click="novaTaxa">+ Nova taxa</button>
      </div>
    </template>
  </main>
</template>

<style scoped>
.mt {
  padding: 1.5rem;
  max-width: 980px;
  margin: 0 auto;
}

.mt-head {
  margin-bottom: 1rem;
}

.mt-head h1 {
  font-size: 1.45rem;
  margin-bottom: 0.15rem;
}

.subtitle {
  color: var(--text-secondary);
  font-size: 0.9rem;
  margin: 0;
}

.restrito {
  color: var(--danger);
}

.mt-owner {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.9rem;
}

.mt-owner label {
  font-size: 0.85rem;
  color: var(--text-secondary);
}

.mt-owner select {
  padding: 0.4rem 0.55rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 0.9rem;
}

.mt-provedores {
  margin-bottom: 1rem;
}

.mt-provedores > label {
  display: block;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--text-secondary);
  margin-bottom: 0.35rem;
}

.mt-provedor-add {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

.mt-provedor-add input {
  flex: 1;
  padding: 0.45rem 0.6rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 0.9rem;
}

.mt-tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-bottom: 1rem;
}

.mt-tab {
  padding: 0.4rem 0.75rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-secondary);
  font-weight: 600;
  font-size: 0.8rem;
  font-family: inherit;
  cursor: pointer;
  transition:
    background 0.15s,
    border-color 0.15s,
    color 0.15s;
}

.mt-tab:hover {
  border-color: var(--border-strong);
}

.mt-tab.active {
  background: var(--primary, #3b82f6);
  border-color: var(--primary, #3b82f6);
  color: #fff;
}

.mt-vazio {
  color: var(--text-secondary);
  font-size: 0.9rem;
  padding: 0.5rem 0 0.75rem;
}

.mt-lista {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.mt-card {
  border: 1px solid var(--border-light);
  border-radius: 10px;
  background: var(--card-bg);
  padding: 0.85rem 0.9rem;
}

.mt-card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
  gap: 0.6rem 0.8rem;
  align-items: end;
}

.mt-card .field {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.mt-card .field label {
  font-size: 0.75rem;
  color: var(--text-secondary);
  font-weight: 500;
}

.mt-card .field input,
.mt-card .field select {
  width: 100%;
  padding: 0.4rem 0.5rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 0.9rem;
}

.mt-ativo {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.85rem;
  color: var(--text-primary);
  padding-bottom: 0.35rem;
}

.mt-card-acoes {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 0.5rem;
  margin-top: 0.7rem;
}

.mt-origem {
  font-size: 0.7rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--text-secondary);
  border: 1px solid var(--border-light);
  border-radius: 999px;
  padding: 0.1rem 0.5rem;
}

.mt-globais {
  margin-top: 1.5rem;
}

.mt-globais-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
}

.mt-globais-title {
  font-size: 1rem;
  margin-bottom: 0.2rem;
}

.mt-globais-hint {
  font-size: 0.8rem;
  color: var(--text-secondary);
  margin: 0;
}

.mt-card-readonly {
  background: var(--table-hover, #f8fafc);
  border-style: dashed;
}

.mt-ro-valor {
  padding: 0.4rem 0.5rem;
  font-size: 0.9rem;
  color: var(--text-secondary);
}

.mt-badge-padrao {
  align-self: center;
  justify-self: end;
  font-size: 0.7rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  font-weight: 700;
  color: var(--text-secondary);
  background: var(--card-bg);
  border: 1px solid var(--border-light);
  border-radius: 999px;
  padding: 0.15rem 0.6rem;
}

.mt-rodape {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 1rem;
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

@media (max-width: 639px) {
  .mt {
    padding: 1rem;
  }
}
</style>
