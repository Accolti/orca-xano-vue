<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { useOrcamentoStore } from '@/stores/orcamento'
import { useAuthStore } from '@/stores/auth'
import { useClienteStore } from '@/stores/cliente'
import SimulacaoModal from '@/components/SimulacaoModal.vue'
import ClienteModal from '@/components/ClienteModal.vue'
import type { SimulacaoItem } from '@/types/orcamento'
import type { Cliente } from '@/types/cliente'

const orcamentoStore = useOrcamentoStore()
const authStore = useAuthStore()
const clienteStore = useClienteStore()

const observacao = ref('')
const mostrarCustos = ref(false)
const simulacaoModalOpen = ref(false)
const simulacaoSelecionada = ref<SimulacaoItem | null>(null)

const termoBuscaCliente = ref('')
const clienteSelecionado = ref<Cliente | null>(null)
const clienteModalOpen = ref(false)
const clienteModalId = ref<number | null>(null)

watch(termoBuscaCliente, (val) => {
  if (val && val.length >= 3) {
    clienteStore.buscarClientes(val)
  } else {
    clienteStore.clientes = []
  }
})

function limparCliente() {
  clienteSelecionado.value = null
  termoBuscaCliente.value = ''
  clienteStore.clientes = []
}

function selecionarCliente(c: Cliente) {
  clienteSelecionado.value = c
  termoBuscaCliente.value = ''
  clienteStore.clientes = []
}

function verCliente() {
  if (clienteSelecionado.value) {
    clienteModalId.value = clienteSelecionado.value.id
    clienteModalOpen.value = true
  }
}

const margemPadrao = computed(() => authStore.user?.margem ?? 100)
const fretePadrao = computed(() => authStore.user?.frtB2B ?? 52)

const formValido = computed(() => {
  if (!clienteSelecionado.value) return false
  if (!orcamentoStore.materialSelecionado) return false
  if (!orcamentoStore.largura || orcamentoStore.largura <= 0) return false
  if (!orcamentoStore.comprimento || orcamentoStore.comprimento <= 0) return false
  if (!orcamentoStore.quantidade || orcamentoStore.quantidade < 1) return false
  if (orcamentoStore.mostrarLinha && orcamentoStore.linhas.length && !orcamentoStore.linhaSelecionada) return false
  if (orcamentoStore.mostrarTipo && orcamentoStore.tipos.length && !orcamentoStore.tipoSelecionado) return false
  if (orcamentoStore.mostrarNivel && orcamentoStore.niveis.length && !orcamentoStore.nivelSelecionado) return false
  if (orcamentoStore.mostrarBorda && orcamentoStore.bordas.length && !orcamentoStore.bordaSelecionada) return false
  return true
})

const fcArray = computed(() => {
  const fatores = orcamentoStore.resultado?.Tipo_Fator_1
  if (!fatores?.length) return []
  const fc = fatores[0]
  return fc?._fator_de_corte.valor ?? []
})

const produtoEncontrado = computed(() => {
  return orcamentoStore.resultado?.Produto_2?.[0] ?? null
})

onMounted(() => {
  orcamentoStore.carregarMateriais()
})

function toggleCustos() {
  mostrarCustos.value = !mostrarCustos.value
}

async function handleCalcular() {
  simulacaoSelecionada.value = null
  await orcamentoStore.calcular(false)
}

async function handleSimular() {
  simulacaoSelecionada.value = null
  await orcamentoStore.calcular(true)
  if (orcamentoStore.resultado?.simulacao?.length) {
    simulacaoModalOpen.value = true
  }
}

function selecionarSimulacao(item: SimulacaoItem) {
  simulacaoSelecionada.value = item
}

const inserirOk = ref(false)
const mostrarResumo = ref(false)
const finalizando = ref(false)

const validadeCalculada = computed(() => {
  const dias = authStore.user?.DiasVencimentoOrcamento ?? 15
  const venc = new Date(Date.now() + dias * 86400000)
  return venc.toLocaleDateString('en-US')
})

async function handleInserir() {
  if (!clienteSelecionado.value) return
  inserirOk.value = false
  try {
    await orcamentoStore.inserirOrcamento(clienteSelecionado.value.id, observacao.value)
    inserirOk.value = true
    observacao.value = ''
  } catch {
    /* error já definido no store */
  }
}

function handleFinalizar() {
  finalizando.value = true
  mostrarResumo.value = true
}

function novoOrcamento() {
  orcamentoStore.resetar()
  limparCliente()
  observacao.value = ''
  mostrarCustos.value = false
  simulacaoSelecionada.value = null
  inserirOk.value = false
  mostrarResumo.value = false
  finalizando.value = false
}

