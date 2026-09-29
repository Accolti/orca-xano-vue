// Cria um vendedor/vendedor_master da equipe + a identidade Supabase Auth (convite).
// Requer o service_role (SUPABASE_SERVICE_ROLE_KEY) — nunca expor no front.
//
// Deploy:
//   supabase functions deploy equipe-criar --project-ref dptyqjyueclscsryyrmv

import { createClient } from 'npm:@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const appUrl = Deno.env.get('APP_URL') || 'http://localhost:5173/login'

const sb = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } })

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
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const body = await req.json()
    const callerId = Number(body?.user_id) || 0
    const nameFirst = String(body?.name_first ?? '').trim()
    const nameLast = String(body?.name_last ?? '').trim()
    const email = String(body?.email ?? '').trim().toLowerCase()
    const percentual = body?.percentual_comissao != null ? Number(body.percentual_comissao) : null
    const roleReq = body?.role === 'vendedor_master' ? 'vendedor_master' : 'vendedor'

    if (!callerId) return json({ error: 'user_id é obrigatório' }, 400)
    if (!nameFirst || !email) return json({ error: 'Informe nome e e-mail.' }, 400)

    // valida o chamador (admin/admin_geral/vendedor_master)
    const { data: caller } = await sb.from('usuarios').select('id,role').eq('id', callerId).single()
    if (!caller) return json({ error: 'Usuário não encontrado.' }, 400)
    if (!['admin', 'admin_geral', 'vendedor_master'].includes(caller.role)) {
      return json({ error: 'Apenas administradores ou vendedores master podem criar vendedores.' }, 403)
    }

    // vendedor_master só cria 'vendedor'
    if (caller.role === 'vendedor_master' && roleReq === 'vendedor_master') {
      return json({ error: 'Apenas administradores podem criar um Vendedor Master.' }, 403)
    }

    // serviço de comissões (plano). admin_geral sempre passa.
    if (caller.role !== 'admin_geral') {
      const { data: tem } = await sb.rpc('f_tem_comissoes', { p_user_id: callerId })
      if (!tem) return json({ error: 'Sem acesso a esta funcionalidade.' }, 403)
    }

    // e-mail já existe em usuarios?
    const { data: existente } = await sb
      .from('usuarios')
      .select('id')
      .ilike('email', email)
      .maybeSingle()
    if (existente) return json({ error: 'Já existe um usuário com esse e-mail.' }, 400)

    // 1. cria a linha em usuarios
    const { data: novo, error: insErr } = await sb
      .from('usuarios')
      .insert({
        created_at: new Date().toISOString(),
        name: [nameFirst, nameLast].filter(Boolean).join(' '),
        name_first: nameFirst,
        name_last: nameLast,
        email,
        role: roleReq,
        vendedor_pai_id: callerId,
        percentual_comissao: percentual,
        ativo: true,
      })
      .select()
      .single()
    if (insErr) return json({ error: insErr.message }, 500)

    // 2. cria a identidade auth + envia convite (o trigger liga auth_id por e-mail)
    const { error: inviteErr } = await sb.auth.admin.inviteUserByEmail(email, {
      redirectTo: appUrl,
    })
    if (inviteErr) {
      // limpa a linha órfã
      await sb.from('usuarios').delete().eq('id', novo.id)
      return json({ error: inviteErr.message }, 400)
    }

    return json({
      id: novo.id,
      name_first: novo.name_first,
      name_last: novo.name_last,
      email: novo.email,
      role: novo.role,
      percentual_comissao: novo.percentual_comissao,
    })
  } catch (err) {
    return json({ error: (err as Error).message || 'Erro ao criar vendedor' }, 500)
  }
})
