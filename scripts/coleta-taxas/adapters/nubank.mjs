// Adapter do Nubank.
//
// FONTE AINDA NÃO DEFINIDA. Enquanto o Provedor no Xano estiver sem `url_taxas`
// (ou com `metodo = "manual"`), este adapter retorna vazio e a coleta é ignorada.
//
// Quando a fonte for definida (API JSON ou página HTML), implementar aqui e
// retornar [{ parcelas, cc_taxa }] — ver `template.mjs` para o contrato.

/**
 * @param {{ url_taxas?: string, seletor?: object }} provedor
 * @returns {Promise<Array<{ parcelas: number, cc_taxa: number }>>}
 */
export async function nubank(provedor) {
  if (!provedor?.url_taxas) return []

  // Exemplo (API JSON):
  // const resp = await fetch(provedor.url_taxas)
  // if (!resp.ok) throw new Error(`Nubank ${resp.status}`)
  // const json = await resp.json()
  // return json.parcelas.map((p) => ({ parcelas: Number(p.n), cc_taxa: Number(p.taxa) }))

  return []
}