const valorVendaTotalB2B = computed(() => {
  if (simulacaoSelecionada.value) return simulacaoSelecionada.value.Valor_Venda_Total_B2B
  return orcamentoStore.func1?.Valor_Venda_Total_B2B ?? 0
})

const valorVendaUnitB2B = computed(() => {
  if (simulacaoSelecionada.value) return simulacaoSelecionada.value.Valor_Venda_Unit_B2B
  return orcamentoStore.func1?.Valor_Venda_Unit_B2B ?? 0
})

const valorVendaTotal = computed(() => {
  if (simulacaoSelecionada.value) return simulacaoSelecionada.value.Valor_Venda_Total
  return orcamentoStore.func1?.Valor_Venda_Total ?? 0
})

const valorVendaUnit = computed(() => {
  if (simulacaoSelecionada.value) return simulacaoSelecionada.value.Valor_Venda_Unit
  return orcamentoStore.func1?.Valor_Venda_Unit ?? 0
})

const lucroTotal = computed(() => {
  if (simulacaoSelecionada.value) return simulacaoSelecionada.value.Valor_Lucro_Total
  return orcamentoStore.func1?.Valor_Lucro_Total ?? 0
})

const custoTotal = computed(() => {
  if (simulacaoSelecionada.value) return simulacaoSelecionada.value.Valor_Custo_Total
  return orcamentoStore.func1?.Valor_Custo_Total ?? 0
})

const custoUnit = computed(() => {
  if (simulacaoSelecionada.value) return simulacaoSelecionada.value.Valor_Custo_Unit
  return orcamentoStore.func1?.Valor_Custo_Unit ?? 0
})

function formatarMoeda(valor: number): string {
  return `R$ ${valor.toFixed(2).replace('.', ',')}`
}
</script>

