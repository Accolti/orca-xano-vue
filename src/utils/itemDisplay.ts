// Exibição padronizada dos itens do orçamento — principalmente produtos vendidos
// por Metro Linear (ML) baseados em rolos (laminados/pisos PVC).
//
// O motor grava, por item ML:
//   larg / comp          → modo Medidas: largura × comprimento | modo Área: larg=0, comp=área
//   larg_fc / comp_fc    → largura do rolo / metros lineares faturados
//   und_produto          → "ML" (Base_de_Calculo)
//   detalhes_calculo.ml  → { rolosFechados, metrosFracionados, orientacaoIdeal, largura_fixa, tam_rolo, ... }
//
// Este módulo concentra a montagem do DTO de exibição usado pela tela, PDF e WhatsApp,
// evitando as duplicações de composição que existiam em pdf.ts e OrcamentosView.vue.

export interface ItemDisplay {
  isML: boolean
  titulo: string
  subtitulo: string
  dimensoes: string
  quantidade: string
  valorUnit: number
  valorTotal: number
}

// Número pt-BR com casas fixas (default 2). Ex.: 7.37 → "7,37".
export function numBR(valor: any, casas = 2): string {
  return (Number(valor) || 0).toLocaleString('pt-BR', {
    minimumFractionDigits: casas,
    maximumFractionDigits: casas,
  })
}

// Número pt-BR compacto (sem zeros à direita). Ex.: 6 → "6"; 12.5 → "12,5".
export function numCompacto(valor: any): string {
  return (Number(valor) || 0).toLocaleString('pt-BR', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  })
}

// Um item é ML quando a unidade de venda é ML ou quando há detalhes de cálculo ML gravados.
export function ehItemML(item: any): boolean {
  const und = String(item?.und_produto ?? '').toUpperCase()
  const base = String(item?.base_calculo ?? '').toUpperCase()
  return und === 'ML' || base === 'ML' || Boolean(item?.detalhes_calculo?.ml)
}

// Especificação do rolo padrão da variação: "(Rolo 1,30 x 15 m)".
// Fallback para larg_fc quando o item é antigo e não tem detalhes_calculo.ml.
function roloSpec(item: any, ml: any): string {
  const larg = Number(ml?.largura_fixa) || Number(item?.larg_fc) || 0
  const tam = Number(ml?.tam_rolo) || 0
  if (larg <= 0) return ''
  return tam > 0 ? `(Rolo ${numBR(larg)} x ${numCompacto(tam)} m)` : `(Rolo ${numBR(larg)} m)`
}

// Composição do produto composto PLAYKAP (a partir do detalhes_calculo gravado no item).
// Ex.: "578 placas + 102 rampas (51 M / 51 F) + 4 cantoneiras"
export function composicaoPlaykap(item: any): string {
  const p = item?.detalhes_calculo?.playkap
  if (!p) return ''
  const partes: string[] = []
  if (p.placas) partes.push(`${p.placas} placas`)
  if (p.rampas_total)
    partes.push(`${p.rampas_total} rampas (${p.rampas_macho} M / ${p.rampas_femea} F)`)
  if (p.cantoneiras) partes.push(`${p.cantoneiras} cantoneiras`)
  return partes.join(' + ')
}

// Subtexto ML no modo MEDIDAS (largura × comprimento informados).
// Ex.: "Consumo: 1 rolo fechado (1,30 x 15 m) + 3 m fracionados • Sentido: Passar a faixa ..."
function subtituloMLMedidas(item: any, ml: any): string {
  const rolos = Number(ml?.rolosFechados) || 0
  const frac = Number(ml?.metrosFracionados) || 0
  const larg = Number(ml?.largura_fixa) || Number(item?.larg_fc) || 0
  const tam = Number(ml?.tam_rolo) || 0

  const partes: string[] = []
  if (rolos > 0) {
    const spec = larg > 0 ? ` (${numBR(larg)} x ${numCompacto(tam)} m)` : ''
    partes.push(`${rolos} ${rolos === 1 ? 'rolo fechado' : 'rolos fechados'}${spec}`)
  }
  if (frac > 0) partes.push(`${numCompacto(frac)} m fracionados`)

  const consumo = partes.length ? `Consumo: ${partes.join(' + ')}` : ''
  const sentido = ml?.orientacaoIdeal ? `Sentido: ${ml.orientacaoIdeal}` : ''
  return [consumo, sentido].filter(Boolean).join(' • ')
}

// Subtexto ML no modo ÁREA (área total líquida informada — sem paginação).
// Ex.: "Fornecido: 6 ML (12 m²) — Atende à área solicitada de 10,00 m²"
function subtituloMLArea(item: any, ml: any): string {
  const compFc = Number(item?.comp_fc) || Number(item?.qtd) || 0
  const larg = Number(ml?.largura_fixa) || Number(item?.larg_fc) || 0
  const areaSolicitada = Number(item?.comp) || 0
  const areaFaturada = compFc * larg

  const fornecido =
    areaFaturada > 0
      ? `Fornecido: ${numCompacto(compFc)} ML (${numCompacto(areaFaturada)} m²)`
      : `Fornecido: ${numCompacto(compFc)} ML`
  const atende = areaSolicitada > 0 ? `Atende à área solicitada de ${numBR(areaSolicitada)} m²` : ''
  return [fornecido, atende].filter(Boolean).join(' — ')
}

// Monta o DTO de exibição do item (tela, PDF e WhatsApp).
export function montarItemDisplay(item: any): ItemDisplay {
  const isML = ehItemML(item)
  const ml = item?.detalhes_calculo?.ml
  const descricao = (item?.Descricao || item?.descricao || '').trim()
  const und = String(item?.und_produto ?? '').toUpperCase()

  const larg = Number(item?.larg) || 0
  const comp = Number(item?.comp) || 0

  // Dimensões: ML em modo Área mostra a área (m²); os demais mostram largura × comprimento.
  let dimensoes: string
  if (isML && larg <= 0) {
    dimensoes = `${numBR(comp)} m²`
  } else if (larg <= 0 && comp <= 0) {
    dimensoes = 'Tamanho Padrão'
  } else {
    dimensoes = `${numBR(larg)} x ${numBR(comp)} m`
  }

  // Quantidade com unidade: ML usa metros lineares faturados (comp_fc); demais usam UND/KIT.
  const qtd = Number(item?.qtd) || 1
  const qtdBase = isML ? Number(item?.comp_fc) || qtd : qtd
  const quantidade = isML
    ? `${numCompacto(qtdBase)} ML`
    : `${numCompacto(qtd)} ${und === 'KIT' ? 'KIT' : 'UND'}`

  let titulo = descricao
  let subtitulo = ''
  if (isML) {
    const spec = roloSpec(item, ml)
    titulo = spec ? `${descricao} ${spec}`.trim() : descricao
    subtitulo = larg > 0 ? subtituloMLMedidas(item, ml) : subtituloMLArea(item, ml)
  } else {
    subtitulo = composicaoPlaykap(item)
  }

  const valorUnit = Number(item?.vlr_vnd_unit_b2b ?? item?.vlr_vnd_unit) || 0
  const valorTotal = valorUnit * qtdBase

  return { isML, titulo, subtitulo, dimensoes, quantidade, valorUnit, valorTotal }
}
