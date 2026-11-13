import { supabase } from './supabase'

// Camada de dados de Nota Fiscal (XML NF-e) — Supabase RPCs.

function extrairMensagem(err: unknown): string {
  const anyErr = err as any
  return anyErr?.message || anyErr?.error_description || 'Erro'
}

async function rpc<T>(name: string, args?: Record<string, unknown>): Promise<T> {
  if (!supabase) throw new Error('Supabase não configurado')
  const { data, error } = await supabase.rpc(name, args)
  if (error) throw new Error(extrairMensagem(error))
  return (typeof data === 'string' ? JSON.parse(data) : data) as T
}

export async function listarNotasFiscais(userId?: number | null): Promise<any[]> {
  const r = await rpc<any>('nota_fiscal_listar', { p_user_id: userId ?? 0 })
  return Array.isArray(r) ? r : []
}

export async function salvarNotaFiscal(
  payload: Record<string, unknown>,
  userId?: number | null,
): Promise<any> {
  return rpc<any>('nota_fiscal_salvar', { p_user_id: userId ?? 0, p_payload: payload })
}

export async function excluirNotaFiscal(id: number, userId?: number | null): Promise<void> {
  await rpc<any>('nota_fiscal_excluir', { p_user_id: userId ?? 0, p_id: id })
}

export async function listarNotasFiscaisPorOrca(
  orcaId: number,
  userId?: number | null,
): Promise<any[]> {
  const r = await rpc<any>('nota_fiscal_por_orca', { p_user_id: userId ?? 0, p_orca_id: orcaId })
  return Array.isArray(r) ? r : []
}

// Sugere pedidos cujo "Custo Kapazi" esteja próximo do valor da NF (sem frete).
export async function sugerirPedidosNf(
  valor: number,
  toleranciaPct: number,
  userId?: number | null,
): Promise<any[]> {
  const r = await rpc<any>('pedidos_sugeridos_nf', {
    p_user_id: userId ?? 0,
    p_valor: valor,
    p_tolerancia_pct: toleranciaPct,
  })
  return Array.isArray(r) ? r : []
}
