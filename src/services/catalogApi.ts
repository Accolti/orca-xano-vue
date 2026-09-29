import { xano } from './xano'
import { supabase } from './supabase'
import { isSupabase } from './backend'
import type { TaxaBanco, ProdutoCatalogo } from '@/types/orcamento'

// Camada de dados do catálogo (produtos/taxas) — transição Xano → Supabase.
// Cada método tem duas implementações: Xano (REST) e Supabase (RPC).

async function rpc<T>(name: string, args?: Record<string, unknown>): Promise<T> {
  if (!supabase) throw new Error('Supabase não configurado')
  const { data, error } = await supabase.rpc(name, args)
  if (error) throw error
  return (typeof data === 'string' ? JSON.parse(data) : data) as T
}

export interface ConfiguracoesMae {
  versao_materiais?: number | null
  versao_produtos?: number | null
  versao_taxas_banco?: number | null
  taxas_atualizado_em?: number | null
}

export interface ConfiguracoesResponse {
  'configuracoes-mae': ConfiguracoesMae[]
}

export async function getConfiguracoes(): Promise<ConfiguracoesResponse> {
  if (isSupabase) return rpc<ConfiguracoesResponse>('rpc_configuracoes')
  const resp = await xano.get('/api:-qqRIakp/configuracoes')
  return resp.getBody() as ConfiguracoesResponse
}

export async function getTaxasBanco(userId?: number | null): Promise<TaxaBanco[]> {
  if (isSupabase) return rpc<TaxaBanco[]>('rpc_taxas_banco', { p_user_id: userId ?? 0 })
  const resp = await xano.get('/api:-qqRIakp/taxas_banco')
  return (resp.getBody() as TaxaBanco[]) ?? []
}

export async function getProdutosParaSelecao(): Promise<{ lista_para_selecao: any }> {
  if (isSupabase) return rpc<{ lista_para_selecao: any }>('rpc_produtos_para_selecao')
  const resp = await xano.get('/api:-qqRIakp/produtos_para_selecao')
  return resp.getBody() as { lista_para_selecao: any }
}

export async function getProdutosAll(): Promise<ProdutoCatalogo[]> {
  if (isSupabase) return rpc<ProdutoCatalogo[]>('rpc_produtos_all')
  const resp = await xano.get('/api:-qqRIakp/produtos_all', {
    produto_id: 0,
    material_id: 0,
    linha_id: 0,
    tipo_id: 0,
    nivel_id: 0,
    detalhe_id: 0,
  })
  return (resp.getBody() as ProdutoCatalogo[]) ?? []
}

export async function getProdutosSucFiltrado(
  materialId: number,
  linhaId?: number,
  tipoId?: number,
): Promise<{ Material_1: any[] }> {
  if (isSupabase) {
    return rpc<{ Material_1: any[] }>('rpc_produtos_suc_filtrado', {
      p_material_id: materialId,
      p_linha_id: linhaId ?? 0,
      p_tipo_id: tipoId ?? 0,
    })
  }
  const resp = await xano.get('/api:-qqRIakp/produtos_suc_filtrado', {
    material_id: materialId,
    linha_id: linhaId ?? 0,
    tipo_id: tipoId ?? 0,
  })
  return resp.getBody() as { Material_1: any[] }
}
