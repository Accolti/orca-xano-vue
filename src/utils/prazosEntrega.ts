import type { ProdutoCatalogo } from '@/types/orcamento'

interface FaixaPrazo {
  label: string
  ordem: number
}

// Prazos de entrega por UF → classificação do produto.
// A estrutura é keyed por UF para suportar multi-região (SaaS): basta adicionar
// novas chaves (ex.: RJ, MG, PR) com as mesmas classificações.
const PRAZOS: Record<string, Record<string, FaixaPrazo>> = {
  SP: {
    Personalizado: { label: '12 a 15 dias úteis', ordem: 2 },
    'Personalizado Simples': { label: '7 a 12 dias úteis', ordem: 1 },
    Acabado: { label: '7 a 12 dias úteis', ordem: 1 },
    'Acabado Personalizado': { label: '7 a 12 dias úteis', ordem: 1 },
  },
}

const UF_PADRAO = 'SP'

// Fallback quando a UF/classificação não está cadastrada: aplica o MAIOR prazo.
const PRAZO_MAIOR = '12 a 15 dias úteis'

// Calcula a previsão de entrega de um orçamento/pedido a partir das
// classificações dos produtos (item.produto_id → produto.classificacao).
// Regra do MAIOR prazo: se houver itens com prazos diferentes, prevalece o maior.
export function prazoEntregaDosItens(
  itens: Array<{ produto_id?: number | null }>,
  produtos: ProdutoCatalogo[],
  uf?: string | null,
): string {
  const ufKey = (uf || '').trim().toUpperCase() || UF_PADRAO
  const mapa = PRAZOS[ufKey] ?? PRAZOS[UF_PADRAO] ?? {}

  const mapaProduto = new Map<number, ProdutoCatalogo>()
  ;(produtos || []).forEach((p) => mapaProduto.set(Number(p.produto_id), p))

  let maior: FaixaPrazo | null = null
  for (const item of itens || []) {
    const produto = mapaProduto.get(Number(item?.produto_id))
    const classificacao = (produto?.classificacao || '').trim()
    const faixa = mapa[classificacao]
    if (faixa && (!maior || faixa.ordem > maior.ordem)) maior = faixa
  }

  return maior?.label ?? PRAZO_MAIOR
}
