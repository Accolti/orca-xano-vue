// Template de adapter de coleta de taxas de um provedor.
//
// Copie este arquivo para `adapters/<nome-do-provedor>.mjs` e implemente a coleta.
// O `nome` do adapter deve ser o nome do Provedor no Xano em minúsculas
// (ex.: "Nubank" -> adapters/nubank.mjs -> export function nubank).
//
// CONTRATO: retornar um objeto mapeando CANAL -> taxas:
//   {
//     cartao_link:    [{ parcelas: 1, cc_taxa: 3.99 }, { parcelas: 2, cc_taxa: 5.99 }, ...],
//     cartao_pos:     [{ parcelas: 1, cc_taxa: 3.09 }, ...],
//     cartao_celular: [...],
//   }
// Valores de `cc_taxa` em % (ex.: 3.99 = 3,99%).
//
// Fontes possíveis:
//  - API JSON: `const r = await fetch(url); const json = await r.json()`
//  - HTML com dados embutidos (ex.: `__NEXT_DATA__`): `fetch` + parse por regex/JSON.
//  - HTML estático: `fetch` + parse por regex.
//  - Páginas renderizadas 100% por JS: exigem Playwright (ver ROADMAP).

/**
 * @param {{ id: number, nome: string, url_taxas?: string, canal_default?: string, metodo?: string, seletor?: object }} provedor
 * @returns {Promise<Record<string, Array<{ parcelas: number, cc_taxa: number }>>>}
 */
export async function template(provedor) {
  if (!provedor?.url_taxas) return {}
  // TODO: implementar a coleta real e retornar as taxas por canal.
  return {}
}
