import { xano } from './xano'
import { supabase } from './supabase'
import { isSupabase } from './backend'

// Camada de dados de Cliente (transição Xano → Supabase).

function extrairMensagem(err: unknown): string {
  const anyErr = err as any
  const msg = anyErr?.message || anyErr?.error_description || ''
  return msg || 'Erro'
}

async function rpc<T>(name: string, args?: Record<string, unknown>): Promise<T> {
  if (!supabase) throw new Error('Supabase não configurado')
  const { data, error } = await supabase.rpc(name, args)
  if (error) throw new Error(extrairMensagem(error))
  return (typeof data === 'string' ? JSON.parse(data) : data) as T
}

// Supabase devolve a coluna `email`; o front espera `e-mail` (naming do Xano).
function normalizarCliente(c: any): any {
  if (!c || typeof c !== 'object') return c
  return { ...c, 'e-mail': c['e-mail'] ?? c.email }
}

// Lista paginada de clientes (busca + total). Retorna { cliente, total, pagina, limite }.
export async function buscarClientes(
  termo: string | undefined,
  pagina: number,
  userId?: number | null,
): Promise<any> {
  if (isSupabase) {
    return rpc('cliente_user_busca', {
      p_user_id: userId ?? 0,
      p_busca: termo ?? '',
      p_pagina: pagina,
    })
  }
  const params: Record<string, string | number> = { pagina }
  if (termo) params.busca = termo
  const resp = await xano.get('/api:-qqRIakp/cliente_user_busca', params)
  return resp.getBody()
}

// Detalhe de um cliente (com _endereco_cliente e _telefone_cliente_of_cliente).
export async function carregarCliente(clienteId: number, userId?: number | null): Promise<any> {
  if (isSupabase) {
    const body = await rpc<any>('cliente_por_id', {
      p_user_id: userId ?? 0,
      p_cliente_id: clienteId,
    })
    return normalizarCliente(body)
  }
  const resp = await xano.get(`/api:-qqRIakp/cliente/${clienteId}`)
  return resp.getBody()
}

// Cria (sem cliente_id) ou atualiza (com cliente_id) cliente + endereço + telefones.
// Retorna { cliente }.
export async function salvarCliente(payload: any, userId?: number | null): Promise<any> {
  if (isSupabase) {
    return rpc('cliente_salvar', { p_user_id: userId ?? 0, p_payload: payload })
  }
  const isEdit = payload?.cliente_id != null
  const resp = isEdit
    ? await xano.patch('/api:-qqRIakp/Cliente_Endereco_Telefone', payload)
    : await xano.post('/api:-qqRIakp/Cliente_Endereco_Telefone', payload)
  const body = resp.getBody() ?? {}
  return { cliente: body?.Cliente_2 ?? body?.Cliente ?? body?.cliente ?? null }
}

// Exclui um cliente (bloqueia se houver orçamentos).
export async function deletarCliente(clienteId: number, userId?: number | null): Promise<any> {
  if (isSupabase) {
    return rpc('cliente_deletar', { p_user_id: userId ?? 0, p_cliente_id: clienteId })
  }
  const resp = await xano.delete(`/api:-qqRIakp/cliente/${clienteId}`)
  return resp.getBody()
}

// Captura dados de CNPJ/IE (api.cnpja.com via Edge Function no Supabase).
export async function capturarDadosCNPJ(cnpj: string): Promise<any> {
  if (isSupabase) {
    if (!supabase) throw new Error('Supabase não configurado')
    const { data, error } = await supabase.functions.invoke('capturar-cnpj', { body: { cnpj } })
    if (error) throw new Error(extrairMensagem(error))
    return data
  }
  const resp = await xano.get('/api:-qqRIakp/capturarDados_CNPJ_IE', { cnpj })
  return resp.getBody()
}
