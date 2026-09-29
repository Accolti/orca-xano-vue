// Captura dados de CNPJ/IE da api.cnpja.com (mesma fonte do Xano f_get_CNPJ).
// Requer o segredo CNPJ_JA (Authorization da api.cnpja.com).
//
// Deploy:
//   supabase secrets set CNPJ_JA=<token>
//   supabase functions deploy capturar-cnpj --project-ref dptyqjyueclscsryyrmv

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return json({ error: 'Método não permitido' }, 405)
  }

  try {
    const token = Deno.env.get('CNPJ_JA')
    if (!token) {
      return json({ error: 'Segredo CNPJ_JA não configurado.' }, 500)
    }

    const body = await req.json()
    const cnpjLimpo = String(body?.cnpj ?? '').replace(/\D/g, '')
    if (cnpjLimpo.length !== 14) {
      return json({ error: 'CNPJ inválido.' }, 400)
    }

    const headers = { Accept: 'application/json', Authorization: token }

    const [officeRes, ieRes] = await Promise.all([
      fetch(`https://api.cnpja.com/office/${cnpjLimpo}`, { headers }),
      fetch(`https://api.cnpja.com/ccc?states=SP&taxId=${cnpjLimpo}`, { headers }),
    ])

    const statusCNPJ = officeRes.status
    const statusIE = ieRes.status

    const cnpjData = officeRes.ok ? await officeRes.json() : null
    const ieData = ieRes.ok ? await ieRes.json() : null

    if (statusCNPJ !== 200 || !cnpjData) {
      return json({
        statusCNPJ,
        errorCNPJ: {
          code: statusCNPJ || 400,
          message: 'CNPJ não encontrado ou inválido.',
          constraints: ['taxId must be a string that obeys cnpj verification algorithm'],
        },
      })
    }

    if (statusIE !== 200) {
      return json({
        statusIE,
        errorIE: {
          code: statusIE || 400,
          message: 'Inscrição estadual inválida ou não encontrada.',
          constraints: ['state registration invalid or not found'],
        },
      })
    }

    const endereco = cnpjData.address
      ? {
          rua: cnpjData.address.street || null,
          numero: cnpjData.address.number || null,
          complemento: cnpjData.address.details || null,
          bairro: cnpjData.address.district || null,
          cidade: cnpjData.address.city || null,
          estado: cnpjData.address.state || null,
          cep: cnpjData.address.zip || null,
          pais: cnpjData.address.country?.name || null,
        }
      : null

    const telefones = cnpjData.phones?.length
      ? cnpjData.phones.map((t: any) => ({
          tipo: t.type || null,
          ddd: t.area || null,
          numero: t.number || null,
        }))
      : []

    const emails = cnpjData.emails?.length ? cnpjData.emails.map((e: any) => e.address) : []

    const ieAtiva = ieData?.registrations?.find((r: any) => r.enabled === true) || null

    return json({
      statusCNPJ,
      statusIE,
      cnpj: cnpjData.taxId || null,
      razaoSocial: cnpjData.company?.name || null,
      nomeFantasia: cnpjData.alias || null,
      enderecoCompleto: endereco,
      telefones,
      emails,
      IE: ieAtiva ? ieAtiva.number : null,
      estadoOrigem: ieData?.originState || null,
    })
  } catch (err) {
    return json({ error: (err as Error).message || 'Erro ao capturar CNPJ' }, 500)
  }
})
