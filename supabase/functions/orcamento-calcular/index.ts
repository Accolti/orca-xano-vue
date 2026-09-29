import { createClient } from 'npm:@supabase/supabase-js@2'
import { calcular } from './engine.ts'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const sb = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } })

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  // Preflight (OPTIONS) do navegador
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Método não permitido' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  }

  try {
    const body = await req.json()

    const input = {
      produto_id: Number(body.produto_id) || 0,
      borda_id: Number(body.borda_id) || 0,
      variacao_id: Number(body.variacao_id) || 0,
      markup: Number(body.markup) || 0,
      orca_id: Number(body.orca_id) || 0,
      item_id: Number(body.item_id) || 0,
      uf_destino: body.uf_destino || 'SP',
      regime_id: Number(body.regime_id) || 0,
      com_medida_exata: body.com_medida_exata === true,
      rampa_larg1: body.rampa_larg1 === true,
      rampa_comp1: body.rampa_comp1 === true,
      rampa_larg2: body.rampa_larg2 === true,
      rampa_comp2: body.rampa_comp2 === true,
      qtd_cantos: Number(body.qtd_cantos) || 0,
      comprimento_ou_area: Number(body.comprimento_ou_area) || 0,
      largura: Number(body.largura) || 0,
      quantidade: Number(body.quantidade) || 0,
      user_id: Number(body.user_id) || 0,
    }

    if (!input.produto_id || !input.user_id) {
      return new Response(JSON.stringify({ error: 'produto_id e user_id são obrigatórios' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      })
    }

    const resultado = await calcular(sb, input)
    return new Response(JSON.stringify(resultado), {
      status: 200,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message || 'Erro ao calcular' }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } },
    )
  }
})
