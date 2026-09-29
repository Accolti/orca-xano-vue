import { createClient } from 'npm:@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

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
    const userId = Number(body?.user_id) || 0
    const mesInicio = String(body?.mes_inicio || '').trim()
    const periodo = String(body?.periodo || 'todos').trim()

    if (!userId) return json({ error: 'user_id é obrigatório' }, 400)

    const [orcaRes, boletoRes] = await Promise.all([
      sb.from('orca').select('id,status,eh_pedido,created_at,vnd_tot').eq('user_id', userId),
      sb.from('boleto').select('id,vencimento,pagamento,valor').eq('user_id', userId),
    ])
    if (orcaRes.error) return json({ error: orcaRes.error.message }, 500)
    if (boletoRes.error) return json({ error: boletoRes.error.message }, 500)

    const orcamentos = orcaRes.data || []
    const parcelas = boletoRes.data || []

    const hoje = new Date()
    hoje.setHours(0, 0, 0, 0)
    const hojeMs = hoje.getTime()

    const rawMes = mesInicio || hoje.getFullYear() + '-' + String(hoje.getMonth() + 1).padStart(2, '0')
    const N = { mensal: 1, trimestral: 3, semestral: 6, anual: 12 }[periodo] || 0

    const parts = rawMes.split('-').map(Number)
    const baseAno = parts[0] || hoje.getFullYear()
    const baseMes = parts[1] || hoje.getMonth() + 1
    const base = new Date(baseAno, baseMes - 1, 1)

    let iniMs = -Infinity
    let fimMs = Infinity
    if (N > 0) {
      iniMs = base.getTime()
      fimMs = new Date(baseAno, baseMes - 1 + N, 1).getTime()
    }

    const ehPedido = (o: any) =>
      o.eh_pedido === true || o.eh_pedido === 'true' || o.eh_pedido === 1 || o.eh_pedido === '1'

    let orcamentosCount = 0
    let pedidos = 0
    const funil: Record<string, number> = {
      RASCUNHO: 0,
      ENVIADO: 0,
      AGUARDANDO_RETORNO: 0,
      APROVADO: 0,
      RECUSADO: 0,
      CANCELADO: 0,
    }

    orcamentos.forEach((o: any) => {
      const ts = new Date(o.created_at).getTime()
      if (isNaN(ts) || ts < iniMs || ts >= fimMs) return
      if (ehPedido(o)) pedidos++
      else {
        orcamentosCount++
        const s = o.status || 'RASCUNHO'
        funil[s] = (funil[s] || 0) + 1
      }
    })

    let boletosVencidos = 0
    let boletosAVencer = 0
    let boletosPagos = 0

    parcelas.forEach((b: any) => {
      const vencStr = b.vencimento ? String(b.vencimento).slice(0, 10) : null
      const venc = vencStr ? new Date(vencStr + 'T00:00:00') : null
      const vencMs = venc && !isNaN(venc.getTime()) ? venc.getTime() : null
      const pago = Boolean(b.pagamento)

      if (pago) {
        if (vencMs !== null && vencMs < fimMs) boletosPagos++
      } else {
        if (vencMs !== null && vencMs < hojeMs) boletosVencidos++
        else if (vencMs !== null && vencMs >= hojeMs && vencMs < fimMs) boletosAVencer++
      }
    })

    const chaveMes = (d: any) => {
      const dt = new Date(d)
      if (isNaN(dt.getTime())) return null
      return dt.getFullYear() + '-' + String(dt.getMonth() + 1).padStart(2, '0')
    }
    const cmpMes = (a: any, b: any) => (a.y !== b.y ? a.y - b.y : a.m - b.m)

    const mesesMap: Record<string, boolean> = {}
    orcamentos.forEach((o: any) => {
      if (o.created_at) mesesMap[chaveMes(o.created_at)!] = true
    })
    parcelas.forEach((b: any) => {
      if (b.vencimento) mesesMap[chaveMes(b.vencimento)!] = true
      if (b.pagamento) mesesMap[chaveMes(b.pagamento)!] = true
    })

    const hojeMes = { y: hoje.getFullYear(), m: hoje.getMonth() }
    let ini: any, fim: any
    if (N > 0) {
      ini = { y: baseAno, m: baseMes - 1 }
      fim = { y: baseAno, m: baseMes - 1 + N - 1 }
    } else {
      const lista = Object.keys(mesesMap).map((k) => {
        const p = k.split('-').map(Number)
        return { y: p[0], m: p[1] - 1 }
      })
      if (!lista.length) {
        ini = hojeMes
        fim = hojeMes
      } else {
        ini = lista.reduce((a, b) => (cmpMes(a, b) <= 0 ? a : b))
        fim = lista.reduce((a, b) => (cmpMes(a, b) >= 0 ? a : b))
        if (cmpMes(hojeMes, fim) > 0) fim = hojeMes
      }
    }

    const serie: any[] = []
    let y = ini.y
    let m = ini.m
    while (cmpMes({ y, m }, fim) <= 0) {
      const st = new Date(y, m, 1).getTime()
      const en = new Date(y, m + 1, 1).getTime()
      let vendas = 0
      let recebido = 0
      let areceber = 0

      orcamentos.forEach((o: any) => {
        if (!ehPedido(o)) return
        const ts = new Date(o.created_at).getTime()
        if (isNaN(ts) || ts < st || ts >= en) return
        vendas += Number(o.vnd_tot) || 0
      })

      parcelas.forEach((b: any) => {
        const pago = Boolean(b.pagamento)
        const val = Number(b.valor) || 0
        if (pago) {
          const pg = b.pagamento ? new Date(b.pagamento) : null
          const pgt = pg && !isNaN(pg.getTime()) ? pg.getTime() : null
          if (pgt !== null && pgt >= st && pgt < en) recebido += val
        } else {
          const vencStr = b.vencimento ? String(b.vencimento).slice(0, 10) : null
          const venc = vencStr ? new Date(vencStr + 'T00:00:00') : null
          const vt = venc && !isNaN(venc.getTime()) ? venc.getTime() : null
          if (vt !== null && vt >= st && vt < en) areceber += val
        }
      })

      serie.push({
        mes: y + '-' + String(m + 1).padStart(2, '0'),
        vendas: Number(vendas.toFixed(2)),
        recebido: Number(recebido.toFixed(2)),
        areceber: Number(areceber.toFixed(2)),
      })
      m += 1
      if (m > 11) {
        m = 0
        y += 1
      }
    }

    return json({
      orcamentos: orcamentosCount,
      pedidos,
      boletosVencidos,
      boletosAVencer,
      boletosPagos,
      funil,
      serie,
    })
  } catch (err) {
    return json({ error: (err as Error).message || 'Erro ao gerar dashboard' }, 500)
  }
})
