import type { Material, ProdutoCatalogo } from '@/types/orcamento'

// Formata a duração da garantia em meses:
// - < 12 meses → "3 meses contra defeito de fábrica"
// - >= 12 meses inteiro → "1 ano de garantia contra defeito de fábrica"
// - não inteiro (ex.: 18) → "1 ano e 6 meses contra defeito de fábrica"
export function formatarDuracaoGarantia(meses: number): string {
  const m = Number(meses) || 0
  if (m <= 0) return ''
  const pluralMeses = (n: number) => `${n} ${n === 1 ? 'mês' : 'meses'}`
  const pluralAnos = (n: number) => `${n} ${n === 1 ? 'ano' : 'anos'} de garantia`
  if (m < 12) return `${pluralMeses(m)} contra defeito de fábrica`
  const anos = Math.floor(m / 12)
  const resto = m % 12
  if (resto === 0) return `${pluralAnos(anos)} contra defeito de fábrica`
  return `${pluralAnos(anos)} e ${pluralMeses(resto)} contra defeito de fábrica`
}

export interface GarantiaItem {
  materialId: number
  nome: string
  meses: number
}

// Resolve o material de cada item (item.produto_id → produto do catálogo → material_id)
// e agrupa por material (dedupe: 1 linha por material, mesmo com vários itens).
export function montarGarantiaItens(
  itens: any[],
  produtos: ProdutoCatalogo[],
  materiais: Material[],
): GarantiaItem[] {
  const mapaProduto = new Map<number, ProdutoCatalogo>()
  produtos.forEach((p) => mapaProduto.set(p.produto_id, p))
  const mapaMaterial = new Map<number, Material>()
  materiais.forEach((m) => mapaMaterial.set(m.id, m))

  const porMaterial = new Map<number, GarantiaItem>()
  ;(itens || []).forEach((item) => {
    const produto = mapaProduto.get(Number(item?.produto_id))
    const materialId = produto?.material_id ?? item?.material_id ?? null
    if (materialId == null) return
    const material = mapaMaterial.get(Number(materialId))
    if (!material) return
    const meses = Number(material.garantia) || 0
    if (meses <= 0) return
    if (!porMaterial.has(material.id)) {
      porMaterial.set(material.id, { materialId: material.id, nome: material.nome, meses })
    }
  })
  return Array.from(porMaterial.values())
}

// Monta as linhas de garantia agrupadas e deduplicadas.
// Materiais com a MESMA duração viram uma única linha com os nomes agrupados:
// "Vinil e EVA 1 ano de garantia contra defeito de fábrica"
export function montarLinhasGarantia(
  itens: any[],
  produtos: ProdutoCatalogo[],
  materiais: Material[],
): string[] {
  const agrupados = montarGarantiaItens(itens, produtos, materiais)
  const porDuracao = new Map<number, GarantiaItem[]>()
  agrupados.forEach((g) => {
    if (!porDuracao.has(g.meses)) porDuracao.set(g.meses, [])
    porDuracao.get(g.meses)!.push(g)
  })

  const linhas: string[] = []
  porDuracao.forEach((grupo) => {
    const duracao = formatarDuracaoGarantia(grupo[0]!.meses)
    if (!duracao) return
    const nomes = juntarNomes(grupo.map((g) => g.nome))
    linhas.push(`${nomes} ${duracao}`)
  })
  return linhas
}

// Junta nomes: 1 → "Vinil"; 2 → "Vinil e EVA"; 3+ → "A, B e C"
function juntarNomes(nomes: string[]): string {
  if (nomes.length <= 1) return nomes[0] || ''
  return `${nomes.slice(0, -1).join(', ')} e ${nomes[nomes.length - 1]}`
}
