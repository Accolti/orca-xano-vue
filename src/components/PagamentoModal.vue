<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { usePagamentoStore } from '@/stores/pagamentos'
import {
  gerarParcelasFinanceiras,
  FORMAS_PAGAMENTO,
  somarParcelas,
  type ParcelaFinanceira,
  type CartaoOpcaoParcela,
} from '@/utils/pagamentos'

const props = defineProps<{
  modelValue: boolean
  orcaId: number
  codOrca?: string
  venda: number
  custo: number
  metodos: { pix: boolean; boleto: boolean; cartao: boolean }
  descontoPixPercentual: number
  parcelasCartao: number | null
  cartaoParcelas: CartaoOpcaoParcela[]
  parcelasBoleto?: number | null
  parcelasPix?: number | null
  // "Faturar para o cliente" negociado (gera boleto com vencimento = entrega + 20 dias)
  faturar?: boolean
  modoFaturamento?: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  saved: []
}>()

const pagamentoStore = usePagamentoStore()

const carregando = ref(false)
const salvando = ref(false)
const erro = ref<string | null>(null)

interface Row {
  valor: number | null
  vencimento: string
  forma_pagamento_id: number
}

const rows = ref<Row[]>([])

type AceiteTipo = 'todas' | 'pix' | 'boleto' | 'cartao' | 'faturamento'
const aceite = ref<AceiteTipo>('todas')
const boletoN = ref<number | null>(null)
const cartaoN = ref<number | null>(null)
const pixN = ref<number | null>(null)
// Data de entrega prevista (usada no boleto de faturamento: vencimento = entrega + 20 dias)
const entregaDate = ref(hojeISO())
const ENTREGA_DEFAULT_DIAS = 15

function somaDiasISO(iso: string, dias: number): string {
  const d = new Date(`${iso}T00:00:00`)
  if (isNaN(d.getTime())) return iso
  d.setDate(d.getDate() + dias)
  const mes = String(d.getMonth() + 1).padStart(2, '0')
  const dia = String(d.getDate()).padStart(2, '0')
  return `${d.getFullYear()}-${mes}-${dia}`
}

function entregaDefaultISO(): string {
  return somaDiasISO(hojeISO(), ENTREGA_DEFAULT_DIAS)
}

const vencFaturamento = computed(() => (entregaDate.value ? somaDiasISO(entregaDate.value, 20) : ''))

function parcelaFaturamento(): ParcelaFinanceira {
  return {
    valor: Number(props.venda) || 0,
    vencimento: vencFaturamento.value || hojeISO(),
    forma_pagamento_id: 1,
  }
}

// Máximo de parcelas do boleto (regra atual: venda ÷ metade do custo)
const boletoMax = computed(() => {
  const v = Number(props.venda) || 0
  const c = Number(props.custo) || 0
  return c > 0 ? Math.max(1, Math.floor(v / (c / 2))) : 1
})

function boletoAtual(): number {
  const n = Number(boletoN.value)
  return Number.isInteger(n) && n >= 1 && n <= boletoMax.value ? n : boletoMax.value
}

function cartaoAtual(): number | null {
  const n = Number(cartaoN.value)
  const existe = Number.isInteger(n) && props.cartaoParcelas.some((o) => o.parcelas === n)
  if (existe) return n
  return props.parcelasCartao && props.cartaoParcelas.some((o) => o.parcelas === props.parcelasCartao)
    ? props.parcelasCartao
    : (props.cartaoParcelas[0]?.parcelas ?? null)
}

function pixAtual(): number {
  const n = Number(pixN.value)
  return n === 1 || n === 2 ? n : 2
}

function gerarPara(tipo: AceiteTipo): ParcelaFinanceira[] {
  const comum = {
    venda: Number(props.venda) || 0,
    custo: Number(props.custo) || 0,
    descontoPixPercentual: props.descontoPixPercentual,
    cartaoParcelas: props.cartaoParcelas,
  }
  if (tipo === 'pix') {
    return gerarParcelasFinanceiras({
      ...comum,
      metodos: { pix: true, boleto: false, cartao: false },
      parcelasCartao: null,
      parcelasPix: pixAtual(),
    })
  }
  if (tipo === 'boleto') {
    return gerarParcelasFinanceiras({
      ...comum,
      metodos: { pix: false, boleto: true, cartao: false },
      parcelasCartao: null,
      parcelasBoleto: boletoAtual(),
    })
  }
  if (tipo === 'cartao') {
    return gerarParcelasFinanceiras({
      ...comum,
      metodos: { pix: false, boleto: false, cartao: true },
      parcelasCartao: cartaoAtual(),
    })
  }
  if (tipo === 'faturamento') {
    return [parcelaFaturamento()]
  }
  // todas (como negociadas)
  const todas = gerarParcelasFinanceiras({
    ...comum,
    metodos: props.metodos,
    parcelasCartao: cartaoAtual(),
    parcelasBoleto: props.parcelasBoleto ?? boletoMax.value,
    parcelasPix: props.parcelasPix ?? 2,
  })
  if (props.faturar) {
    todas.push(parcelaFaturamento())
  }
  return todas.sort((a, b) => a.vencimento.localeCompare(b.vencimento))
}