<template>
  <div class="orcamento-page">
    <template v-if="!mostrarResumo">
    <!-- A. Cabeçalho e Identificação do Cliente -->
    <section class="card welcome-card">
      <div class="welcome-top">
        <div>
          <h2>Tapetes personalizados</h2>
          <p class="subtitle">Vinil, Cleankap, Duo, Rubberkap Personalizado e etc...</p>
        </div>
        <span class="orc-num">{{ orcamentoStore.numeroOrcamento || '---' }}</span>
      </div>
      <div v-if="clienteSelecionado" class="welcome-cliente">
        <strong>{{ clienteSelecionado.nome_fantasia || clienteSelecionado.razao_social }}</strong>
        <span>{{ clienteSelecionado.cnpj || clienteSelecionado.cpf || '' }}</span>
      </div>
      <div class="welcome-metrics">
        <span class="metric"><strong>Margem:</strong> {{ margemPadrao }}%</span>
        <span class="metric"><strong>Frete B2B:</strong> {{ formatarMoeda(fretePadrao) }}</span>
      </div>
    </section>

    <!-- Cliente -->
    <section class="card">
      <h3 class="section-title">Cliente</h3>

      <div v-if="!clienteSelecionado" class="cliente-busca">
        <div class="field">
          <label>Buscar cliente por nome, CNPJ...</label>
          <input v-model="termoBuscaCliente" placeholder="Digite pelo menos 3 caracteres..." />
        </div>

        <div v-if="clienteStore.loading" class="cliente-loading">Buscando...</div>

        <div v-if="clienteStore.clientes.length" class="cliente-resultados">
          <button
            v-for="c in clienteStore.clientes"
            :key="c.id"
            class="cliente-item"
            @click="selecionarCliente(c)"
          >
            <strong>{{ c.nome_fantasia || c.razao_social }}</strong>
            <span>{{ c.cnpj || c.cpf || '' }}</span>
          </button>
        </div>

        <p v-if="clienteStore.error" class="error-msg">{{ clienteStore.error }}</p>
      </div>

      <div v-else class="cliente-selecionado">
        <div class="cliente-info">
          <strong>{{ clienteSelecionado.nome_fantasia || clienteSelecionado.razao_social }}</strong>
          <span>{{ clienteSelecionado.cnpj || clienteSelecionado.cpf || '' }}</span>
        </div>
        <div class="cliente-actions">
          <button class="btn btn-sm" @click="verCliente">👁 Ver dados</button>
          <button class="btn btn-sm btn-outline" @click="limparCliente">✕ Limpar</button>
        </div>
      </div>
    </section>

    <!-- Totais do Orçamento -->
    <section v-if="orcamentoStore.itensInseridos.length" class="card card-totais">
      <div class="totais-header">
        <span class="orc-num">{{ orcamentoStore.numeroOrcamento }}</span>
        <span class="totais-cliente">{{ clienteSelecionado?.nome_fantasia || clienteSelecionado?.razao_social }}</span>
      </div>
      <div class="totais-grid">
        <div class="totais-item">
          <span class="totais-label">Total Venda</span>
          <span class="totais-valor">{{ formatarMoeda(orcamentoStore.orcamentoHeader?.vnd_tot ?? 0) }}</span>
        </div>
        <div class="totais-item">
          <span class="totais-label">Total B2B</span>
          <span class="totais-valor totais-b2b">{{ formatarMoeda(orcamentoStore.orcamentoHeader?.vnd_B2B_tot ?? 0) }}</span>
        </div>
        <div class="totais-item">
          <span class="totais-label">Custo Total</span>
          <span class="totais-valor">{{ formatarMoeda(orcamentoStore.orcamentoHeader?.cst_tot ?? 0) }}</span>
        </div>
        <div class="totais-item">
          <span class="totais-label">Lucro Total</span>
          <span class="totais-valor">{{ formatarMoeda(orcamentoStore.orcamentoHeader?.luc_tot ?? 0) }}</span>
        </div>
        <div class="totais-item">
          <span class="totais-label">Itens</span>
          <span class="totais-valor">{{ orcamentoStore.itensInseridos.length }}</span>
        </div>
        <div class="totais-item">
          <span class="totais-label">Margem</span>
          <span class="totais-valor">{{ orcamentoStore.orcamentoHeader?.margem ?? margemPadrao }}%</span>
        </div>
      </div>
      <div class="totais-validade">
        Validade: {{ orcamentoStore.orcamentoHeader?.validade ? new Date(orcamentoStore.orcamentoHeader.validade).toLocaleDateString('en-US') : validadeCalculada }}
      </div>
    </section>

    <!-- Itens do Orçamento -->
    <section v-if="orcamentoStore.itensInseridos.length" class="card">
      <h3 class="section-title">Itens do Orçamento ({{ orcamentoStore.itensInseridos.length }})</h3>
      <div class="itens-tabela">
        <div class="itens-header">
          <span class="itens-col-num">#</span>
          <span class="itens-col-desc">Descrição</span>
          <span class="itens-col-dim">Dimensões</span>
          <span class="itens-col-qtd">Qtd</span>
          <span class="itens-col-vlr">Valor</span>
        </div>
        <div v-for="(item, idx) in orcamentoStore.itensInseridos" :key="item.id" class="itens-row">
          <span class="itens-col-num">{{ idx + 1 }}</span>
          <span class="itens-col-desc">{{ item.Descricao || item.descricao }}</span>
          <span class="itens-col-dim">{{ item.larg }} x {{ item.comp }} m</span>
          <span class="itens-col-qtd">{{ item.qtd }}</span>
          <span class="itens-col-vlr">{{ formatarMoeda(item.vlr_vnd_unit_b2b ?? item.vlr_vnd_unit ?? 0) }}</span>
        </div>
      </div>
    </section>

    <!-- B. Especificação do Produto -->
    <section class="card">
      <h3 class="section-title">Especificação do Produto</h3>

      <div class="field">
        <label>Material</label>
        <div class="select-wrap">
          <select
            v-model="orcamentoStore.materialSelecionado"
            @change="orcamentoStore.selecionarMaterial(orcamentoStore.materialSelecionado!)"
          >
            <option :value="null" disabled>Selecione um material</option>
            <option
              v-for="m in orcamentoStore.materiais"
              :key="m.id"
              :value="m"
            >{{ m.nome }}</option>
          </select>
          <button
            v-if="orcamentoStore.materialSelecionado"
            class="btn-clear"
            @click="orcamentoStore.limparMaterial()"
          >✕</button>
        </div>
      </div>

      <div v-if="orcamentoStore.mostrarLinha && orcamentoStore.linhas.length" class="field">
        <label>Linha</label>
        <div class="select-wrap">
          <select v-model="orcamentoStore.linhaSelecionada">
            <option :value="null" disabled>Selecione</option>
            <option v-for="l in orcamentoStore.linhas" :key="l.id" :value="l">{{ l.nome }}</option>
          </select>
          <button
            v-if="orcamentoStore.linhaSelecionada"
            class="btn-clear"
            @click="orcamentoStore.linhaSelecionada = null"
          >✕</button>
        </div>
      </div>

      <div v-if="orcamentoStore.mostrarTipo && orcamentoStore.tipos.length" class="field">
        <label>Tipo</label>
        <div class="select-wrap">
          <select v-model="orcamentoStore.tipoSelecionado">
            <option :value="null" disabled>Selecione</option>
            <option v-for="t in orcamentoStore.tipos" :key="t.id" :value="t">{{ t.nome }}</option>
          </select>
          <button
            v-if="orcamentoStore.tipoSelecionado"
            class="btn-clear"
            @click="orcamentoStore.tipoSelecionado = null"
          >✕</button>
        </div>
      </div>

      <div v-if="orcamentoStore.mostrarNivel && orcamentoStore.niveis.length" class="field">
        <label>Nível</label>
        <div class="select-wrap">
          <select v-model="orcamentoStore.nivelSelecionado">
            <option :value="null" disabled>Selecione</option>
            <option v-for="n in orcamentoStore.niveis" :key="n.id" :value="n">{{ n.nome }}</option>
          </select>
          <button
            v-if="orcamentoStore.nivelSelecionado"
            class="btn-clear"
            @click="orcamentoStore.nivelSelecionado = null"
          >✕</button>
        </div>
      </div>

      <div v-if="orcamentoStore.mostrarBorda && orcamentoStore.bordas.length" class="field">
        <label>Borda</label>
        <div class="select-wrap">
          <select v-model="orcamentoStore.bordaSelecionada">
            <option :value="null" disabled>Selecione</option>
            <option v-for="b in orcamentoStore.bordas" :key="b.id" :value="b">{{ b.nome }}</option>
          </select>
          <button
            v-if="orcamentoStore.bordaSelecionada"
            class="btn-clear"
            @click="orcamentoStore.bordaSelecionada = null"
          >✕</button>
        </div>
      </div>

      <div class="field">
        <label>Quantidade</label>
        <input
          v-model.number="orcamentoStore.quantidade"
          type="number"
          min="1"
          class="input-num"
        />
        <span class="field-suffix">unidades</span>
      </div>
    </section>

    <!-- C. Calculadora de Dimensões -->
    <section class="card">
      <h3 class="section-title">Dimensões</h3>

      <div class="dimensoes-row">
        <div class="field flex-1">
          <label>Largura (m)</label>
          <input v-model.number="orcamentoStore.largura" type="number" step="0.01" min="0" placeholder="0,00" />
        </div>
        <span class="dimensoes-x">X</span>
        <div class="field flex-1">
          <label>Comprimento (m)</label>
          <input v-model.number="orcamentoStore.comprimento" type="number" step="0.01" min="0" placeholder="0,00" />
        </div>
      </div>

      <div class="field">
        <label>Área Nominal (m²)</label>
        <input :value="orcamentoStore.areaNominal.toFixed(2)" readonly class="input-readonly" />
      </div>

      <div class="btn-row">
        <button class="btn btn-secondary" :disabled="orcamentoStore.loading || !formValido" @click="handleCalcular">
          {{ orcamentoStore.loading ? 'Calculando...' : 'Calcular' }}
        </button>
        <button class="btn btn-primary" :disabled="orcamentoStore.loading || !formValido" @click="handleSimular">
          {{ orcamentoStore.loading ? 'Calculando...' : 'Simular' }}
        </button>
      </div>
    </section>

    <!-- Resultados -->
    <template v-if="orcamentoStore.resultado">
      <!-- D. FC e Dimensões Faturadas -->
      <section class="card">
        <h3 class="section-title">Fator de Conversão</h3>

        <p class="fc-display">
          <strong>FC:</strong>
          <span v-for="(v, i) in fcArray" :key="i" class="fc-item">{{ v }}<span v-if="i < fcArray.length - 1">, </span></span>
        </p>

        <div class="dimensoes-row">
          <div class="field flex-1">
            <label>Largura FC (m)</label>
            <input :value="orcamentoStore.resultado.LargFC" readonly class="input-readonly" />
          </div>
          <span class="dimensoes-x">X</span>
          <div class="field flex-1">
            <label>Comprimento FC (m)</label>
            <input :value="orcamentoStore.resultado.CompFC" readonly class="input-readonly" />
          </div>
        </div>

        <div class="field area-fc-wrap">
          <label>Área Faturada (m²)</label>
          <div class="area-fc-input">
            <input :value="formatarMoeda(orcamentoStore.func1?.AreaFC ?? 0).replace('R$ ', '')" readonly class="input-readonly input-big" />
            <button class="btn-eye" :class="{ active: mostrarCustos }" @click="toggleCustos" title="Detalhamento financeiro">
              <svg v-if="!mostrarCustos" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
                <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                <circle cx="12" cy="12" r="3" />
              </svg>
              <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
                <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94" />
                <path d="M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19" />
                <line x1="1" y1="1" x2="23" y2="23" />
              </svg>
            </button>
          </div>
        </div>
      </section>

      <!-- E. Tabela de Preços -->
      <section class="card">
        <h3 class="section-title">Valores</h3>

        <div class="price-grid">
          <div class="price-label">Valor Vnd Unit</div>
          <div class="price-value price-bg">{{ formatarMoeda(valorVendaUnit) }}</div>
          <div class="price-label">Valor Vnd Unit B2B</div>
          <div class="price-value price-bg">{{ formatarMoeda(valorVendaUnitB2B) }}</div>

          <div class="price-label">Valor Vnd Total</div>
          <div class="price-value price-bg">{{ formatarMoeda(valorVendaTotal) }}</div>
          <div class="price-label">Valor Vnd Tot B2B</div>
          <div class="price-value price-b2b">{{ formatarMoeda(valorVendaTotalB2B) }}</div>
        </div>

        <div class="field">
          <label>Novo Vlr de Vnd Total B2B</label>
          <div class="novo-valor-wrap">
            <input type="number" step="0.01" placeholder="0,00" class="input-num" />
            <button class="btn-recalc" title="Recalcular (funcionalidade futura)">&#8635;</button>
          </div>
          <p class="field-hint">Função não implementada</p>
        </div>
      </section>

      <!-- G. Detalhamento Financeiro (Toggle) -->
      <section v-if="mostrarCustos" class="card custos-card">
        <h3 class="section-title">Detalhamento Financeiro</h3>

        <div class="custos-grid">
          <span class="price-label">Cst da Mat Prima M2</span>
          <span class="price-value price-bg">{{ formatarMoeda(orcamentoStore.resultado.Produto_2[0]?.valor ?? 0) }}</span>

          <span class="price-label">Cst da Borda M2</span>
          <span class="price-value price-bg">{{ formatarMoeda(orcamentoStore.resultado.cst_borda) }}</span>

          <span class="price-label">Frete B2B</span>
          <span class="price-value price-bg">{{ formatarMoeda(orcamentoStore.resultado.frete_b2b) }}</span>

          <span class="price-label">Novo Frete B2B</span>
          <div class="novo-valor-wrap">
            <input type="number" step="0.01" placeholder="0,00" class="input-num" />
            <button class="btn-recalc" title="Recalcular (funcionalidade futura)">&#8635;</button>
          </div>

          <span class="price-label">Margem</span>
          <span class="price-value price-bg">{{ margemPadrao }}%</span>

          <span class="price-label">Nova Margem</span>
          <div class="novo-valor-wrap">
            <input type="number" step="0.1" placeholder="0" class="input-num" />
            <button class="btn-recalc" title="Recalcular (funcionalidade futura)">&#8635;</button>
          </div>

          <span class="price-label">Custo Unitário</span>
          <span class="price-value price-bg">{{ formatarMoeda(custoUnit) }}</span>

          <span class="price-label">Custo Total</span>
          <span class="price-value price-bg">{{ formatarMoeda(custoTotal) }}</span>

          <span class="price-label">Lucro Unitário</span>
          <span class="price-value price-bg">{{ formatarMoeda(lucroTotal) }}</span>

          <span class="price-label">Lucro Total</span>
          <span class="price-value price-bg">{{ formatarMoeda(lucroTotal) }}</span>

          <span class="price-label">Novo Lcr Total</span>
          <div class="novo-valor-wrap">
            <input type="number" step="0.01" placeholder="0,00" class="input-num" />
            <button class="btn-recalc" title="Recalcular (funcionalidade futura)">&#8635;</button>
          </div>
        </div>
      </section>
    </template>

    <!-- F. Observações e Ações -->
    <section class="card">
      <h3 class="section-title">Finalização</h3>

      <div class="field">
        <label>Descrição / Observação</label>
        <textarea v-model="observacao" placeholder="Observações do orçamento..." rows="3"></textarea>
      </div>

      <div class="btn-row">
        <button
          class="btn btn-primary btn-lg"
          :disabled="orcamentoStore.loading || !formValido"
          @click="handleCalcular"
        >
          Calcular
        </button>
        <button
          class="btn btn-primary btn-lg"
          :disabled="orcamentoStore.loading || !orcamentoStore.resultado || orcamentoStore.inserindo"
          @click="handleInserir"
        >
          {{ orcamentoStore.inserindo ? 'Inserindo…' : 'Adicionar Item' }}
        </button>
      </div>

      <div v-if="orcamentoStore.itensInseridos.length" class="btn-row" style="margin-top: 0.75rem">
        <button
          class="btn btn-success btn-lg"
          @click="handleFinalizar"
        >
          Finalizar Orçamento
        </button>
      </div>

      <p v-if="inserirOk" class="success-msg">Item adicionado ao orçamento {{ orcamentoStore.numeroOrcamento }}!</p>
      <p v-if="orcamentoStore.error" class="error-msg">{{ orcamentoStore.error }}</p>
    </section>

    <!-- Modal de Simulação -->
    <SimulacaoModal
      v-if="orcamentoStore.resultado"
      v-model="simulacaoModalOpen"
      :simulacao="orcamentoStore.resultado.simulacao"
      :custo-total="custoTotal"
      @select="selecionarSimulacao"
    />

    <ClienteModal
      v-model="clienteModalOpen"
      :cliente-id="clienteModalId"
      :readonly="true"
    />
  </template>

  <template v-else>
    <section class="card resumo-card">
      <h2>Orçamento {{ orcamentoStore.numeroOrcamento }} finalizado!</h2>

      <div class="resumo-totais">
        <div class="resumo-total-item">
          <span class="resumo-label">Total Venda</span>
          <span class="resumo-preco">{{ formatarMoeda(orcamentoStore.orcamentoHeader?.vnd_tot ?? 0) }}</span>
        </div>
        <div class="resumo-total-item">
          <span class="resumo-label">Total B2B</span>
          <span class="resumo-preco" style="color: var(--danger)">{{ formatarMoeda(orcamentoStore.orcamentoHeader?.vnd_B2B_tot ?? 0) }}</span>
        </div>
        <div class="resumo-total-item">
          <span class="resumo-label">Custo Total</span>
          <span>{{ formatarMoeda(orcamentoStore.orcamentoHeader?.cst_tot ?? 0) }}</span>
        </div>
        <div class="resumo-total-item">
          <span class="resumo-label">Lucro Total</span>
          <span>{{ formatarMoeda(orcamentoStore.orcamentoHeader?.luc_tot ?? 0) }}</span>
        </div>
        <div class="resumo-total-item">
          <span class="resumo-label">Margem</span>
          <span>{{ orcamentoStore.orcamentoHeader?.margem ?? margemPadrao }}%</span>
        </div>
        <div class="resumo-total-item">
          <span class="resumo-label">Validade</span>
          <span>{{ orcamentoStore.orcamentoHeader?.validade ? new Date(orcamentoStore.orcamentoHeader.validade).toLocaleDateString('en-US') : validadeCalculada }}</span>
        </div>
      </div>

      <div class="resumo-itens">
        <h3>Itens ({{ orcamentoStore.itensInseridos.length }})</h3>
        <div class="itens-tabela">
          <div class="itens-header">
            <span class="itens-col-num">#</span>
            <span class="itens-col-desc">Descrição</span>
            <span class="itens-col-dim">Dimensões</span>
            <span class="itens-col-qtd">Qtd</span>
            <span class="itens-col-vlr">Valor</span>
          </div>
          <div v-for="(item, idx) in orcamentoStore.itensInseridos" :key="item.id" class="itens-row">
            <span class="itens-col-num">{{ idx + 1 }}</span>
            <span class="itens-col-desc">{{ item.Descricao || item.descricao }}</span>
            <span class="itens-col-dim">{{ item.larg }} x {{ item.comp }} m</span>
            <span class="itens-col-qtd">{{ item.qtd }}</span>
            <span class="itens-col-vlr">{{ formatarMoeda(item.vlr_vnd_unit_b2b ?? item.vlr_vnd_unit ?? 0) }}</span>
          </div>
        </div>
      </div>

      <div class="btn-row resumo-actions">
        <button class="btn btn-primary btn-lg" @click="novoOrcamento">Novo Orçamento</button>
        <button class="btn btn-secondary btn-lg" disabled>Imprimir (em breve)</button>
      </div>
    </section>
  </template>
