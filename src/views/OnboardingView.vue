<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { xano } from '@/services/xano'
import { XanoRequestError } from '@xano/js-sdk'
import { useAuthStore } from '@/stores/auth'
import { regimeMap } from '@/data/mappings'

const authStore = useAuthStore()
const router = useRouter()

const passo = ref(1)
const salvando = ref(false)
const erro = ref<string | null>(null)
const sucesso = ref(false)

const form = reactive({
  isPJ: true,
  razao: '',
  fantasia: '',
  cnpj: '',
  ie: '',
  cpf: '',
  uf: '',
  regime_id: 0,
  organizacao_id: 0,
  frtB2B: 0,
  margem: 0,
  DiasVencimentoOrcamento: 15,
})

const regimes = ref<Array<{ id: number; descricao: string; slug: string }>>([])
const organizacoes = ref<Array<{ id: number; nome: string; uf: string }>>([])
const UFS = [
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA', 'PB',
  'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
]

const buscandoCNPJ = ref(false)
const erroCNPJ = ref<string | null>(null)

const totalPassos = 3
const isUltimo = computed(() => passo.value === totalPassos)

function preencherForm() {
  const u = authStore.user as any
  if (!u) return
  form.isPJ = u.isPJ !== false
  form.razao = u.razao ?? ''
  form.fantasia = u.fantasia ?? ''
  form.cnpj = u.cnpj ?? ''
  form.ie = u.ie ?? ''
  form.cpf = u.cpf ?? ''
  form.uf = u.uf ?? ''
  form.regime_id = u.regime_id ?? 0
  form.organizacao_id = Number(u.organizacao_id) || 0
  form.frtB2B = u.frtB2B ?? 0
  form.margem = u.margem ?? 0
  form.DiasVencimentoOrcamento = u.DiasVencimentoOrcamento ?? 15
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
  regimes.value = Object.entries(regimeMap).map(([descricao, id]) => ({
    id,
    descricao,
    slug: descricao,
  }))
}

async function buscarCNPJ() {
  const raw = form.cnpj.replace(/\D/g, '')
  if (raw.length !== 14) return

  // Limpa campos de dados vindos de uma busca anterior antes de preencher com a nova
  // (evita gravar informações de outro CNPJ se a consulta falhar).
  form.razao = ''
  form.fantasia = ''
  form.ie = ''
  form.uf = ''

  buscandoCNPJ.value = true
  erroCNPJ.value = null
  try {
    const resp = await xano.get('/api:-qqRIakp/capturarDados_CNPJ_IE', { cnpj: raw })
    const data = resp.getBody() as any
    if (data?.razaoSocial) form.razao = data.razaoSocial
    if (data?.nomeFantasia) form.fantasia = data.nomeFantasia
    if (data?.IE) form.ie = data.IE
    if (data?.enderecoCompleto?.estado) form.uf = data.enderecoCompleto.estado
    form.isPJ = true
  } catch (err: any) {
    erroCNPJ.value = err?.getResponse?.()?.getBody?.()?.message || 'CNPJ não encontrado.'
  } finally {
    buscandoCNPJ.value = false
  }
}

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

function ir(p: number) {
  erro.value = null
  if (p > passo.value && passo.value === 2) {
    if (!form.uf) {
      erro.value = 'Selecione a UF (destino da venda) para continuar.'
      return
    }
    if (!form.regime_id) {
      erro.value = 'Selecione o Regime Tributário para continuar.'
      return
    }
    if (!form.organizacao_id) {
      erro.value = 'Selecione o Fornecedor (Organização) para continuar.'
      return
    }
  }
  passo.value = Math.min(totalPassos, Math.max(1, p))
}

function concluirDepois() {
  router.push('/')
}

async function salvar() {
  if (salvando.value) return
  if (!form.uf) {
    erro.value = 'UF é obrigatória.'
    passo.value = 2
    return
  }
  if (!form.regime_id) {
    erro.value = 'Regime Tributário é obrigatório.'
    passo.value = 2
    return
  }
  if (!form.organizacao_id) {
    erro.value = 'Fornecedor (Organização) é obrigatório.'
    passo.value = 2
    return
  }
  if (form.margem == null || Number.isNaN(Number(form.margem)) || Number(form.margem) <= 0) {
    erro.value = 'A Margem padrão deve ser maior que zero.'
    passo.value = 3
    return
  }
  const userId = authStore.user?.id
  if (!userId) {
    erro.value = 'Usuário não identificado.'
    return
  }

  salvando.value = true
  erro.value = null
  try {
    await xano.post(`/api:-qqRIakp/user/${userId}`, {
      name: authStore.user?.name || form.razao || '',
      name_first: authStore.user?.name_first || '',
      name_last: authStore.user?.name_last || '',
      email: authStore.user?.email || '',
      razao: form.razao,
      fantasia: form.fantasia,
      cnpj: form.isPJ ? form.cnpj : '',
      ie: form.ie,
      cpf: form.isPJ ? '' : form.cpf,
      isPJ: form.isPJ,
      uf: form.uf,
      regime_id: form.regime_id || undefined,
      organizacao_id: form.organizacao_id || undefined,
      frtB2B: form.frtB2B,
      margem: form.margem,
      DiasVencimentoOrcamento: form.DiasVencimentoOrcamento,
    })
    await authStore.fetchMe()
    sucesso.value = true
    setTimeout(() => router.push('/'), 900)
  } catch (err: unknown) {
    erro.value = getErrorMessage(err)
  } finally {
    salvando.value = false
  }
}

