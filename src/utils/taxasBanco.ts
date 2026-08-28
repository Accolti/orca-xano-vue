import type { TaxaBanco } from '@/types/orcamento'

export interface ParcelaCalculada {
  parcelas: number
  taxaPercentual: string
  clientePagaTotal: number
  valorParcela: number
  voceRecebeLiquido: number
  custoTaxa: number
  provedor?: string | null
  provedor_id?: number
}

// Port do lambda `calcularTabelaParcelamento` da função Xano f_taxas_banco.
// GROSS-UP: quando repassarTaxas=true, o cliente assume a taxa (valor total =
// valorBase / (1 - taxa)); quando false, a loja assume (recebe valorBase * (1 - taxa)).
export function calcularTabelaParcelamento(
  tabelaTaxas: TaxaBanco[],
  valorBase: number,
  repassarTaxas = true,
  provedorFiltro?: string | number | null,
): ParcelaCalculada[] {
  const base = Number(valorBase) || 0

  return tabelaTaxas
    .filter((item) => {
      if (provedorFiltro == null || provedorFiltro === '') return true
      return item.provedor_id === Number(provedorFiltro) || item.provedor === String(provedorFiltro)
    })
    .map((item) => {
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
        provedor: item.provedor || null,
        provedor_id: item.provedor_id,
      }
    })
}

// Instituições distintas da tabela de taxas (com id + nome).
export function provedoresDisponiveis(tabelaTaxas: TaxaBanco[]): {
  id: number
  nome: string
}[] {
  const map = new Map<number, { id: number; nome: string }>()
  tabelaTaxas.forEach((t) => {
    if (t.provedor_id == null) return
    if (!map.has(t.provedor_id)) {
      map.set(t.provedor_id, {
        id: t.provedor_id,
        nome: t.provedor || `Instituição ${t.provedor_id}`,
      })
    }
  })
  return Array.from(map.values())
}

// Marca as opções mais vantajosas por nº de parcelas (menor custo total p/ o cliente).
// Retorna um Set de chaves "provedorId|parcelas" que representam a melhor opção.
export function opcoesMaisVantajosas(
  tabelaTaxas: TaxaBanco[],
  valorBase: number,
  repassarTaxas = true,
): Set<string> {
  const agrupado = new Map<number, ParcelaCalculada[]>()
  calcularTabelaParcelamento(tabelaTaxas, valorBase, repassarTaxas).forEach((p) => {
    const parcelas = p.parcelas
    if (!agrupado.has(parcelas)) agrupado.set(parcelas, [])
    agrupado.get(parcelas)!.push(p)
  })

  const melhores = new Set<string>()
  agrupado.forEach((opcoes, parcelas) => {
    let melhor = opcoes[0]!
    opcoes.forEach((o) => {
      if (o.clientePagaTotal < melhor.clientePagaTotal) melhor = o
    })
    melhores.add(`${melhor.provedor_id ?? '?'}|${parcelas}`)
  })
  return melhores
}