</div>
</template>

<style scoped>
.orcamento-page {
  padding: 1rem;
  max-width: 900px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.card {
  background: var(--card-bg, #fff);
  border-radius: 8px;
  padding: 1.25rem;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.08);
}

.welcome-card .welcome-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 0.75rem;
}

.welcome-cliente {
  display: flex;
  gap: 0.75rem;
  font-size: 0.85rem;
  color: #4b5563;
  margin-bottom: 0.5rem;
}

.welcome-cliente strong {
  color: #1f2937;
}

.welcome-card h2 {
  font-size: 1.2rem;
  margin: 0;
}

.subtitle {
  font-size: 0.85rem;
  color: var(--secondary);
  margin: 0.25rem 0 0;
}

.orc-num {
  font-weight: 700;
  font-size: 1.1rem;
  color: var(--primary);
  flex-shrink: 0;
}

.welcome-metrics {
  display: flex;
  gap: 1.5rem;
  flex-wrap: wrap;
}

.metric {
  font-size: 0.9rem;
  color: #4b5563;
}

.section-title {
  font-size: 0.9rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--secondary);
  margin: 0 0 1rem;
  padding-bottom: 0.4rem;
  border-bottom: 1px solid #e5e7eb;
}

.field {
  margin-bottom: 0.875rem;
}

