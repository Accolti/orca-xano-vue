import { xano } from './xano'
import { supabase } from './supabase'
import { isSupabase } from './backend'

// Camada de dados de Notificações (transição Xano → Supabase).

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

// Lista as notificações do usuário + contagem de não lidas.
export async function listarNotificacoes(userId?: number | null, limite = 20): Promise<any> {
  if (isSupabase) {
    return rpc('notificacoes', { p_user_id: userId ?? 0, p_limite: limite })
  }
  const resp = await xano.get('/api:-qqRIakp/notificacoes', { limite })
  return resp.getBody()
}

// Marca todas as notificações como lidas.
export async function marcarNotificacoesLidas(userId?: number | null): Promise<any> {
  if (isSupabase) {
    return rpc('notificacoes_marcar_lida', { p_user_id: userId ?? 0 })
  }
  const resp = await xano.post('/api:-qqRIakp/notificacoes_marcar_lida')
  return resp.getBody()
}
