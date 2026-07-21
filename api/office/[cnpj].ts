import type { VercelRequest, VercelResponse } from '@vercel/node'

export default async function handler(req: VercelRequest, res: VercelResponse) {
  const apiKey = process.env.VITE_CNPJ_JA

  if (!apiKey) {
    res.status(500).json({ error: 'VITE_CNPJ_JA não configurada' })
    return
  }

  const response = await fetch(`https://api.cnpja.com/office/${req.query.cnpj}`, {
    headers: { Accept: 'application/json', Authorization: apiKey },
  })

  const data = await response.json()
  res.status(response.status).json(data)
}