.field label {
  display: block;
  font-size: 0.8rem;
  font-weight: 600;
  color: #374151;
  margin-bottom: 0.25rem;
}

.field input,
.field select,
.field textarea {
  width: 100%;
  padding: 0.5rem 0.7rem;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 0.9rem;
  color: #1f2937;
  background: #fff;
  outline: none;
  transition: border-color 0.15s;
}

.field input:focus,
.field select:focus,
.field textarea:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 2px rgba(37, 99, 235, 0.12);
}

.field textarea {
  resize: vertical;
  font-family: inherit;
}

.input-readonly {
  background: #f3f4f6 !important;
  cursor: default;
  color: #6b7280;
}

.input-big {
  font-size: 1.1rem !important;
  font-weight: 700;
}

.input-num {
  max-width: 160px;
}

.field-suffix {
  font-size: 0.8rem;
  color: var(--secondary);
  margin-left: 0.4rem;
}

.select-wrap {
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

.select-wrap select {
  flex: 1;
}

.btn-clear {
  background: none;
  border: none;
  cursor: pointer;
  color: #9ca3af;
  font-size: 1rem;
  padding: 0.2rem 0.4rem;
  border-radius: 4px;
  flex-shrink: 0;
}

.btn-clear:hover {
  color: #6b7280;
  background: #f3f4f6;
}

.dimensoes-row {
  display: flex;
  align-items: flex-end;
  gap: 0.75rem;
}

.dimensoes-x {
  font-weight: 700;
  font-size: 1.2rem;
  color: var(--secondary);
  padding-bottom: 0.5rem;
}

.flex-1 {
  flex: 1;
}

.btn-row {
  display: flex;
  gap: 0.75rem;
  flex-wrap: wrap;
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

.btn-primary {
  background: var(--primary);
  color: #fff;
}

.btn-primary:hover:not(:disabled) {
  background: #1d4ed8;
}

.btn-secondary {
  background: #f3f4f6;
  color: #374151;
}

.btn-secondary:hover:not(:disabled) {
  background: #e5e7eb;
}

.btn-lg {
  flex: 1;
  padding: 0.65rem 1.25rem;
}

.fc-display {
  font-size: 0.9rem;
  margin-bottom: 0.75rem;
}

.fc-item {
  color: var(--primary);
  font-weight: 600;
}

.area-fc-wrap {
  margin-top: 0.5rem;
}

.area-fc-input {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.area-fc-input input {
  flex: 1;
}

.btn-eye {
  background: none;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  color: var(--primary);
  flex-shrink: 0;
  transition: background 0.15s, color 0.15s, border-color 0.15s;
}

.btn-eye:hover {
  background: #f3f4f6;
}

.btn-eye.active {
  color: var(--danger);
  border-color: var(--danger-light);
}

.btn-eye svg {
  width: 18px;
  height: 18px;
}

.price-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.5rem 1rem;
  margin-bottom: 1rem;
}

.price-label {
  font-size: 0.85rem;
  font-weight: 600;
  color: #4b5563;
  display: flex;
  align-items: center;
}

.price-value {
  font-size: 0.95rem;
  font-weight: 700;
  text-align: right;
  padding: 0.35rem 0.6rem;
  border-radius: 4px;
}

.price-bg {
  background: #f3f4f6;
  color: #1f2937;
}

.price-b2b {
  background: #fef2f2;
  color: var(--danger);
}

.novo-valor-wrap {
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

.novo-valor-wrap input {
  max-width: 160px;
}

.btn-recalc {
  background: none;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  width: 34px;
  height: 34px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  color: var(--primary);
  font-size: 1.2rem;
  flex-shrink: 0;
  transition: background 0.15s;
}

.btn-recalc:hover {
  background: #eff6ff;
}

.field-hint {
  font-size: 0.75rem;
  color: var(--secondary);
  margin-top: 0.2rem;
}

.custos-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.5rem 1rem;
}

.custos-card {
  animation: fadeIn 0.2s ease;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(-8px); }
  to { opacity: 1; transform: translateY(0); }
}

.error-msg {
  color: var(--danger);
  font-size: 0.85rem;
  margin-top: 0.5rem;
}

.success-msg {
  color: #16a34a;
  font-size: 0.85rem;
  margin-top: 0.5rem;
  font-weight: 600;
}

.cliente-busca .field {
  margin-bottom: 0.5rem;
}

.cliente-loading {
  font-size: 0.8rem;
  color: var(--secondary);
  padding: 0.25rem 0;
}

.cliente-resultados {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  margin-bottom: 0.5rem;
}

.cliente-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  width: 100%;
  padding: 0.55rem 0.75rem;
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  text-align: left;
  cursor: pointer;
  font-size: 0.85rem;
  transition: background 0.15s;
}

