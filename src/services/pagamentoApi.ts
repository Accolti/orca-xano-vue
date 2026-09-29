import { xano } from './xano'
import { supabase } from './supabase'
import { isSupabase } from './backend'
import type { ParcelaFinanceira } from '@/utils/pagamentos'

// Camada de dados de Pagamentos/Financeiro (transição Xano → Supabase).

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

// Lista as parcelas (todas ou de uma orca).
export async function listarParcelas(userId?: number | null, orcaId?: number | null): Promise<any[]> {
  if (isSupabase) {
    const r = await rpc<any>('pagamentos', {
      p_user_id: userId ?? 0,
      p_orca_id: orcaId ?? null,
    })
    return Array.isArray(r) ? r : []
  }
  const resp = orcaId
    ? await xano.get('/api:-qqRIakp/pagamentos', { orca_id: orcaId })
    : await xano.get('/api:-qqRIakp/pagamentos')
  const body = resp.getBody() as any
  return Array.isArray(body) ? body : []
}

// Substitui as parcelas de um orçamento.
export async function salvarParcelas(
  orcaId: number,
  lista: ParcelaFinanceira[],
  userId?: number | null,
): Promise<void> {
  const parcelas = lista.map((p) => ({
    valor: p.valor,
    vencimento: p.vencimento,
    forma_pagamento_id: p.forma_pagamento_id,
  }))
  if (isSupabase) {
    await rpc('pagamento_salvar', {
      p_user_id: userId ?? 0,
      p_orca_id: orcaId,
      p_parcelas: parcelas,
    })
    return
  }
  await xano.post('/api:-qqRIakp/pagamento_salvar', { orca_id: orcaId, parcelas })
}

// Baixa (marca pago) uma parcela.
export async function baixarParcela(
  boletoId: number,
  pagamento?: string,
  userId?: number | null,
): Promise<void> {
  if (isSupabase) {
    await rpc('pagamento_baixa', {
      p_user_id: userId ?? 0,
      p_boleto_id: boletoId,
      p_pagamento: pagamento ?? null,
    })
    return
  }
  await xano.post('/api:-qqRIakp/pagamento_baixa', {
    boleto_id: boletoId,
    pagamento: pagamento ?? 'today',
  })
}

// Estorna a baixa de uma parcela.
export async function estornarParcela(boletoId: number, userId?: number | null): Promise<void> {
  if (isSupabase) {
    await rpc('pagamento_baixa', {
      p_user_id: userId ?? 0,
      p_boleto_id: boletoId,
      p_estornar: true,
    })
    return
  }
  await xano.post('/api:-qqRIakp/pagamento_baixa', { boleto_id: boletoId, estornar: true })
}

// Exclui uma parcela.
export async function excluirParcela(boletoId: number, userId?: number | null): Promise<void> {
  if (isSupabase) {
    await rpc('pagamento_excluir', { p_user_id: userId ?? 0, p_boleto_id: boletoId })
    return
  }
  await xano.post('/api:-qqRIakp/pagamento_excluir', { boleto_id: boletoId })
}