function rowsDe(parcelas: ParcelaFinanceira[]): Row[] {
  return parcelas.map((p) => ({
    valor: p.valor,
    vencimento: p.vencimento,
    forma_pagamento_id: p.forma_pagamento_id,
  }))
}

function aplicarAceite(tipo: AceiteTipo) {
  aceite.value = tipo
  erro.value = null
  rows.value = rowsDe(gerarPara(tipo))
}

const totalParcelas = computed(() =>
  somarParcelas(
    rows.value.map((r) => ({
      valor: Number(r.valor) || 0,
      vencimento: r.vencimento,
      forma_pagamento_id: r.forma_pagamento_id,
    })),
  ),
)

function hojeISO(): string {
  const d = new Date()
  const mes = String(d.getMonth() + 1).padStart(2, '0')
  const dia = String(d.getDate()).padStart(2, '0')
  return `${d.getFullYear()}-${mes}-${dia}`
}

function close() {
  emit('update:modelValue', false)
}

async function abrir() {
  erro.value = null
  rows.value = []
  aceite.value = 'todas'
  const pb = Number(props.parcelasBoleto)
  boletoN.value = Number.isInteger(pb) && pb >= 1 && pb <= boletoMax.value ? pb : null
  const pp = Number(props.parcelasPix)
  pixN.value = pp === 1 || pp === 2 ? pp : 2
  entregaDate.value = entregaDefaultISO()
  const pc = Number(props.parcelasCartao)
  cartaoN.value =
    pc && props.cartaoParcelas.some((o) => o.parcelas === pc)
      ? pc
      : (props.cartaoParcelas[0]?.parcelas ?? null)
  carregando.value = true
  try {
    const existentes = await pagamentoStore.carregarPorOrca(props.orcaId)
    rows.value = existentes.map((e) => ({
      valor: Number(e.valor) ?? null,
      vencimento: (e.vencimento || hojeISO()).slice(0, 10),
      forma_pagamento_id: e.forma_pagamento_id ?? 1,
    }))
  } catch (err: any) {
    erro.value = err?.message || 'Erro ao carregar parcelas existentes.'
  } finally {
    carregando.value = false
  }
}

watch(
  () => props.modelValue,
  (open) => {
    if (open) abrir()
  },
)

function gerarDasCondicoes() {
  erro.value = null
  aceite.value = 'todas'
  rows.value = rowsDe(gerarPara('todas'))
}

function adicionar() {
  rows.value.push({ valor: null, vencimento: hojeISO(), forma_pagamento_id: 1 })
}

function remover(idx: number) {
  rows.value.splice(idx, 1)
}

function toPayload(): ParcelaFinanceira[] {
  return rows.value
    .filter((r) => Number(r.valor) > 0 && r.vencimento)
    .map((r) => ({
      valor: Number(r.valor) || 0,
      vencimento: r.vencimento,
      forma_pagamento_id: r.forma_pagamento_id,
    }))
}

async function salvar() {
  const payload = toPayload()
  if (!payload.length) {
    if (!confirm('Nenhuma parcela válida. Remover todas as parcelas deste orçamento?')) return
  } else if (!confirm('Isso substituirá as parcelas existentes deste orçamento. Continuar?')) {
    return
  }

  salvando.value = true
  erro.value = null
  try {
    await pagamentoStore.salvarParcelas(props.orcaId, payload)
    emit('saved')
    close()
  } catch (err: any) {
    erro.value = err?.message || 'Erro ao salvar parcelas.'
  } finally {
    salvando.value = false
  }
}