.cliente-item:hover {
  background: #eff6ff;
  border-color: var(--primary);
}

.cliente-item strong {
  color: #1f2937;
}

.cliente-item span {
  color: var(--secondary);
  white-space: nowrap;
}

.cliente-selecionado {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
}

.cliente-info {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  font-size: 0.85rem;
}

.cliente-info strong {
  color: #1f2937;
}

.cliente-info span {
  color: var(--secondary);
}

.cliente-actions {
  display: flex;
  gap: 0.4rem;
  flex-shrink: 0;
}

.btn-sm {
  padding: 0.35rem 0.7rem;
  font-size: 0.8rem;
  border-radius: 5px;
  font-weight: 500;
  cursor: pointer;
  border: 1px solid #d1d5db;
  background: #fff;
  color: #374151;
  transition: background 0.15s;
}

.btn-sm:hover {
  background: #f3f4f6;
}

.btn-outline {
  border-color: #d1d5db;
}

.btn-success {
  background: #16a34a;
  color: #fff;
}

.btn-success:hover:not(:disabled) {
  background: #15803d;
}

.card-totais {
  background: #f0fdf4;
  border: 1px solid #bbf7d0;
}

.totais-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.75rem;
}

.totais-cliente {
  font-size: 0.85rem;
  color: #4b5563;
  font-weight: 600;
}

