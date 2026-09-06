// Utilitários do controle financeiro (parcelas de boletos/Pix/cartão por orçamento).
// Gera as parcelas a partir das condições negociadas no orçamento.

export const FORMAS_PAGAMENTO = [
  { id: 1, tipo: 'Boleto' },
  { id: 2, tipo: 'Pix' },
  { id: 3, tipo: 'Espécie' },
  { id: 4, tipo: 'Cartão' },
] as const

export function nomeForma(id: number | null | undefined): string {
  if (!id) return '—'
  return FORMAS_PAGAMENTO.find((f) => f.id === id)?.tipo ?? `Forma ${id}`
}

export interface ParcelaFinanceira {
  valor: number
  vencimento: string // yyyy-mm-dd
  forma_pagamento_id: number
}

export interface CartaoOpcaoParcela {
  parcelas: number
  valorParcela: number
  total: number
}

export interface GerarParcelasInput {
  venda: number
  custo: number
  metodos: { pix: boolean; boleto: boolean; cartao: boolean }
  descontoPixPercentual: number
  parcelasCartao: number | null
  cartaoParcelas: CartaoOpcaoParcela[]
  dataBase?: string // yyyy-mm-dd (default hoje)
  // Nº de parcelas do boleto (default = máximo calculado; só reduzir)
  parcelasBoleto?: number | null
  // Nº de parcelas do Pix (1x ou 2x; default 2x)
  parcelasPix?: number | null
}

function somaDias(base: Date, dias: number): string {
  const d = new Date(base)
  d.setDate(d.getDate() + dias)
  const mes = String(d.getMonth() + 1).padStart(2, '0')
  const dia = String(d.getDate()).padStart(2, '0')
  return `${d.getFullYear()}-${mes}-${dia}`
}

// Vencimentos: 1ª parcela +5 dias, demais +30 (a partir da base).
function vencimentos(base: Date, quantidade: number): string[] {
  const lista: string[] = []
  for (let i = 0; i < quantidade; i++) {
    lista.push(somaDias(base, 5 + i * 30))
  }
  return lista
}

// Gera a lista de parcelas a partir das condições negociadas:
// - Pix: 2x fixas (com desconto Pix aplicado) → forma 2
// - Boleto: Nx = floor(venda / (custo/2)) → forma 1
// - Cartão: Nx = parcela selecionada, valor com gross-up já calculado → forma 4
export function gerarParcelasFinanceiras({
  venda,
  custo,
  metodos,
  descontoPixPercentual = 0,
  parcelasCartao,
  cartaoParcelas,
  dataBase,
  parcelasBoleto,
  parcelasPix,
}: GerarParcelasInput): ParcelaFinanceira[] {
  const base = dataBase ? new Date(`${dataBase}T00:00:00`) : new Date()
  const parcelas: ParcelaFinanceira[] = []
  const valorVenda = Number(venda) || 0
  const valorCusto = Number(custo) || 0

  if (metodos.pix && valorVenda > 0) {
    const desconto = descontoPixPercentual > 0 ? valorVenda * (descontoPixPercentual / 100) : 0
    const valorPix = valorVenda - desconto
    const nPixUser = Number(parcelasPix)
    const pixParcelas = Number.isInteger(nPixUser) && nPixUser >= 1 && nPixUser <= 2 ? nPixUser : 2
    const valorPixParcela = valorPix / pixParcelas
    vencimentos(base, pixParcelas).forEach((vencimento) => {
      parcelas.push({
        valor: parseFloat(valorPixParcela.toFixed(2)),
        vencimento,
        forma_pagamento_id: 2,
      })
    })
  }

  if (metodos.boleto && valorVenda > 0) {
    const metadeCusto = valorCusto / 2
    const parcelasMax = valorCusto > 0 ? Math.max(1, Math.floor(valorVenda / metadeCusto)) : 1
    const nUsuario = Number(parcelasBoleto)
    const numeroParcelas =
      Number.isInteger(nUsuario) && nUsuario >= 1 && nUsuario <= parcelasMax
        ? nUsuario
        : parcelasMax
    const valorBoleto = valorVenda / numeroParcelas
    vencimentos(base, numeroParcelas).forEach((vencimento) => {
      parcelas.push({
        valor: parseFloat(valorBoleto.toFixed(2)),
        vencimento,
        forma_pagamento_id: 1,
      })
    })
  }

  if (metodos.cartao && parcelasCartao && valorVenda > 0) {
    const opcao = cartaoParcelas.find((o) => o.parcelas === parcelasCartao)
    if (opcao) {
      vencimentos(base, opcao.parcelas).forEach((vencimento) => {
        parcelas.push({
          valor: parseFloat(opcao.valorParcela.toFixed(2)),
          vencimento,
          forma_pagamento_id: 4,
        })
      })
    }
  }

  return parcelas.sort((a, b) => a.vencimento.localeCompare(b.vencimento))
}

// Soma das parcelas (para exibir o total planejado)
export function somarParcelas(parcelas: ParcelaFinanceira[]): number {
  return parseFloat(parcelas.reduce((soma, p) => soma + (Number(p.valor) || 0), 0).toFixed(2))
}