onMounted(async () => {
  if (!authStore.user) {
    try {
      await authStore.fetchMe()
    } catch {
      /* sessão inválida — guarda de rota redireciona */
    }
  }
  preencherForm()
  await carregarRegimes()
  await carregarOrganizacoes()
  const primeiraOrg = organizacoes.value[0]
  if (!form.organizacao_id && primeiraOrg) {
    form.organizacao_id = primeiraOrg.id
  }
})
</script>

<template>
  <main class="onb">
    <div class="onb-card">
      <div class="onb-head">
        <div>
          <h1>Configure sua conta</h1>
          <p class="onb-sub">Dados usados para calcular e emitir os orçamentos corretamente.</p>
        </div>
        <button class="btn btn-sm btn-outline" @click="concluirDepois">Concluir depois</button>
      </div>

      <div class="onb-passos">
        <span
          v-for="n in totalPassos"
          :key="n"
          class="onb-passo"
          :class="{ ativo: passo === n, feito: passo > n }"
        >
          {{ ['Empresa', 'Fiscal', 'Preferências'][n - 1] }}
        </span>
      </div>

      <form @submit.prevent="salvar">
        <section v-if="passo === 1" class="onb-bloco">
          <h2>1. Empresa</h2>
          <div class="field">
            <label>Tipo</label>
            <select v-model="form.isPJ">
              <option :value="true">Pessoa Jurídica (CNPJ)</option>
              <option :value="false">Pessoa Física (CPF)</option>
            </select>
          </div>

          <div v-if="form.isPJ" class="field">
            <label for="onb-cnpj">CNPJ</label>
            <div class="cnpj-row">
              <input
                id="onb-cnpj"
                v-model="form.cnpj"
                placeholder="00.000.000/0000-00"
                @input="erroCNPJ = null"
              />
              <button
                type="button"
                class="btn btn-sm btn-outline"
                :disabled="buscandoCNPJ || form.cnpj.replace(/\D/g, '').length !== 14"
                @click="buscarCNPJ"
              >
                {{ buscandoCNPJ ? 'Buscando…' : 'Buscar CNPJ' }}
              </button>
            </div>
            <p v-if="erroCNPJ" class="erro-campo">{{ erroCNPJ }}</p>
          </div>

          <template v-if="form.isPJ">
            <div class="field">
              <label for="onb-razao">Razão Social</label>
              <input id="onb-razao" v-model="form.razao" placeholder="Razão Social" />
            </div>
            <div class="field">
              <label for="onb-fantasia">Nome Fantasia</label>
              <input id="onb-fantasia" v-model="form.fantasia" placeholder="Nome Fantasia" />
            </div>
            <div class="field">
              <label for="onb-ie">Inscrição Estadual (IE)</label>
              <input id="onb-ie" v-model="form.ie" placeholder="IE" />
            </div>
          </template>
          <template v-else>
            <div class="field">
              <label for="onb-nomecpf">Nome completo</label>
              <input id="onb-nomecpf" v-model="form.razao" placeholder="Nome completo" />
            </div>
            <div class="field">
              <label for="onb-cpf">CPF</label>
              <input id="onb-cpf" v-model="form.cpf" placeholder="000.000.000-00" />
            </div>
          </template>
        </section>

        <section v-if="passo === 2" class="onb-bloco">
          <h2>2. Fiscal e fornecedor</h2>
          <div class="field">
            <label for="onb-uf">UF (destino da venda) <span class="req">*</span></label>
            <select id="onb-uf" v-model="form.uf">
              <option value="">Selecione a UF</option>
              <option v-for="uf in UFS" :key="uf" :value="uf">{{ uf }}</option>
            </select>
            <small class="field-hint"
              >UF da empresa do vendedor (de onde você vende). A busca do CNPJ no passo 1 pode
              preencher; você pode alterar.</small
            >
          </div>
          <div class="field">
            <label for="onb-regime">Regime Tributário <span class="req">*</span></label>
            <select id="onb-regime" v-model.number="form.regime_id">
              <option :value="0" disabled>Selecione o regime</option>
              <option v-for="r in regimes" :key="r.id" :value="r.id">{{ r.descricao }}</option>
            </select>
            <small class="field-hint"
              >Define DIFAL/crédito ICMS. Usado apenas em novos orçamentos.</small
            >
          </div>
          <div class="field">
            <label for="onb-org">Fornecedor (Organização) <span class="req">*</span></label>
            <select id="onb-org" v-model.number="form.organizacao_id">
              <option :value="0">Sem fornecedor (usa PR por padrão)</option>
              <option v-for="o in organizacoes" :key="o.id" :value="o.id">
                {{ o.nome }} — {{ o.uf }}
              </option>
            </select>
            <small class="field-hint"
              >Organização que fornece a mercadoria (ex.: Kapazi — PR). Sem escolha, o cálculo usa
              PR como UF de origem.</small
            >
          </div>
        </section>

        <section v-if="passo === 3" class="onb-bloco">
          <h2>3. Preferências</h2>
          <div class="field">
            <label for="onb-margem">Margem padrão (%) <span class="req">*</span></label>
            <input
              id="onb-margem"
              v-model.number="form.margem"
              type="number"
              min="0.01"
              step="0.01"
              placeholder="Ex.: 50 a 120"
            />
            <small class="field-hint"
              >Valor percentual (markup) aplicado sobre o custo — ex.: 50 a 120.</small
            >
          </div>
          <div class="field">
            <label for="onb-frete">Frete B2B mínimo (R$)</label>
            <input
              id="onb-frete"
              v-model.number="form.frtB2B"
              type="number"
              step="0.01"
              placeholder="Ex.: 52"
            />
          </div>
          <div class="field">
            <label for="onb-dias">Validade do orçamento (dias)</label>
            <input
              id="onb-dias"
              v-model.number="form.DiasVencimentoOrcamento"
              type="number"
              min="1"
              step="1"
              placeholder="Ex.: 15"
            />
          </div>
        </section>

        <p v-if="erro" class="erro-onb" role="alert">{{ erro }}</p>
        <p v-if="sucesso" class="ok-onb" role="status">Dados salvos com sucesso!</p>

        <div class="onb-nav">
          <button
            v-if="passo > 1"
            type="button"
            class="btn btn-outline"
            :disabled="salvando"
            @click="ir(passo - 1)"
          >
            ← Voltar
          </button>
          <button v-if="!isUltimo" type="button" class="btn btn-primary" @click="ir(passo + 1)">
            Continuar →
          </button>
          <button v-else type="submit" class="btn btn-primary" :disabled="salvando">
            {{ salvando ? 'Salvando…' : 'Salvar' }}
          </button>
        </div>
      </form>
    </div>
  </main>
