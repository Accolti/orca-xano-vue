import type { SimulacaoItem } from '@/types/orcamento'

// Faixa padrão de simulação de margens (markup) quando o vendedor não configura nada.
export const SIMULACAO_PADRAO = { inicio: 50, fim: 100, passo: 10 }

// Guardrails: passo mínimo e amplitude máxima para não gerar listas gigantes.
const PASSO_MINIMO = 5
const AMPLITUDE_MAXIMA = 200

function round2(n: number): number {
  return Math.round(n * 100) / 100
}

// Monta a lista de margens respeitando os guardrails:
// - passo mínimo 5, amplitude máxima 200 (clamp);
// - se inicio > fim, inverte;
// - se (fim − inicio) não for múltiplo do passo, trunca o último.
export function montarMargens(inicio: number, fim: number, passo: number): number[] {
  let lo = Number.isFinite(inicio) ? inicio : SIMULACAO_PADRAO.inicio
  let hi = Number.isFinite(fim) ? fim : SIMULACAO_PADRAO.fim
  let step = Number.isFinite(passo) && passo > 0 ? passo : SIMULACAO_PADRAO.passo

  if (lo > hi) {
    ;[lo, hi] = [hi, lo]
  }

  // Passo mínimo
  if (step < PASSO_MINIMO) step = PASSO_MINIMO

  // Amplitude máxima (clamp no teto; mantém o início)
  if (hi - lo > AMPLITUDE_MAXIMA) hi = lo + AMPLITUDE_MAXIMA

  const margens: number[] = []
  for (let m = lo; m <= hi; m += step) {
    margens.push(round2(m))
  }
  return margens
}

// Rótulo disfarçado da margem: margem ÷ 10 → c5 = 50%, c10 = 100%.
export function rotuloMargem(margem: number): string {
  const divisivel = margem % 10 === 0 ? margem / 10 : round2(margem / 10)
  return `c${divisivel}`
}

// Gera a simulação de margens no front (sem depender do backend):
// venda = custo × (1 + m/100), lucro = venda − custo.
// Retorna lista compatível com SimulacaoItem (usada pela SimulacaoModal).
export function gerarSimulacaoFront(custoTotal: number, qtd = 1): SimulacaoItem[] {
  const cst = Number(custoTotal) || 0
  const quantidade = qtd > 0 ? qtd : 1
  const margens = montarMargens(
    SIMULACAO_PADRAO.inicio,
    SIMULACAO_PADRAO.fim,
    SIMULACAO_PADRAO.passo,
  )

  return margens.map((m) => {
    const vendaTotal = cst * (1 + m / 100)
    const lucroTotal = vendaTotal - cst
    return {
      Valor_Custo_Unit: round2(cst / quantidade),
      Valor_Venda_Unit: round2(vendaTotal / quantidade),
      Valor_Lucro_Unit: round2(lucroTotal / quantidade),
      Valor_Venda_Unit_B2B: round2(vendaTotal / quantidade),
      AreaFC: 0,
      Qtd_Unidades: quantidade,
      Valor_Custo_Total: round2(cst),
      Valor_Venda_Total: round2(vendaTotal),
      Valor_Lucro_Total: round2(lucroTotal),
      Valor_Venda_Total_FRT_B2B: round2(vendaTotal),
      Valor_Custo_IPI: 0,
      Valor_Custo_IMP: 0,
      valor_venda_ipi_tot: 0,
      valor_venda_imp_tot: 0,
      Valor_Venda_Total_B2B: round2(vendaTotal),
      margem: m,
    }
  })
}
