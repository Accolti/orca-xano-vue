<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useOrcamentoStore } from '@/stores/orcamento'
import { useAuthStore } from '@/stores/auth'
import { useClienteStore } from '@/stores/cliente'
import { useCatalogoStore } from '@/stores/catalogo'
import {
  gerarPdfOrcamento,
  gerarPdfPedidoVenda,
  montarTextoWhatsApp,
  obterWhatsappCliente,
  copiarEabrirWhatsApp,
} from '@/services/pdf'
import { xano } from '@/services/xano'
import { calcularCondicoesPagamento as calcularCondicoesUnificado } from '@/utils/condicoesPagamento'
import { provedoresDisponiveis } from '@/utils/taxasBanco'
import SimulacaoModal from '@/components/SimulacaoModal.vue'
import ClienteModal from '@/components/ClienteModal.vue'
import PagamentoModal from '@/components/PagamentoModal.vue'
import PendenciasPerfilBanner from '@/components/PendenciasPerfilBanner.vue'
import { gerarSimulacaoFront } from '@/utils/simulacao'
import type { SimulacaoItem } from '@/types/orcamento'
import type { Cliente } from '@/types/cliente'
import type { TaxaBanco } from '@/types/orcamento'

const route = useRoute()
const router = useRouter()
const codOrcaParam = route.params.codOrca as string | undefined
const isEditMode = computed(() => !!codOrcaParam)
const isVinculado = computed(() => {
  const e = orcamentoStore.orcamentoHeader?.eh_pedido
  return e === true || e === 'true' || e === 1 || e === '1'
})

const orcamentoStore = useOrcamentoStore()
const authStore = useAuthStore()
const clienteStore = useClienteStore()
const catalogo = useCatalogoStore()

const observacao = ref('')
const observacaoOrcamento = ref('')
const condicoesPagamento = ref('')
const mostrarCustos = ref(false)
const mostrarCustosHeader = ref(false)
const simulacaoModalOpen = ref(false)
const simulacaoSelecionada = ref<SimulacaoItem | null>(null)

// Altura (linhas) das caixas de condições e observações — botões +/− no mobile
const linhasCondicoes = ref(3)
const linhasObservacoes = ref(3)

// Auto-resize: a caixa cresce conforme o conteúdo (sem depender do puxador no mobile)
function autoResize(el: HTMLTextAreaElement | null) {
  if (!el) return
  el.style.height = 'auto'
  el.style.height = `${el.scrollHeight + 2}px`
}

// UI do seletor de condições de pagamento (Etapa 3)
const abaPagamento = ref<'pix' | 'cartao'>('pix')
const cartaoSelecionado = ref<string | null>(null)
const modoCondicoesAvancado = ref(false)
// Quem paga a taxa do cartão: true = cliente (gross-up, default) | false = a loja assume
const repassarTaxasCartao = ref(true)

// Tarefa 4 — checkboxes de métodos + mesclagem + desconto Pix + instituição
const metodosPagamento = ref<{ pix: boolean; boleto: boolean; cartao: boolean }>({
  pix: true,
  boleto: true,
  cartao: true,
})
const mesclarMetodos = ref(false)
const trazerTodasParcelas = ref(false)
const descontoPixPercentual = ref<number>(0)
// Nº de parcelas do boleto escolhido pelo vendedor (null = máximo calculado)
const parcelasBoleto = ref<number | null>(null)
// Nº de parcelas do Pix escolhido (null = 2x)
const parcelasPix = ref<number | null>(null)
const provedorSelecionado = ref<string | number | null>(null)
// Estado salvo do seletor (condicoes_pagamento_params) — para reaplicar ao carregar
const condicoesParamsSalvos = ref<string | null>(null)

const termoBuscaCliente = ref('')
const clienteSelecionado = ref<Cliente | null>(null)
const clienteModalOpen = ref(false)
const clienteModalId = ref<number | null>(null)
const clienteModalSomenteLeitura = ref(true)

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
    clienteModalSomenteLeitura.value = true
    clienteModalId.value = clienteSelecionado.value.id
    clienteModalOpen.value = true
  }
}

// Abre o modal em modo de criação; ao salvar, o novo cliente já entra
// selecionado (vinculado) no orçamento aberto.
function novoCliente() {
  clienteModalSomenteLeitura.value = false
  clienteModalId.value = null
  clienteModalOpen.value = true
}

function aoSalvarCliente(c?: Partial<Cliente>) {
  if (!c?.id) return
  const novo: Cliente = {
    id: c.id,
    tipo_pessoa: c.tipo_pessoa ?? '',
    razao_social: c.razao_social ?? '',
    nome_fantasia: c.nome_fantasia ?? '',
    contato: c.contato ?? '',
    cpf: c.cpf ?? '',
    nome_cpf: c.nome_cpf ?? '',
    cnpj: c.cnpj ?? '',
    inscricao_estadual: c.inscricao_estadual ?? '',
    'e-mail': c['e-mail'] ?? '',
    contribui_icms: c.contribui_icms ?? false,
    isento: c.isento ?? false,
    observacao: c.observacao ?? '',
    user_id: c.user_id ?? 0,
    beneficio_fiscal_id: c.beneficio_fiscal_id ?? 0,
    mercado_id: c.mercado_id ?? 0,
    ramo_id: c.ramo_id ?? 0,
    regime_id: c.regime_id ?? 0,
    created_at: c.created_at ?? 0,
    _enderecos: [],
    _telefone_cliente_of_cliente: [],
  }
  clienteSelecionado.value = novo
  termoBuscaCliente.value = ''
  clienteStore.clientes = []
}

const margemPadrao = computed(() => {
  // Orçamento existente com itens → margem registrada na ORCA
  if (orcamentoStore.itensInseridos.length > 0 && orcamentoStore.orcamentoHeader?.margem) {
    return orcamentoStore.orcamentoHeader.margem
  }
  // Orçamento novo ou sem itens (todos removidos) → margem do usuário
  return authStore.user?.margem ?? 100
})
const fretePadrao = computed(() => authStore.user?.frtB2B ?? 52)

const formValido = computed(() => {
  if (!clienteSelecionado.value) return false
  if (!orcamentoStore.materialSelecionado) return false
  if (orcamentoStore.unidadeSelecionada === 'UND') {
    if (!orcamentoStore.quantidade || orcamentoStore.quantidade < 1) return false
  } else if (orcamentoStore.ehML) {
    if (areaMLEfetiva.value <= 0) return false
  } else if (orcamentoStore.ehComposto) {
    if (orcamentoStore.modoEntradaComposto === 'area') {
      if (!orcamentoStore.areaML || orcamentoStore.areaML <= 0) return false
    } else {
      if (!orcamentoStore.largura || orcamentoStore.largura <= 0) return false
      if (!orcamentoStore.comprimento || orcamentoStore.comprimento <= 0) return false
    }
  } else {
    if (!orcamentoStore.largura || orcamentoStore.largura <= 0) return false
    if (!orcamentoStore.comprimento || orcamentoStore.comprimento <= 0) return false
  }
  if (
    orcamentoStore.mostrarLinha &&
    orcamentoStore.linhas.length &&
    !orcamentoStore.linhaSelecionada
  )
    return false
  if (orcamentoStore.mostrarTipo && orcamentoStore.tipos.length && !orcamentoStore.tipoSelecionado)
    return false
  if (
    orcamentoStore.mostrarNivel &&
    orcamentoStore.niveis.length &&
    !orcamentoStore.nivelSelecionado
  )
    return false
  if (
    orcamentoStore.mostrarBorda &&
    orcamentoStore.bordas.length &&
    !orcamentoStore.bordaSelecionada
  )
    return false
  if (orcamentoStore.mostrarVariacao && !orcamentoStore.variacaoSelecionada) return false
  return true
})

const fcArray = computed<number[]>(() => {
  const novo = orcamentoStore.resultadoNovo?.fc
  if (novo?.length) return novo
  const fatores = orcamentoStore.resultado?.Tipo_Fator_1
  if (!fatores?.length) return []
  const fc = fatores[0]
  return (fc?._fator_de_corte.valor ?? []).map(Number)
})

const produtoEncontrado = computed(() => {
  return orcamentoStore.resultado?.Produto_2?.[0] ?? null
})

const areaFaturada = computed(() => {
  const it = orcamentoStore.resultadoNovo
  if (it?.comp_fc && it?.larg_fc) return it.comp_fc * it.larg_fc
  return orcamentoStore.func1?.AreaFC ?? 0
})

onMounted(async () => {
  if (!isEditMode.value) {
    orcamentoStore.resetar()
    limparCliente()
    observacao.value = ''
    observacaoOrcamento.value = ''
    condicoesPagamento.value = ''
    faturarCliente.value = false
    mostrarCustos.value = false
    mostrarCustosHeader.value = false
    simulacaoSelecionada.value = null
    inserirOk.value = false
    mostrarResumo.value = false
    finalizando.value = false
    modoEntradaML.value = 'area'
    resetarCondicoesUi()
  }
  orcamentoStore.carregarMateriais()
  catalogo.fetchTaxasBanco().catch(() => {})
  if (isEditMode.value && codOrcaParam) {
    try {
      await orcamentoStore.carregarOrcamento(codOrcaParam)
      // Pedido (convertido) é read-only: abre direto na tela finalizada
      if (isVinculado.value) mostrarResumo.value = true
      const orcaId = orcamentoStore.orcamentoHeader?.id
      if (orcaId) {
        await orcamentoStore.carregarStatusHistorico(orcaId)
        await orcamentoStore.carregarControlePedido(orcaId)
      }
      sincronizarSimulacao()
      const header = orcamentoStore.orcamentoHeader
      if (header?._cliente) {
        const c = header._cliente
        clienteSelecionado.value = {
          id: c.id,
          razao_social: c.razao_social || '',
          nome_fantasia: c.nome_fantasia || '',
          contato: c.contato || '',
          cpf: c.cpf || '',
          nome_cpf: c.nome_cpf || '',
          cnpj: c.cnpj || '',
          inscricao_estadual: c.inscricao_estadual || '',
          'e-mail': c['e-mail'] || '',
          contribui_icms: c.contribui_icms ?? false,
          isento: c.isento ?? false,
          observacao: c.observacao || '',
          user_id: c.user_id ?? 0,
          beneficio_fiscal_id: c.beneficio_fiscal_id ?? null,
          mercado_id: c.mercado_id ?? null,
          ramo_id: c.ramo_id ?? null,
          regime_id: c.regime_id ?? null,
          created_at: c.created_at ?? 0,
          _enderecos: c._enderecos ?? [],
          _telefone_cliente_of_cliente: c._telefone_cliente_of_cliente ?? [],
        }
      }
    } catch {
      /* error stays in store */
    }
  }
})

function toggleCustos() {
  mostrarCustos.value = !mostrarCustos.value
}

function toggleCustosHeader() {
  mostrarCustosHeader.value = !mostrarCustosHeader.value
}

async function handleCalcular() {
  simulacaoSelecionada.value = null
  await orcamentoStore.calcularOrquestrador(modoEntradaML.value)
}

async function handleSimular() {
  simulacaoSelecionada.value = null
  await orcamentoStore.calcularOrquestrador(modoEntradaML.value)
  if (simulacaoLista.value.length) {
    simulacaoModalOpen.value = true
  }
}

function selecionarSimulacao(item: SimulacaoItem) {
  simulacaoSelecionada.value = item
  // Aplica a margem escolhida no quadro de totais (Ajustar Orçamento)
  novaMargemResumo.value = item.margem
  if (custoTotalBase.value > 0) simularPorMargem()
  // Não fecha a modal: o usuário pode continuar comparando as opções;
  // fecha apenas ao clicar em ✕ ou fora da modal.
}

const inserirOk = ref(false)
const mostrarResumo = ref(false)
const finalizando = ref(false)
const resumoAberto = ref(true)
const editandoItemId = ref<number | null>(null)

const validadeCalculada = computed(() => {
  const dias = authStore.user?.DiasVencimentoOrcamento ?? 15
  const venc = new Date(Date.now() + dias * 86400000)
  return venc.toLocaleDateString('en-US')
})

async function handleInserir() {
  if (!clienteSelecionado.value) return
  inserirOk.value = false
  try {
    if (editandoItemId.value) {
      await orcamentoStore.atualizarItem(editandoItemId.value, observacao.value)
      editandoItemId.value = null
    } else {
      await orcamentoStore.inserirOrcamento(
        clienteSelecionado.value.id,
        observacao.value,
        isEditMode.value ? codOrcaParam : undefined,
        observacaoOrcamento.value,
        orcaIdAtual.value ?? undefined,
      )
    }
    inserirOk.value = true
    observacao.value = ''
  } catch {
    /* error já definido no store */
  }
}

function cancelarEdicaoItem() {
  editandoItemId.value = null
  orcamentoStore.limparFormItem()
  observacao.value = ''
}
async function handleFinalizar() {
  // Persiste condições, observação e negociação antes de mostrar a tela finalizada
  await persistirCondicoesPagamento()
  finalizando.value = true
  mostrarResumo.value = true
}

function novoOrcamento() {
  orcamentoStore.resetar()
  limparCliente()
  observacao.value = ''
  observacaoOrcamento.value = ''
  condicoesPagamento.value = ''
  faturarCliente.value = false
  mostrarCustos.value = false
  mostrarCustosHeader.value = false
  simulacaoSelecionada.value = null
  inserirOk.value = false
  mostrarResumo.value = false
  finalizando.value = false
  modoEntradaML.value = 'area'
  resetarCondicoesUi()
  router.push('/orcamentos/novo')
}

// Item calculado do novo orquestrador — objeto flat (não mais itens[0])
const itemCalc = computed(() => (orcamentoStore.resultadoNovo as any) ?? null)

// Para ML, o usuário pode informar Área (m²) diretamente ou Largura × Comprimento
const modoEntradaML = ref<'area' | 'dimensoes'>('area')

// Área efetiva do ML: se informou área, usa; senão calcula de larg × comp
const areaMLEfetiva = computed(() => {
  if (modoEntradaML.value === 'area') return orcamentoStore.areaML
  return (orcamentoStore.largura || 0) * (orcamentoStore.comprimento || 0)
})

// Lista de simulação de margens gerada no front (faixa padrão 50–100, rótulos c5..c10).
// Base de custo: item calculado (novo orquestrador) → cabeçalho cst_tot.
const simulacaoLista = computed(() => {
  const custo = Number(itemCalc.value?.vlr_cst_entrada_tot) || Number(custoTotalBase.value) || 0
  const qtd = Number(itemCalc.value?.qtd) || 1
  return custo > 0 ? gerarSimulacaoFront(custo, qtd) : []
})

const valorVendaTotalB2B = computed(() => {
  if (simulacaoSelecionada.value) return simulacaoSelecionada.value.Valor_Venda_Total_B2B
  if (itemCalc.value) return itemCalc.value.vlr_vnd_tot ?? 0
  return orcamentoStore.func1?.Valor_Venda_Total_B2B ?? 0
})

const valorVendaUnitB2B = computed(() => {
  if (simulacaoSelecionada.value) return simulacaoSelecionada.value.Valor_Venda_Unit_B2B
  if (itemCalc.value) return itemCalc.value.vlr_vnd_unit ?? 0
  return orcamentoStore.func1?.Valor_Venda_Unit_B2B ?? 0
})

const lucroTotal = computed(() => {
  if (simulacaoSelecionada.value) return simulacaoSelecionada.value.Valor_Lucro_Total
  if (itemCalc.value) return itemCalc.value.vlr_lucro_tot ?? 0
  return orcamentoStore.func1?.Valor_Lucro_Total ?? 0
})

const lucroUnit = computed(() => {
  if (simulacaoSelecionada.value) return simulacaoSelecionada.value.Valor_Lucro_Unit
  if (itemCalc.value) return itemCalc.value.vlr_lucro_unit ?? 0
  return orcamentoStore.func1?.Valor_Lucro_Unit ?? 0
})

const custoTotal = computed(() => {
  if (simulacaoSelecionada.value) return simulacaoSelecionada.value.Valor_Custo_Total
  if (itemCalc.value) return itemCalc.value.vlr_cst_entrada_tot ?? 0
  return orcamentoStore.func1?.Valor_Custo_Total ?? 0
})

const custoUnit = computed(() => {
  if (simulacaoSelecionada.value) return simulacaoSelecionada.value.Valor_Custo_Unit
  if (itemCalc.value) return itemCalc.value.vlr_cst_entrada_unit ?? 0
  return orcamentoStore.func1?.Valor_Custo_Unit ?? 0
})

const novaMargemResumo = ref(0)
const novoValorVendaResumo = ref(0)
const novoLucroResumo = ref(0)
const margemRealResumo = ref(0)
const freteB2CResumo = ref(0)
const descontoResumo = ref(0)
const maoDeObraResumo = ref(0)
const recaleError = ref<string | null>(null)
const faturarCliente = ref(false)

// Custo de entrada + frete B2B (fixo na negociação)
const custoTotalBase = computed(() => orcamentoStore.orcamentoHeader?.cst_tot ?? 0)

// Custo pago à Kapazi = Σ (vlr_cst_nota_unit × qtd) — só visualização
const custoKapaziTotal = computed(() =>
  orcamentoStore.itensInseridos.reduce(
    (acc, it) =>
      acc + (it.vlr_cst_nota_unit ?? it.vlr_custo_nota_unit ?? it.vlr_custo ?? 0) * (it.qtd ?? 1),
    0,
  ),
)

// Desconto Kapazi (metadado no ControlePedido) — só aumenta o lucro, não altera a venda.
// desconto = custoKapaziTotal × perc/100; lucro real = luc_tot + desconto.
const descontoKapazi = computed(() => {
  const perc = Number(orcamentoStore.controlePedido?.desconto_kapazi_perc) || 0
  if (perc <= 0) return 0
  return (custoKapaziTotal.value * perc) / 100
})
const custoKapaziEfetivo = computed(() => custoKapaziTotal.value - descontoKapazi.value)
const lucroRealKapazi = computed(
  () => (orcamentoStore.orcamentoHeader?.luc_tot ?? 0) + descontoKapazi.value,
)
const margemRealKapazi = computed(() => {
  const vnd = orcamentoStore.orcamentoHeader?.vnd_tot ?? 0
  if (vnd <= 0) return 0
  return (lucroRealKapazi.value / vnd) * 100
})

