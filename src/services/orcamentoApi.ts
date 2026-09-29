import { xano } from './xano'
import { supabase } from './supabase'
import { isSupabase } from './backend'

// Camada de dados do orçamento (transição Xano → Supabase).
// Precificação (calcular) vai para a Edge Function; escrita/status (2B/2C)
// irão para Postgres RPCs.

function extrairMensagem(err: unknown): string {
  const anyErr = err as any
  const msg = anyErr?.message || anyErr?.error_description || ''
  if (typeof msg === 'string' && msg.trim().startsWith('{')) {
    try {
      const parsed = JSON.parse(msg)
      return parsed?.error || parsed?.message || msg
    } catch {
      /* mantém msg */
    }
  }
  return msg || 'Erro ao calcular'
}

async function rpc<T>(name: string, args?: Record<string, unknown>): Promise<T> {
  if (!supabase) throw new Error('Supabase não configurado')
  const { data, error } = await supabase.rpc(name, args)
  if (error) throw new Error(extrairMensagem(error))
  return (typeof data === 'string' ? JSON.parse(data) : data) as T
}

// Supabase devolve colunas em snake_case (o Postgres lowercasa os identificadores),
// mas o front espera o naming do Xano (camelCase / "B2B" maiúsculo). Normaliza o ORCA_1.
function normalizarOrca(orca: any): any {
  if (!orca || typeof orca !== 'object') return orca
  return {
    ...orca,
    frtB2B: orca.frtB2B ?? orca.frt_b2b,
    frtB2C: orca.frtB2C ?? orca.frt_b2c,
    vnd_B2B_tot: orca.vnd_B2B_tot ?? orca.vnd_b2b_tot,
    vnd_B2B_B2C_tot: orca.vnd_B2B_B2C_tot ?? orca.vnd_b2b_b2c_tot,
  }
}

// Executa um RPC de escrita e normaliza o ORCA_1 do retorno.
async function rpcOrca(name: string, args: Record<string, unknown>): Promise<any> {
  const body = await rpc<any>(name, args)
  return { ...body, ORCA_1: normalizarOrca(body?.ORCA_1) }
}

// Motor de precificação (orcamento_calcular / Orcamento_Orquestrador).
export async function calcularOrcamento(
  payload: Record<string, unknown>,
  userId?: number | null,
): Promise<any> {
  if (isSupabase) {
    if (!supabase) throw new Error('Supabase não configurado')
    const { data, error } = await supabase.functions.invoke('orcamento-calcular', {
      body: { ...payload, user_id: userId ?? 0 },
    })
    if (error) throw new Error(extrairMensagem(error))
    return data
  }
  const resp = await xano.post('/api:-qqRIakp/orcamento_calcular', payload)
  return resp.getBody()
}

// Gera o próximo cod_orca. Retorna o código (string) ou null.
export async function gerarNumeroOrcamento(userId?: number | null): Promise<string | null> {
  if (isSupabase) {
    const r = await rpc<{ newOrca?: string }>('novo_numero_orcamento', { p_user_id: userId ?? 0 })
    return r?.newOrca ?? null
  }
  const resp = await xano.get('/api:-qqRIakp/Novo_Numero_Orcamento', { id_do_Usuario: userId })
  return resp.getBody()?.result_1?.newOrca ?? null
}

// Insere item (cria Orca na 1ª vez). Retorna { ORCA_1, itemS }.
export async function inserirItem(payload: any, userId?: number | null): Promise<any> {
  if (isSupabase) {
    return rpcOrca('orcamento_item_inserir', { p_payload: { ...payload, user_id: userId ?? 0 } })
  }
  const resp = await xano.post('/api:-qqRIakp/OrcamentoItem_Inserir', payload)
  const body = resp.getBody()
  return { ORCA_1: body?.ORC?.ORCA_1 ?? null, itemS: body?.ORC?.itemS ?? [] }
}

// Atualiza item existente. Retorna { ORCA_1, itemS }.
export async function atualizarItem(payload: any, userId?: number | null): Promise<any> {
  if (isSupabase) {
    return rpcOrca('orcamento_item_atualizar', { p_payload: { ...payload, user_id: userId ?? 0 } })
  }
  const resp = await xano.post('/api:-qqRIakp/OrcamentoItem_Atualizar', payload)
  return resp.getBody()
}

// Remove item. Retorna { ORCA_1, itemS }.
export async function deletarItem(itemId: number): Promise<any> {
  if (isSupabase) {
    return rpcOrca('orcamento_item_deletar', { p_item_id: itemId })
  }
  const resp = await xano.delete('/api:-qqRIakp/orcamento_item_deletar', { item_id: itemId })
  return resp.getBody()
}

