import { xano } from './xano'
import { supabase } from './supabase'
import { isSupabase } from './backend'

// Camada de dados do perfil do usuário (Meus Dados / Onboarding) — transição Xano → Supabase.

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

// Atualiza o próprio perfil (payload camelCase, igual ao que era enviado ao Xano).
export async function salvarPerfil(
  userId: number | null | undefined,
  payload: Record<string, unknown>,
): Promise<void> {
  if (isSupabase) {
    await rpc('user_salvar', { p_user_id: userId ?? 0, p_payload: payload })
    return
  }
  await xano.post(`/api:-qqRIakp/user/${userId}`, payload)
}

// Lista os regimes tributários (dropdown do perfil).
export async function listarRegimes(): Promise<any[]> {
  if (isSupabase) {
    const r = await rpc<any>('regime_lista')
    return Array.isArray(r) ? r : []
  }
  const resp = await xano.get('/api:-qqRIakp/regime')
  const body = resp.getBody() as any
  return Array.isArray(body) ? body : []
}

// Lista as organizações fornecedoras (dropdown do perfil).
export async function listarOrganizacoes(): Promise<any[]> {
  if (isSupabase) {
    const r = await rpc<any>('organizacao_lista')
    return Array.isArray(r) ? r : []
  }
  const resp = await xano.get('/api:-qqRIakp/organizacao')
  const body = resp.getBody() as any
  return Array.isArray(body) ? body : []
}

// Busca dados de CNPJ/IE (api.cnpja.com) via edge function `capturar-cnpj`.
export async function capturarCnpj(cnpj: string): Promise<any> {
  if (isSupabase) {
    if (!supabase) throw new Error('Supabase não configurado')
    const { data, error } = await supabase.functions.invoke('capturar-cnpj', { body: { cnpj } })
    if (error) throw new Error((error as any)?.message || 'Erro ao capturar CNPJ')
    if (data?.errorCNPJ) throw new Error(data.errorCNPJ.message || 'CNPJ não encontrado.')
    if (data?.errorIE) throw new Error(data.errorIE.message || 'Inscrição estadual não encontrada.')
    if (data?.error) throw new Error(data.error)
    return data
  }
  const resp = await xano.get('/api:-qqRIakp/capturarDados_CNPJ_IE', { cnpj })
  return resp.getBody()
}
