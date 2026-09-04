<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import logoOrca from '@/assets/orca_system_1000x1000.png?inline'
import { useAuthStore } from '@/stores/auth'
import { xano } from '@/services/xano'
import { XanoRequestError } from '@xano/js-sdk'
import DashboardGrafico from '@/components/DashboardGrafico.vue'
import PendenciasPerfilBanner from '@/components/PendenciasPerfilBanner.vue'

const authStore = useAuthStore()
const router = useRouter()

interface SerieMes {
  mes: string
  vendas: number
  recebido: number
  areceber: number
}

type PeriodoOpcao = 'todos' | 'mensal' | 'trimestral' | 'semestral' | 'anual'
const periodo = ref<PeriodoOpcao>('todos')
const mesInicio = ref(mesAtualISO())

const periodos: { id: PeriodoOpcao; label: string }[] = [
  { id: 'todos', label: 'Todos os períodos' },
  { id: 'mensal', label: 'Mensal' },
  { id: 'trimestral', label: 'Trimestral' },
  { id: 'semestral', label: 'Semestral' },
  { id: 'anual', label: 'Anual' },
]

function mesAtualISO(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

function mudarPeriodo(p: PeriodoOpcao) {
  periodo.value = p
  carregar()
}

const loading = ref(true)
const error = ref<string | null>(null)

const orcamentos = ref(0)
const pedidos = ref(0)
const boletosVencidos = ref(0)
const boletosAVencer = ref(0)
const boletosPagos = ref(0)
const funil = ref<Record<string, number>>({})
const serie = ref<SerieMes[]>([])

const ordemFunil = ['RASCUNHO', 'ENVIADO', 'AGUARDANDO_RETORNO', 'APROVADO', 'RECUSADO', 'CANCELADO']

const statusLabel: Record<string, string> = {
  RASCUNHO: 'Rascunho',
  ENVIADO: 'Enviado',
  AGUARDANDO_RETORNO: 'Aguardando retorno',
  APROVADO: 'Aprovado',
  RECUSADO: 'Recusado',
  CANCELADO: 'Cancelado',
}

async function carregar() {
  loading.value = true
  error.value = null
  try {
    const params = new URLSearchParams({ periodo: periodo.value, mes_inicio: mesInicio.value })
    const resp = await xano.get(`/api:-qqRIakp/dashboard?${params.toString()}`)
    const d = resp.getBody() ?? {}
    orcamentos.value = Number(d.orcamentos) || 0
    pedidos.value = Number(d.pedidos) || 0
    boletosVencidos.value = Number(d.boletosVencidos) || 0
    boletosAVencer.value = Number(d.boletosAVencer) || 0
    boletosPagos.value = Number(d.boletosPagos) || 0
    funil.value = d.funil ?? {}
    serie.value = Array.isArray(d.serie) ? (d.serie as SerieMes[]) : []
  } catch (err) {
    const body = (err as XanoRequestError)?.getResponse?.()?.getBody?.()
    error.value = body?.message || (err as Error).message || 'Erro ao carregar o dashboard.'
  } finally {
    loading.value = false
  }
}

const MESES_CURTOS = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez']

function rotuloMes(mes: string): string {
  const [ano, mm] = mes.split('-')
  const idx = Number(mm) - 1
  return `${MESES_CURTOS[idx] ?? mm}/${String(ano).slice(2)}`
}

function fmtReais(n: number): string {
  return (Number(n) || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
}

// Vendas por mês: só meses até o atual (futuro não faz sentido).
const vendasSerie = computed(() => {
  const atual = mesAtualISO()
  return serie.value.filter((s) => s.mes <= atual)
})

const rotulosVendas = computed(() => vendasSerie.value.map((s) => rotuloMes(s.mes)))
const valoresVendas = computed(() => vendasSerie.value.map((s) => s.vendas))
const totalVendas = computed(() => vendasSerie.value.reduce((acc, s) => acc + (Number(s.vendas) || 0), 0))

// Recebido vs A receber: janela completa (inclui projeção futura de a receber).
const rotulosCaixa = computed(() => serie.value.map((s) => rotuloMes(s.mes)))
const valoresRecebido = computed(() => serie.value.map((s) => s.recebido))
const valoresAReceber = computed(() => serie.value.map((s) => s.areceber))
const totalRecebido = computed(() => serie.value.reduce((acc, s) => acc + (Number(s.recebido) || 0), 0))
const totalAReceber = computed(() => serie.value.reduce((acc, s) => acc + (Number(s.areceber) || 0), 0))

function irPara(caminho: string) {
  router.push(caminho)
}

function irParaStatus(status: string) {
  router.push({ path: '/orcamentos', query: { status } })
}

onMounted(carregar)
</script>

<template>
  <main class="home">
    <header class="home-head">
      <img :src="logoOrca" alt="Orca Systems" class="home-logo" />
      <div>
        <h1>Olá, {{ authStore.user?.name_first || authStore.user?.name || 'Usuário' }}!</h1>
        <p class="subtitle">Visão geral da sua conta.</p>
      </div>
    </header>

    <PendenciasPerfilBanner />

    <div class="periodo-bar">
      <label class="periodo-label">
        Período a partir de
        <input v-model="mesInicio" type="month" class="periodo-input" @change="carregar" />
      </label>
      <div class="periodo-chips">
        <button
          v-for="p in periodos"
          :key="p.id"
          class="aba"
          :class="{ active: periodo === p.id }"
          @click="mudarPeriodo(p.id)"
        >
          {{ p.label }}
        </button>
      </div>
    </div>

    <p v-if="loading" class="status"><span class="spinner" /> Carregando...</p>

    <div v-else-if="error" class="erro-bloco">
      <p class="erro">{{ error }}</p>
      <button class="btn-retry" @click="carregar">Tentar novamente</button>
    </div>

    <template v-else>
      <section class="cards">
        <button class="dash-card dash-card-primary" @click="irPara('/orcamentos')">
          <span class="dash-num">{{ orcamentos }}</span>
          <span class="dash-label">Orçamentos</span>
        </button>

        <button class="dash-card dash-card-primary" @click="irPara('/pedidos')">
          <span class="dash-num">{{ pedidos }}</span>
          <span class="dash-label">Pedidos</span>
        </button>

        <button class="dash-card dash-card-danger" @click="irPara('/pagamentos')">
          <span class="dash-num">{{ boletosVencidos }}</span>
          <span class="dash-label">Boletos Vencidos</span>
        </button>

        <button class="dash-card dash-card-alerta" @click="irPara('/pagamentos')">
          <span class="dash-num">{{ boletosAVencer }}</span>
          <span class="dash-label">Boletos a Vencer</span>
        </button>

        <button class="dash-card dash-card-ok" @click="irPara('/pagamentos')">
          <span class="dash-num">{{ boletosPagos }}</span>
          <span class="dash-label">Boletos Pagos</span>
        </button>
      </section>

      <section class="funil">
        <h2>Status dos orçamentos</h2>
        <div class="funil-chips">
          <button
            v-for="status in ordemFunil"
            :key="status"
            class="funil-chip"
            @click="irParaStatus(status)"
          >
            <span class="funil-num">{{ funil[status] ?? 0 }}</span>
            <span class="funil-label">{{ statusLabel[status] }}</span>
          </button>
        </div>
      </section>

      <section class="graficos">
        <h2>Gráficos</h2>
        <div class="graf-cards">
          <div class="graf-card">
            <div class="graf-head">
              <span class="graf-titulo">Vendas por mês</span>
              <span class="graf-total">{{ fmtReais(totalVendas) }}</span>
            </div>
            <DashboardGrafico
              :rotulos="rotulosVendas"
              :series="[{ nome: 'Vendas', cor: 'var(--primary-light)', valores: valoresVendas }]"
            />
          </div>

          <div class="graf-card">
            <div class="graf-head">
              <span class="graf-titulo">Recebido vs A receber</span>
              <span class="graf-total">
                {{ fmtReais(totalRecebido) }} <span class="graf-total-div">/</span>
                {{ fmtReais(totalAReceber) }}
              </span>
            </div>
            <DashboardGrafico
              :rotulos="rotulosCaixa"
              :series="[
                { nome: 'Recebido', cor: '#16a34a', valores: valoresRecebido },
                { nome: 'A receber', cor: '#d97706', valores: valoresAReceber },
              ]"
            />
          </div>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.home {
  padding: 1.5rem;
  max-width: 1100px;
  margin: 0 auto;
}

.home-head {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.home-logo {
  max-width: 72px;
  width: 100%;
  height: auto;
  object-fit: contain;
}

.home h1 {
  font-size: 1.45rem;
  margin-bottom: 0.15rem;
}

.subtitle {
  color: var(--text-secondary);
  font-size: 1rem;
  margin: 0;
}

.periodo-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.6rem 0.9rem;
  margin-bottom: 1.25rem;
}

.periodo-label {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  font-size: 0.85rem;
  color: var(--text-secondary);
}

.periodo-input {
  padding: 0.35rem 0.5rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 0.85rem;
}

.periodo-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.aba {
  padding: 0.4rem 0.9rem;
  border-radius: 999px;
  border: 1px solid var(--border-light);
  background: var(--card-bg);
  font-size: 0.85rem;
  color: var(--text-secondary);
  cursor: pointer;
  font-family: inherit;
  transition: background 0.15s;
}

.aba:hover {
  background: var(--table-hover);
}

.aba.active {
  background: var(--primary);
  color: #fff;
  border-color: var(--primary);
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

.erro-bloco {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.75rem;
}

.btn-retry {
  padding: 0.4rem 0.9rem;
  background: var(--danger-soft);
  color: var(--danger);
  border: 1px solid var(--danger-soft);
  border-radius: 6px;
  font-size: 0.85rem;
  cursor: pointer;
}

.cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
  gap: 1rem;
  margin-bottom: 1.75rem;
}

.dash-card {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.35rem;
  padding: 1rem 1.1rem;
  border-radius: 12px;
  border: 1px solid var(--border-subtle);
  background: var(--card-bg);
  box-shadow: var(--shadow-card);
  cursor: pointer;
  text-align: left;
  transition:
    transform 0.15s,
    box-shadow 0.15s;
  font-family: inherit;
}

.dash-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.08);
}