// Recalcula (margem/frete/desconto/mão de obra/observação/condições) + política de desconto.
export async function recalcularOrcamento(payload: any, userId?: number | null): Promise<any> {
  if (isSupabase) {
    return rpcOrca('orcamento_recalcular', { p_payload: { ...payload, user_id: userId ?? 0 } })
  }
  const resp = await xano.post('/api:-qqRIakp/orcamento_recalcular', payload)
  return resp.getBody()
}

// Leitura read-only de um orçamento pelo cod_orca. Retorna { ORCA_1, itemS }.
export async function carregarOrcamentoDetalhes(
  codOrca: string,
  userId?: number | null,
): Promise<any> {
  if (isSupabase) {
    const body = await rpc<any>('orca_detalhes', {
      p_user_id: userId ?? 0,
      p_cod_orca: codOrca,
    })
    return { ORCA_1: normalizarOrca(body?.ORCA_1), itemS: body?.itemS ?? [] }
  }
  const resp = await xano.get('/api:-qqRIakp/orca_detalhes', { cod_orca: codOrca })
  return resp.getBody()
}

// Leitura read-only de um orçamento pelo id (com permissão de dono/ancestral).
export async function carregarOrcamentoDetalhesPorId(
  orcaId: number,
  userId?: number | null,
): Promise<any> {
  if (isSupabase) {
    const body = await rpc<any>('orca_por_id', {
      p_user_id: userId ?? 0,
      p_orca_id: orcaId,
    })
    return { ORCA_1: normalizarOrca(body?.ORCA_1), itemS: body?.itemS ?? [] }
  }
  const resp = await xano.get('/api:-qqRIakp/orca_por_id', { orca_id: orcaId })
  return resp.getBody()
}

export interface BuscarOrcamentosParams {
  userId?: number | null
  busca?: string
  page?: number
  perPage?: number
  soPedidos?: boolean
  somenteOrcamentos?: boolean
}

// Lista paginada de orçamentos/pedidos (busca + status mesclado).
export async function buscarListaOrcamentos(
  params: BuscarOrcamentosParams,
): Promise<{ items: any[]; hasNext: boolean; hasPrev: boolean }> {
  const perPage = params.perPage ?? 20
  if (isSupabase) {
    const body = await rpc<any>('orca_por_cliente_busca', {
      p_user_id: params.userId ?? 0,
      p_busca: params.busca ?? '',
      p_page: params.page ?? 1,
      p_per_page: perPage,
      p_so_pedidos: params.soPedidos ?? false,
      p_somente_orcamentos: params.somenteOrcamentos ?? false,
    })
    const items = (body?.items ?? []).map(normalizarOrca)
    const itemsReceived = body?.itemsReceived ?? items.length
    return {
      items,
      hasNext: !!body?.nextPage && itemsReceived >= perPage,
      hasPrev: !!body?.prevPage,
    }
  }
  const [buscaRes, statusRes] = await Promise.all([
    xano.get('/api:-qqRIakp/orca_por_cliente_busca', {
      busca: params.busca,
      page: params.page,
      per_page: perPage,
      so_pedidos: params.soPedidos || undefined,
      somente_orcamentos: params.somenteOrcamentos || undefined,
    }),
    xano.get('/api:-qqRIakp/orcamento_status_lista'),
  ])
  const body = buscaRes.getBody() as any
  const statusMap = new Map<number, string>()
  const statusList = (statusRes.getBody() as any[]) ?? []
  statusList.forEach((o: any) => {
    if (o?.id != null && o?.status) statusMap.set(Number(o.id), o.status)
  })
  const items = ((body?.items ?? []) as any[]).map((row) => ({
    ...row,
    status: statusMap.get(Number(row.id)) ?? row.status ?? 'RASCUNHO',
  }))
  const itemsReceived = body?.itemsReceived ?? items.length
  return {
    items,
    hasNext: !!body.nextPage && itemsReceived >= perPage,
    hasPrev: !!body.prevPage,
  }
}

// Atualiza o status do orçamento. Retorna { ORCA_1 }.
export async function atualizarStatusOrcamento(
  orcaId: number,
  status: string,
  motivo: string | undefined,
  userId?: number | null,
): Promise<any> {
  if (isSupabase) {
    const body = await rpc<any>('orcamento_status', {
      p_user_id: userId ?? 0,
      p_orca_id: orcaId,
      p_status: status,
      p_motivo: motivo ?? null,
    })
    return { ORCA_1: normalizarOrca(body?.ORCA_1) }
  }
  const resp = await xano.post('/api:-qqRIakp/orcamento_status', {
    orca_id: orcaId,
    status,
    motivo,
  })
  return resp.getBody()
}