function formatarMoeda(valor: number | null): string {
  return (Number(valor) || 0).toLocaleString('pt-BR', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })
}
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div v-if="modelValue" class="modal-overlay" @click="close">
        <div class="modal-card" @click.stop>
          <header class="modal-header">
            <h2>Parcelas do orçamento {{ codOrca ? `#${codOrca}` : '' }}</h2>
            <button class="modal-close" @click="close" aria-label="Fechar">&times;</button>
          </header>

          <div class="modal-body">
            <p v-if="carregando" class="loading-msg">Carregando parcelas...</p>

            <template v-else>
              <p v-if="erro" class="error-msg">{{ erro }}</p>

              <div class="parc-actions">
                <button class="btn btn-outline" @click="gerarDasCondicoes">
                  Gerar das condições negociadas
                </button>
              </div>

              <div class="aceite">
                <span class="aceite-titulo">Qual condição o cliente aceitou? (opcional)</span>
                <div class="aceite-chips">
                  <button
                    type="button"
                    class="aceite-chip"
                    :class="{ active: aceite === 'todas' }"
                    @click="aplicarAceite('todas')"
                  >
                    Todas (como negociadas)
                  </button>
                  <button
                    v-if="props.metodos.pix"
                    type="button"
                    class="aceite-chip"
                    :class="{ active: aceite === 'pix' }"
                    @click="aplicarAceite('pix')"
                  >
                    Pix
                  </button>
                  <button
                    v-if="props.metodos.boleto"
                    type="button"
                    class="aceite-chip"
                    :class="{ active: aceite === 'boleto' }"
                    @click="aplicarAceite('boleto')"
                  >
                    Boleto
                  </button>
                  <button
                    v-if="props.metodos.cartao && props.cartaoParcelas.length"
                    type="button"
                    class="aceite-chip"
                    :class="{ active: aceite === 'cartao' }"
                    @click="aplicarAceite('cartao')"
                  >
                    Cartão
                  </button>
                  <button
                    v-if="props.faturar"
                    type="button"
                    class="aceite-chip"
                    :class="{ active: aceite === 'faturamento' }"
                    @click="aplicarAceite('faturamento')"
                  >
                    Faturamento (boleto)
                  </button>
                </div>

                <div v-if="aceite === 'pix'" class="aceite-sub">
                  <label for="aceite-pix-n">Parcelas do Pix</label>
                  <select id="aceite-pix-n" v-model.number="pixN" @change="aplicarAceite('pix')">
                    <option :value="1">1x (pagamento em até 5 dias)</option>
                    <option :value="2">2x</option>
                  </select>
                </div>

                <div v-if="aceite === 'boleto' && boletoMax > 1" class="aceite-sub">
                  <label for="aceite-boleto-n">Parcelas do Boleto</label>
                  <select id="aceite-boleto-n" v-model.number="boletoN" @change="aplicarAceite('boleto')">
                    <option v-for="n in boletoMax" :key="n" :value="n">{{ n }}x</option>
                  </select>
                </div>

                <div v-if="aceite === 'cartao' && props.cartaoParcelas.length > 1" class="aceite-sub">
                  <label for="aceite-cartao-n">Parcelas do Cartão</label>
                  <select id="aceite-cartao-n" v-model.number="cartaoN" @change="aplicarAceite('cartao')">
                    <option v-for="o in props.cartaoParcelas" :key="o.parcelas" :value="o.parcelas">
                      {{ o.parcelas }}x de R$ {{ formatarMoeda(o.valorParcela) }}
                    </option>
                  </select>
                </div>

                <div
                  v-if="props.faturar && (aceite === 'faturamento' || aceite === 'todas')"
                  class="aceite-sub"
                >
                  <label for="aceite-entrega">Data de entrega prevista</label>
                  <input
                    id="aceite-entrega"
                    v-model="entregaDate"
                    type="date"
                    @change="aplicarAceite(aceite === 'faturamento' ? 'faturamento' : 'todas')"
                  />
                  <span class="aceite-hint">Vencimento do boleto: {{ vencFaturamento }}</span>
                </div>
              </div>

              <div v-if="rows.length === 0" class="vazio">
                <p>Nenhuma parcela registrada.</p>
                <p class="vazio-hint">Use "Gerar das condições negociadas" para preencher ou adicione manualmente.</p>
              </div>

              <div v-for="(row, idx) in rows" :key="idx" class="parc-row">
                <select v-model="row.forma_pagamento_id">
                  <option v-for="f in FORMAS_PAGAMENTO" :key="f.id" :value="f.id">
                    {{ f.tipo }}
                  </option>
                </select>
                <input
                  v-model.number="row.valor"
                  type="number"
                  min="0"
                  step="0.01"
                  placeholder="Valor"
                />
                <input v-model="row.vencimento" type="date" />
                <button class="btn-remove" title="Remover" @click="remover(idx)">&times;</button>
              </div>

              <button class="btn-add" @click="adicionar">+ Adicionar parcela</button>

              <div class="parc-total">
                <span>Total planejado</span>
                <strong>R$ {{ formatarMoeda(totalParcelas) }}</strong>
              </div>

              <p v-if="modoFaturamento" class="parc-aviso">
                Ao salvar, o orçamento será marcado como FATURADO.
              </p>
            </template>
          </div>

          <footer class="modal-footer">
            <button type="button" class="btn btn-cancel" :disabled="salvando || carregando" @click="close">
              Cancelar
            </button>
            <button
              type="button"
              class="btn btn-accent"
              :disabled="salvando || carregando"
              @click="salvar"
            >
              {{ salvando ? 'Salvando…' : modoFaturamento ? 'Salvar e Faturar' : 'Salvar Parcelas' }}
            </button>
          </footer>
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
  max-width: 640px;
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
}

