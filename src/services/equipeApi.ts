import { xano } from './xano'
import { supabase } from './supabase'
import { isSupabase } from './backend'

// Camada de dados de Equipe + Comissões + Faixas (transição Xano → Supabase).

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

// Lista a equipe.
export async function listarEquipe(userId?: number | null): Promise<any[]> {
  if (isSupabase) {
    const r = await rpc<any>('equipe', { p_user_id: userId ?? 0 })
    return Array.isArray(r) ? r : []
  }
  const resp = await xano.get('/api:-qqRIakp/equipe')
  const body = resp.getBody() as any
  return Array.isArray(body) ? body : []
}

// Cria um vendedor/master (cria usuarios + convite no Supabase Auth).
export async function criarVendedor(userId: number | null | undefined, payload: any): Promise<any> {
  if (isSupabase) {
    if (!supabase) throw new Error('Supabase não configurado')
    const { data, error } = await supabase.functions.invoke('equipe-criar', {
      body: { user_id: userId ?? 0, ...payload },
    })
    if (error) throw new Error(extrairMensagem(error))
    if (data?.error) throw new Error(data.error)
    return data
  }
  const resp = await xano.post('/api:-qqRIakp/equipe_criar', payload)
  return resp.getBody()
}

// Vincula uma conta existente como vendedor/master.
export async function vincularEquipe(
  userId: number | null | undefined,
  email: string,
  percentual: number | undefined,
  role: string,
): Promise<any> {
  if (isSupabase) {
    return rpc('equipe_vincular', {
      p_user_id: userId ?? 0,
      p_email: email,
      p_percentual_comissao: percentual ?? null,
      p_role: role,
    })
  }
  const resp = await xano.post('/api:-qqRIakp/equipe_vincular', {
    email,
    percentual_comissao: percentual || undefined,
    role,
  })
  return resp.getBody()
}

// Salva o cadastro de um vendedor (snapshot completo).
export async function salvarEquipe(userId: number | null | undefined, payload: any): Promise<any> {
  if (isSupabase) {
    return rpc('equipe_salvar', {
      p_user_id: userId ?? 0,
      p_target_id: payload.user_id,
      p_percentual_comissao: payload.percentual_comissao ?? 0,
      p_ativo: payload.ativo ?? true,
      p_desconto_livre_perc: payload.desconto_livre_perc ?? 0,
      p_desconto_max_perc: payload.desconto_max_perc ?? 0,
    })
  }
  const resp = await xano.post('/api:-qqRIakp/equipe_salvar', payload)
  return resp.getBody()
}

// Define o papel (admin_geral).
export async function promoverRole(
  userId: number | null | undefined,
  targetId: number,
  role: string,
): Promise<any> {
  if (isSupabase) {
    return rpc('equipe_role', { p_user_id: userId ?? 0, p_target_id: targetId, p_role: role })
  }
  const resp = await xano.post('/api:-qqRIakp/equipe_role', { user_id: targetId, role })
  return resp.getBody()
}

// Comissões por período.
export async function listarComissoes(
  userId: number | null | undefined,
  periodo: string,
  mesInicio: string,
): Promise<any> {
  if (isSupabase) {
    return rpc('comissoes', {
      p_user_id: userId ?? 0,
      p_mes_inicio: mesInicio,
      p_periodo: periodo,
    })
  }
  const params = new URLSearchParams({ periodo, mes_inicio: mesInicio })
  const resp = await xano.get(`/api:-qqRIakp/comissoes?${params.toString()}`)
  return resp.getBody()
}

// Marca uma comissão como paga.
export async function pagarComissao(userId: number | null | undefined, comissaoId: number): Promise<any> {
  if (isSupabase) {
    return rpc('comissao_pagar', { p_user_id: userId ?? 0, p_comissao_id: comissaoId })
  }
  const resp = await xano.post('/api:-qqRIakp/comissao_pagar', { comissao_id: comissaoId })
  return resp.getBody()
}

// Faixas de comissão (resolve a empresa dona).
export async function listarFaixas(
  userId: number | null | undefined,
  targetUserId?: number | null,
): Promise<any> {
  if (isSupabase) {
    return rpc('faixas_comissao', {
      p_user_id: userId ?? 0,
      p_target_user_id: targetUserId ?? null,
    })
  }
  const params = new URLSearchParams()
  if (targetUserId) params.set('user_id', String(targetUserId))
  const resp = await xano.get(`/api:-qqRIakp/faixas_comissao?${params.toString()}`)
  return resp.getBody()
}

// Cria/edita uma faixa.
export async function salvarFaixa(userId: number | null | undefined, payload: any): Promise<any> {
  if (isSupabase) {
    return rpc('faixa_comissao_salvar', {
      p_user_id: userId ?? 0,
      p_id: payload.id ?? null,
      p_target_user_id: payload.user_id ?? null,
      p_faixa_min: payload.faixa_min ?? null,
      p_faixa_max: payload.faixa_max ?? null,
      p_comissao_total_perc: payload.comissao_total_perc ?? null,
      p_ordem: payload.ordem ?? null,
      p_ativo: payload.ativo ?? true,
    })
  }
  const resp = await xano.post('/api:-qqRIakp/faixa_comissao_salvar', payload)
  return resp.getBody()
}

// Define o plano (admin_geral).
export async function definirPlano(
  userId: number | null | undefined,
  targetId: number,
  plano: string,
): Promise<any> {
  if (isSupabase) {
    return rpc('user_plano', { p_user_id: userId ?? 0, p_target_id: targetId, p_plano: plano })
  }
  const resp = await xano.post('/api:-qqRIakp/user_plano', { user_id: targetId, plano })
  return resp.getBody()
}
