// Adapter do Nubank — taxas do Nu Empresas (Link de pagamento e Tap to Pay).
//
// Fonte: a página da calculadora é server-rendered (Next.js) e traz as taxas
// embutidas no JSON `__NEXT_DATA__` (não precisa de browser/Playwright).
// Mapeia apenas CRÉDITO 1x–12x:
//   "Link de pagamento" -> canal cartao_link
//   "Tap to Pay"        -> canal cartao_celular (cartão pelo celular)

const URL_PADRAO = 'https://blog.nubank.com.br/calculadoras/calculadora-taxas-nu-empresas/'

const MAPA_PRODUTO_CANAL = {
  'Link de pagamento': 'cartao_link',
  'Tap to Pay': 'cartao_celular',
}

function extrairNextData(html) {
  const m = html.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/)
  if (!m) throw new Error('__NEXT_DATA__ não encontrado na página')
  return JSON.parse(m[1])
}

// crédito: credito_a_vista (1x) e credito_Nx (2..12) -> [{ parcelas, cc_taxa }]
function creditosDoProduto(produto) {
  const pc = produto?.taxas_valores?.parcelas_credito || {}
  const taxas = []
  for (let n = 1; n <= 12; n++) {
    const chave = n === 1 ? 'credito_a_vista' : `credito_${n}x`
    const valor = pc[chave]
    if (valor != null && valor !== '') {
      taxas.push({ parcelas: n, cc_taxa: Number(valor) })
    }
  }
  return taxas
}

/**
 * @param {{ url_taxas?: string }} provedor
 * @returns {Promise<Record<string, Array<{ parcelas: number, cc_taxa: number }>>>}
 */
export async function nubank(provedor) {
  const url = provedor?.url_taxas || URL_PADRAO
  const resp = await fetch(url, {
    headers: {
      'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
      'Accept-Language': 'pt-BR,pt;q=0.9',
      Accept: 'text/html,application/xhtml+xml',
    },
  })
  if (!resp.ok) throw new Error(`Nubank ${resp.status}`)

  const html = await resp.text()
  const json = extrairNextData(html)
  const produtos = json?.props?.pageProps?.data?.calculadora_infos?.produtos_nu_empresas_taxas
  if (!Array.isArray(produtos)) {
    throw new Error('produtos_nu_empresas_taxas não encontrado no __NEXT_DATA__')
  }

  const resultado = {}
  for (const produto of produtos) {
    const canal = MAPA_PRODUTO_CANAL[produto?.nome_do_produto]
    if (!canal) continue
    const taxas = creditosDoProduto(produto)
    if (taxas.length) resultado[canal] = taxas
  }
  return resultado
}