.modal-header h2 {
  font-size: 1.15rem;
  font-weight: 700;
  color: var(--text-primary);
}

.modal-close {
  background: none;
  border: none;
  font-size: 1.5rem;
  color: var(--text-secondary);
  cursor: pointer;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
  transition: background 0.15s;
}

.modal-close:hover {
  background: var(--border-subtle);
  color: var(--text-primary);
}

.modal-body {
  padding: 1.25rem 1.5rem;
  overflow-y: auto;
  flex: 1;
}

.loading-msg,
.error-msg {
  text-align: center;
  padding: 1rem 0;
}

.error-msg {
  color: #e74c3c;
  font-size: 0.875rem;
}

.parc-actions {
  margin-bottom: 1rem;
}

.aceite {
  margin-bottom: 1rem;
  padding: 0.7rem 0.8rem;
  border: 1px solid var(--border-light);
  border-radius: 8px;
  background: var(--card-bg);
}

.aceite-titulo {
  display: block;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--text-secondary);
  margin-bottom: 0.5rem;
}

.aceite-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.aceite-chip {
  padding: 0.35rem 0.75rem;
  border-radius: 999px;
  border: 1px solid var(--border-light);
  background: var(--card-bg);
  font-size: 0.8rem;
  color: var(--text-secondary);
  cursor: pointer;
  font-family: inherit;
  transition: background 0.15s;
}

.aceite-chip:hover {
  background: var(--table-hover);
}

.aceite-chip.active {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}

.aceite-sub {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  margin-top: 0.6rem;
}

.aceite-sub label {
  font-size: 0.8rem;
  color: var(--text-secondary);
}

.aceite-sub select,
.aceite-sub input[type='date'] {
  padding: 0.3rem 0.5rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 0.85rem;
}

.aceite-hint {
  font-size: 0.78rem;
  color: var(--text-secondary);
}

.parc-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.parc-row select,
.parc-row input {
  flex: 1;
  padding: 0.5rem 0.6rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  font-size: 0.9rem;
  color: var(--text-primary);
  background: var(--card-bg);
  outline: none;
}

.parc-row select {
  flex: 1.2;
}

.parc-row input[type='date'] {
  flex: 1;
}

.btn-remove {
  background: none;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  width: 34px;
  height: 34px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.15rem;
  color: #9ca3af;
  cursor: pointer;
  flex-shrink: 0;
  transition: background 0.15s, color 0.15s;
}

.btn-remove:hover {
  background: #fef2f2;
  color: #dc2626;
  border-color: #fecaca;
}

.btn-add {
  width: 100%;
  margin-bottom: 1rem;
  padding: 0.4rem 1rem;
  background: none;
  border: 1px dashed var(--border-light);
  border-radius: 6px;
  font-size: 0.85rem;
  color: var(--primary-light);
  cursor: pointer;
}

.btn-add:hover {
  background: var(--primary-soft);
  border-color: var(--primary-light);
}

.vazio {
  text-align: center;
  color: var(--text-secondary);
  padding: 0.75rem 0;
}

.vazio-hint {
  font-size: 0.8rem;
  color: var(--text-secondary);
}

.parc-total {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem 0;
  border-top: 1px solid var(--border-light);
  font-size: 0.95rem;
  color: var(--text-secondary);
}

.parc-total strong {
  color: var(--text-primary);
  font-size: 1.05rem;
}

.parc-aviso {
  margin: 0.25rem 0 0.5rem;
  padding: 0.5rem 0.75rem;
  background: var(--primary-soft, #eff6ff);
  border: 1px solid var(--border-light);
  border-radius: 6px;
  font-size: 0.8rem;
  color: var(--text-secondary);
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
  border-radius: 6px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  border: none;
  transition: background 0.15s;
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-outline {
  background: none;
  border: 1px solid var(--border-light);
  color: var(--primary-light);
}

.btn-outline:hover {
  background: var(--primary-soft);
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

.btn-cancel:hover:not(:disabled) {
  background: var(--border-light);
}

.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.2s ease;
}

.modal-enter-active .modal-card,
.modal-leave-active .modal-card {
  transition: transform 0.2s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.modal-enter-from .modal-card,
.modal-leave-to .modal-card {
  transform: translateY(-20px);
}

@media (max-width: 639px) {
  .modal-overlay {
    padding: 0;
    align-items: flex-end;
  }

  .modal-card {
    max-height: 95vh;
    border-radius: 14px 14px 0 0;
  }

  .modal-body {
    padding: 1rem;
  }

  .parc-row {
    flex-wrap: wrap;
  }
}
</style>
