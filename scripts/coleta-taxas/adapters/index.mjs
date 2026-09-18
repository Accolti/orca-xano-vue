// Registro de adapters de coleta por provedor.
// A chave é o nome do Provedor no Xano em minúsculas.
import { nubank } from './nubank.mjs'

const ADAPTERS = {
  nubank,
}

/**
 * Executa o adapter do provedor (se existir). Sem adapter/fonte -> retorna [].
 * @param {{ nome: string }} provedor
 */
export async function coletar(provedor) {
  const chave = String(provedor?.nome || '')
    .trim()
    .toLowerCase()
  const adapter = ADAPTERS[chave]
  if (!adapter) return []
  return adapter(provedor)
}