// Preview ao vivo da negociação (valores simulados, não persistidos)
const previewVenda = computed(() => novoValorVendaResumo.value)
const previewLucro = computed(() => novoLucroResumo.value)
const previewMargemEfetiva = computed(() => {
  const cst = custoTotalBase.value
  if (cst <= 0) return 0
  return round2(((novoValorVendaResumo.value - cst) / cst) * 100)
})
const previewTotalB2C = computed(
  () =>
    (novoValorVendaResumo.value || 0) + (freteB2CResumo.value || 0) + (maoDeObraResumo.value || 0),
)

// Diferença do Total c/ Frete B2C (preview simulado − total atual persistido)
const diferencaTotalB2C = computed(
  () => previewTotalB2C.value - (orcamentoStore.orcamentoHeader?.vnd_B2B_B2C_tot ?? 0),
)

function round2(n: number) {
  return Math.round(n * 100) / 100
}

function round6(n: number) {
  return Math.round(n * 1_000_000) / 1_000_000
}

// Sincroniza a simulação com os valores oficiais (base do header/totais)
function sincronizarSimulacao() {
  const header = orcamentoStore.orcamentoHeader
  const totais = orcamentoStore.totaisRecalculo
  const base = totais?.markup_alvo ?? header?.margem ?? 0
  novaMargemResumo.value = base
  novoValorVendaResumo.value = header?.vnd_tot ?? 0
  novoLucroResumo.value = header?.luc_tot ?? 0
  descontoResumo.value = totais?.desconto ?? header?.desconto ?? 0
  freteB2CResumo.value = totais?.frtB2C ?? header?.frtB2C ?? 0
  maoDeObraResumo.value = totais?.mao_de_obra ?? header?.mao_de_obra ?? 0
  observacaoOrcamento.value = header?.observacao ?? ''
  condicoesPagamento.value = (header?.condicoes_pagamento || '').trim()
  condicoesParamsSalvos.value = header?.condicoes_pagamento_params || null
  restaurarCondicoesParams(condicoesParamsSalvos.value)
  const vendaFinal = novoValorVendaResumo.value
  const cst = custoTotalBase.value
  margemRealResumo.value =
    totais?.margem_real_total ??
    (vendaFinal > 0 && cst > 0 ? round2(((vendaFinal - cst) / vendaFinal) * 100) : 0)
}

watch(
  [() => orcamentoStore.orcamentoHeader?.id, () => orcamentoStore.itensInseridos.length],
  () => {
    if (orcamentoStore.orcamentoHeader?.id) sincronizarSimulacao()
  },
)

// Reaplica o estado salvo do seletor quando as taxas de cartão terminam de carregar
// (na abertura, o header chega antes do /taxas_banco — a validação do cartão depende delas).
watch(
  () => catalogo.taxasBanco,
  () => {
    if (condicoesParamsSalvos.value) restaurarCondicoesParams(condicoesParamsSalvos.value)
  },
)

// Estado do seletor de condições → JSON persistido em Orca.condicoes_pagamento_params.
// Permite restaurar checkboxes, desconto Pix %, instituição, parcelas e repasse ao reabrir.
function serializarCondicoesParams(): string {
  let provedorId: number | null = null
  let provedor: string | null = null
  let parcelas: number | null = null
  if (cartaoSelecionado.value) {
    const [pid, parc] = cartaoSelecionado.value.split('|')
    provedorId = Number(pid) || null
    parcelas = Number(parc) || null
    const op = condicoesCalculadas.value.cartao.find(
      (o) => chaveCartao(o) === cartaoSelecionado.value,
    )
    provedor = op?.provedor ?? null
  }
  if (provedorId == null && provedorSelecionado.value != null) {
    provedorId = Number(provedorSelecionado.value) || null
  }
  return JSON.stringify({
    metodos: { ...metodosPagamento.value },
    mesclar: mesclarMetodos.value,
    trazerTodasParcelas: trazerTodasParcelas.value,
    descontoPixPercentual: descontoPixPercentual.value,
    parcelas_boleto: parcelasBoleto.value,
    parcelas_pix: parcelasPix.value,
    provedorId,
    provedor,
    parcelas,
    repassarTaxas: repassarTaxasCartao.value,
    aba: abaPagamento.value,
  })
}

// Restaura os refs do seletor a partir do JSON salvo. Defensivo: instituição e parcela
// só voltam se ainda existirem nas taxas atuais (senão a seleção é limpa).
function restaurarCondicoesParams(paramsStr?: string | null) {
  if (!paramsStr) return
  let p: any
  try {
    p = JSON.parse(paramsStr)
  } catch {
    return
  }
  if (!p || typeof p !== 'object') return
  if (p.metodos && typeof p.metodos === 'object') {
    metodosPagamento.value = {
      pix: p.metodos.pix !== false,
      boleto: p.metodos.boleto !== false,
      cartao: p.metodos.cartao !== false,
    }
  }
  mesclarMetodos.value = Boolean(p.mesclar)
  trazerTodasParcelas.value = Boolean(p.trazerTodasParcelas)
  if (typeof p.descontoPixPercentual === 'number') {
    descontoPixPercentual.value = p.descontoPixPercentual
  }
  if (typeof p.parcelas_boleto === 'number' && p.parcelas_boleto >= 1) {
    parcelasBoleto.value = p.parcelas_boleto
  }
  if (typeof p.parcelas_pix === 'number' && (p.parcelas_pix === 1 || p.parcelas_pix === 2)) {
    parcelasPix.value = p.parcelas_pix
  }
  repassarTaxasCartao.value = typeof p.repassarTaxas === 'boolean' ? p.repassarTaxas : true
  if (p.aba === 'pix' || p.aba === 'cartao') abaPagamento.value = p.aba

  const pId = p.provedorId != null ? Number(p.provedorId) : null
  const provedorExiste =
    pId != null && provedoresDisponiveis(catalogo.taxasBanco).some((x) => Number(x.id) === pId)
  provedorSelecionado.value = provedorExiste ? pId : null

  const chave = provedorExiste && p.parcelas != null ? `${pId}|${p.parcelas}` : null
  const chaveExiste =
    chave != null && condicoesCalculadas.value.cartao.some((o) => chaveCartao(o) === chave)
  cartaoSelecionado.value = chaveExiste ? chave : null
}

// Reseta o seletor de condições para os defaults (orçamento novo)
function resetarCondicoesUi() {
  abaPagamento.value = 'pix'
  cartaoSelecionado.value = null
  repassarTaxasCartao.value = true
  metodosPagamento.value = { pix: true, boleto: true, cartao: true }
  mesclarMetodos.value = false
  trazerTodasParcelas.value = false
  descontoPixPercentual.value = 0
  parcelasBoleto.value = null
  parcelasPix.value = null
  provedorSelecionado.value = null
  condicoesParamsSalvos.value = null
}

// 1. Simulação em memória (sem chamada de API por tecla)
// Ao digitar um campo, recalcula os demais em tempo real.

function simularPorMargem() {
  const cst = custoTotalBase.value
  if (cst <= 0) return
  const dsc = descontoResumo.value || 0
  const vendaBruta = cst * (1 + (novaMargemResumo.value || 0) / 100)
  novoValorVendaResumo.value = round2(vendaBruta - dsc)
  novoLucroResumo.value = round2(vendaBruta - dsc - cst)
  margemRealResumo.value =
    novoValorVendaResumo.value > 0
      ? round2(((novoValorVendaResumo.value - cst) / novoValorVendaResumo.value) * 100)
      : 0
}

function simularPorVenda() {
  const cst = custoTotalBase.value
  if (cst <= 0) return
  const dsc = descontoResumo.value || 0
  const vendaFinal = novoValorVendaResumo.value || 0
  novoLucroResumo.value = round2(vendaFinal - cst)
  margemRealResumo.value = vendaFinal > 0 ? round2(((vendaFinal - cst) / vendaFinal) * 100) : 0
  const vendaBruta = vendaFinal + dsc
  novaMargemResumo.value = round6((vendaBruta / cst - 1) * 100)
}

function simularPorLucro() {
  const cst = custoTotalBase.value
  if (cst <= 0) return
  const dsc = descontoResumo.value || 0
  const lucro = novoLucroResumo.value || 0
  const vendaFinal = cst + lucro
  novoValorVendaResumo.value = round2(vendaFinal)
  margemRealResumo.value = vendaFinal > 0 ? round2((lucro / vendaFinal) * 100) : 0
  novaMargemResumo.value = round6(((vendaFinal + dsc) / cst - 1) * 100)
}

function simularPorMargemReal() {
  const cst = custoTotalBase.value
  if (cst <= 0) return
  const mr = margemRealResumo.value || 0
  if (mr >= 100) return
  const vendaFinal = mr <= 0 ? 0 : cst / (1 - mr / 100)
  novoValorVendaResumo.value = round2(vendaFinal)
  novoLucroResumo.value = round2(vendaFinal - cst)
  const dsc = descontoResumo.value || 0
  novaMargemResumo.value = round6(((vendaFinal + dsc) / cst - 1) * 100)
}

function simularPorDesconto() {
  const cst = custoTotalBase.value
  if (cst <= 0) return
  const dsc = descontoResumo.value || 0
  const vendaBruta = cst * (1 + (novaMargemResumo.value || 0) / 100)
  novoValorVendaResumo.value = round2(Math.max(vendaBruta - dsc, 0))
  novoLucroResumo.value = round2(Math.max(vendaBruta - dsc - cst, 0))
  const vendaFinal = novoValorVendaResumo.value
  margemRealResumo.value = vendaFinal > 0 ? round2(((vendaFinal - cst) / vendaFinal) * 100) : 0
}

function simularPorFreteB2C() {
  // Frete B2C é aditivo: só atualiza o Total c/ Frete B2C (preview)
}

// 2. Aplicação oficial no servidor (envia margem base + desconto + frete B2C numa chamada)
async function aplicarNegociacao() {
  const orcaId = orcaIdAtual.value
  if (!orcaId) return
  if (novaMargemResumo.value <= 0) {
    if (!confirm('Você deseja realmente zerar a margem do orçamento?')) return
  }
  recaleError.value = null
  try {
    console.log('[aplicarNegociacao] payload', {
      orcaId,
      newMargem: novaMargemResumo.value,
      desconto: Number(descontoResumo.value) || 0,
      frtB2C: Number(freteB2CResumo.value) || 0,
      maoDeObra: Number(maoDeObraResumo.value) || 0,
      observacao: observacaoOrcamento.value,
      condicoesPagamento: condicoesPagamento.value,
    })
    await orcamentoStore.recalcularTotais(orcaId, {
      newMargem: novaMargemResumo.value,
      desconto: Number(descontoResumo.value) || 0,
      frtB2C: Number(freteB2CResumo.value) || 0,
      maoDeObra: Number(maoDeObraResumo.value) || 0,
      observacao: observacaoOrcamento.value,
      condicoesPagamento: condicoesPagamento.value,
      condicoesPagamentoParams: serializarCondicoesParams(),
    })
    sincronizarSimulacao()
  } catch (err: any) {
    recaleError.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao recalcular'
  }
}

// Código do orçamento atual: gerado na inserção ou o da rota em edição
const codOrcaAtual = computed(() => orcamentoStore.numeroOrcamento ?? codOrcaParam ?? '')

// id numérico do orçamento (usado no recálculo por somatório)
const orcaIdAtual = computed(() => orcamentoStore.orcamentoHeader?.id ?? null)

function voltarLista() {
  const origem = route.query.origem
  if (origem === 'pedidos') {
    router.push('/pedidos')
  } else {
    router.push('/orcamentos')
  }
}

