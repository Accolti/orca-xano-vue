// Camada de abstração do backend (transição Xano → Supabase).
//
// O app roda em DUAL: uma flag decide qual backend está ativo, permitindo migrar
// feature a feature sem derrubar o sistema em produção (que hoje usa Xano).
//
// Fases futuras: as stores deixam de chamar `xano.*` direto e passam a chamar
// operações semânticas implementadas aqui (ex.: fetchCatalogo(), calcularOrcamento(),
// inserirItem(), recalcular(), login()...), com duas implementações:
//   - XanoBackend    → REST (src/services/xano.ts)
//   - SupabaseBackend → PostgREST + RPC (src/services/supabase.ts)
//
// Por enquanto (Fase 0) é só o esqueleto: a flag de seleção + o client do Supabase.

export type BackendKind = 'xano' | 'supabase'

const raw = (import.meta.env.VITE_BACKEND as string | undefined)?.toLowerCase()
export const backendKind: BackendKind = raw === 'supabase' ? 'supabase' : 'xano'

export const isSupabase = backendKind === 'supabase'
export const isXano = backendKind === 'xano'

export { supabase } from './supabase'
