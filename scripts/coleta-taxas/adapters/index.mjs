// Registro de adapters de coleta por provedor.
// A chave é o nome do Provedor no Xano em minúsculas.
//
// Contrato do adapter: `coletar(provedor)` retorna um objeto mapeando CANAL -> taxas,
// ex.: { cartao_link: [{ parcelas, cc_taxa }], cartao_pos: [...] }.
// Sem adapter/fonte -> retorna {}.
import { nubank } from './nubank.mjs'

const ADAPTERS = {
  nubank,
}

/**
 * @param {{ nome: string }} provedor
 * @returns {Promise<Record<string, Array<{ parcelas: number, cc_taxa: number }>>>}
 */
export async function coletar(provedor) {
  const chave = String(provedor?.nome || '')
    .trim()
    .toLowerCase()
  const adapter = ADAPTERS[chave]
  if (!adapter) return {}
  return adapter(provedor)
}
