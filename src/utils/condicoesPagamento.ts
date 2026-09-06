import type { TaxaBanco } from '@/types/orcamento'
import { calcularTabelaParcelamento, opcoesMaisVantajosas } from '@/utils/taxasBanco'

export const TEXTO_FATURAR = 'Faturamos com até 20 dias da entrega do produto'

function formatarMoeda(valor: number): string {
  return `R$ ${(Number(valor) || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

export interface OpcaoCartao {
  parcelas: number
  taxa: number
  total: number
  parcela: number
  voceRecebeLiquido: number
  custoTaxa: number
  provedor?: string | null
  provedor_id?: number
  maisVantajosa?: boolean
}

export interface PixImpacto {
  desconto: number
  valorComDesconto: number
  lucro: number
  margem: number
}

export interface OpcoesPagamento {
  pix: string
  boleto: string
  cartao: OpcaoCartao[]
  texto: string
  pixImpacto: PixImpacto
  boletoMax: number
  boletoParcelas: number
  pixMax: number
  pixParcelas: number
}

export interface MetodosSelecionados {
  pix: boolean
  boleto: boolean
  cartao: boolean
}

export interface CalcularCondicoesInput {
  valorVenda: number
  valorCusto: number
  faturar?: boolean
  tabelaTaxasCartao?: TaxaBanco[]
  repassarTaxasCartao?: boolean
  descontoPixPercentual?: number
  provedorSelecionado?: string | number | null
  metodos?: MetodosSelecionados
  // Mesclar métodos na saída; quando true + cartão com uma parcela escolhida,
  // entra só a parcela selecionada (a menos de trazerTodasParcelas).
  mesclar?: boolean
  parcelaCartao?: number | null
  trazerTodasParcelas?: boolean
  // Nº de parcelas do boleto escolhido pelo vendedor (só para menos; default = máximo)
  parcelasBoleto?: number | null
  // Nº de parcelas do Pix escolhido (1x ou 2x; default 2x — mais que 2 vira Boleto)
  parcelasPix?: number | null
}

// Regras atuais: Pix 2x fixas + Boleto parcelado pela métrica metadeCusto.
// Cartão com Gross-Up (repassarTaxasCartao) ou assumindo a taxa (direto).
// O desconto Pix reduz a venda e o lucro — o impacto (lucro/margem) é retornado.
export function calcularCondicoesPagamento({
  valorVenda,
  valorCusto,
  faturar = false,
  tabelaTaxasCartao = [],
  repassarTaxasCartao = true,
  descontoPixPercentual = 0,
  provedorSelecionado = null,
  metodos,
  mesclar = false,
  parcelaCartao = null,
  trazerTodasParcelas = false,
  parcelasBoleto = null,
  parcelasPix = null,
}: CalcularCondicoesInput): OpcoesPagamento {
  const venda = Number(valorVenda) || 0
  const custo = Number(valorCusto) || 0
  const entradaPrazo = 5
  const intervaloParcelas = 30

  const usaPix = metodos?.pix !== false
  const usaBoleto = metodos?.boleto !== false
  const usaCartao = metodos?.cartao !== false

  // ---- PIX (1x ou 2x — ajustável pelo vendedor; mais que 2 vira Boleto) ----
  const descontoPix = descontoPixPercentual > 0 ? venda * (descontoPixPercentual / 100) : 0
  const valorVendaPix = venda - descontoPix

  const pixMax = 2
  const nPixUser = Number(parcelasPix)
  const pixParcelas =
    Number.isInteger(nPixUser) && nPixUser >= 1 && nPixUser <= pixMax ? nPixUser : pixMax
  const valorParcelaPix = valorVendaPix / pixParcelas
  const descontoPixTexto =
    descontoPixPercentual > 0 ? ` — ${descontoPixPercentual}% de desconto` : ''
  const prazoPix =
    pixParcelas === 1
      ? `paga em até ${entradaPrazo} dias do pedido`
      : `1ª parcela em ${entradaPrazo} dias do pedido; 2ª parcela em ${entradaPrazo + intervaloParcelas} dias`
  const pixString = `Pix (${pixParcelas}x de ${formatarMoeda(valorParcelaPix)})${descontoPixTexto}: ${prazoPix} : total de R$ ${formatarMoeda(valorVendaPix)}.`

  // Impacto do desconto no Pix (lucro e margem sobre a venda SEM desconto, para comparação)
  const pixImpacto: PixImpacto = {
    desconto: parseFloat(descontoPix.toFixed(2)),
    valorComDesconto: parseFloat(valorVendaPix.toFixed(2)),
    lucro: parseFloat((valorVendaPix - custo).toFixed(2)),
    margem: venda > 0 ? parseFloat((((valorVendaPix - custo) / venda) * 100).toFixed(2)) : 0,
  }

  // ---- BOLETO (parcelas ajustáveis pelo vendedor, só para menos) ----
  const metadeCusto = custo / 2
  const parcelasMaxBoleto = custo > 0 ? Math.max(1, Math.floor(venda / metadeCusto)) : 1
  const nUsuario = Number(parcelasBoleto)
  const numeroParcelasBoleto =
    Number.isInteger(nUsuario) && nUsuario >= 1 && nUsuario <= parcelasMaxBoleto
      ? nUsuario
      : parcelasMaxBoleto
  const valorParcelasBoleto = venda / numeroParcelasBoleto

  const juntarPrazos = (lista: number[]): string => {
    if (!lista.length) return ''
    if (lista.length === 1) return String(lista[0])
    return `${lista.slice(0, -1).join(', ')} e ${lista[lista.length - 1]}`
  }
  const prazosRestantesNum: number[] = []
  for (let i = 1; i < numeroParcelasBoleto; i++) {
    prazosRestantesNum.push(entradaPrazo + i * intervaloParcelas)
  }
  let prazoBoleto = `${entradaPrazo} dias do pedido`
  if (numeroParcelasBoleto > 1) {
    prazoBoleto += `, demais em ${juntarPrazos(prazosRestantesNum)} dias`
  }
  const boletoString = `Boleto (${numeroParcelasBoleto}x de ${formatarMoeda(valorParcelasBoleto)}): ${prazoBoleto} : total de R$ ${formatarMoeda(venda)}.`

  // ---- CARTÃO (com instituição e marcação de mais vantajosa) ----
  const parcelasCalculadas = calcularTabelaParcelamento(
    tabelaTaxasCartao,
    venda,
    repassarTaxasCartao,
    provedorSelecionado,
  )
  const melhores = opcoesMaisVantajosas(tabelaTaxasCartao, venda, repassarTaxasCartao)
  const cartao: OpcaoCartao[] = parcelasCalculadas.map((p) => {
    const chave = `${p.provedor_id ?? '?'}|${p.parcelas}`
    return {
      parcelas: p.parcelas,
      taxa: Number(p.taxaPercentual.replace('%', '')) || 0,
      total: p.clientePagaTotal,
      parcela: p.valorParcela,
      voceRecebeLiquido: p.voceRecebeLiquido,
      custoTaxa: p.custoTaxa,
      provedor: p.provedor,
      provedor_id: p.provedor_id,
      maisVantajosa: melhores.has(chave),
    }
  })

  // Linhas finais conforme métodos selecionados + mesclagem
  const linhas: string[] = []

  // Cartão: mesclado → só a parcela escolhida (ou todas se trazerTodasParcelas);
  // não mesclado e aba cartão → todas as parcelas.
  let cartaoLinhas: string[] = []
  if (cartao.length) {
    const cartaoFiltrado =
      trazerTodasParcelas || !parcelaCartao
        ? cartao
        : cartao.filter((o) => o.parcelas === parcelaCartao)
    cartaoFiltrado.forEach((o) => {
      cartaoLinhas.push(
        `Cartão de Crédito (${o.parcelas}x de ${formatarMoeda(o.parcela)}): total de ${formatarMoeda(o.total)}.`,
      )
    })
    if (!cartaoLinhas.length && parcelaCartao) {
      const op = cartao.find((o) => o.parcelas === parcelaCartao)
      if (op) {
        cartaoLinhas.push(
          `Cartão de Crédito (${op.parcelas}x de ${formatarMoeda(op.parcela)}): total de ${formatarMoeda(op.total)}.`,
        )
      }
    }
  }

  if (mesclar) {
    if (usaPix) linhas.push(pixString)
    if (usaBoleto) linhas.push(boletoString)
    if (usaCartao) linhas.push(...cartaoLinhas)
  } else {
    // Modo seletor (não mesclado): apenas os métodos marcados, cartão com todas as parcelas
    if (usaPix) linhas.push(pixString)
    if (usaBoleto) linhas.push(boletoString)
    if (usaCartao && cartaoLinhas.length) linhas.push(...cartaoLinhas)
  }

  if (faturar) {
    linhas.push(TEXTO_FATURAR)
  }

  const texto = linhas.length ? linhas.join('\n') : ''

  return {
    pix: pixString,
    boleto: boletoString,
    cartao,
    texto,
    pixImpacto,
    boletoMax: parcelasMaxBoleto,
    boletoParcelas: numeroParcelasBoleto,
    pixMax,
    pixParcelas,
  }
}
