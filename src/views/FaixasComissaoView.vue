<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { xano } from '@/services/xano'
import { XanoRequestError } from '@xano/js-sdk'
import ConfigComissoesBanner from '@/components/ConfigComissoesBanner.vue'

interface FaixaRow {
  id: number | null
  user_id?: number
  faixa_min: number | null
  faixa_max: number | null
  comissao_total_perc: number | null
  ordem: number
  ativo: boolean
}

const authStore = useAuthStore()

const faixas = ref<FaixaRow[]>([])
const empresas = ref<{ id: number; nome: string }[]>([])
const empresaSelecionada = ref<number | null>(null)
const loading = ref(false)
const erro = ref<string | null>(null)
const okMsg = ref<string | null>(null)
const salvandoId = ref<number | string | null>(null)

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
      .filter((u) => u.role === 'admin')
      .map((u) => ({ id: Number(u.id), nome: u.name_first || u.name || `#${u.id}` }))
    if (empresas.value.length && !empresaSelecionada.value) {
      empresaSelecionada.value = empresas.value[0]?.id ?? null
    }
  } catch {
    empresas.value = []
  }
}

async function carregar() {
  loading.value = true
  erro.value = null
  try {
    const params = new URLSearchParams()
    if (authStore.isAdminGeral && empresaSelecionada.value) {
      params.set('user_id', String(empresaSelecionada.value))
    }
    const resp = await xano.get(`/api:-qqRIakp/faixas_comissao?${params.toString()}`)
    const d = resp.getBody() ?? {}
    const lista = (d?.faixas ?? []) as any[]
    faixas.value = lista.map((f) => ({
      id: f.id ?? null,
      user_id: f.user_id,
      faixa_min: f.faixa_min != null ? Number(f.faixa_min) : null,
      faixa_max: f.faixa_max != null ? Number(f.faixa_max) : null,
      comissao_total_perc: f.comissao_total_perc != null ? Number(f.comissao_total_perc) : null,
      ordem: Number(f.ordem) || 0,
      ativo: f.ativo !== false,
    }))
  } catch (err) {
    erro.value = getErrorMessage(err)
  } finally {
    loading.value = false
  }
}

const SUGESTOES = [
  { faixa_min: 50, faixa_max: 69, comissao_total_perc: 7 },
  { faixa_min: 70, faixa_max: 89, comissao_total_perc: 8 },
  { faixa_min: 90, faixa_max: 100, comissao_total_perc: 10 },
]

function novaFaixa() {
  const next = SUGESTOES[faixas.value.length] ?? null
  faixas.value.push({
    id: null,
    faixa_min: next?.faixa_min ?? null,
    faixa_max: next?.faixa_max ?? null,
    comissao_total_perc: next?.comissao_total_perc ?? null,
    ordem: faixas.value.length + 1,
    ativo: true,
  })
}

function sugerirPadrao() {
  if (faixas.value.length) return
  faixas.value = SUGESTOES.map((s, i) => ({
    id: null,
    faixa_min: s.faixa_min,
    faixa_max: s.faixa_max,
    comissao_total_perc: s.comissao_total_perc,
    ordem: i + 1,
    ativo: true,
  }))
}

async function salvar(f: FaixaRow) {
  if (salvandoId.value) return
  if (f.faixa_min == null || f.comissao_total_perc == null) {
    erro.value = 'Preencha o início da faixa (markup %) e a comissão total (%).'
    return
  }
  salvandoId.value = f.id ?? 'novo'
  erro.value = null
  try {
    const payload: Record<string, unknown> = {
      faixa_min: f.faixa_min,
      faixa_max: f.faixa_max,
      comissao_total_perc: f.comissao_total_perc,
      ordem: f.ordem,
      ativo: f.ativo,
    }
    if (f.id != null) payload.id = f.id
    if (authStore.isAdminGeral && empresaSelecionada.value) {
      payload.user_id = empresaSelecionada.value
    }
    await xano.post('/api:-qqRIakp/faixa_comissao_salvar', payload)
    avisarOk('Faixa salva.')
    await carregar()
  } catch (err) {
    erro.value = getErrorMessage(err)
  } finally {
    salvandoId.value = null
  }
}

onMounted(async () => {
  await carregarEmpresas()
  await carregar()
})
</script>

