import { supabase } from './supabase'

// Camada de dados de Promoções temporárias (admin_geral).

export interface PromocaoItem {
  id?: number
  produto_id: number | null
  variacao_id: number | null
  borda_id: number | null
  tipo: 'VALOR_FIXO' | 'PERCENTUAL'
  valor: number
}

export interface Promocao {
  id: number
  nome: string
  data_inicio: string
  data_fim: string
  ativo: boolean
  itens: PromocaoItem[]
}

export interface PromocaoSalvarPayload {
  id?: number | null
  nome: string
  data_inicio: string
  data_fim: string
  ativo: boolean
  itens: PromocaoItem[]
}

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

export async function listarPromocoes(userId?: number | null): Promise<Promocao[]> {
  const r = await rpc<any>('promocao_listar', { p_user_id: userId ?? 0 })
  return Array.isArray(r) ? r : []
}

export async function salvarPromocao(
  userId: number | null | undefined,
  payload: PromocaoSalvarPayload,
): Promise<{ id: number }> {
  return rpc<any>('promocao_salvar', { p_user_id: userId ?? 0, p_payload: payload })
}

export async function excluirPromocao(
  userId: number | null | undefined,
  id: number,
): Promise<void> {
  await rpc<any>('promocao_excluir', { p_user_id: userId ?? 0, p_id: id })
}
