// Template de adapter de coleta de taxas de um provedor.
//
// Copie este arquivo para `adapters/<nome-do-provedor>.mjs` e implemente a coleta.
// O `nome` do adapter deve ser o nome do Provedor no Xano em minúsculas
// (ex.: "Nubank" -> adapters/nubank.mjs -> export function nubank).
//
// Deve retornar um array no formato:
//   [{ parcelas: 1, cc_taxa: 3.09 }, { parcelas: 2, cc_taxa: 5.79 }, ...]
// Valores de `cc_taxa` em % (ex.: 3.09 = 3,09%).
//
// Fontes possíveis:
//  - API JSON: `const r = await fetch(provedor.url_taxas); const json = await r.json()`
//  - HTML estático: `fetch` + parse por regex (não há browser/cheerio aqui).
//  - Páginas renderizadas por JS exigem Playwright (ver README/ROADMAP).

/**
 * @param {{ id: number, nome: string, url_taxas?: string, canal_default?: string, metodo?: string, seletor?: object }} provedor
 * @returns {Promise<Array<{ parcelas: number, cc_taxa: number }>>}
 */
export async function template(provedor) {
  if (!provedor?.url_taxas) return []
  // TODO: implementar a coleta real e retornar as taxas.
  return []
}