function editarItem(item: any) {
  if (!item?.id) return
  // Resolve o produto do catálogo pelo produto_id do item
  const prod = catalogo.allProdutos.find((p) => p.produto_id === item.produto_id)
  const material = catalogo.allMaterials.find(
    (m) => m.id === (prod?.material_id ?? item.material_id),
  )

  editandoItemId.value = item.id
  orcamentoStore.limparFormItem()

  if (!material) {
    console.warn('Material do item não encontrado no catálogo', item)
    return
  }
  orcamentoStore.selecionarMaterial(material)

  const linha =
    catalogo.allLinhas.find((l) => l.id === (item.linha_id ?? prod?.linha_id ?? 0)) ?? null
  const tipo = catalogo.allTipos.find((t) => t.id === (item.tipo_id ?? prod?.tipo_id ?? 0)) ?? null
  const nivel =
    catalogo.allNiveis.find((n) => n.id === (item.nivel_id ?? prod?.nivel_id ?? 0)) ?? null
  const borda = catalogo.allBordas.find((b) => b.id === (item.borda_id ?? 0)) ?? null

  if (linha) orcamentoStore.linhaSelecionada = linha
  if (tipo) orcamentoStore.tipoSelecionado = tipo
  if (nivel) orcamentoStore.nivelSelecionado = nivel
  if (borda) orcamentoStore.bordaSelecionada = borda

  if (item.variacao_id) {
    const varItem = orcamentoStore.variacoes.find((v) => v.id === item.variacao_id)
    if (varItem) orcamentoStore.variacaoSelecionada = varItem
  }

  orcamentoStore.largura = item.larg ?? 0
  orcamentoStore.comprimento = item.comp ?? 0
  orcamentoStore.quantidade = item.qtd ?? 1
  orcamentoStore.medidaExata = item.com_medida_exata === true
  if (orcamentoStore.ehML) {
    orcamentoStore.areaML = item.area_calc ?? 0
    modoEntradaML.value = item.area_calc ? 'area' : 'dimensoes'
  }
  if (orcamentoStore.ehComposto && item.detalhes_calculo?.playkap) {
    const p = item.detalhes_calculo.playkap
    orcamentoStore.rampaLarg1 = !!p.lados?.rampa_larg1
    orcamentoStore.rampaComp1 = !!p.lados?.rampa_comp1
    orcamentoStore.rampaLarg2 = !!p.lados?.rampa_larg2
    orcamentoStore.rampaComp2 = !!p.lados?.rampa_comp2
    orcamentoStore.qtdCantos = p.cantoneiras ?? 0
    // Restaura em modo dimensões com as medidas digitadas pelo usuário (comp × larg).
    // O orquestrador recalcula a grade (múltiplos de 30cm) a partir delas.
    orcamentoStore.modoEntradaComposto = 'dimensoes'
    orcamentoStore.largura = item.larg ?? 0
    orcamentoStore.comprimento = item.comp ?? 0
  }
  observacao.value = item.descricao ?? ''
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

async function removerItem(item: any, idx: number) {
  if (!item?.id) return
  if (!confirm('Remover este item do orçamento?')) return
  try {
    await orcamentoStore.removerItem(item.id)
  } catch {
    /* error já definido no store */
  }
}

function formatarMoeda(valor: number | string | null | undefined): string {
  return `R$ ${(Number(valor) || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

// Composição do produto composto PLAYKAP (a partir do detalhes_calculo gravado no item).
// Ex.: "578 placas + 102 rampas (51 M / 51 F) + 4 cantoneiras"
function composicaoPlaykap(item: any): string {
  const p = item?.detalhes_calculo?.playkap
  if (!p) return ''
  const partes: string[] = []
  if (p.placas) partes.push(`${p.placas} placas`)
  if (p.rampas_total)
    partes.push(`${p.rampas_total} rampas (${p.rampas_macho} M / ${p.rampas_femea} F)`)
  if (p.cantoneiras) partes.push(`${p.cantoneiras} cantoneiras`)
  return partes.join(' + ')
}

// Composição de venda por ML (detalhes_calculo.ml) — rolos/metros/orientação.
// Ex.: "3 rolo(s) — 2,5 m fracionado — <orientação>"; com rolos, o total entra na frente:
// "32,5 m — 3 rolo(s) — 2,5 m fracionado — <orientação>". Sem rolos, só o fracionado.
function composicaoML(item: any): string {
  const m = item?.detalhes_calculo?.ml
  if (!m) return ''
  const partes: string[] = []
  const total = Number(m.totalMetrosLineares) || 0
  const rolos = Number(m.rolosFechados) || 0
  const frac = Number(m.metrosFracionados) || 0
  if (rolos > 0 && total > 0) partes.push(`${total} m`)
  if (rolos > 0) partes.push(`${rolos} rolo(s)`)
  if (frac > 0) partes.push(`${frac} m fracionado`)
  if (m.orientacaoIdeal) partes.push(m.orientacaoIdeal)
  return partes.join(' — ')
}

// Composição combinada: PLAYKAP ou ML (a que existir no detalhes_calculo do item)
function composicaoItemView(item: any): string {
  return composicaoPlaykap(item) || composicaoML(item)
}

// Dimensão exibida na lista de itens — sempre 2 casas decimais (itens antigos podem ter
// valores brutos, ex.: sqrt de área = 7.0710678118654755).
function formatarDimensaoItem(item: any): string {
  const larg = Number(item?.larg ?? 0)
  const comp = Number(item?.comp ?? 0)
  return `${larg.toFixed(2)} x ${comp.toFixed(2)} m`
}

function formatarDataHora(ts: number | string | null | undefined): string {
  if (!ts) return ''
  const d = new Date(ts)
  if (Number.isNaN(d.getTime())) return String(ts)
  return d.toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function formatarMargemReal(): string {
  const mr = margemRealResumo.value || 0
  return `${mr.toFixed(2).replace('.', ',')}%`
}

function formatarMargemRealKapazi(): string {
  const mr = margemRealKapazi.value || 0
  return `${mr.toFixed(2).replace('.', ',')}%`
}

// Persiste as condições de pagamento editadas na ORCA antes de enviar.
// Envia também os demais campos atuais — o backend grava incondicionalmente (0 não é vazio).
async function persistirCondicoesPagamento(): Promise<boolean> {
  const orcaId = orcaIdAtual.value
  if (!orcaId) return false
  try {
    await orcamentoStore.recalcularTotais(orcaId, {
      newMargem: novaMargemResumo.value,
      frtB2C: Number(freteB2CResumo.value) || 0,
      desconto: Number(descontoResumo.value) || 0,
      maoDeObra: Number(maoDeObraResumo.value) || 0,
      observacao: observacaoOrcamento.value,
      condicoesPagamento: condicoesPagamento.value,
      condicoesPagamentoParams: serializarCondicoesParams(),
    })
    return true
  } catch (err: any) {
    recaleError.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao salvar condições'
    return false
  }
}

// Condições padrão calculadas (Pix 2x + Boleto parcelado + Cartão) para o total atual.
// "Gerar Condições" sempre combina os métodos marcados nos checkboxes.
function calcularCondicoesPadrao(): string {
  const header = orcamentoStore.orcamentoHeader
  return calcularCondicoesUnificado({
    valorVenda: Number(header?.vnd_B2B_B2C_tot) || Number(header?.vnd_tot) || 0,
    valorCusto: Number(header?.cst_tot) || 0,
    faturar: faturarCliente.value,
    tabelaTaxasCartao: catalogo.taxasBanco,
    repassarTaxasCartao: repassarTaxasCartao.value,
    descontoPixPercentual: descontoPixPercentual.value,
    provedorSelecionado: provedorSelecionado.value,
    metodos: metodosPagamento.value,
    mesclar: true,
    parcelaCartao: cartaoSelecionado.value ? Number(cartaoSelecionado.value.split('|')[1]) : null,
    trazerTodasParcelas: trazerTodasParcelas.value,
    parcelasBoleto: parcelasBoleto.value ?? undefined,
    parcelasPix: parcelasPix.value ?? undefined,
  }).texto
}

// Opções calculadas do seletor (dados estruturados, sem texto)
const condicoesCalculadas = computed(() => {
  const header = orcamentoStore.orcamentoHeader
  return calcularCondicoesUnificado({
    valorVenda: Number(header?.vnd_B2B_B2C_tot) || Number(header?.vnd_tot) || 0,
    valorCusto: Number(header?.cst_tot) || 0,
    faturar: faturarCliente.value,
    tabelaTaxasCartao: catalogo.taxasBanco,
    repassarTaxasCartao: repassarTaxasCartao.value,
    descontoPixPercentual: descontoPixPercentual.value,
    provedorSelecionado: provedorSelecionado.value,
    metodos: metodosPagamento.value,
    mesclar: mesclarMetodos.value,
    parcelaCartao: cartaoSelecionado.value ? Number(cartaoSelecionado.value.split('|')[1]) : null,
    trazerTodasParcelas: trazerTodasParcelas.value,
    parcelasBoleto: parcelasBoleto.value ?? undefined,
    parcelasPix: parcelasPix.value ?? undefined,
  })
})

// Máximo de parcelas do boleto (segue o cálculo padrão: venda ÷ metade do custo)
const maxParcelasBoleto = computed(() => Math.max(1, condicoesCalculadas.value.boletoMax ?? 1))

// Instituições disponíveis na tabela de taxas (seletor aparece quando > 1)
const provedores = computed(() => provedoresDisponiveis(catalogo.taxasBanco))

// ---- Controle financeiro (gerar parcelas a partir das condições negociadas) ----
const pagamentoModalOpen = ref(false)
// Quando o modal for aberto pelo "Faturar", guarda o status a aplicar após salvar.
const statusPosFinanceiro = ref<string | null>(null)
const pagamentoModalModoFaturamento = computed(() => statusPosFinanceiro.value === 'FATURADO')

// "Faturar" abre o Financeiro para cadastrar/confirmar os boletos; só após salvar
// as parcelas o status avança para FATURADO.
function faturarComParcelas() {
  statusPosFinanceiro.value = 'FATURADO'
  pagamentoModalOpen.value = true
}

function abrirFinanceiro() {
  statusPosFinanceiro.value = null
  pagamentoModalOpen.value = true
}

function aoSalvarFinanceiro() {
  const destino = statusPosFinanceiro.value
  statusPosFinanceiro.value = null
  if (destino) mudarStatus(destino)
}
const pagamentoModalVenda = computed(() => {
  const header = orcamentoStore.orcamentoHeader
  return Number(header?.vnd_B2B_B2C_tot) || Number(header?.vnd_tot) || 0
})
const pagamentoModalCusto = computed(() => Number(orcamentoStore.orcamentoHeader?.cst_tot) || 0)
const pagamentoModalCartao = computed(() =>
  condicoesCalculadas.value.cartao.map((o) => ({
    parcelas: o.parcelas,
    valorParcela: o.parcela,
    total: o.total,
  })),
)
const pagamentoModalParcelasCartao = computed(() =>
  cartaoSelecionado.value ? Number(cartaoSelecionado.value.split('|')[1]) : null,
)

// Impacto do desconto Pix na margem/lucro (exibido na aba Pix)
const pixImpacto = computed(() => condicoesCalculadas.value.pixImpacto)

// Cartão selecionado (informação completa para o badge do vendedor).
// A seleção é por chave "provedorId|parcelas" (evita ambiguidade com vários provedores).
function chaveCartao(o: { provedor_id?: number | null; parcelas: number }): string {
  return `${o.provedor_id ?? '?'}|${o.parcelas}`
}
const cartaoSelecionadoInfo = computed(() =>
  condicoesCalculadas.value.cartao.find((o) => chaveCartao(o) === cartaoSelecionado.value),
)

// Estado das condições de pagamento em relação ao que está salvo na ORCA
const condicoesPendentes = computed(
  () =>
    condicoesPagamento.value.trim() !==
    (orcamentoStore.orcamentoHeader?.condicoes_pagamento || '').trim(),
)
const condicoesSalvas = computed(() =>
  Boolean((orcamentoStore.orcamentoHeader?.condicoes_pagamento || '').trim()),
)

// Lucro do cartão conforme o modo:
// - Cliente paga (gross-up): você recebe a venda cheia → lucro = venda − custo
// - Eu assumo: você recebe o líquido → lucro real = voceRecebeLiquido − custo
const lucroCartao = computed(() => {
  const header = orcamentoStore.orcamentoHeader
  const venda = Number(header?.vnd_B2B_B2C_tot) || Number(header?.vnd_tot) || 0
  const custo = Number(header?.cst_tot) || 0
  if (repassarTaxasCartao.value) return venda - custo
  const op = cartaoSelecionadoInfo.value
  return op ? op.voceRecebeLiquido - custo : venda - custo
})

const margemRealCartao = computed(() => {
  const header = orcamentoStore.orcamentoHeader
  const venda = Number(header?.vnd_B2B_B2C_tot) || Number(header?.vnd_tot) || 0
  if (venda <= 0) return 0
  return (lucroCartao.value / venda) * 100
})

// Custo da taxa absorvido pela loja (só no modo "eu assumo")
const custoDaTaxa = computed(() => {
  if (repassarTaxasCartao.value) return 0
  return cartaoSelecionadoInfo.value?.custoTaxa ?? 0
})

// Cor do badge: verde (cliente paga) | âmbar (assume com lucro) | vermelho (assume no prejuízo)
const corBadgeCartao = computed(() => {
  if (!repassarTaxasCartao.value) {
    return lucroCartao.value > 0 ? 'badge-alerta' : 'badge-recusado'
  }
  return lucroCartao.value > 0 ? 'badge-ok' : 'badge-alerta'
})

// Troca a aba do seletor e preenche o texto quando o vendedor escolhe uma opção.
// Sem mesclagem → prévia da aba atual (Pix+Boleto ou Cartão); com mesclagem → combinado.
function selecionarPagamento(tipo: 'pix' | 'cartao', chave?: string | null) {
  abaPagamento.value = tipo
  if (chave !== undefined) {
    cartaoSelecionado.value = chave
  }
  const c = condicoesCalculadas.value
  if (mesclarMetodos.value) {
    condicoesPagamento.value = c.texto
    return
  }
  if (tipo === 'cartao') {
    const op = cartaoSelecionado.value
      ? c.cartao.find((o) => chaveCartao(o) === cartaoSelecionado.value)
      : null
    if (op) {
      const linhas = [
        `Cartão de Crédito (${op.parcelas}x de R$ ${op.parcela.toFixed(2).replace('.', ',')}): total de R$ ${op.total.toFixed(2).replace('.', ',')}.`,
      ]
      if (faturarCliente.value) linhas.push('Faturamos com até 20 dias da entrega do produto')
      condicoesPagamento.value = linhas.join('\n')
    } else {
      condicoesPagamento.value = c.texto
    }
  } else {
    const linhas: string[] = []
    if (metodosPagamento.value.pix) linhas.push(c.pix)
    if (metodosPagamento.value.boleto) linhas.push(c.boleto)
    if (faturarCliente.value) linhas.push('Faturamos com até 20 dias da entrega do produto')
    condicoesPagamento.value = linhas.join('\n')
  }
}

// Atualiza o texto das condições com Pix/Boleto (sem trocar a aba) — usado ao
// reduzir as parcelas do boleto.
function recomporTextoPixBoleto() {
  const c = condicoesCalculadas.value
  if (mesclarMetodos.value) {
    condicoesPagamento.value = c.texto
    return
  }
  const linhas: string[] = []
  if (metodosPagamento.value.pix) linhas.push(c.pix)
  if (metodosPagamento.value.boleto) linhas.push(c.boleto)
  if (faturarCliente.value) linhas.push('Faturamos com até 20 dias da entrega do produto')
  condicoesPagamento.value = linhas.join('\n')
}

function formatarValorParcelaBoleto(n: number): string {
  const header = orcamentoStore.orcamentoHeader
  const venda = Number(header?.vnd_B2B_B2C_tot) || Number(header?.vnd_tot) || 0
  return formatarMoeda(n > 0 ? venda / n : 0)
}

function alterarParcelasBoleto(e: Event) {
  const n = Number((e.target as HTMLSelectElement).value)
  if (Number.isInteger(n) && n >= 1) parcelasBoleto.value = n
  recomporTextoPixBoleto()
}

function valorPixComDesconto(): number {
  const header = orcamentoStore.orcamentoHeader
  const venda = Number(header?.vnd_B2B_B2C_tot) || Number(header?.vnd_tot) || 0
  const desc = descontoPixPercentual.value > 0 ? venda * (descontoPixPercentual.value / 100) : 0
  return venda - desc
}

function formatarValorParcelaPix(n: number): string {
  const total = valorPixComDesconto()
  return formatarMoeda(n > 0 ? total / n : 0)
}

function alterarParcelasPix(e: Event) {
  const n = Number((e.target as HTMLSelectElement).value)
  if (n === 1 || n === 2) parcelasPix.value = n
  recomporTextoPixBoleto()
}

// Define o modo de repasse explicitamente (toggle) e re-preenche o texto
function setRepasseTaxa(valor: boolean) {
  repassarTaxasCartao.value = valor
  if (abaPagamento.value === 'cartao') {
    selecionarPagamento('cartao', cartaoSelecionado.value)
  }
}

// Troca de instituição: limpa a parcela selecionada se o provedor salvo não bater
// com o novo (evita chave órfã "provedor|parcelas" apontando para outra instituição).
function selecionarProvedor() {
  const sel = cartaoSelecionado.value
  if (sel) {
    const [pid] = sel.split('|')
    const novo = provedorSelecionado.value
    if (novo != null && String(novo) !== String(pid)) {
      cartaoSelecionado.value = null
    }
  }
  selecionarPagamento('cartao')
}

// Gera as condições padrão no textarea (pergunta antes de sobrescrever conteúdo existente)
function gerarCondicoes() {
  const atual = condicoesPagamento.value.trim()
  if (atual && !confirm('Isso substituirá as condições atuais. Continuar?')) return
  condicoesPagamento.value = calcularCondicoesPadrao()
}

// Salva as condições editadas na ORCA (sem gerar PDF/WhatsApp)
async function salvarCondicoes() {
  const ok = await persistirCondicoesPagamento()
  if (ok) alert('Condições de pagamento salvas.')
}

// Aplica as condições para envio:
// - campo vazio → alerta "prosseguir sem condições?" (Cancelar → retorna null, aborta);
// - campo alterado em relação ao salvo → pergunta se salva antes de enviar.
// Retorna o texto efetivo das condições, ou null se o usuário cancelar.
async function condicoesParaEnvio(): Promise<string | null> {
  const atual = condicoesPagamento.value.trim()
  const salvo = (orcamentoStore.orcamentoHeader?.condicoes_pagamento || '').trim()
  if (!atual && !salvo) {
    const ok = confirm(
      'Deseja prosseguir sem as condições de pagamento? Lembre-se: as condições precisam ser salvas antes do envio.',
    )
    if (!ok) return null
    return ''
  }
  if (atual !== salvo) {
    if (confirm('As condições foram alteradas. Salvar as alterações antes de enviar?')) {
      await persistirCondicoesPagamento()
    }
  }
  return atual
}

async function gerarPdf() {
  const cond = await condicoesParaEnvio()
  if (cond === null) return
  gerarPdfOrcamento({
    header: orcamentoStore.orcamentoHeader,
    itens: orcamentoStore.itensInseridos,
    cliente: clienteSelecionado.value,
    user: authStore.user,
    faturar: faturarCliente.value,
    condicoesPagamento: cond,
  })
}

async function gerarPdfPedidoVendaView() {
  const cond = await condicoesParaEnvio()
  if (cond === null) return
  gerarPdfPedidoVenda({
    header: orcamentoStore.orcamentoHeader,
    itens: orcamentoStore.itensInseridos,
    cliente: clienteSelecionado.value,
    user: authStore.user,
    condicoesPagamento: cond,
  })
}

const enviandoWhatsApp = ref(false)

// Toast temporário (rodapé) para avisos de clipboard/WhatsApp
const toastMsg = ref('')
let toastTimer: ReturnType<typeof setTimeout> | null = null
function mostrarToast(msg: string) {
  toastMsg.value = msg
  if (toastTimer) clearTimeout(toastTimer)
  toastTimer = setTimeout(() => {
    toastMsg.value = ''
  }, 4000)
}

// Status do orçamento (badge + fluxo de botões)
const statusAtual = computed(() => orcamentoStore.orcamentoHeader?.status ?? 'RASCUNHO')
const statusFinalizado = computed(() =>
  ['APROVADO', 'AGUARDANDO_FATURAMENTO', 'FATURADO', 'ENTREGUE', 'RECUSADO', 'CANCELADO'].includes(
    statusAtual.value,
  ),
)
// Estados finais (sem ação de status possível) — ENTREGUE/RECUSADO/CANCELADO
const statusTerminal = computed(() =>
  ['ENTREGUE', 'RECUSADO', 'CANCELADO'].includes(statusAtual.value),
)
const atualizandoStatus = ref(false)

const STATUS_LABELS: Record<string, string> = {
  RASCUNHO: 'Rascunho',
  ENVIADO: 'Enviado',
  AGUARDANDO_RETORNO: 'Aguardando retorno',
  APROVADO: 'Aprovado',
  AGUARDANDO_FATURAMENTO: 'Aguardando faturamento',
  FATURADO: 'Faturado',
  ENTREGUE: 'Entregue',
  RECUSADO: 'Recusado',
  CANCELADO: 'Cancelado',
}

function statusLabel(status: string): string {
  return STATUS_LABELS[status] ?? status
}

// Modal de confirmação de status
const statusConfirm = ref<{ destino: string; rotulo: string; pedirMotivo: boolean } | null>(null)
const motivoStatus = ref('')

const STATUS_ACAO_LABEL: Record<string, string> = {
  AGUARDANDO_RETORNO: 'Enviar',
  APROVADO: 'Aprovar',
  AGUARDANDO_FATURAMENTO: 'Converter em Pedido',
  FATURADO: 'Faturar',
  ENTREGUE: 'Entregar',
  RECUSADO: 'Recusar',
  CANCELADO: 'Cancelar',
  RASCUNHO: 'Voltar para Rascunho',
}

const STATUS_PEDE_MOTIVO = ['RECUSADO', 'CANCELADO']

function pedirConfirmacao(destino: string) {
  motivoStatus.value = ''
  statusConfirm.value = {
    destino,
    rotulo: STATUS_ACAO_LABEL[destino] ?? destino,
    pedirMotivo: STATUS_PEDE_MOTIVO.includes(destino),
  }
}

function cancelarStatus() {
  statusConfirm.value = null
  motivoStatus.value = ''
}

async function confirmarStatus() {
  const confirm = statusConfirm.value
  if (!confirm) return

  // Valida pré-requisito obrigatório antes de fechar o modal (conversão em pedido)
  if (
    confirm.destino === 'AGUARDANDO_FATURAMENTO' &&
    !kapaziForm.value.num_pedido_fabrica?.trim()
  ) {
    statusConfirm.value = null
    mostrarToast('Preencha o Nº do Pedido da Fábrica (Kapazi) antes de converter em pedido.')
    return
  }

  statusConfirm.value = null
  if (confirm.destino === 'AGUARDANDO_FATURAMENTO') {
    await converterParaPedido()
  } else {
    await mudarStatus(confirm.destino, motivoStatus.value.trim() || undefined)
  }
  motivoStatus.value = ''
}

async function mudarStatus(status: string, motivo?: string) {
  const orcaId = orcaIdAtual.value
  if (!orcaId) return
  atualizandoStatus.value = true
  try {
    await orcamentoStore.atualizarStatus(orcaId, status, motivo)
    mostrarToast(`Status atualizado para ${statusLabel(status)}.`)
  } catch {
    mostrarToast(orcamentoStore.error || 'Erro ao atualizar status')
  } finally {
    atualizandoStatus.value = false
  }
}

async function converterParaPedido() {
  const orcaId = orcaIdAtual.value
  if (!orcaId) return

  // Pré-requisito obrigatório: Nº do Pedido da Fábrica (Kapazi) antes de converter.
  if (!kapaziForm.value.num_pedido_fabrica?.trim()) {
    mostrarToast('Preencha o Nº do Pedido da Fábrica (Kapazi) antes de converter em pedido.')
    return
  }

  atualizandoStatus.value = true
  try {
    await orcamentoStore.converterEmPedido(orcaId)
    mostrarToast('Orçamento convertido em pedido.')
  } catch {
    mostrarToast(orcamentoStore.error || 'Erro ao converter em pedido')
  } finally {
    atualizandoStatus.value = false
  }
}

// ── Dados para Kapazi / Controle do Pedido ──────────────────────────────────
// Campos manuais do fluxo da fábrica (ordem lógica): data_envio_fabrica →
// num_pedido_fabrica → data_aprovacao_layout → num_pedido_venda → num_nf →
// forma de pagamento → cod_rastreio (+ transportadora/datas/fretes reais).
const kapaziForm = ref({
  data_envio_fabrica: '',
  num_pedido_fabrica: '',
  data_aprovacao_layout: '',
  num_pedido_venda: '',
  num_nf: '',
  forma_pagamento_fabrica: '',
  desconto_kapazi_perc: '',
  cod_rastreio: '',
  transportadoraB2B: '',
  transportadoraB2C: '',
  dataPrevisao: '',
  dataChegada: '',
  freteB2BReal: '',
  freteB2CReal: '',
})
const salvandoKapazi = ref(false)

function kapaziParaForm(c: any) {
  if (!c) return
  kapaziForm.value = {
    data_envio_fabrica: c.data_envio_fabrica ?? '',
    num_pedido_fabrica: c.num_pedido_fabrica ?? '',
    data_aprovacao_layout: c.data_aprovacao_layout ?? '',
    num_pedido_venda: c.num_pedido_venda ?? '',
    num_nf: c.num_nf ?? '',
    forma_pagamento_fabrica: c.forma_pagamento_fabrica ?? '',
    desconto_kapazi_perc: c.desconto_kapazi_perc ?? '',
    cod_rastreio: c.cod_rastreio ?? '',
    transportadoraB2B: c.transportadoraB2B ?? '',
    transportadoraB2C: c.transportadoraB2C ?? '',
    dataPrevisao: c.dataPrevisao ?? '',
    dataChegada: c.dataChegada ?? '',
    freteB2BReal: c.freteB2BReal ?? '',
    freteB2CReal: c.freteB2CReal ?? '',
  }
}

watch(
  () => orcamentoStore.controlePedido,
  (c) => kapaziParaForm(c),
  { immediate: true },
)

async function salvarDadosKapazi() {
  const orcaId = orcaIdAtual.value
  if (!orcaId) return
  salvandoKapazi.value = true
  try {
    const f = kapaziForm.value
    await orcamentoStore.salvarControlePedido(orcaId, {
      data_envio_fabrica: f.data_envio_fabrica || null,
      num_pedido_fabrica: f.num_pedido_fabrica || null,
      data_aprovacao_layout: f.data_aprovacao_layout || null,
      num_pedido_venda: f.num_pedido_venda || null,
      num_nf: f.num_nf || null,
      forma_pagamento_fabrica: f.forma_pagamento_fabrica || null,
      desconto_kapazi_perc: f.desconto_kapazi_perc !== '' ? Number(f.desconto_kapazi_perc) : null,
      cod_rastreio: f.cod_rastreio || null,
      transportadoraB2B: f.transportadoraB2B || null,
      transportadoraB2C: f.transportadoraB2C || null,
      dataPrevisao: f.dataPrevisao || null,
      dataChegada: f.dataChegada || null,
      freteB2BReal: f.freteB2BReal !== '' ? Number(f.freteB2BReal) : null,
      freteB2CReal: f.freteB2CReal !== '' ? Number(f.freteB2CReal) : null,
    })
    mostrarToast('Dados da fábrica salvos.')
  } catch {
    /* error já definido no store */
  } finally {
    salvandoKapazi.value = false
  }
}

async function enviarWhatsApp() {
  const codOrca = orcamentoStore.numeroOrcamento ?? codOrcaParam
  if (!codOrca) return
  enviandoWhatsApp.value = true
  try {
    // Aplica as condições (vazio → pergunta se prossegue sem; alterado → pergunta se salva)
    const cond = await condicoesParaEnvio()
    if (cond === null) return
    // Garante telefones do cliente no header (_cliente._telefone_cliente_of_cliente)
    const header = orcamentoStore.orcamentoHeader
    if (!header?._cliente?._telefone_cliente_of_cliente?.length) {
      await orcamentoStore.carregarOrcamento(codOrca)
    }
    const h = orcamentoStore.orcamentoHeader
    const telefone = obterWhatsappCliente(h?._cliente ?? null)
    if (!telefone) {
      alert('Cliente sem telefone cadastrado (tipo 1).')
      return
    }
    const mensagem = montarTextoWhatsApp({
      header: h,
      itens: orcamentoStore.itensInseridos,
      cliente: h?._cliente ?? null,
      faturar: faturarCliente.value,
      condicoesPagamento: cond,
    })
    const status = await copiarEabrirWhatsApp(telefone, mensagem)
    if (status === 'shared') {
      mostrarToast('Mensagem enviada para compartilhamento. Escolha o WhatsApp.')
    } else if (status === 'copied') {
      mostrarToast('Mensagem copiada! Cole na conversa do WhatsApp (Ctrl+V / segure o campo).')
    } else {
      mostrarToast('Não foi possível copiar. A mensagem foi aberta no WhatsApp.')
    }
  } catch (err: any) {
    alert(err?.getResponse?.()?.getBody?.()?.message || 'Erro ao gerar o WhatsApp')
  } finally {
    enviandoWhatsApp.value = false
  }
}
</script>

<template>
  <div class="orcamento-page">
    <PendenciasPerfilBanner />
    <template v-if="!mostrarResumo">
      <!-- A. Cabeçalho e Identificação do Cliente -->
      <section class="card welcome-card">
        <div class="welcome-top">
          <div>
            <h2>Tapetes personalizados</h2>
            <p class="subtitle">Vinil, Cleankap, Duo, Rubberkap Personalizado e etc...</p>
          </div>
          <div class="welcome-actions">
            <span v-if="isVinculado" class="edit-badge read-only-badge">Somente Leitura</span>
            <span v-else-if="isEditMode" class="edit-badge">Edição</span>
            <span class="orc-num">{{ orcamentoStore.numeroOrcamento || '---' }}</span>
            <button class="btn btn-sm btn-outline" @click="voltarLista">← Voltar</button>
          </div>
        </div>
        <div v-if="clienteSelecionado" class="welcome-cliente">
          <strong>{{ clienteSelecionado.nome_fantasia || clienteSelecionado.razao_social }}</strong>
          <span>{{ clienteSelecionado.cnpj || clienteSelecionado.cpf || '' }}</span>
        </div>
        <div class="welcome-metrics">
          <span class="metric"
            ><strong>Frete B2B mínimo:</strong> {{ formatarMoeda(fretePadrao) }}</span
          >
        </div>
      </section>

      <!-- Cliente -->
      <template v-if="!isVinculado">
        <section class="card">
          <div class="section-title-row">
            <h3 class="section-title">Cliente</h3>
            <button class="btn btn-sm btn-outline" @click="novoCliente">＋ Novo cliente</button>
          </div>

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
              <strong>{{
                clienteSelecionado.nome_fantasia || clienteSelecionado.razao_social
              }}</strong>
              <span>{{ clienteSelecionado.cnpj || clienteSelecionado.cpf || '' }}</span>
            </div>
            <div class="cliente-actions">
              <button class="btn btn-sm" @click="verCliente">👁 Ver dados</button>
              <button class="btn btn-sm btn-outline" @click="limparCliente">✕ Limpar</button>
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
                <option v-for="m in orcamentoStore.materiais" :key="m.id" :value="m">
                  {{ m.nome }}
                </option>
              </select>
              <button
                v-if="orcamentoStore.materialSelecionado"
                class="btn-clear"
                @click="orcamentoStore.limparMaterial()"
              >
                ✕
              </button>
            </div>
          </div>

          <div v-if="orcamentoStore.mostrarLinha && orcamentoStore.linhas.length" class="field">
            <label>Linha</label>
            <div class="select-wrap">
              <select v-model="orcamentoStore.linhaSelecionada">
                <option :value="null" disabled>Selecione</option>
                <option v-for="l in orcamentoStore.linhas" :key="l.id" :value="l">
                  {{ l.nome }}
                </option>
              </select>
              <button
                v-if="orcamentoStore.linhaSelecionada"
                class="btn-clear"
                @click="orcamentoStore.linhaSelecionada = null"
              >
                ✕
              </button>
            </div>
          </div>

          <div v-if="orcamentoStore.mostrarTipo && orcamentoStore.tipos.length" class="field">
            <label>Tipo</label>
            <div class="select-wrap">
              <select v-model="orcamentoStore.tipoSelecionado">
                <option :value="null" disabled>Selecione</option>
                <option v-for="t in orcamentoStore.tipos" :key="t.id" :value="t">
                  {{ t.nome }}
                </option>
              </select>
              <button
                v-if="orcamentoStore.tipoSelecionado"
                class="btn-clear"
                @click="orcamentoStore.tipoSelecionado = null"
              >
                ✕
              </button>
            </div>
          </div>

          <div v-if="orcamentoStore.mostrarNivel && orcamentoStore.niveis.length" class="field">
            <label>Nível</label>
            <div class="select-wrap">
              <select v-model="orcamentoStore.nivelSelecionado">
                <option :value="null" disabled>Selecione</option>
                <option v-for="n in orcamentoStore.niveis" :key="n.id" :value="n">
                  {{ n.nome }}
                </option>
              </select>
              <button
                v-if="orcamentoStore.nivelSelecionado"
                class="btn-clear"
                @click="orcamentoStore.nivelSelecionado = null"
              >
                ✕
              </button>
            </div>
          </div>

          <div v-if="orcamentoStore.mostrarVariacao" class="field">
            <label>Variação</label>
            <div class="select-wrap">
              <select v-model="orcamentoStore.variacaoSelecionada">
                <option :value="null" disabled>Selecione</option>
                <option v-for="v in orcamentoStore.variacoes" :key="v.id" :value="v">
                  {{ v.descricao }}
                </option>
              </select>
              <button
                v-if="orcamentoStore.variacaoSelecionada"
                class="btn-clear"
                @click="orcamentoStore.variacaoSelecionada = null"
              >
                ✕
              </button>
            </div>
          </div>

          <div v-if="orcamentoStore.mostrarBorda && orcamentoStore.bordas.length" class="field">
            <label>Borda</label>
            <div class="select-wrap">
              <select v-model="orcamentoStore.bordaSelecionada">
                <option :value="null" disabled>Selecione</option>
                <option v-for="b in orcamentoStore.bordas" :key="b.id" :value="b">
                  {{ b.nome }}
                </option>
              </select>
              <button
                v-if="orcamentoStore.bordaSelecionada"
                class="btn-clear"
                @click="orcamentoStore.bordaSelecionada = null"
              >
                ✕
              </button>
            </div>
          </div>

          <div
            v-if="
              (orcamentoStore.unidadeSelecionada === 'M2' ||
                orcamentoStore.unidadeSelecionada === 'UND') &&
              !orcamentoStore.ehComposto
            "
            class="field"
          >
            <label>Quantidade</label>
            <input
              v-model.number="orcamentoStore.quantidade"
              type="number"
              min="0.01"
              step="0.01"
              class="input-num"
            />
            <span class="field-suffix">unidades</span>
          </div>
        </section>

        <!-- C. Calculadora de Dimensões -->
        <section class="card">
          <h3 class="section-title">Dimensões</h3>

          <template v-if="orcamentoStore.ehML">
            <div class="field">
              <label>Informar</label>
              <div class="modo-entrada">
                <button
                  class="btn-seg"
                  :class="{ active: modoEntradaML === 'area' }"
                  @click="modoEntradaML = 'area'"
                >
                  Área (m²)
                </button>
                <button
                  class="btn-seg"
                  :class="{ active: modoEntradaML === 'dimensoes' }"
                  @click="modoEntradaML = 'dimensoes'"
                >
                  Largura × Comprimento
                </button>
              </div>
            </div>

            <template v-if="modoEntradaML === 'area'">
              <div class="field">
                <label>Área (m²)</label>
                <input
                  v-model.number="orcamentoStore.areaML"
                  type="number"
                  step="0.01"
                  min="0"
                  placeholder="0,00"
                />
              </div>
            </template>

            <template v-else>
              <div class="dimensoes-row">
                <div class="field flex-1">
                  <label>Largura (m)</label>
                  <input
                    v-model.number="orcamentoStore.largura"
                    type="number"
                    step="0.01"
                    min="0"
                    placeholder="0,00"
                  />
                </div>
                <span class="dimensoes-x">X</span>
                <div class="field flex-1">
                  <label>Comprimento (m)</label>
                  <input
                    v-model.number="orcamentoStore.comprimento"
                    type="number"
                    step="0.01"
                    min="0"
                    placeholder="0,00"
                  />
                </div>
              </div>
              <div class="field">
                <label>Área Calculada (m²)</label>
                <input :value="areaMLEfetiva.toFixed(2)" readonly class="input-readonly" />
              </div>
            </template>

            <p class="field-hint">
              Venda por metro linear (ML) — a área é convertida em metros lineares pela largura do
              rolo.
            </p>
          </template>

          <template v-else-if="orcamentoStore.unidadeSelecionada === 'UND'">
            <p class="field-hint">Produto vendido por unidade — informe a quantidade acima.</p>
          </template>

          <template v-else-if="!orcamentoStore.ehComposto">
            <div class="dimensoes-row">
              <div class="field flex-1">
                <label>Largura (m)</label>
                <input
                  v-model.number="orcamentoStore.largura"
                  type="number"
                  step="0.01"
                  min="0"
                  placeholder="0,00"
                />
              </div>
              <span class="dimensoes-x">X</span>
              <div class="field flex-1">
                <label>Comprimento (m)</label>
                <input
                  v-model.number="orcamentoStore.comprimento"
                  type="number"
                  step="0.01"
                  min="0"
                  placeholder="0,00"
                />
              </div>
            </div>

            <div class="field">
              <label>Área Nominal (m²)</label>
              <input
                :value="orcamentoStore.areaNominal.toFixed(2)"
                readonly
                class="input-readonly"
              />
            </div>
          </template>

          <!-- Produto composto (tipo_composto = playkap): piso modular -->
          <template v-if="orcamentoStore.ehComposto && orcamentoStore.tipoComposto === 'PLAYKAP'">
            <div class="field">
              <label>Informar</label>
              <div class="modo-entrada">
                <button
                  class="btn-seg"
                  :class="{ active: orcamentoStore.modoEntradaComposto === 'area' }"
                  @click="orcamentoStore.modoEntradaComposto = 'area'"
                >
                  Área (m²)
                </button>
                <button
                  class="btn-seg"
                  :class="{ active: orcamentoStore.modoEntradaComposto === 'dimensoes' }"
                  @click="orcamentoStore.modoEntradaComposto = 'dimensoes'"
                >
                  Largura × Comprimento
                </button>
              </div>
            </div>

            <template v-if="orcamentoStore.modoEntradaComposto === 'area'">
              <div class="field">
                <label>Área (m²)</label>
                <input
                  v-model.number="orcamentoStore.areaML"
                  type="number"
                  step="0.01"
                  min="0"
                  placeholder="0,00"
                />
              </div>
            </template>
            <template v-else>
              <div class="dimensoes-row">
                <div class="field flex-1">
                  <label>Largura (m)</label>
                  <input
                    v-model.number="orcamentoStore.largura"
                    type="number"
                    step="0.01"
                    min="0"
                    placeholder="0,00"
                  />
                </div>
                <span class="dimensoes-x">X</span>
                <div class="field flex-1">
                  <label>Comprimento (m)</label>
                  <input
                    v-model.number="orcamentoStore.comprimento"
                    type="number"
                    step="0.01"
                    min="0"
                    placeholder="0,00"
                  />
                </div>
              </div>
              <div class="field">
                <label>Área Nominal (m²)</label>
                <input
                  :value="orcamentoStore.areaNominal.toFixed(2)"
                  readonly
                  class="input-readonly"
                />
              </div>
            </template>

            <div class="field">
              <label>Rampa (lados do perímetro)</label>
              <div class="composto-rampas">
                <label class="checkbox-inline">
                  <input v-model="orcamentoStore.rampaLarg1" type="checkbox" />
                  <span>Largura 1</span>
                </label>
                <label class="checkbox-inline">
                  <input v-model="orcamentoStore.rampaComp1" type="checkbox" />
                  <span>Comprimento 1</span>
                </label>
                <label class="checkbox-inline">
                  <input v-model="orcamentoStore.rampaLarg2" type="checkbox" />
                  <span>Largura 2</span>
                </label>
                <label class="checkbox-inline">
                  <input v-model="orcamentoStore.rampaComp2" type="checkbox" />
                  <span>Comprimento 2</span>
                </label>
              </div>
            </div>

            <div class="field">
              <label>Cantoneira(s) (0-4)</label>
              <input
                v-model.number="orcamentoStore.qtdCantos"
                type="number"
                min="0"
                max="4"
                step="1"
                placeholder="0"
              />
            </div>
            <p class="field-hint">
              Piso modular PLAYKAP — placas de 30×30cm com arredondamento para cima; rampas
              (macho/fêmea, divisão automática) e cantoneiras somadas ao custo do conjunto.
            </p>
          </template>

          <div
            v-if="orcamentoStore.produtoSelecionado?.com_medida_exata"
            class="field medida-exata-wrap"
          >
            <label class="checkbox-inline">
              <input type="checkbox" v-model="orcamentoStore.medidaExata" />
              <span>
                Medida exata —
                <strong
                  >acréscimo de
                  {{ orcamentoStore.produtoSelecionado.porcentagem_acrescimo || 0 }}%</strong
                >
                no custo de fábrica
              </span>
            </label>
            <small class="field-hint"
              >Para tapetes com a medida exata, a fábrica cobra uma taxa adicional.</small
            >
          </div>

          <div class="btn-row">
            <button
              class="btn btn-secondary"
              :disabled="orcamentoStore.loading || !formValido"
              @click="handleCalcular"
            >
              {{ orcamentoStore.loading ? 'Calculando...' : 'Calcular' }}
            </button>
            <button
              class="btn btn-primary"
              :disabled="orcamentoStore.loading || !formValido"
              @click="handleSimular"
            >
              Simular
            </button>
          </div>
        </section>

        <!-- Resultados -->
        <template v-if="orcamentoStore.resultado || orcamentoStore.resultadoNovo">
          <!-- D. FC e Dimensões Faturadas -->
          <section class="card">
            <h3 class="section-title">Fator de Conversão</h3>

            <p class="fc-display">
              <strong>FC:</strong>
              <span v-for="(v, i) in fcArray" :key="i" class="fc-item"
                >{{ v }}<span v-if="i < fcArray.length - 1">, </span></span
              >
            </p>

            <div v-if="!orcamentoStore.ehML" class="dimensoes-row">
              <div class="field flex-1">
                <label>Largura FC (m)</label>
                <input
                  :value="itemCalc?.larg_fc ?? orcamentoStore.resultado?.LargFC ?? 0"
                  readonly
                  class="input-readonly"
                />
              </div>
              <span class="dimensoes-x">X</span>
              <div class="field flex-1">
                <label>Comprimento FC (m)</label>
                <input
                  :value="itemCalc?.comp_fc ?? orcamentoStore.resultado?.CompFC ?? 0"
                  readonly
                  class="input-readonly"
                />
              </div>
            </div>

            <div v-if="!orcamentoStore.ehML" class="field area-fc-wrap">
              <label>Área Faturada (m²)</label>
              <div class="area-fc-input">
                <input :value="areaFaturada.toFixed(2)" readonly class="input-readonly input-big" />
                <button
                  class="btn-eye"
                  :class="{ active: mostrarCustos }"
                  @click="toggleCustos"
                  title="Detalhamento financeiro"
                >
                  <svg
                    v-if="!mostrarCustos"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                  >
                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                    <circle cx="12" cy="12" r="3" />
                  </svg>
                  <svg
                    v-else
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                  >
                    <path
                      d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94"
                    />
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
              <div class="price-label">Valor Venda Total</div>
              <div class="price-value price-b2b">{{ formatarMoeda(valorVendaTotalB2B) }}</div>
            </div>
          </section>

          <!-- G. Detalhamento Financeiro (Toggle) -->
          <section v-if="mostrarCustos" class="card custos-card">
            <h3 class="section-title">Detalhamento Financeiro</h3>

            <div class="custos-grid">
              <span class="price-label">Cst Mat Prima</span>
              <span class="price-value price-bg">{{
                formatarMoeda(
                  itemCalc?.vlr_cst_materia_prima ??
                    orcamentoStore.resultado?.Produto_2?.[0]?.valor ??
                    0,
                )
              }}</span>

              <span class="price-label">Cst Borda</span>
              <span class="price-value price-bg">{{
                formatarMoeda(itemCalc?.vlr_cst_borda ?? 0)
              }}</span>

              <span class="price-label">IPI Unit</span>
              <span class="price-value price-bg">{{
                formatarMoeda(itemCalc?.vlr_ipi_unit ?? 0)
              }}</span>

              <span class="price-label">Cst Nota Unit</span>
              <span class="price-value price-bg">{{
                formatarMoeda(itemCalc?.vlr_custo_nota_unit ?? 0)
              }}</span>

              <span class="price-label">ST Unit</span>
              <span class="price-value price-bg">{{
                formatarMoeda(itemCalc?.vlr_st_unit ?? 0)
              }}</span>

              <span class="price-label">DIFAL Unit</span>
              <span class="price-value price-bg">{{
                formatarMoeda(itemCalc?.vlr_difal_unit ?? 0)
              }}</span>

              <span class="price-label">Crédito ICMS Unit</span>
              <span class="price-value price-bg">{{
                formatarMoeda(itemCalc?.vlr_credito_icms_unit ?? 0)
              }}</span>

              <span class="price-label">Cst Fiscal Unit</span>
              <span class="price-value price-bg">{{
                formatarMoeda(itemCalc?.vlr_custo_fiscal_unit ?? 0)
              }}</span>

              <span class="price-label">Frete B2B Unit</span>
              <span class="price-value price-bg">{{
                formatarMoeda(itemCalc?.vlr_frete_b2b_unit ?? itemCalc?.frete_b2b ?? 0)
              }}</span>

              <span class="price-label">Cst Entrada Unit</span>
              <span class="price-value price-bg">{{
                formatarMoeda(itemCalc?.vlr_cst_entrada_unit ?? 0)
              }}</span>

              <span class="price-label">Margem (Markup)</span>
              <span class="price-value price-bg"
                >{{ orcamentoStore.margemPersonalizada ?? margemPadrao }}%</span
              >

              <span class="price-label">Margem Real</span>
              <span class="price-value price-bg"
                >{{ (itemCalc?.perc_marguem_real ?? 0).toFixed?.(2) }}%</span
              >

              <span class="price-label">Alíq. Inter</span>
              <span class="price-value price-bg">{{ itemCalc?.vlr_aliq_inter ?? 0 }}%</span>

              <span class="price-label">Alíq. Interna</span>
              <span class="price-value price-bg">{{ itemCalc?.vlr_aliq_interna ?? 0 }}%</span>

              <span class="price-label">% DIFAL</span>
              <span class="price-value price-bg">{{ itemCalc?.vlr_perc_difal ?? 0 }}%</span>

              <template v-if="itemCalc && orcamentoStore.ehML">
                <span class="price-label">Metros Lineares</span>
                <span class="price-value price-bg">{{ itemCalc.qtd ?? 0 }} m</span>
              </template>

              <span class="price-label">Custo Unitário (Entrada)</span>
              <span class="price-value price-bg">{{ formatarMoeda(custoUnit) }}</span>

              <span class="price-label">Custo Total (Entrada)</span>
              <span class="price-value price-bg">{{ formatarMoeda(custoTotal) }}</span>

              <span class="price-label">Venda Unit (c/ Frete B2B)</span>
              <span class="price-value price-bg">{{ formatarMoeda(valorVendaUnitB2B) }}</span>

              <span class="price-label">Venda Total (c/ Frete B2B)</span>
              <span class="price-value price-b2b">{{ formatarMoeda(valorVendaTotalB2B) }}</span>

              <span class="price-label">Lucro Unitário</span>
              <span class="price-value price-bg">{{ formatarMoeda(lucroUnit) }}</span>

              <span class="price-label">Lucro Total</span>
              <span class="price-value price-bg">{{ formatarMoeda(lucroTotal) }}</span>
            </div>
          </section>
        </template>

        <!-- F. Observações e Ações -->
        <section class="card">
          <h3 class="section-title">Finalização</h3>

          <div class="field">
            <label>Descrição do Item</label>
            <textarea
              v-model="observacao"
              placeholder="Descrição adicional do item..."
              rows="2"
            ></textarea>
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
              :disabled="
                orcamentoStore.loading ||
                (!orcamentoStore.resultado && !orcamentoStore.resultadoNovo) ||
                orcamentoStore.inserindo
              "
              @click="handleInserir"
            >
              {{
                orcamentoStore.inserindo
                  ? 'Salvando…'
                  : editandoItemId
                    ? 'Salvar Alterações'
                    : 'Adicionar Item'
              }}
            </button>
            <button
              v-if="editandoItemId"
              class="btn btn-outline btn-lg"
              @click="cancelarEdicaoItem"
            >
              ✕ Cancelar edição
            </button>
          </div>

          <p v-if="inserirOk" class="success-msg">
            {{
              editandoItemId
                ? 'Item atualizado!'
                : `Item adicionado ao orçamento ${orcamentoStore.numeroOrcamento}!`
            }}
          </p>
          <p v-if="orcamentoStore.error" class="error-msg">{{ orcamentoStore.error }}</p>
        </section>
      </template>

      <!-- Resumo do Orçamento (itens inseridos) -->
      <section v-if="orcamentoStore.itensInseridos.length" class="summary-section">
        <div class="summary-header" @click="resumoAberto = !resumoAberto">
          <h3 class="summary-title">Resumo do Orçamento</h3>
          <span class="summary-toggle">{{ resumoAberto ? '▲' : '▼' }}</span>
        </div>

        <template v-if="resumoAberto">
          <div class="card card-totais">
            <div class="totais-header">
              <span class="orc-num">{{ orcamentoStore.numeroOrcamento }}</span>
              <span class="totais-cliente">{{
                clienteSelecionado?.nome_fantasia || clienteSelecionado?.razao_social
              }}</span>
              <button
                class="btn-eye header-eye"
                :class="{ active: mostrarCustosHeader }"
                @click="toggleCustosHeader"
                title="Mostrar custos, lucro e ajustes"
              >
                <svg
                  v-if="!mostrarCustosHeader"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                >
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                  <circle cx="12" cy="12" r="3" />
                </svg>
                <svg
                  v-else
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                >
                  <path
                    d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94"
                  />
                  <path d="M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19" />
                  <line x1="1" y1="1" x2="23" y2="23" />
                </svg>
              </button>
            </div>
            <div class="totais-grid">
              <div class="totais-item">
                <span class="totais-label">Total Venda</span>
                <span class="totais-valor">{{
                  formatarMoeda(orcamentoStore.orcamentoHeader?.vnd_tot ?? 0)
                }}</span>
              </div>
              <div class="totais-item">
                <span class="totais-label">Total B2B</span>
                <span class="totais-valor totais-b2b">{{
                  formatarMoeda(orcamentoStore.orcamentoHeader?.vnd_B2B_tot ?? 0)
                }}</span>
              </div>
              <div class="totais-item">
                <span class="totais-label">Itens</span>
                <span class="totais-valor">{{ orcamentoStore.itensInseridos.length }}</span>
              </div>
              <div class="totais-item">
                <span class="totais-label">Desconto</span>
                <span class="totais-valor">{{
                  formatarMoeda(orcamentoStore.orcamentoHeader?.desconto ?? 0)
                }}</span>
              </div>
              <div class="totais-item">
                <span class="totais-label">Frete B2C</span>
                <span class="totais-valor">{{
                  formatarMoeda(orcamentoStore.orcamentoHeader?.frtB2C ?? 0)
                }}</span>
              </div>
              <div class="totais-item">
                <span class="totais-label">Total c/ Frete B2C</span>
                <span class="totais-valor totais-b2b">{{
                  formatarMoeda(orcamentoStore.orcamentoHeader?.vnd_B2B_B2C_tot ?? 0)
                }}</span>
              </div>
            </div>
            <div v-if="mostrarCustosHeader" class="totais-sensivel">
              <div class="totais-item">
                <span class="totais-label">Custo Total</span>
                <span class="totais-valor">{{
                  formatarMoeda(orcamentoStore.orcamentoHeader?.cst_tot ?? 0)
                }}</span>
              </div>
              <div class="totais-item">
                <span class="totais-label">Lucro Total</span>
                <span class="totais-valor">{{
                  formatarMoeda(orcamentoStore.orcamentoHeader?.luc_tot ?? 0)
                }}</span>
              </div>
              <div class="totais-item">
                <span class="totais-label">Frete B2B</span>
                <span class="totais-valor">{{
                  formatarMoeda(
                    orcamentoStore.totaisRecalculo?.frete_b2b_total ??
                      orcamentoStore.orcamentoHeader?.frtB2B ??
                      0,
                  )
                }}</span>
              </div>
              <div class="totais-item">
                <span class="totais-label">Margem (Alvo)</span>
                <span class="totais-valor"
                  >{{
                    orcamentoStore.totaisRecalculo?.markup_alvo ??
                    orcamentoStore.orcamentoHeader?.margem ??
                    margemPadrao
                  }}%</span
                >
              </div>
              <div class="totais-item">
                <span class="totais-label">Margem Efetiva</span>
                <span class="totais-valor">{{ orcamentoStore.totaisRecalculo?.margem ?? 0 }}%</span>
              </div>
              <div class="totais-item">
                <span class="totais-label">IPI</span>
                <span class="totais-valor">{{
                  formatarMoeda(orcamentoStore.totaisRecalculo?.ipi_tot ?? 0)
                }}</span>
              </div>
              <div
                v-if="(orcamentoStore.totaisRecalculo?.credito_icms_tot ?? 0) > 0"
                class="totais-item"
              >
                <span class="totais-label">ICMS (Crédito)</span>
                <span class="totais-valor">{{
                  formatarMoeda(orcamentoStore.totaisRecalculo?.credito_icms_tot ?? 0)
                }}</span>
              </div>
              <div v-if="(orcamentoStore.totaisRecalculo?.st_tot ?? 0) > 0" class="totais-item">
                <span class="totais-label">ICMS-ST</span>
                <span class="totais-valor">{{
                  formatarMoeda(orcamentoStore.totaisRecalculo?.st_tot ?? 0)
                }}</span>
              </div>
              <div v-if="(orcamentoStore.totaisRecalculo?.difal_tot ?? 0) > 0" class="totais-item">
                <span class="totais-label">DIFAL</span>
                <span class="totais-valor">{{
                  formatarMoeda(orcamentoStore.totaisRecalculo?.difal_tot ?? 0)
                }}</span>
              </div>
            </div>
            <div class="totais-validade">
              Validade:
              {{
                orcamentoStore.orcamentoHeader?.validade
                  ? new Date(orcamentoStore.orcamentoHeader.validade).toLocaleDateString('en-US')
                  : validadeCalculada
              }}
            </div>

            <div v-if="!isVinculado && mostrarCustosHeader" class="recalc-card">
              <h4 class="recalc-title">Ajustar Orçamento</h4>
              <div class="recalc-grid">
                <div class="recalc-item">
                  <label>Nova Margem (%)</label>
                  <div class="novo-valor-wrap">
                    <input
                      v-model.number="novaMargemResumo"
                      type="number"
                      step="0.0001"
                      placeholder="0"
                      class="input-num"
                      @input="simularPorMargem"
                    />
                  </div>
                </div>

                <div class="recalc-item">
                  <label>Novo Vlr de Venda Total B2B</label>
                  <div class="novo-valor-wrap">
                    <input
                      v-model.number="novoValorVendaResumo"
                      type="number"
                      step="0.01"
                      placeholder="0,00"
                      class="input-num"
                      @input="simularPorVenda"
                    />
                  </div>
                </div>

                <div class="recalc-item">
                  <label>Novo Lucro Total</label>
                  <div class="novo-valor-wrap">
                    <input
                      v-model.number="novoLucroResumo"
                      type="number"
                      step="0.01"
                      placeholder="0,00"
                      class="input-num"
                      @input="simularPorLucro"
                    />
                  </div>
                </div>

                <div class="recalc-item">
                  <label>Margem Real (%)</label>
                  <div class="novo-valor-wrap">
                    <input
                      v-model.number="margemRealResumo"
                      type="number"
                      step="0.0001"
                      placeholder="0"
                      class="input-num"
                      @input="simularPorMargemReal"
                    />
                  </div>
                </div>

                <div class="recalc-item">
                  <label>Desconto (R$)</label>
                  <div class="novo-valor-wrap">
                    <input
                      v-model.number="descontoResumo"
                      type="number"
                      step="0.01"
                      placeholder="0,00"
                      class="input-num"
                      @input="simularPorDesconto"
                    />
                  </div>
                </div>

                <div class="recalc-item">
                  <label>Frete B2C (R$)</label>
                  <div class="novo-valor-wrap">
                    <input
                      v-model.number="freteB2CResumo"
                      type="number"
                      step="0.01"
                      placeholder="0,00"
                      class="input-num"
                      @input="simularPorFreteB2C"
                    />
                  </div>
                </div>

                <div class="recalc-item">
                  <label>Mão de Obra (R$)</label>
                  <div class="novo-valor-wrap">
                    <input
                      v-model.number="maoDeObraResumo"
                      type="number"
                      step="0.01"
                      placeholder="0,00"
                      class="input-num"
                      @input="simularPorFreteB2C"
                    />
                  </div>
                </div>

                <div class="recalc-item recalc-item-action">
                  <button class="btn btn-primary btn-sm" @click="aplicarNegociacao">Aplicar</button>
                  <button
                    class="btn btn-outline btn-sm"
                    :disabled="!simulacaoLista.length"
                    @click="simulacaoModalOpen = true"
                  >
                    Simulação
                  </button>
                </div>
              </div>

              <div class="recalc-preview">
                <div class="preview-item">
                  <span class="preview-label">Venda B2B</span>
                  <span class="preview-value">{{ formatarMoeda(previewVenda) }}</span>
                </div>
                <div class="preview-item">
                  <span class="preview-label">Lucro</span>
                  <span class="preview-value">{{ formatarMoeda(previewLucro) }}</span>
                </div>
                <div class="preview-item">
                  <span class="preview-label">Margem Real</span>
                  <span class="preview-value">{{ margemRealResumo }}%</span>
                </div>
                <div class="preview-item">
                  <span class="preview-label">Margem Efetiva</span>
                  <span class="preview-value">{{ previewMargemEfetiva }}%</span>
                </div>
                <div class="preview-item">
                  <span class="preview-label">Total c/ Frete B2C</span>
                  <span class="preview-value">{{
                    formatarMoeda((novoValorVendaResumo || 0) + (freteB2CResumo || 0))
                  }}</span>
                </div>
                <div class="preview-item">
                  <span class="preview-label">Mão de Obra</span>
                  <span class="preview-value">{{ formatarMoeda(maoDeObraResumo) }}</span>
                </div>
                <div class="preview-item">
                  <span class="preview-label">Total Geral</span>
                  <span class="preview-value preview-total">{{
                    formatarMoeda(previewTotalB2C)
                  }}</span>
                </div>
                <div class="preview-item">
                  <span class="preview-label" title="Total simulado − Total c/ Frete B2C atual"
                    >Diferença Total c/ B2C</span
                  >
                  <span
                    class="preview-value"
                    :class="diferencaTotalB2C >= 0 ? 'preview-pos' : 'preview-neg'"
                    >{{ formatarMoeda(diferencaTotalB2C) }}</span
                  >
                </div>
                <div class="preview-item">
                  <span class="preview-label">Custo Kapazi</span>
                  <span class="preview-value">{{ formatarMoeda(custoKapaziTotal) }}</span>
                </div>
              </div>
              <p v-if="recaleError" class="error-msg">{{ recaleError }}</p>
            </div>
          </div>

          <div class="card">
            <h3 class="section-title">Itens ({{ orcamentoStore.itensInseridos.length }})</h3>
            <div class="itens-tabela">
              <div class="itens-header">
                <span class="itens-col-num">#</span>
                <span class="itens-col-desc">Descrição</span>
                <span class="itens-col-dim">Dimensões</span>
                <span class="itens-col-qtd">Qtd</span>
                <span class="itens-col-vlr">Valor Unit</span>
                <span class="itens-col-total">Total</span>
                <span class="itens-col-actions"></span>
              </div>
              <div
                v-for="(item, idx) in orcamentoStore.itensInseridos"
                :key="item.id"
                class="itens-item"
              >
                <div class="itens-row">
                  <span class="itens-col-num" data-label="#">{{ idx + 1 }}</span>
                  <span class="itens-col-desc" data-label="Descrição">{{
                    item.Descricao || item.descricao
                  }}</span>
                  <span class="itens-col-dim" data-label="Dimensões">{{
                    formatarDimensaoItem(item)
                  }}</span>
                  <span class="itens-col-qtd" data-label="Qtd">{{ item.qtd }}</span>
                  <span class="itens-col-vlr" data-label="Valor Unit">{{
                    formatarMoeda(item.vlr_vnd_unit_b2b ?? item.vlr_vnd_unit ?? 0)
                  }}</span>
                  <span class="itens-col-total" data-label="Total">{{
                    formatarMoeda(
                      (item.vlr_vnd_unit_b2b ?? item.vlr_vnd_unit ?? 0) * (item.qtd ?? 1),
                    )
                  }}</span>
                  <span class="itens-col-actions">
                    <button class="btn-icon" title="Editar item" @click="editarItem(item)">
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
                        <path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z" />
                        <path d="m15 5 4 4" />
                      </svg>
                    </button>
                    <button
                      class="btn-icon btn-icon-danger"
                      title="Remover item"
                      @click="removerItem(item, idx)"
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
                        <path d="M3 6h18" />
                        <path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6" />
                        <path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2" />
                        <line x1="10" x2="10" y1="11" y2="17" />
                        <line x1="14" x2="14" y1="11" y2="17" />
                      </svg>
                    </button>
                  </span>
                </div>
                <div v-if="item.descricao" class="itens-obs">{{ item.descricao }}</div>
                <div
                  v-if="composicaoPlaykap(item) || composicaoML(item)"
                  class="itens-obs itens-obs-composicao"
                >
                  {{ composicaoItemView(item) }}
                </div>
              </div>
            </div>
          </div>

          <div v-if="!isVinculado" class="btn-row">
            <button class="btn btn-success btn-lg" @click="handleFinalizar">
              Finalizar Orçamento
            </button>
          </div>
        </template>
      </section>

      <!-- Modal de Simulação -->
      <SimulacaoModal
        v-if="simulacaoLista.length"
        v-model="simulacaoModalOpen"
        :simulacao="simulacaoLista"
        :custo-total="custoTotal"
        @select="selecionarSimulacao"
      />

      <ClienteModal
        v-model="clienteModalOpen"
        :cliente-id="clienteModalId"
        :readonly="clienteModalSomenteLeitura"
        @saved="aoSalvarCliente"
      />
    </template>

    <template v-else>
      <section class="card resumo-card">
        <div class="resumo-top">
          <h2>Orçamento {{ orcamentoStore.numeroOrcamento }} finalizado!</h2>
          <button class="btn btn-sm btn-outline" @click="voltarLista">← Voltar</button>
        </div>

        <div class="resumo-totais-header">
          <span class="resumo-escopo">Resumo</span>
          <button
            class="btn-eye header-eye"
            :class="{ active: mostrarCustosHeader }"
            @click="toggleCustosHeader"
            title="Mostrar custos, lucro e frete"
          >
            <svg
              v-if="!mostrarCustosHeader"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
            >
              <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
              <circle cx="12" cy="12" r="3" />
            </svg>
            <svg
              v-else
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
            >
              <path
                d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94"
              />
              <path d="M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19" />
              <line x1="1" y1="1" x2="23" y2="23" />
            </svg>
          </button>
        </div>

        <div class="resumo-totais">
          <div class="resumo-total-item">
            <span class="resumo-label">Total Venda</span>
            <span class="resumo-preco">{{
              formatarMoeda(orcamentoStore.orcamentoHeader?.vnd_tot ?? 0)
            }}</span>
          </div>
          <div class="resumo-total-item">
            <span class="resumo-label">Total B2B</span>
            <span class="resumo-preco resumo-b2b">{{
              formatarMoeda(orcamentoStore.orcamentoHeader?.vnd_B2B_tot ?? 0)
            }}</span>
          </div>
          <div class="resumo-total-item">
            <span class="resumo-label">Mão de Obra</span>
            <span class="resumo-preco">{{
              formatarMoeda(orcamentoStore.orcamentoHeader?.mao_de_obra ?? 0)
            }}</span>
          </div>
          <div class="resumo-total-item">
            <span class="resumo-label">Frete B2C</span>
            <span class="resumo-preco">{{
              formatarMoeda(orcamentoStore.orcamentoHeader?.frtB2C ?? 0)
            }}</span>
          </div>
          <div class="resumo-total-item">
            <span class="resumo-label">Desconto</span>
            <span class="resumo-preco">{{
              formatarMoeda(orcamentoStore.orcamentoHeader?.desconto ?? 0)
            }}</span>
          </div>
          <div class="resumo-total-item">
            <span class="resumo-label">Total c/ Frete B2C</span>
            <span class="resumo-preco resumo-b2b">{{
              formatarMoeda(orcamentoStore.orcamentoHeader?.vnd_B2B_B2C_tot ?? 0)
            }}</span>
          </div>
          <div class="resumo-total-item">
            <span class="resumo-label">Validade</span>
            <span>{{
              orcamentoStore.orcamentoHeader?.validade
                ? new Date(orcamentoStore.orcamentoHeader.validade).toLocaleDateString('en-US')
                : validadeCalculada
            }}</span>
          </div>
        </div>

        <div v-if="mostrarCustosHeader" class="resumo-totais resumo-sensivel">
          <div class="resumo-total-item">
            <span class="resumo-label">Custo Total</span>
            <span>{{ formatarMoeda(orcamentoStore.orcamentoHeader?.cst_tot ?? 0) }}</span>
          </div>
          <div class="resumo-total-item">
            <span class="resumo-label">Custo Kapazi</span>
            <span>{{ formatarMoeda(custoKapaziTotal) }}</span>
          </div>
          <div class="resumo-total-item">
            <span class="resumo-label">Lucro Total</span>
            <span>{{ formatarMoeda(orcamentoStore.orcamentoHeader?.luc_tot ?? 0) }}</span>
          </div>
          <template v-if="descontoKapazi > 0">
            <div class="resumo-total-item">
              <span class="resumo-label">Custo Kapazi efetivo</span>
              <span>{{ formatarMoeda(custoKapaziEfetivo) }}</span>
            </div>
            <div class="resumo-total-item">
              <span class="resumo-label">Lucro Real (c/ desconto)</span>
              <span>{{ formatarMoeda(lucroRealKapazi) }}</span>
            </div>
            <div class="resumo-total-item">
              <span class="resumo-label">Margem Real (c/ desconto)</span>
              <span>{{ formatarMargemRealKapazi() }}</span>
            </div>
          </template>
          <div class="resumo-total-item">
            <span class="resumo-label">Frete B2B</span>
            <span>{{
              formatarMoeda(
                orcamentoStore.totaisRecalculo?.frete_b2b_total ??
                  orcamentoStore.orcamentoHeader?.frtB2B ??
                  0,
              )
            }}</span>
          </div>
          <div class="resumo-total-item">
            <span class="resumo-label">Margem Real</span>
            <span>{{ formatarMargemReal() }}</span>
          </div>
          <div class="resumo-total-item">
            <span class="resumo-label">Margem (Alvo)</span>
            <span
              >{{
                orcamentoStore.totaisRecalculo?.markup_alvo ??
                orcamentoStore.orcamentoHeader?.margem ??
                margemPadrao
              }}%</span
            >
          </div>
          <div class="resumo-total-item">
            <span class="resumo-label">Margem Efetiva</span>
            <span>{{ orcamentoStore.totaisRecalculo?.margem ?? 0 }}%</span>
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
              <span class="itens-col-vlr">Valor Unit</span>
              <span class="itens-col-total">Total</span>
            </div>
            <div
              v-for="(item, idx) in orcamentoStore.itensInseridos"
              :key="item.id"
              class="itens-row"
            >
              <span class="itens-col-num" data-label="#">{{ idx + 1 }}</span>
              <span class="itens-col-desc" data-label="Descrição">
                {{ item.Descricao || item.descricao }}
                <span
                  v-if="composicaoPlaykap(item) || composicaoML(item)"
                  class="itens-obs itens-obs-composicao"
                >
                  {{ composicaoItemView(item) }}
                </span>
              </span>
              <span class="itens-col-dim" data-label="Dimensões">{{
                formatarDimensaoItem(item)
              }}</span>
              <span class="itens-col-qtd" data-label="Qtd">{{ item.qtd }}</span>
              <span class="itens-col-vlr" data-label="Valor Unit">{{
                formatarMoeda(item.vlr_vnd_unit_b2b ?? item.vlr_vnd_unit ?? 0)
              }}</span>
              <span class="itens-col-total" data-label="Total">{{
                formatarMoeda((item.vlr_vnd_unit_b2b ?? item.vlr_vnd_unit ?? 0) * (item.qtd ?? 1))
              }}</span>
            </div>
          </div>
        </div>

        <div v-if="!isVinculado && !statusTerminal" class="resumo-obs" data-section="condicoes">
          <div class="condicoes-head">
            <div class="condicoes-title">
              <h3>Condições de Pagamento</h3>
              <span
                class="cond-status-badge"
                :class="
                  condicoesPendentes
                    ? 'cond-status-pendente'
                    : condicoesSalvas
                      ? 'cond-status-salvo'
                      : 'cond-status-vazio'
                "
                :title="
                  condicoesPendentes
                    ? 'Clique em Salvar Condições antes de enviar'
                    : condicoesSalvas
                      ? 'Condições salvas na ORCA'
                      : 'Nenhuma condição salva'
                "
              >
                {{
                  condicoesPendentes ? 'Não salvo' : condicoesSalvas ? 'Salvas' : 'Sem condições'
                }}
              </span>
            </div>
            <div class="condicoes-botoes">
              <button
                v-if="modoCondicoesAvancado"
                class="btn btn-sm btn-outline"
                @click="modoCondicoesAvancado = false"
              >
                Seletor
              </button>
              <button v-else class="btn btn-sm btn-outline" @click="modoCondicoesAvancado = true">
                Modo avançado
              </button>
              <button class="btn btn-sm btn-outline" @click="gerarCondicoes">
                Gerar Condições
              </button>
              <button class="btn btn-sm btn-outline" @click="salvarCondicoes">
                Salvar Condições
              </button>
              <button
                v-if="orcamentoStore.orcamentoHeader?.id"
                class="btn btn-sm btn-outline"
                title="Gerar/ajustar boletos, Pix e cartão deste orçamento"
                @click="pagamentoModalOpen = true"
              >
                💳 Financeiro
              </button>
            </div>
          </div>

          <template v-if="!modoCondicoesAvancado">
            <div class="cond-seletor">
              <div class="cond-methods">
                <label class="cond-check">
                  <input
                    type="checkbox"
                    v-model="metodosPagamento.pix"
                    @change="selecionarPagamento(abaPagamento, cartaoSelecionado)"
                  />
                  Pix
                </label>
                <label class="cond-check">
                  <input
                    type="checkbox"
                    v-model="metodosPagamento.boleto"
                    @change="selecionarPagamento(abaPagamento, cartaoSelecionado)"
                  />
                  Boleto
                </label>
                <label class="cond-check">
                  <input
                    type="checkbox"
                    v-model="metodosPagamento.cartao"
                    @change="selecionarPagamento(abaPagamento, cartaoSelecionado)"
                  />
                  Cartão
                </label>
              </div>

              <div class="cond-tabs">
                <button
                  class="cond-tab"
                  :class="{ active: abaPagamento === 'pix' }"
                  @click="selecionarPagamento('pix')"
                >
                  Pix / Boleto
                </button>
                <button
                  class="cond-tab"
                  :class="{ active: abaPagamento === 'cartao' }"
                  @click="selecionarPagamento('cartao')"
                >
                  Cartão de Crédito
                </button>
              </div>

              <div v-if="abaPagamento === 'pix'" class="cond-pix">
                <div class="cond-pix-desconto">
                  <label>Desconto Pix (%)</label>
                  <input
                    v-model.number="descontoPixPercentual"
                    type="number"
                    min="0"
                    max="100"
                    step="0.01"
                    @change="selecionarPagamento('pix')"
                  />
                </div>
                <p v-if="descontoPixPercentual > 0" class="cond-badge badge-ok cond-pix-impacto">
                  Com desconto: seu lucro será R$
                  {{ pixImpacto.lucro.toFixed(2).replace('.', ',') }} ({{
                    pixImpacto.margem.toFixed(2).replace('.', ',')
                  }}%)
                </p>
                <p v-if="metodosPagamento.pix" class="cond-linha">{{ condicoesCalculadas.pix }}</p>
                <div v-if="metodosPagamento.pix" class="cond-boleto-parcelas">
                  <label for="cond-parcelas-pix">Parcelas do Pix</label>
                  <select
                    id="cond-parcelas-pix"
                    :value="parcelasPix ?? 2"
                    @change="alterarParcelasPix"
                  >
                    <option :value="1">1x de {{ formatarValorParcelaPix(1) }} (pagamento em até 5 dias)</option>
                    <option :value="2">2x de {{ formatarValorParcelaPix(2) }}</option>
                  </select>
                </div>
                <p v-if="metodosPagamento.boleto" class="cond-linha">
                  {{ condicoesCalculadas.boleto }}
                </p>
                <div v-if="metodosPagamento.boleto" class="cond-boleto-parcelas">
                  <label for="cond-parcelas-boleto">Parcelas do Boleto (máx.
                    {{ maxParcelasBoleto }}x)</label>
                  <select
                    id="cond-parcelas-boleto"
                    :value="parcelasBoleto ?? maxParcelasBoleto"
                    @change="alterarParcelasBoleto"
                  >
                    <option v-for="n in maxParcelasBoleto" :key="n" :value="n">
                      {{ n }}x de {{ formatarValorParcelaBoleto(n) }}
                    </option>
                  </select>
                </div>
                <p v-if="faturarCliente" class="cond-linha cond-faturar">
                  Faturamos com até 20 dias da entrega do produto
                </p>
              </div>

              <div v-else class="cond-cartao">
                <div class="cond-toggle">
                  <button
                    class="cond-toggle-btn"
                    :class="{ active: repassarTaxasCartao }"
                    @click="setRepasseTaxa(true)"
                  >
                    Cliente paga a taxa
                  </button>
                  <button
                    class="cond-toggle-btn"
                    :class="{ active: !repassarTaxasCartao }"
                    @click="setRepasseTaxa(false)"
                  >
                    Eu assumo a taxa
                  </button>
                </div>

                <div v-if="provedores.length > 1" class="cond-cartao-row">
                  <label>Instituição</label>
                  <select v-model="provedorSelecionado" @change="selecionarProvedor()">
                    <option :value="null">Todas</option>
                    <option v-for="p in provedores" :key="p.id" :value="p.id">
                      {{ p.nome }}
                    </option>
                  </select>
                </div>

                <div class="cond-cartao-row">
                  <label>Parcelas</label>
                  <select
                    v-model="cartaoSelecionado"
                    @change="selecionarPagamento('cartao', cartaoSelecionado)"
                  >
                    <option :value="null">Selecione...</option>
                    <option
                      v-for="o in condicoesCalculadas.cartao"
                      :key="chaveCartao(o)"
                      :value="chaveCartao(o)"
                    >
                      {{ o.parcelas }}x de R$ {{ o.parcela.toFixed(2).replace('.', ',') }} (R$
                      {{ o.total.toFixed(2).replace('.', ',') }})<template v-if="o.provedor">
                        — {{ o.provedor }}</template
                      ><template v-if="o.maisVantajosa"> ⭐</template>
                    </option>
                  </select>
                </div>

                <div v-if="cartaoSelecionadoInfo" class="cond-badge" :class="corBadgeCartao">
                  <strong>
                    Valor p/ cliente: R$
                    {{ cartaoSelecionadoInfo.total.toFixed(2).replace('.', ',') }} ({{
                      cartaoSelecionadoInfo.parcelas
                    }}x de R$ {{ cartaoSelecionadoInfo.parcela.toFixed(2).replace('.', ',') }})
                    <template v-if="cartaoSelecionadoInfo.provedor">
                      — {{ cartaoSelecionadoInfo.provedor }}</template
                    >
                  </strong>
                  <span>
                    {{ repassarTaxasCartao ? 'Seu lucro preservado' : 'Seu lucro real' }}: R$
                    {{ lucroCartao.toFixed(2).replace('.', ',') }} ({{
                      margemRealCartao.toFixed(2).replace('.', ',')
                    }}%)
                  </span>
                  <span v-if="!repassarTaxasCartao && custoDaTaxa > 0" class="cond-taxa-custo">
                    Custo da taxa pago pelo vendedor: R$
                    {{ custoDaTaxa.toFixed(2).replace('.', ',') }}
                  </span>
                </div>
                <p v-else class="cond-hint">Selecione um parcelamento acima.</p>
              </div>

              <div class="cond-mix">
                <label class="cond-check">
                  <input
                    type="checkbox"
                    v-model="mesclarMetodos"
                    @change="selecionarPagamento(abaPagamento, cartaoSelecionado)"
                  />
                  Mesclar métodos na saída
                </label>
                <label v-if="mesclarMetodos" class="cond-check">
                  <input
                    type="checkbox"
                    v-model="trazerTodasParcelas"
                    @change="selecionarPagamento(abaPagamento, cartaoSelecionado)"
                  />
                  Trazer todas as parcelas
                </label>
              </div>
            </div>
          </template>

          <div class="cond-textarea-wrap">
            <textarea
              v-model="condicoesPagamento"
              placeholder="Pix (2x de R$ ...): ...&#10;Boleto (3x de R$ ...): ..."
              :rows="linhasCondicoes"
              @input="autoResize($event.target as HTMLTextAreaElement)"
            ></textarea>
            <div class="cond-textarea-controls">
              <button
                class="btn btn-outline btn-xs"
                title="Diminuir caixa"
                @click="linhasCondicoes = Math.max(2, linhasCondicoes - 1)"
              >
                −
              </button>
              <button
                class="btn btn-outline btn-xs"
                title="Aumentar caixa"
                @click="linhasCondicoes = Math.min(15, linhasCondicoes + 1)"
              >
                +
              </button>
            </div>
          </div>
          <h3>Observações do Orçamento</h3>
          <div class="cond-textarea-wrap">
            <textarea
              v-model="observacaoOrcamento"
              placeholder="Informações importantes para o cliente..."
              :rows="linhasObservacoes"
              @input="autoResize($event.target as HTMLTextAreaElement)"
            ></textarea>
            <div class="cond-textarea-controls">
              <button
                class="btn btn-outline btn-xs"
                title="Diminuir caixa"
                @click="linhasObservacoes = Math.max(2, linhasObservacoes - 1)"
              >
                −
              </button>
              <button
                class="btn btn-outline btn-xs"
                title="Aumentar caixa"
                @click="linhasObservacoes = Math.min(15, linhasObservacoes + 1)"
              >
                +
              </button>
            </div>
          </div>
        </div>

        <template v-else>
          <div v-if="orcamentoStore.orcamentoHeader?.condicoes_pagamento" class="resumo-obs">
            <h3>Condições de Pagamento</h3>
            <p style="white-space: pre-line">
              {{ orcamentoStore.orcamentoHeader.condicoes_pagamento }}
            </p>
          </div>
          <div v-if="orcamentoStore.orcamentoHeader?.observacao" class="resumo-obs">
            <h3>Observações</h3>
            <p>{{ orcamentoStore.orcamentoHeader.observacao }}</p>
          </div>
        </template>

        <div class="status-top">
          <span class="status-top-label">Status do Orçamento</span>
          <span class="badge-status" :class="`badge-${statusAtual.toLowerCase()}`">
            {{ statusLabel(statusAtual) }}
          </span>
        </div>

        <div v-if="orcamentoStore.statusHistorico.length" class="status-section">
          <h3 class="status-section-title">Histórico de Status</h3>
          <div class="status-historico">
            <div
              v-for="(reg, idx) in orcamentoStore.statusHistorico"
              :key="idx"
              class="status-historico-item"
            >
              <span class="status-historico-dot"></span>
              <div class="status-historico-body">
                <div class="status-historico-line">
                  <span class="badge-status" :class="`badge-${reg.status.toLowerCase()}`">
                    {{ statusLabel(reg.status) }}
                  </span>
                  <span v-if="reg.status_anterior" class="status-historico-de">
                    (anterior: {{ statusLabel(reg.status_anterior) }})
                  </span>
                  <span class="status-historico-data">{{ formatarDataHora(reg.created_at) }}</span>
                </div>
                <div v-if="reg.motivo" class="status-historico-motivo">{{ reg.motivo }}</div>
              </div>
            </div>
          </div>
        </div>

        <div v-if="!statusTerminal" class="status-section">
          <h3 class="status-section-title">Ações de Status</h3>
          <div class="status-actions">
            <button
              v-if="statusAtual === 'RASCUNHO'"
              class="btn btn-primary btn-sm"
              :disabled="atualizandoStatus"
              @click="pedirConfirmacao('AGUARDANDO_RETORNO')"
            >
              Enviar
            </button>
            <button
              v-if="statusAtual === 'AGUARDANDO_RETORNO' || statusAtual === 'ENVIADO'"
              class="btn btn-primary btn-sm"
              :disabled="atualizandoStatus"
              @click="pedirConfirmacao('APROVADO')"
            >
              Aprovar
            </button>
            <button
              v-if="statusAtual === 'APROVADO' && !isVinculado"
              class="btn btn-accent btn-sm"
              :disabled="atualizandoStatus"
              @click="pedirConfirmacao('AGUARDANDO_FATURAMENTO')"
            >
              Converter em Pedido
            </button>
            <button
              v-if="statusAtual === 'AGUARDANDO_FATURAMENTO' && isVinculado"
              class="btn btn-accent btn-sm"
              :disabled="atualizandoStatus"
              @click="faturarComParcelas()"
            >
              Faturar
            </button>
            <button
              v-if="statusAtual === 'FATURADO' && isVinculado"
              class="btn btn-accent btn-sm"
              :disabled="atualizandoStatus"
              @click="pedirConfirmacao('ENTREGUE')"
            >
              Entregar
            </button>
            <button
              v-if="isVinculado && !statusTerminal"
              class="btn btn-sm btn-outline"
              title="Ajustar boletos, Pix e cartão deste pedido"
              @click="abrirFinanceiro()"
            >
              💳 Financeiro
            </button>
            <button
              v-if="
                !isVinculado &&
                statusAtual !== 'FATURADO' &&
                statusAtual !== 'ENTREGUE' &&
                statusAtual !== 'APROVADO'
              "
              class="btn btn-sm btn-danger-outline"
              :disabled="atualizandoStatus"
              @click="pedirConfirmacao('RECUSADO')"
            >
              Recusar
            </button>
            <button
              v-if="statusAtual !== 'FATURADO' && statusAtual !== 'ENTREGUE'"
              class="btn btn-sm btn-outline"
              :disabled="atualizandoStatus"
              @click="pedirConfirmacao('CANCELADO')"
            >
              Cancelar
            </button>
            <button
              v-if="statusAtual === 'AGUARDANDO_RETORNO' || statusAtual === 'ENVIADO'"
              class="btn btn-sm btn-outline"
              :disabled="atualizandoStatus"
              @click="pedirConfirmacao('RASCUNHO')"
            >
              ← Voltar para Rascunho
            </button>
            <button
              v-if="
                statusAtual === 'APROVADO' ||
                statusAtual === 'RECUSADO' ||
                statusAtual === 'CANCELADO'
              "
              class="btn btn-sm btn-outline"
              :disabled="atualizandoStatus"
              @click="pedirConfirmacao('AGUARDANDO_RETORNO')"
            >
              ← Voltar para Aguardando Retorno
            </button>
          </div>
          <p v-if="orcamentoStore.error" class="error-msg">{{ orcamentoStore.error }}</p>
        </div>

        <div v-if="isVinculado || statusAtual === 'APROVADO'" class="kapazi-card">
          <h3 class="kapazi-title">Dados para Kapazi (Fábrica)</h3>
          <div class="kapazi-grid">
            <div class="field">
              <label>Data envio p/ fábrica</label>
              <input v-model="kapaziForm.data_envio_fabrica" type="date" />
            </div>
            <div class="field">
              <label>Nº Pedido da Fábrica *</label>
              <input
                v-model="kapaziForm.num_pedido_fabrica"
                type="text"
                placeholder="Retornado pela Kapazi"
              />
            </div>
            <div class="field">
              <label>Data aprovação layout</label>
              <input v-model="kapaziForm.data_aprovacao_layout" type="date" />
            </div>
            <div class="field">
              <label>Nº Pedido de Venda</label>
              <input
                v-model="kapaziForm.num_pedido_venda"
                type="text"
                placeholder="Email da Kapazi"
              />
            </div>
            <div class="field">
              <label>Nº NF</label>
              <input v-model="kapaziForm.num_nf" type="text" />
            </div>
            <div class="field">
              <label>Acerto (boleto / CC / Pix)</label>
              <input v-model="kapaziForm.forma_pagamento_fabrica" type="text" />
            </div>
            <div class="field">
              <label>Desconto Kapazi (%)</label>
              <input
                v-model="kapaziForm.desconto_kapazi_perc"
                type="number"
                step="0.01"
                min="0"
                placeholder="Ex.: 10"
              />
            </div>
            <div class="field">
              <label>Transportadora B2B</label>
              <input v-model="kapaziForm.transportadoraB2B" type="text" />
            </div>
            <div class="field">
              <label>Transportadora B2C</label>
              <input v-model="kapaziForm.transportadoraB2C" type="text" />
            </div>
            <div class="field">
              <label>Previsão de chegada</label>
              <input v-model="kapaziForm.dataPrevisao" type="date" />
            </div>
            <div class="field">
              <label>Data de chegada</label>
              <input v-model="kapaziForm.dataChegada" type="date" />
            </div>
            <div class="field">
              <label>Frete B2B real</label>
              <input v-model="kapaziForm.freteB2BReal" type="number" step="0.01" />
            </div>
            <div class="field">
              <label>Frete B2C real</label>
              <input v-model="kapaziForm.freteB2CReal" type="number" step="0.01" />
            </div>
            <div class="field kapazi-full">
              <label>Código de rastreio</label>
              <input
                v-model="kapaziForm.cod_rastreio"
                type="text"
                placeholder="Código dos Correios"
              />
            </div>
          </div>
          <div class="kapazi-actions">
            <button
              class="btn btn-accent btn-sm"
              :disabled="salvandoKapazi"
              @click="salvarDadosKapazi"
            >
              {{ salvandoKapazi ? 'Salvando…' : 'Salvar Dados da Fábrica' }}
            </button>
          </div>
        </div>

        <div class="btn-row resumo-actions resumo-toolbar">
          <button class="btn btn-primary btn-lg" @click="novoOrcamento">Novo Orçamento</button>
          <div class="switch-wrap">
            <label class="switch">
              <input type="checkbox" v-model="faturarCliente" />
              <span class="slider"></span>
            </label>
            <span class="switch-label">Faturar para cliente</span>
          </div>
          <span
            v-if="condicoesPendentes"
            class="cond-pendente-indicator"
            title="Clique em Salvar Condições antes de enviar"
          >
            ● condições não salvas
          </span>
          <button
            class="btn btn-whatsapp btn-lg"
            :disabled="enviandoWhatsApp"
            @click="enviarWhatsApp"
          >
            {{ enviandoWhatsApp ? 'Enviando…' : 'WhatsApp' }}
          </button>
          <button class="btn btn-secondary btn-lg" @click="gerarPdf">Gerar PDF</button>
          <button
            v-if="isVinculado"
            class="btn btn-secondary btn-lg"
            @click="gerarPdfPedidoVendaView"
          >
            PDF Pedido de Venda
          </button>
        </div>
      </section>
    </template>

    <Transition name="toast-fade">
      <div v-if="toastMsg" class="app-toast">{{ toastMsg }}</div>
    </Transition>

    <Teleport to="body">
      <Transition name="modal-fade">
        <div v-if="statusConfirm" class="status-modal-overlay" @click.self="cancelarStatus">
          <div class="status-modal-card">
            <h3>Tem certeza que deseja {{ statusConfirm.rotulo.toLowerCase() }} este orçamento?</h3>
            <label v-if="statusConfirm.pedirMotivo" class="status-modal-label">
              Motivo (opcional)
              <input
                v-model="motivoStatus"
                type="text"
                class="status-modal-input"
                placeholder="Ex.: cliente pediu mudança no produto"
              />
            </label>
            <div class="status-modal-actions">
              <button class="btn btn-sm btn-outline" @click="cancelarStatus">Cancelar</button>
              <button class="btn btn-primary btn-sm" @click="confirmarStatus">Confirmar</button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <PagamentoModal
      v-if="orcamentoStore.orcamentoHeader?.id"
      v-model="pagamentoModalOpen"
      :orca-id="orcamentoStore.orcamentoHeader.id"
      :cod-orca="orcamentoStore.orcamentoHeader.cod_orca"
      :venda="pagamentoModalVenda"
      :custo="pagamentoModalCusto"
      :metodos="metodosPagamento"
      :desconto-pix-percentual="descontoPixPercentual"
      :parcelas-cartao="pagamentoModalParcelasCartao"
      :cartao-parcelas="pagamentoModalCartao"
      :parcelas-boleto="parcelasBoleto"
      :parcelas-pix="parcelasPix"
      :faturar="faturarCliente"
      :modo-faturamento="pagamentoModalModoFaturamento"
      @saved="aoSalvarFinanceiro"
    />
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

.perfil-banner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  flex-wrap: wrap;
  background: #fef3c7;
  border: 1px solid #f59e0b;
  border-radius: 10px;
  padding: 0.75rem 1rem;
  color: #92400e;
  font-size: 0.9rem;
}

.perfil-banner-text {
  line-height: 1.4;
}

.mt-075 {
  margin-top: 0.75rem;
}

.card {
  background: var(--card-bg, #fff);
  border-radius: 10px;
  padding: 1.25rem;
  box-shadow: var(--shadow-card);
  border: 1px solid var(--border-subtle, var(--border-subtle));
}

.card-totais {
  background: var(--primary-soft, var(--primary-soft));
  border: 1px solid var(--primary-light, #3b82f6);
}

.resumo-b2b {
  color: var(--danger) !important;
}

.welcome-card {
  background: var(--primary-soft, var(--primary-soft));
  border: 1px solid var(--primary-light, #3b82f6);
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
  color: var(--text-secondary);
  margin-bottom: 0.5rem;
}

.welcome-cliente strong {
  color: var(--text-primary);
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
  color: var(--text-secondary);
}

.section-title {
  font-size: 0.8rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--primary, #1e40af);
  margin: 0 0 1rem;
  padding: 0.35rem 0 0.4rem 0.6rem;
  border-left: 4px solid;
  border-image: linear-gradient(180deg, var(--primary, #1e40af), var(--accent, #f97316)) 1;
  border-bottom: 1px solid var(--border-light, var(--border-light));
}

.section-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
}

.section-title-row .section-title {
  margin-bottom: 0;
}

.field {
  margin-bottom: 0.875rem;
}

.field label {
  display: block;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--text-secondary);
  margin-bottom: 0.25rem;
}

.field input,
.field select,
.field textarea {
  width: 100%;
  padding: 0.5rem 0.7rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  font-size: 0.9rem;
  color: var(--text-primary);
  background: var(--input-bg);
  outline: none;
  transition: border-color 0.15s;
}

.field input:focus,
.field select:focus,
.field textarea:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.18);
}

.field textarea {
  resize: vertical;
  font-family: inherit;
}

.input-readonly {
  background: var(--border-subtle) !important;
  cursor: default;
  color: var(--text-secondary);
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
  color: var(--text-secondary);
  background: var(--border-subtle);
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

.modo-entrada {
  display: flex;
  gap: 0.5rem;
}

.btn-seg {
  padding: 0.4rem 0.9rem;
  border: 1px solid var(--border-light);
  border-radius: 8px;
  background: var(--card-bg);
  color: var(--text-secondary);
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s;
}

.btn-seg:hover {
  border-color: var(--primary);
  color: var(--primary);
}

.btn-seg.active {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
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
  border-radius: 8px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  border: none;
  transition:
    background 0.2s,
    transform 0.15s;
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn:active:not(:disabled) {
  transform: scale(0.97);
}

.btn-primary {
  background: var(--primary);
  color: #fff;
}

.btn-primary:hover:not(:disabled) {
  background: var(--primary-hover);
}

.btn-accent {
  background: var(--accent);
  color: #fff;
}

.btn-accent:hover:not(:disabled) {
  background: var(--accent-hover);
}

.btn-secondary {
  background: var(--border-subtle);
  color: var(--text-secondary);
}

.btn-secondary:hover:not(:disabled) {
  background: var(--border-light);
}

.btn-whatsapp {
  background: #25d366;
  color: #fff;
}

.btn-whatsapp:hover:not(:disabled) {
  background: #1fb959;
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

.medida-exata-wrap {
  margin-top: 0.5rem;
  padding: 0.65rem 0.75rem;
  border: 1px dashed var(--accent, #f97316);
  border-radius: 8px;
  background: var(--accent-soft, rgba(249, 115, 22, 0.08));
}

.checkbox-inline {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.85rem;
  color: var(--text-primary);
  cursor: pointer;
  font-weight: 500;
}

.checkbox-inline input[type='checkbox'] {
  width: 16px;
  height: 16px;
  accent-color: var(--accent, #f97316);
  cursor: pointer;
  flex-shrink: 0;
}

.checkbox-inline strong {
  color: var(--accent, #f97316);
}

.field-hint {
  display: block;
  font-size: 0.72rem;
  color: var(--text-secondary);
  margin-top: 0.2rem;
}

.btn-eye {
  background: none;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  color: var(--primary);
  flex-shrink: 0;
  transition:
    background 0.15s,
    color 0.15s,
    border-color 0.15s;
}

.btn-eye:hover {
  background: var(--border-subtle);
}

.btn-eye.active {
  color: var(--danger);
  border-color: var(--danger-light);
}

.btn-eye svg {
  width: 18px;
  height: 18px;
}

.header-eye {
  width: 30px;
  height: 30px;
  margin-left: 0.5rem;
}

.header-eye svg {
  width: 15px;
  height: 15px;
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
  color: var(--text-secondary);
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
  background: var(--border-subtle);
  color: var(--text-primary);
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
  border: 1px solid var(--border-light);
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
  background: var(--primary-soft);
}

.recalc-card {
  margin-top: 1rem;
  padding-top: 1rem;
  border-top: 1px dashed var(--primary-light);
}

.recalc-title {
  font-size: 0.9rem;
  font-weight: 600;
  color: #166534;
  margin-bottom: 0.6rem;
}

.recalc-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 0.75rem;
}

.recalc-item label {
  display: block;
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--text-secondary);
  margin-bottom: 0.3rem;
}

.recalc-item .novo-valor-wrap input {
  width: 100%;
  max-width: none;
}

.recalc-item-action {
  display: flex;
  align-items: flex-end;
  gap: 0.5rem;
}

.recalc-item-action .btn {
  flex: 1;
  width: auto;
}

.recalc-item-action .btn-primary {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}

.recalc-item-action .btn-primary:hover:not(:disabled) {
  background: var(--primary-light);
}

.recalc-item-action .btn-outline {
  background: transparent;
}

.recalc-obs {
  margin-top: 0.85rem;
}

.recalc-obs label {
  display: block;
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--text-secondary);
  margin-bottom: 0.3rem;
}

.recalc-obs textarea {
  width: 100%;
  padding: 0.55rem 0.7rem;
  border: 1px solid var(--border-light);
  border-radius: 8px;
  font-family: inherit;
  font-size: 0.9rem;
  resize: vertical;
}

.recalc-preview {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 0.5rem;
  margin-top: 0.85rem;
  padding-top: 0.75rem;
  border-top: 1px dashed var(--primary-light);
}

.preview-item {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
  background: rgba(187, 247, 208, 0.3);
  border-radius: 8px;
  padding: 0.4rem 0.6rem;
}

.preview-label {
  font-size: 0.65rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--secondary);
}

.preview-value {
  font-size: 0.95rem;
  font-weight: 700;
  color: #166534;
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
  from {
    opacity: 0;
    transform: translateY(-8px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
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
  background: var(--table-hover);
  border: 1px solid var(--border-light);
  border-radius: 6px;
  text-align: left;
  cursor: pointer;
  font-size: 0.85rem;
  transition: background 0.15s;
}

.cliente-item:hover {
  background: var(--primary-soft);
  border-color: var(--primary);
}

.cliente-item strong {
  color: var(--text-primary);
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
  color: var(--text-primary);
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
}

.btn-sm:hover {
  filter: brightness(0.96);
}

.btn-outline {
  border: 1px solid var(--border-light);
  background: var(--card-bg);
  color: var(--text-secondary);
}

.btn-outline:hover:not(:disabled) {
  background: var(--border-subtle);
}

.btn-danger-outline {
  border: 1px solid #dc2626;
  background: var(--card-bg);
  color: #dc2626;
}

.btn-danger-outline:hover:not(:disabled) {
  background: #fef2f2;
}

.summary-section {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.summary-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  cursor: pointer;
  padding: 0.75rem 1rem;
  background: var(--card-bg);
  border-radius: 10px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06);
  user-select: none;
}

.summary-header:hover {
  background: var(--table-hover);
}

.summary-title {
  font-size: 0.9rem;
  font-weight: 700;
  color: var(--text-primary);
  margin: 0;
}

.summary-toggle {
  font-size: 0.75rem;
  color: var(--secondary);
}

.btn-success {
  background: #16a34a;
  color: #fff;
}

.btn-success:hover:not(:disabled) {
  background: #15803d;
}

.card-totais {
  background: var(--primary-soft);
  border: 1px solid var(--primary-light);
}

.totais-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.75rem;
}

.totais-cliente {
  font-size: 0.85rem;
  color: var(--text-secondary);
  font-weight: 600;
}

.totais-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.5rem;
}

.totais-sensivel {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.5rem;
  margin-top: 0.75rem;
  padding-top: 0.75rem;
  border-top: 1px dashed var(--primary-light);
  background: rgba(187, 247, 208, 0.25);
  border-radius: 8px;
  padding-left: 0.75rem;
  padding-right: 0.75rem;
  padding-bottom: 0.75rem;
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
  color: var(--text-primary);
  display: flex;
  align-items: center;
  gap: 0.35rem;
}

.welcome-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.read-only-badge {
  background: var(--border-light);
  color: var(--text-secondary);
}

.edit-badge {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  background: var(--warning-soft);
  color: #92400e;
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
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
  border-bottom: 1px solid var(--border-light);
}

.itens-item + .itens-item {
  border-top: 1px solid var(--border-subtle);
}

.itens-obs {
  display: block;
  padding: 0 0.75rem 0.4rem 2.5rem;
  font-size: 0.78rem;
  color: var(--text-secondary);
  font-style: italic;
}

.itens-obs-composicao {
  font-style: normal;
  font-weight: 600;
  color: var(--primary, #1e40af);
}

.itens-col-num {
  width: 2rem;
  flex-shrink: 0;
  text-align: center;
}
.itens-col-desc {
  flex: 1;
  min-width: 0;
}
.itens-col-dim {
  width: 6rem;
  flex-shrink: 0;
  text-align: center;
}
.itens-col-qtd {
  width: 3rem;
  flex-shrink: 0;
  text-align: center;
}
.itens-col-vlr {
  width: 6rem;
  flex-shrink: 0;
  text-align: right;
}
.itens-col-total {
  width: 6rem;
  flex-shrink: 0;
  text-align: right;
}
.itens-col-actions {
  width: 4.5rem;
  flex-shrink: 0;
  display: flex;
  gap: 0.25rem;
  justify-content: flex-end;
  align-items: center;
}

.btn-icon {
  width: 32px;
  height: 32px;
  border: none;
  border-radius: 50%;
  background: transparent;
  color: var(--secondary);
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transition:
    background 0.15s,
    color 0.15s;
}
.btn-icon:hover {
  background: var(--border-subtle);
  color: var(--primary);
}
.btn-icon-danger:hover {
  background: #fef2f2;
  color: var(--danger, #dc2626);
}

.resumo-totais {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1rem;
  text-align: left;
  max-width: 500px;
  margin: 0 auto 1.5rem;
}

.resumo-totais-header {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.5rem;
  max-width: 500px;
  margin: 0 auto 0.5rem;
}

.resumo-escopo {
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--secondary);
}

.resumo-sensivel {
  border-top: 1px dashed var(--primary-light);
  padding-top: 1rem;
  background: rgba(187, 247, 208, 0.2);
  border-radius: 8px;
  padding-left: 0.75rem;
  padding-right: 0.75rem;
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
  color: var(--text-primary);
}

.resumo-card {
  text-align: center;
  padding: 2rem 1.5rem;
}

.resumo-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  max-width: 600px;
  margin: 0 auto 0.5rem;
  text-align: left;
}

.resumo-card h2 {
  color: #16a34a;
  font-size: 1.25rem;
  margin-bottom: 0;
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
  align-items: center;
  flex-wrap: wrap;
}

.resumo-obs {
  max-width: 600px;
  margin: 1.25rem auto;
  padding: 0.9rem 1.1rem;
  background: var(--border-subtle);
  border: 1px solid var(--border-light);
  border-radius: 8px;
  text-align: left;
}

.resumo-obs h3 {
  font-size: 0.95rem;
  margin: 0 0 0.35rem;
  color: var(--text-primary);
}

.resumo-obs p {
  margin: 0;
  font-size: 0.9rem;
  color: var(--text-secondary);
  white-space: pre-wrap;
}

.resumo-obs textarea {
  width: 100%;
  font-size: 0.9rem;
  font-family: inherit;
  padding: 0.5rem 0.6rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-primary);
  resize: vertical;
}

/* Caixa com botões +/− para ajustar a altura (mobile friendly) */
.cond-textarea-wrap {
  position: relative;
}
.cond-textarea-wrap textarea {
  margin-bottom: 0.4rem;
}
.cond-textarea-controls {
  display: flex;
  justify-content: flex-end;
  gap: 0.35rem;
  margin-bottom: 1rem;
}
.cond-textarea-controls .btn {
  width: 34px;
  height: 30px;
  padding: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 1rem;
  line-height: 1;
}

.resumo-obs .condicoes-botoes {
  margin: 0 0 0.5rem;
}

.resumo-obs .condicoes-botoes + textarea {
  margin-bottom: 1rem;
}

.condicoes-edit {
  width: 100%;
  font-size: 0.9rem;
  font-family: inherit;
  padding: 0.5rem 0.6rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--card-bg);
  resize: vertical;
}

.condicoes-botoes {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

/* Seletor de condições de pagamento (Etapa 3) */
.condicoes-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  flex-wrap: wrap;
  margin-bottom: 0.5rem;
}
.condicoes-head h3 {
  margin: 0;
}
.condicoes-title {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  flex-wrap: wrap;
}
.cond-status-badge {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  padding: 0.15rem 0.5rem;
  border-radius: 999px;
  border: 1px solid transparent;
}
.cond-status-pendente {
  background: #fef3c7;
  border-color: #f59e0b;
  color: #92400e;
}
.cond-status-salvo {
  background: var(--success-bg, #ecfdf5);
  border-color: var(--success, #16a34a);
  color: var(--success-strong, #065f46);
}
.cond-status-vazio {
  background: var(--border-light);
  border-color: var(--border-strong);
  color: var(--text-secondary);
}
.cond-pendente-indicator {
  font-size: 0.75rem;
  color: #92400e;
  font-weight: 600;
  white-space: nowrap;
}
.cond-seletor {
  border: 1px solid var(--border-light);
  border-radius: 8px;
  padding: 0.75rem;
  margin-bottom: 0.75rem;
  background: var(--card-bg);
}
.cond-methods {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
}
.cond-check {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  color: var(--text-primary);
}
.cond-check input {
  accent-color: var(--success, #16a34a);
  width: 16px;
  height: 16px;
  cursor: pointer;
}
.cond-mix {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin-top: 0.75rem;
  padding-top: 0.6rem;
  border-top: 1px dashed var(--border-light);
}
.cond-pix-desconto {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}
.cond-pix-desconto label {
  font-size: 0.85rem;
  font-weight: 600;
}
.cond-pix-desconto input {
  width: 90px;
  padding: 0.35rem 0.5rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  font-family: inherit;
  font-size: 0.9rem;
  background: var(--card-bg);
  color: var(--text-primary);
}
.cond-pix-impacto {
  margin: 0 0 0.5rem;
  font-size: 0.82rem;
}
.cond-tabs {
  display: flex;
  gap: 0.35rem;
  margin-bottom: 0.75rem;
}
.cond-tab {
  flex: 1;
  padding: 0.5rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-secondary);
  font-weight: 600;
  cursor: pointer;
  font-family: inherit;
  font-size: 0.85rem;
  transition:
    background 0.15s,
    border-color 0.15s,
    color 0.15s;
}
.cond-tab:hover {
  border-color: var(--border-strong);
}
.cond-tab.active {
  background: var(--success, #16a34a);
  border-color: var(--success, #16a34a);
  color: #fff;
}
.cond-linha {
  margin: 0 0 0.4rem;
  font-size: 0.85rem;
  line-height: 1.45;
}
.cond-faturar {
  color: var(--text-secondary);
  font-style: italic;
}
.cond-cartao-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.6rem;
}
.cond-cartao-row label {
  font-weight: 600;
  font-size: 0.85rem;
  white-space: nowrap;
}
.cond-cartao-row select {
  flex: 1;
}
.cond-badge {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  border-radius: 8px;
  padding: 0.6rem 0.75rem;
  font-size: 0.85rem;
}
.cond-badge.badge-ok {
  background: var(--success-bg, #ecfdf5);
  border: 1px solid var(--success, #16a34a);
  color: var(--success-strong, #065f46);
}
.cond-badge.badge-alerta {
  background: #fef3c7;
  border: 1px solid #f59e0b;
  color: #92400e;
}
.cond-badge.badge-recusado {
  background: var(--danger-soft, #fee2e2);
  border: 1px solid var(--danger, #dc2626);
  color: var(--danger, #b91c1c);
}
.cond-taxa-custo {
  font-weight: 700;
  margin-top: 0.15rem;
}
.cond-toggle {
  display: flex;
  gap: 0.35rem;
  margin-bottom: 0.6rem;
}
.cond-toggle-btn {
  flex: 1;
  padding: 0.4rem;
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
.cond-toggle-btn:hover {
  border-color: var(--border-strong);
}
.cond-toggle-btn.active {
  background: var(--success, #16a34a);
  border-color: var(--success, #16a34a);
  color: #fff;
}
.cond-hint {
  margin: 0;
  font-size: 0.8rem;
  color: var(--text-secondary);
  font-style: italic;
}
.cond-pix {
  min-height: 2.5rem;
}

.switch-wrap {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
}

.switch-label {
  font-size: 0.9rem;
  color: var(--text-secondary);
}

.switch {
  position: relative;
  display: inline-block;
  width: 42px;
  height: 24px;
  flex-shrink: 0;
}

.switch input {
  opacity: 0;
  width: 0;
  height: 0;
}

.slider {
  position: absolute;
  cursor: pointer;
  inset: 0;
  background-color: var(--border-light);
  transition: 0.2s;
  border-radius: 24px;
}

.slider:before {
  position: absolute;
  content: '';
  height: 18px;
  width: 18px;
  left: 3px;
  top: 3px;
  background-color: #fff;
  transition: 0.2s;
  border-radius: 50%;
}

.switch input:checked + .slider {
  background-color: var(--primary, #16a34a);
}

.switch input:checked + .slider:before {
  transform: translateX(18px);
}

.preview-total {
  font-weight: 700;
  color: #16a34a;
}

.preview-pos {
  color: #16a34a;
  font-weight: 600;
}

.preview-neg {
  color: #dc2626;
  font-weight: 600;
}

.status-card {
  max-width: 600px;
  margin: 1.25rem auto;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.75rem;
}

.status-top {
  max-width: 600px;
  margin: 1.25rem auto 0.5rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.6rem 1rem;
  background: var(--border-subtle);
  border: 1px solid var(--border-light);
  border-radius: 8px;
}

.status-top-label {
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.status-section {
  max-width: 600px;
  margin: 0 auto 1.25rem;
  padding: 0.9rem 1rem;
  background: var(--card-bg);
  border: 1px solid var(--border-light);
  border-radius: 8px;
}

.status-section-title {
  margin: 0 0 0.6rem;
  font-size: 0.85rem;
  font-weight: 700;
  color: var(--text-primary);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.status-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 0.5rem;
}

.resumo-toolbar {
  margin-top: 0.5rem;
  padding-top: 0.75rem;
  border-top: 1px solid var(--border-light);
}

.kapazi-card {
  max-width: 600px;
  margin: 0 auto 1.25rem;
  padding: 0.9rem 1rem;
  background: var(--card-bg);
  border: 1px solid var(--border-light);
  border-radius: 8px;
}

.kapazi-title {
  margin: 0 0 0.6rem;
  font-size: 0.85rem;
  font-weight: 700;
  color: var(--text-primary);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.kapazi-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.6rem 0.75rem;
}

.kapazi-grid .field label {
  display: block;
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--text-secondary);
  margin-bottom: 0.2rem;
}

.kapazi-grid .field input {
  width: 100%;
  padding: 0.45rem 0.6rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  font-size: 0.85rem;
  color: var(--text-primary);
  background: var(--card-bg);
}

.kapazi-grid .field input:focus {
  outline: none;
  border-color: var(--primary, #3366cc);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
}

.kapazi-full {
  grid-column: 1 / -1;
}

.kapazi-actions {
  margin-top: 0.75rem;
  display: flex;
  justify-content: flex-end;
}

@media (max-width: 520px) {
  .kapazi-grid {
    grid-template-columns: 1fr;
  }
}

.status-modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1300;
  padding: 1rem;
}

.status-modal-card {
  background: var(--card-bg);
  border-radius: 10px;
  padding: 1.25rem 1.5rem;
  max-width: 420px;
  width: 100%;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.25);
  text-align: center;
}

.status-modal-card h3 {
  margin: 0 0 1rem;
  font-size: 1rem;
  color: var(--text-primary);
  line-height: 1.4;
}

.status-modal-actions {
  display: flex;
  justify-content: center;
  gap: 0.75rem;
}

.status-modal-label {
  display: block;
  text-align: left;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--text-secondary);
  margin-bottom: 1rem;
}

.status-modal-input {
  display: block;
  width: 100%;
  margin-top: 0.35rem;
  padding: 0.5rem 0.65rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  font-size: 0.9rem;
  color: var(--text-primary);
  background: var(--card-bg);
}

.status-modal-input:focus {
  outline: none;
  border-color: var(--primary, #3366cc);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
}

.status-historico {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding-left: 0.25rem;
}

.status-historico-item {
  display: flex;
  gap: 0.6rem;
  align-items: flex-start;
}

.status-historico-dot {
  flex: 0 0 auto;
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: var(--primary, #3366cc);
  margin-top: 0.45rem;
}

.status-historico-body {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
}

.status-historico-line {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.status-historico-de {
  font-size: 0.75rem;
  color: var(--text-secondary);
}

.status-historico-data {
  font-size: 0.75rem;
  color: var(--text-secondary);
}

.status-historico-motivo {
  font-size: 0.8rem;
  color: var(--text-secondary);
  background: var(--border-subtle);
  border-left: 3px solid var(--primary, #3366cc);
  padding: 0.3rem 0.6rem;
  border-radius: 4px;
}

.modal-fade-enter-active,
.modal-fade-leave-active {
  transition: opacity 0.2s ease;
}

.modal-fade-enter-from,
.modal-fade-leave-to {
  opacity: 0;
}

.badge-status {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.3rem 0.85rem;
  border-radius: 999px;
  font-size: 0.8rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}

.badge-rascunho {
  background: var(--border-subtle);
  color: var(--text-secondary);
}

.badge-enviado,
.badge-aguardando_retorno {
  background: var(--warning-soft);
  color: var(--warning);
}

.badge-aprovado {
  background: var(--success-soft);
  color: var(--success);
}

.badge-faturado {
  background: var(--primary-soft);
  color: var(--primary);
}

.badge-aguardando_faturamento {
  background: var(--primary-soft);
  color: var(--primary-light);
}

.badge-entregue {
  background: var(--success-soft);
  color: var(--success);
}

.badge-recusado {
  background: var(--danger-soft);
  color: var(--danger);
}

.badge-cancelado {
  background: var(--border-light);
  color: var(--text-secondary);
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

  .itens-header {
    display: none;
  }

  .itens-tabela {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .itens-row {
    flex-direction: column;
    align-items: stretch;
    gap: 0.25rem;
    padding: 0.75rem;
    border: 1px solid var(--border-light);
    border-radius: 8px;
  }

  .itens-item + .itens-item {
    border-top: 1px solid var(--border-light);
  }

  .itens-obs {
    padding-left: 0.75rem;
  }

  .itens-col-num {
    display: none;
  }

  .itens-col-desc {
    font-weight: 600;
    font-size: 0.9rem;
    margin-bottom: 0.25rem;
  }

  .itens-col-dim,
  .itens-col-qtd,
  .itens-col-vlr,
  .itens-col-total {
    width: auto;
    text-align: left;
    display: flex;
    align-items: center;
    gap: 0.35rem;
  }

  .itens-col-dim::before,
  .itens-col-qtd::before,
  .itens-col-vlr::before,
  .itens-col-total::before {
    content: attr(data-label);
    font-weight: 600;
    font-size: 0.65rem;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: var(--secondary);
    min-width: 4.5rem;
    flex-shrink: 0;
  }

  .itens-col-actions {
    width: auto;
    justify-content: flex-start;
    margin-top: 0.35rem;
    padding-top: 0.35rem;
    border-top: 1px solid var(--border-subtle);
  }

  .btn-row {
    flex-direction: column;
  }
}

.app-toast {
  position: fixed;
  bottom: 1.25rem;
  left: 50%;
  transform: translateX(-50%);
  max-width: min(90vw, 520px);
  padding: 0.75rem 1.1rem;
  background: #1f4e79;
  color: #fff;
  border-radius: 8px;
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.25);
  font-size: 0.9rem;
  text-align: center;
  z-index: 1200;
}

.toast-fade-enter-active,
.toast-fade-leave-active {
  transition:
    opacity 0.25s ease,
    transform 0.25s ease;
}

.toast-fade-enter-from,
.toast-fade-leave-to {
  opacity: 0;
  transform: translateX(-50%) translateY(10px);
}

.cond-boleto-parcelas {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  margin: 0.35rem 0 0.1rem;
  font-size: 0.82rem;
  color: var(--text-secondary);
}

.cond-boleto-parcelas select {
  padding: 0.35rem 0.5rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 0.85rem;
}
</style>
