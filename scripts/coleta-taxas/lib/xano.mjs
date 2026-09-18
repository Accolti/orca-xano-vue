// Cliente mínimo do Xano para a coleta de taxas (cron).
// Usa o token de serviço (env COLETA_SECRET), validado no Xano por `coleta_secret`.

const BASE_URL = process.env.XANO_BASE_URL || 'https://x8ki-letl-twmt.n7.xano.io'
const API_GROUP = process.env.XANO_API_GROUP || '-qqRIakp'
const SECRET = process.env.COLETA_SECRET || ''

function url(path) {
  return `${BASE_URL.replace(/\/$/, '')}/api:${API_GROUP}/${path}`
}

async function lerErro(resp) {
  try {
    const body = await resp.text()
    return body || resp.statusText
  } catch {
    return resp.statusText
  }
}

// Lista os provedores ativos que devem ser coletados automaticamente.
export async function listarProvedores() {
  const resp = await fetch(`${url('taxas_coleta_provedores')}?token=${encodeURIComponent(SECRET)}`)
  if (!resp.ok) throw new Error(`listarProvedores ${resp.status}: ${await lerErro(resp)}`)
  const body = await resp.json()
  return body?.provedores ?? []
}

// Importa as taxas coletadas (substitui apenas as de origem "scrape" no Xano).
export async function importarTaxas({ provedor_id, canal, taxas, sucesso, mensagem }) {
  const resp = await fetch(url('taxas_coleta_importar'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      token: SECRET,
      provedor_id,
      canal,
      taxas: taxas ?? [],
      sucesso: sucesso !== false,
      mensagem: mensagem ?? '',
    }),
  })
  if (!resp.ok) throw new Error(`importarTaxas ${resp.status}: ${await lerErro(resp)}`)
  return resp.json()
}
