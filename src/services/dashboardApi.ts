import { xano } from './xano'
import { supabase } from './supabase'
import { isSupabase } from './backend'

// Camada de dados de Dashboard / Relatórios (transição Xano → Supabase).

function extrairMensagem(err: unknown): string {
  const anyErr = err as any
  return anyErr?.message || anyErr?.error_description || 'Erro'
}

export interface PeriodoParams {
  periodo: string
  mesInicio: string
  userId?: number | null
}

async function invoke(name: string, params: PeriodoParams): Promise<any> {
  if (!supabase) throw new Error('Supabase não configurado')
  const { data, error } = await supabase.functions.invoke(name, {
    body: {
      user_id: params.userId ?? 0,
      mes_inicio: params.mesInicio,
      periodo: params.periodo,
    },
  })
  if (error) throw new Error(extrairMensagem(error))
  if (data?.error) throw new Error(data.error)
  return data
}

export async function carregarDashboard(params: PeriodoParams): Promise<any> {
  if (isSupabase) return invoke('dashboard', params)
  const q = new URLSearchParams({ periodo: params.periodo, mes_inicio: params.mesInicio })
  const resp = await xano.get(`/api:-qqRIakp/dashboard?${q.toString()}`)
  return resp.getBody()
}

export async function carregarRelatorio(params: PeriodoParams): Promise<any> {
  if (isSupabase) return invoke('relatorio', params)
  const q = new URLSearchParams({ periodo: params.periodo, mes_inicio: params.mesInicio })
  const resp = await xano.get(`/api:-qqRIakp/relatorio?${q.toString()}`)
  return resp.getBody()
}