.totais-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.5rem;
}

.totais-item {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}

.totais-label {
  font-size: 0.65rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--secondary);
}

.totais-valor {
  font-size: 1rem;
  font-weight: 700;
  color: #1f2937;
}

.totais-b2b {
  color: var(--danger);
}

.totais-validade {
  font-size: 0.75rem;
  color: var(--secondary);
  margin-top: 0.5rem;
}

.itens-tabela {
  font-size: 0.85rem;
}

.itens-header,
.itens-row {
  display: flex;
  gap: 0.5rem;
  padding: 0.4rem 0;
  align-items: center;
}

.itens-header {
  font-weight: 700;
  color: var(--secondary);
  font-size: 0.75rem;
  text-transform: uppercase;
  border-bottom: 1px solid #e5e7eb;
}

.itens-row + .itens-row {
  border-top: 1px solid #f3f4f6;
}

.itens-col-num { width: 2rem; flex-shrink: 0; text-align: center; }
.itens-col-desc { flex: 1; }
.itens-col-dim { width: 6rem; flex-shrink: 0; text-align: center; }
.itens-col-qtd { width: 3rem; flex-shrink: 0; text-align: center; }
.itens-col-vlr { width: 6rem; flex-shrink: 0; text-align: right; }

.resumo-totais {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1rem;
  text-align: left;
  max-width: 500px;
  margin: 0 auto 1.5rem;
}

