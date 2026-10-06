import { supabase } from './supabase'
import { useAuthStore } from '@/stores/auth'

// Camada de dados das dev tools (admin do catálogo) — Supabase.
// Substitui os endpoints Xano usados por DevMateriais/DevProdutos/DevFatores/DevConfiguracoes.

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

function userIdAtual(): number {
  return useAuthStore().user?.id ?? 0
}

// Leituras (listas)
export async function listarMateriaisDev(): Promise<any[]> {
  const r = await rpc<any>('rpc_materiais_dev')
  return Array.isArray(r) ? r : []
}

export async function listarProdutosDev(): Promise<any[]> {
  const r = await rpc<any>('rpc_produtos_dev')
  return Array.isArray(r) ? r : []
}

export async function listarFatoresCorteDev(): Promise<{ fatores: any[]; associacoes: any[] }> {
  const r = await rpc<any>('rpc_fatores_corte_dev')
  return { fatores: r?.fatores ?? [], associacoes: r?.associacoes ?? [] }
}

export async function listarConfiguracoesDev(): Promise<any[]> {
  const r = await rpc<any>('rpc_configuracoes_dev')
  return Array.isArray(r) ? r : []
}

export async function listarClassificacoes(): Promise<any[]> {
  const r = await rpc<any>('rpc_classificacao_lista')
  return Array.isArray(r) ? r : []
}

export async function listarTiposVariacao(): Promise<any[]> {
  const r = await rpc<any>('rpc_tipo_variacao_lista')
  return Array.isArray(r) ? r : []
}

export async function listarCores(): Promise<any[]> {
  const r = await rpc<any>('rpc_cor_lista')
  return Array.isArray(r) ? r : []
}

export async function listarModelos(): Promise<any[]> {
  const r = await rpc<any>('rpc_modelo_lista')
  return Array.isArray(r) ? r : []
}

export async function listarFatoresCorte(): Promise<any[]> {
  const r = await rpc<any>('rpc_fatordecorte_lista')
  return Array.isArray(r) ? r : []
}

export async function listarOrganizacoesDev(): Promise<any[]> {
  const r = await rpc<any>('organizacao_lista')
  return Array.isArray(r) ? r : []
}

export async function listarLinhasDev(): Promise<any[]> {
  const r = await rpc<any>('rpc_linhas_dev')
  return Array.isArray(r) ? r : []
}

export async function listarTiposDev(): Promise<any[]> {
  const r = await rpc<any>('rpc_tipos_dev')
  return Array.isArray(r) ? r : []
}

export async function listarNiveisDev(): Promise<any[]> {
  const r = await rpc<any>('rpc_niveis_dev')
  return Array.isArray(r) ? r : []
}

export async function listarBordasDev(): Promise<any[]> {
  const r = await rpc<any>('rpc_bordas_dev')
  return Array.isArray(r) ? r : []
}

// Escritas (CRUD)
export async function salvarMaterial(payload: Record<string, unknown>): Promise<void> {
  await rpc('material_salvar', { p_user_id: userIdAtual(), p_payload: payload })
}

export async function salvarProduto(payload: Record<string, unknown>): Promise<void> {
  await rpc('produto_salvar', { p_user_id: userIdAtual(), p_payload: payload })
}

export async function salvarLinha(payload: Record<string, unknown>): Promise<void> {
  await rpc('linha_salvar', { p_user_id: userIdAtual(), p_payload: payload })
}

export async function salvarTipo(payload: Record<string, unknown>): Promise<void> {
  await rpc('tipo_salvar', { p_user_id: userIdAtual(), p_payload: payload })
}

export async function salvarNivel(payload: Record<string, unknown>): Promise<void> {
  await rpc('nivel_salvar', { p_user_id: userIdAtual(), p_payload: payload })
}

export async function salvarBorda(payload: Record<string, unknown>): Promise<void> {
  await rpc('borda_salvar', { p_user_id: userIdAtual(), p_payload: payload })
}

export async function salvarFatorCorte(payload: Record<string, unknown>): Promise<void> {
  await rpc('fator_corte_salvar', { p_user_id: userIdAtual(), p_payload: payload })
}

export async function excluirFatorCorte(id: number): Promise<void> {
  await rpc('fator_corte_excluir', { p_user_id: userIdAtual(), p_fator_de_corte_id: id })
}

export async function salvarTipoFator(payload: Record<string, unknown>): Promise<void> {
  await rpc('tipo_fator_salvar', { p_user_id: userIdAtual(), p_payload: payload })
}

export async function bumpConfiguracoesVersao(
  configuracoesId: number,
  campo: string,
  delta: number,
): Promise<void> {
  await rpc('configuracoes_versao', {
    p_user_id: userIdAtual(),
    p_configuracoes_id: configuracoesId,
    p_campo: campo,
    p_delta: delta,
  })
}