</template>

<style scoped>
.onb {
  padding: 1.5rem;
  max-width: 720px;
  margin: 0 auto;
}

.onb-card {
  border-radius: 14px;
  border: 1px solid var(--border-subtle);
  background: var(--card-bg);
  box-shadow: var(--shadow-card);
  padding: 1.4rem 1.5rem 1.5rem;
}

.onb-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1rem;
}

.onb-head h1 {
  font-size: 1.35rem;
  margin-bottom: 0.2rem;
}

.onb-sub {
  color: var(--text-secondary);
  font-size: 0.9rem;
  margin: 0;
}

.onb-passos {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1.25rem;
}

.onb-passo {
  padding: 0.35rem 0.8rem;
  border-radius: 999px;
  font-size: 0.8rem;
  border: 1px solid var(--border-light);
  background: var(--card-bg);
  color: var(--text-secondary);
}

.onb-passo.ativo {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
  font-weight: 600;
}

.onb-passo.feito {
  border-color: #16a34a;
  color: #16a34a;
}

.onb-bloco h2 {
  font-size: 1rem;
  margin-bottom: 0.85rem;
}

.field {
  margin-bottom: 0.85rem;
}

.field label {
  display: block;
  font-size: 0.85rem;
  font-weight: 600;
  margin-bottom: 0.3rem;
  color: var(--text-primary);
}

.field input,
.field select {
  width: 100%;
  padding: 0.5rem 0.6rem;
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

.req {
  color: var(--danger);
}

.field-hint {
  color: var(--text-secondary);
  font-size: 0.78rem;
}

.cnpj-row {
  display: flex;
  gap: 0.5rem;
}

.cnpj-row input {
  flex: 1;
}

.erro-campo {
  color: var(--danger);
  font-size: 0.8rem;
  margin: 0.3rem 0 0;
}

.erro-onb {
  color: var(--danger);
  font-size: 0.88rem;
  margin: 0.5rem 0;
}

.ok-onb {
  color: #16a34a;
  font-size: 0.88rem;
  margin: 0.5rem 0;
}

.onb-nav {
  display: flex;
  justify-content: space-between;
  gap: 0.6rem;
  margin-top: 1.25rem;
}

@media (max-width: 639px) {
  .onb {
    padding: 1rem;
  }

  .onb-head {
    flex-direction: column;
  }
}
</style>