<template>
  <main class="fx">
    <header class="fx-head">
      <h1>Configuração de Comissão</h1>
      <p class="subtitle">
        Faixas por markup efetivo: o total liberado ao Vendedor Master. A ponta recebe o % cadastrado
        e o Master fica com o remanescente (override).
      </p>
    </header>

    <ConfigComissoesBanner :apenas-limites="true" />

    <p v-if="!authStore.isAdmin && !authStore.isAdminGeral" class="restrito">
      Acesso restrito a administradores.
    </p>

    <template v-else>
      <div v-if="authStore.isAdminGeral && empresas.length" class="fx-owner">
        <label for="fx-empresa">Empresa</label>
        <select id="fx-empresa" v-model.number="empresaSelecionada" @change="carregar">
          <option v-for="e in empresas" :key="e.id" :value="e.id">{{ e.nome }}</option>
        </select>
      </div>

      <p v-if="loading" class="status"><span class="spinner" /> Carregando...</p>
      <p v-if="erro" class="erro" role="alert">{{ erro }}</p>
      <p v-if="okMsg" class="ok" role="status">{{ okMsg }}</p>

      <div class="fx-note">
        As faixas definem o <strong>total de comissão liberado</strong> por faixa de
        <strong>markup efetivo</strong>. O ponta recebe o % cadastrado nele e o Master fica com o
        restante (override). Ex.: faixa <strong>50–69% → 7%</strong>; se o ponta tem 5%, ele leva 5%
        e o Master 2%. Valem para pedidos 100% pagos; a base é a venda (<code>vnd_tot</code>).
      </div>

      <p v-if="!faixas.length" class="fx-vazio">
        Nenhuma faixa cadastrada ainda — clique em <strong>+ Nova faixa</strong> ou use
        <strong>Sugerir faixas padrão</strong>.
      </p>

      <div class="fx-lista">
        <div v-for="f in faixas" :key="f.id ?? 'novo'" class="fx-card">
          <div class="fx-card-grid">
            <div class="field">
              <label>Markup de (%)</label>
              <input v-model.number="f.faixa_min" type="number" step="0.01" placeholder="50" />
            </div>
            <div class="field">
              <label>Markup até (%)</label>
              <input v-model.number="f.faixa_max" type="number" step="0.01" placeholder="69" />
            </div>
            <div class="field">
              <label>Comissão total (%)</label>
              <input
                v-model.number="f.comissao_total_perc"
                type="number"
                step="0.01"
                placeholder="7"
              />
            </div>
            <div class="field field-ordem">
              <label>Ordem</label>
              <input v-model.number="f.ordem" type="number" min="0" step="1" />
            </div>
            <label class="fx-ativo">
              <input v-model="f.ativo" type="checkbox" />
              Ativo
            </label>
          </div>
          <div class="fx-card-acoes">
            <button class="btn btn-sm btn-primary" :disabled="salvandoId != null" @click="salvar(f)">
              {{ salvandoId === (f.id ?? 'novo') ? '…' : 'Salvar' }}
            </button>
          </div>
        </div>
      </div>

      <div class="fx-rodape">
        <button class="btn btn-primary" @click="novaFaixa">+ Nova faixa</button>
        <button v-if="!faixas.length" class="btn btn-outline" @click="sugerirPadrao">
          Sugerir faixas padrão
        </button>
      </div>
    </template>
  </main>
</template>

<style scoped>
.fx {
  padding: 1.5rem;
  max-width: 980px;
  margin: 0 auto;
}

.fx-head {
  margin-bottom: 1rem;
}

.fx-head h1 {
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

.fx-owner {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.9rem;
}

.fx-owner label {
  font-size: 0.85rem;
  color: var(--text-secondary);
}

.fx-owner select {
  padding: 0.4rem 0.55rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 0.9rem;
}

.fx-note {
  font-size: 0.8rem;
  color: var(--text-secondary);
  background: var(--primary-soft, #eff6ff);
  border: 1px solid var(--border-light);
  border-radius: 8px;
  padding: 0.6rem 0.8rem;
  margin-bottom: 1rem;
}

.fx-note code {
  font-size: 0.78rem;
}

.fx-vazio {
  color: var(--text-secondary);
  font-size: 0.9rem;
  padding: 0.5rem 0 0.75rem;
}

.fx-lista {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.fx-card {
  border: 1px solid var(--border-light);
  border-radius: 10px;
  background: var(--card-bg);
  padding: 0.85rem 0.9rem;
}

.fx-card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
  gap: 0.6rem 0.8rem;
  align-items: end;
}

.fx-card .field {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.fx-card .field label {
  font-size: 0.75rem;
  color: var(--text-secondary);
  font-weight: 500;
}

.fx-card .field input[type='number'] {
  width: 100%;
  padding: 0.4rem 0.5rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 0.9rem;
}

.field-ordem {
  max-width: 90px;
}

.fx-ativo {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.85rem;
  color: var(--text-primary);
  padding-bottom: 0.35rem;
}

.fx-card-acoes {
  display: flex;
  justify-content: flex-end;
  margin-top: 0.7rem;
}

.fx-rodape {
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
  white-space: nowrap;
}

.tabela th {
  background-color: var(--primary);
  color: white;
  font-weight: 600;
}

.tabela td input[type='number'] {
  width: 110px;
  padding: 0.3rem 0.45rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-family: inherit;
}

.td-num {
  text-align: center;
}

.btn-nova {
  margin-top: 1rem;
}

@media (max-width: 639px) {
  .fx {
    padding: 1rem;
  }
}
</style>
