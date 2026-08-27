import type { TaxaBanco } from '@/types/orcamento'
import { calcularTabelaParcelamento } from '@/utils/taxasBanco'

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
}

export interface OpcoesPagamento {
  pix: string
  boleto: string
  cartao: OpcaoCartao[]
  texto: string
}

export interface CalcularCondicoesInput {
  valorVenda: number
  valorCusto: number
  faturar?: boolean
  tabelaTaxasCartao?: TaxaBanco[]
  repassarTaxasCartao?: boolean
  descontoPixPercentual?: number
}

// Regras atuais: Pix 2x fixas + Boleto parcelado pela métrica metadeCusto.
// Cartão com Gross-Up (repassarTaxasCartao) ou assumindo a taxa (direto).
export function calcularCondicoesPagamento({
  valorVenda,
  valorCusto,
  faturar = false,
  tabelaTaxasCartao = [],
  repassarTaxasCartao = true,
  descontoPixPercentual = 0,
}: CalcularCondicoesInput): OpcoesPagamento {
  const venda = Number(valorVenda) || 0
  const custo = Number(valorCusto) || 0
  const entradaPrazo = 5
  const intervaloParcelas = 30

  const descontoPix = descontoPixPercentual > 0 ? venda * (descontoPixPercentual / 100) : 0
  const valorVendaPix = venda - descontoPix

  const primeiraParcelaPix = valorVendaPix / 2
  const segundaParcelaPix = valorVendaPix / 2
  const pixString = `Pix (2x de ${formatarMoeda(primeiraParcelaPix)}): 1ª parcela em ${entradaPrazo} dias do pedido; 2ª parcela em ${entradaPrazo + intervaloParcelas} dias.`

  const metadeCusto = custo / 2
  const numeroParcelasBoleto = Math.max(1, Math.floor(venda / metadeCusto))
  const valorParcelasBoleto = venda / numeroParcelasBoleto

  let prazos = `${entradaPrazo} dias do pedido`
  const prazosRestantes: string[] = []
  for (let i = 1; i < numeroParcelasBoleto; i++) {
    prazosRestantes.push(String(entradaPrazo + i * intervaloParcelas))
  }
  if (numeroParcelasBoleto > 1) {
    prazos += `; demais em ${prazosRestantes.join(' e ')} dias`
  }
  const boletoString = `Boleto (${numeroParcelasBoleto}x de ${formatarMoeda(valorParcelasBoleto)}): 1ª parcela em ${prazos}.`

  const parcelasCalculadas = calcularTabelaParcelamento(
    tabelaTaxasCartao,
    venda,
    repassarTaxasCartao,
  )
  const cartao: OpcaoCartao[] = parcelasCalculadas.map((p) => ({
    parcelas: p.parcelas,
    taxa: Number(p.taxaPercentual.replace('%', '')) || 0,
    total: p.clientePagaTotal,
    parcela: p.valorParcela,
    voceRecebeLiquido: p.voceRecebeLiquido,
    custoTaxa: p.custoTaxa,
  }))
  const cartaoString = cartao
    .map((o) => `${o.parcelas}x de ${formatarMoeda(o.parcela)} (${formatarMoeda(o.total)})`)
    .join('; ')

  const linhas = [pixString, boletoString]
  if (cartao.length) {
    linhas.push(`Cartão de Crédito: ${cartaoString}.`)
  }
  if (faturar) {
    linhas.push(TEXTO_FATURAR)
  }

  return {
    pix: pixString,
    boleto: boletoString,
    cartao,
    texto: linhas.join('\n'),
  }
}
