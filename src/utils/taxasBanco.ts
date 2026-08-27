import type { TaxaBanco } from '@/types/orcamento'

export interface ParcelaCalculada {
  parcelas: number
  taxaPercentual: string
  clientePagaTotal: number
  valorParcela: number
  voceRecebeLiquido: number
  custoTaxa: number
}

// Port do lambda `calcularTabelaParcelamento` da função Xano f_taxas_banco.
// GROSS-UP: quando repassarTaxas=true, o cliente assume a taxa (valor total =
// valorBase / (1 - taxa)); quando false, a loja assume (recebe valorBase * (1 - taxa)).
export function calcularTabelaParcelamento(
  tabelaTaxas: TaxaBanco[],
  valorBase: number,
  repassarTaxas = true,
): ParcelaCalculada[] {
  const base = Number(valorBase) || 0

  return tabelaTaxas.map((item) => {
    const parcelas = item.parcelas
    const taxaDecimal = Number(item.cc_taxa) / 100

    let valorTotalCliente = 0
    let valorLiquidoVoceRecebe = 0

    if (repassarTaxas) {
      // GROSS-UP: Cliente assume a taxa
      valorTotalCliente = base / (1 - taxaDecimal)
      valorLiquidoVoceRecebe = base
    } else {
      // DIRETO: Você assume a taxa
      valorTotalCliente = base
      valorLiquidoVoceRecebe = base * (1 - taxaDecimal)
    }

    const valorParcela = valorTotalCliente / parcelas
    const custoTaxa = valorTotalCliente - valorLiquidoVoceRecebe

    return {
      parcelas,
      taxaPercentual: `${item.cc_taxa}%`,
      clientePagaTotal: parseFloat(valorTotalCliente.toFixed(2)),
      valorParcela: parseFloat(valorParcela.toFixed(2)),
      voceRecebeLiquido: parseFloat(valorLiquidoVoceRecebe.toFixed(2)),
      custoTaxa: parseFloat(custoTaxa.toFixed(2)),
    }
  })
}