.resumo-total-item {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}

.resumo-itens {
  margin-top: 1.5rem;
  text-align: left;
  max-width: 600px;
  margin-left: auto;
  margin-right: auto;
}

.resumo-itens h3 {
  font-size: 0.9rem;
  font-weight: 700;
  margin-bottom: 0.5rem;
  color: #1f2937;
}

.resumo-card {
  text-align: center;
  padding: 2rem 1.5rem;
}

.resumo-card h2 {
  color: #16a34a;
  font-size: 1.25rem;
  margin-bottom: 1.5rem;
}

.resumo-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.25rem;
  text-align: left;
  max-width: 520px;
  margin: 0 auto 1.5rem;
}

.resumo-item {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}

.resumo-label {
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--secondary);
}

.resumo-preco {
  font-size: 1.3rem;
  font-weight: 700;
  color: var(--primary);
}

.resumo-actions {
  justify-content: center;
}

@media (max-width: 480px) {
  .resumo-grid {
    grid-template-columns: 1fr;
    gap: 0.75rem;
  }
}

@media (max-width: 639px) {
  .orcamento-page {
    padding: 0.75rem;
  }

  .card {
    padding: 1rem;
  }

  .welcome-metrics {
    flex-direction: column;
    gap: 0.35rem;
  }

  .price-grid,
  .custos-grid {
    grid-template-columns: 1fr;
  }

  .btn-row {
    flex-direction: column;
  }
}
</style>