// Converte um orçamento APROVADO em pedido. Retorna { ORCA_1 }.
export async function converterOrcamentoPedido(orcaId: number, userId?: number | null): Promise<any> {
  if (isSupabase) {
    const body = await rpc<any>('orcamento_converter_pedido', {
      p_user_id: userId ?? 0,
      p_orca_id: orcaId,
    })
    return { ORCA_1: normalizarOrca(body?.ORCA_1) }
  }
  const resp = await xano.post('/api:-qqRIakp/orcamento_converter_pedido', { orca_id: orcaId })
  return resp.getBody()
}

// Histórico de status (auditoria). Retorna array.
export async function carregarStatusHistorico(
  orcaId: number,
  userId?: number | null,
): Promise<any[]> {
  if (isSupabase) {
    const body = await rpc<any>('orcamento_status_historico', {
      p_user_id: userId ?? 0,
      p_orca_id: orcaId,
    })
    return Array.isArray(body) ? body : []
  }
  const resp = await xano.get('/api:-qqRIakp/orcamento_status_historico', { orca_id: orcaId })
  const body = resp.getBody() as any
  return Array.isArray(body) ? body : []
}

// Exclui um orçamento (cascata). Retorna { ok }.
export async function deletarOrcamento(orcaId: number, userId?: number | null): Promise<any> {
  if (isSupabase) {
    return rpc<any>('orcamento_deletar', { p_user_id: userId ?? 0, p_orca_id: orcaId })
  }
  const resp = await xano.delete('/api:-qqRIakp/orcamento_deletar', { orca_id: orcaId })
  return resp.getBody()
}

// Duplica um orçamento. Retorna { orca: { cod_orca } }.
export async function duplicarOrcamento(orcaId: number, userId?: number | null): Promise<any> {
  if (isSupabase) {
    return rpc<any>('orcamento_duplicar', { p_user_id: userId ?? 0, p_orca_id: orcaId })
  }
  const resp = await xano.post('/api:-qqRIakp/Orcamento_Duplicar', {
    orca_id: orcaId,
    user_id: userId,
  })
  return resp.getBody()
}

// Aprova/recusa o desconto acima do limite. Retorna { id, desconto_aprovado }.
export async function aprovarDescontoOrcamento(
  orcaId: number,
  aprovado: boolean,
  userId?: number | null,
): Promise<any> {
  if (isSupabase) {
    return rpc<any>('orcamento_aprovar_desconto', {
      p_user_id: userId ?? 0,
      p_orca_id: orcaId,
      p_aprovado: aprovado,
    })
  }
  const resp = await xano.post('/api:-qqRIakp/orcamento_aprovar_desconto', {
    orca_id: orcaId,
    aprovado,
  })
  return resp.getBody()
}

// Fila de orçamentos de filhos com desconto pendente. Retorna { linhas }.
export async function buscarPendentesAprovacao(userId?: number | null): Promise<any> {
  if (isSupabase) {
    return rpc<any>('orcamentos_pendentes_aprovacao', { p_user_id: userId ?? 0 })
  }
  const resp = await xano.get('/api:-qqRIakp/orcamentos_pendentes_aprovacao')
  return resp.getBody()
}

// Retorna o ControlePedido (dados Kapazi) de uma orca, ou null se ainda não existe.
export async function carregarControlePedido(orcaId: number, userId?: number | null): Promise<any> {
  if (isSupabase) {
    return rpc<any>('controle_pedido_por_orca', { p_user_id: userId ?? 0, p_orca_id: orcaId })
  }
  const resp = await xano.get('/api:-qqRIakp/controle_pedido_por_orca', { orca_id: orcaId })
  return resp.getBody()
}

// Salva (cria/atualiza) o ControlePedido. Retorna o registro salvo.
export async function salvarControlePedido(
  orcaId: number,
  dados: Record<string, any>,
  userId?: number | null,
): Promise<any> {
  if (isSupabase) {
    return rpc<any>('controle_pedido_salvar', {
      p_user_id: userId ?? 0,
      p_payload: { orca_id: orcaId, ...dados },
    })
  }
  const resp = await xano.post('/api:-qqRIakp/controle_pedido_salvar', { orca_id: orcaId, ...dados })
  return resp.getBody()
}
