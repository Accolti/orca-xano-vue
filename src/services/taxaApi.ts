import { xano } from './xano'
import { supabase } from './supabase'
import { isSupabase } from './backend'

// Camada de dados de Taxas de cartão (tela /taxas) — transição Xano → Supabase.

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

// Lista taxas (empresa + globais) e provedores.
export async function listarTaxasGerenciar(
  userId?: number | null,
  targetUserId?: number | null,
): Promise<any> {
  if (isSupabase) {
    return rpc('taxas_banco_gerenciar', {
      p_user_id: userId ?? 0,
      p_target_user_id: targetUserId ?? null,
    })
  }
  const params = new URLSearchParams()
  if (targetUserId) params.set('user_id', String(targetUserId))
  const qs = params.toString()
  const resp = await xano.get(`/api:-qqRIakp/taxas_banco_gerenciar${qs ? `?${qs}` : ''}`)
  return resp.getBody()
}

// Cria/edita uma taxa.
export async function salvarTaxa(userId: number | null | undefined, payload: any): Promise<any> {
  if (isSupabase) {
    return rpc('taxa_banco_salvar', { p_user_id: userId ?? 0, p_payload: payload })
  }
  const resp = await xano.post('/api:-qqRIakp/taxa_banco_salvar', payload)
  return resp.getBody()
}

// Exclui uma taxa.
export async function excluirTaxa(userId: number | null | undefined, id: number): Promise<any> {
  if (isSupabase) {
    return rpc('taxa_banco_excluir', { p_user_id: userId ?? 0, p_id: id })
  }
  const resp = await xano.post('/api:-qqRIakp/taxa_banco_excluir', { id })
  return resp.getBody()
}

// Cria/edita um provedor.
export async function salvarProvedor(
  userId: number | null | undefined,
  payload: any,
): Promise<any> {
  if (isSupabase) {
    return rpc('provedor_salvar', { p_user_id: userId ?? 0, p_payload: payload })
  }
  const resp = await xano.post('/api:-qqRIakp/provedor_salvar', payload)
  return resp.getBody()
}