.dash-num {
  font-size: 1.8rem;
  font-weight: 700;
  line-height: 1;
}

.dash-label {
  font-size: 0.85rem;
  color: var(--text-secondary);
  font-weight: 500;
}

.dash-card-primary .dash-num {
  color: var(--primary-light);
}

.dash-card-danger .dash-num {
  color: var(--danger);
}

.dash-card-alerta .dash-num {
  color: #d97706;
}

.dash-card-ok .dash-num {
  color: #16a34a;
}

.funil h2 {
  font-size: 1rem;
  margin-bottom: 0.75rem;
  color: var(--text-primary);
}

.funil-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.6rem;
}

.funil-chip {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  padding: 0.45rem 0.85rem;
  border-radius: 999px;
  border: 1px solid var(--border-light);
  background: var(--card-bg);
  cursor: pointer;
  font-family: inherit;
  transition: background 0.15s;
}

.funil-chip:hover {
  background: var(--table-hover);
}

.funil-num {
  font-weight: 700;
  font-size: 0.9rem;
  color: var(--primary-light);
}

.funil-label {
  font-size: 0.82rem;
  color: var(--text-secondary);
}

.graficos {
  margin-top: 1.75rem;
}

.graficos h2 {
  font-size: 1rem;
  margin-bottom: 0.75rem;
  color: var(--text-primary);
}

.graf-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1rem;
}

.graf-card {
  padding: 1rem 1.1rem 0.9rem;
  border-radius: 12px;
  border: 1px solid var(--border-subtle);
  background: var(--card-bg);
  box-shadow: var(--shadow-card);
}

.graf-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.6rem;
}

.graf-titulo {
  font-size: 0.92rem;
  font-weight: 600;
  color: var(--text-primary);
}

.graf-total {
  font-size: 0.82rem;
  font-weight: 600;
  color: var(--text-secondary);
}

.graf-total-div {
  opacity: 0.45;
  font-weight: 400;
}

@media (max-width: 639px) {
  .home {
    padding: 1rem;
  }

  .home-head {
    flex-direction: column;
    text-align: center;
  }
}
</style>
