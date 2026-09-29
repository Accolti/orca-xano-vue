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

    const [orcaRes, clienteRes, ctrlRes, boletoRes] = await Promise.all([
      sb
        .from('orca')
        .select(
          'id,cod_orca,cliente_id,eh_pedido,status,created_at,vnd_tot,luc_tot,frt_b2b,valor_difal_tot,vlr_credito_icms_tot,vlr_st_tot',
        )
        .eq('user_id', userId),
      sb.from('cliente').select('id,razao_social,nome_fantasia').eq('user_id', userId),
      sb
        .from('controle_pedido')
        .select('orca_id,desconto_kapazi_perc,frete_b2b_real')
        .eq('user_id', userId),
      sb
        .from('boleto')
        .select('orca_id,vencimento,pagamento,valor,forma_pagamento_id')
        .eq('user_id', userId),
    ])
    if (orcaRes.error) return json({ error: orcaRes.error.message }, 500)
    if (clienteRes.error) return json({ error: clienteRes.error.message }, 500)
    if (ctrlRes.error) return json({ error: ctrlRes.error.message }, 500)
    if (boletoRes.error) return json({ error: boletoRes.error.message }, 500)

    const orcas = orcaRes.data || []
    const clientes = clienteRes.data || []
    const controles = ctrlRes.data || []
    const boletos = boletoRes.data || []

    const orcaIds = orcas.map((o: any) => o.id)
    let itens: any[] = []
    let logsDesc: any[] = []
    let logsStatus: any[] = []
    if (orcaIds.length) {
      const [itemRes, logRes, statusRes] = await Promise.all([
        sb.from('item').select('orca_id,qtd,vlr_cst_nota_unit').in('orca_id', orcaIds),
        sb
          .from('desconto_kapazi_log')
          .select('orca_id,desconto_anterior,desconto_novo,created_at')
          .in('orca_id', orcaIds)
          .order('created_at', { ascending: true }),
        sb.from('orca_status_log').select('orca_id,status,status_anterior,created_at').in('orca_id', orcaIds),
      ])
      if (itemRes.error) return json({ error: itemRes.error.message }, 500)
      if (logRes.error) return json({ error: logRes.error.message }, 500)
      if (statusRes.error) return json({ error: statusRes.error.message }, 500)
      itens = itemRes.data || []
      logsDesc = logRes.data || []
      logsStatus = statusRes.data || []
    }

    const clienteNome: Record<number, string> = {}
    const clienteFantasia: Record<number, string> = {}
    clientes.forEach((c: any) => {
      clienteNome[c.id] = c.razao_social || ''
      clienteFantasia[c.id] = c.nome_fantasia || ''
    })

    const hoje = new Date()
    hoje.setHours(0, 0, 0, 0)

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

    const inWin = (ts: number) => !isNaN(ts) && ts >= iniMs && ts < fimMs
    const ehPedido = (o: any) =>
      o.eh_pedido === true || o.eh_pedido === 'true' || o.eh_pedido === 1 || o.eh_pedido === '1'

    // índices
    const somaItens: Record<number, number> = {}
    itens.forEach((i: any) => {
      const v = (Number(i.vlr_cst_nota_unit) || 0) * (Number(i.qtd) || 1)
      somaItens[i.orca_id] = (somaItens[i.orca_id] || 0) + v
    })
    const ctrl: Record<number, any> = {}
    controles.forEach((c: any) => {
      ctrl[c.orca_id] = c
    })
    const descPorOrca: Record<number, any> = {}
    logsDesc.forEach((l: any) => {
      descPorOrca[l.orca_id] = l
    })
    const orcaById: Record<number, any> = {}
    orcas.forEach((o: any) => {
      orcaById[o.id] = o
    })

    // Financeiro
    const pedidos = orcas.filter((o: any) => ehPedido(o) && inWin(new Date(o.created_at).getTime()))
    const financeiroLinhas = pedidos.map((o: any) => {
      const custoKapazi = somaItens[o.id] || 0
      const perc = Number(
        (descPorOrca[o.id] && descPorOrca[o.id].desconto_novo != null
          ? descPorOrca[o.id].desconto_novo
          : ctrl[o.id] && ctrl[o.id].desconto_kapazi_perc) || 0,
      )
      const descontoKapazi = custoKapazi * (perc / 100)
      const frtB2B = Number(o.frt_b2b) || 0
      const freteRealRaw =
        ctrl[o.id] && ctrl[o.id].frete_b2b_real != null ? Number(ctrl[o.id].frete_b2b_real) : 0
      const freteEfetivo = freteRealRaw > 0 ? freteRealRaw : frtB2B
      const lucT = Number(o.luc_tot) || 0
      const vnd = Number(o.vnd_tot) || 0
      const stTot = Number(o.vlr_st_tot) || 0
      const difal = Number(o.valor_difal_tot) || 0
      const credito = Number(o.vlr_credito_icms_tot) || 0
      const difalEfetivo = credito > 0 ? 0 : difal
      const impostos = stTot + difalEfetivo - credito
      const lucroReal = lucT + descontoKapazi + (frtB2B - freteEfetivo)
      const margemReal = vnd > 0 ? (lucroReal / vnd) * 100 : 0
      const created = o.created_at ? new Date(o.created_at) : null
      return {
        orca_id: o.id,
        cod_orca: o.cod_orca || '#' + o.id,
        cliente: clienteFantasia[o.cliente_id] || clienteNome[o.cliente_id] || '',
        data: created && !isNaN(created.getTime()) ? created.toISOString().slice(0, 10) : '',
        custo_kapazi: Number(custoKapazi.toFixed(2)),
        perc_desconto: perc,
        desconto_kapazi: Number(descontoKapazi.toFixed(2)),
        frete_efetivo: Number(freteEfetivo.toFixed(2)),
        impostos: Number(impostos.toFixed(2)),
        venda: Number(vnd.toFixed(2)),
        lucro_real: Number(lucroReal.toFixed(2)),
        margem_real: Number(margemReal.toFixed(2)),
      }
    })
    const fin: any = {
      custo_kapazi: 0,
      desconto_kapazi: 0,
      frete_efetivo: 0,
      impostos: 0,
      venda: 0,
      lucro_real: 0,
    }
    financeiroLinhas.forEach((r: any) => {
      fin.custo_kapazi += r.custo_kapazi
      fin.desconto_kapazi += r.desconto_kapazi
      fin.frete_efetivo += r.frete_efetivo
      fin.impostos += r.impostos
      fin.venda += r.venda
      fin.lucro_real += r.lucro_real
    })
    Object.keys(fin).forEach((k) => {
      fin[k] = Number(fin[k].toFixed(2))
    })
    fin.margem_real = fin.venda > 0 ? Number(((fin.lucro_real / fin.venda) * 100).toFixed(2)) : 0

    // Recebidos
    const recebidosLinhas: any[] = []
    boletos.forEach((b: any) => {
      const pg = b.pagamento ? new Date(b.pagamento) : null
      if (!pg || isNaN(pg.getTime())) return
      if (!inWin(pg.getTime())) return
      const orca = orcaById[b.orca_id]
      recebidosLinhas.push({
        id: b.id,
        orca_id: b.orca_id,
        cod_orca: orca && orca.cod_orca ? orca.cod_orca : '#' + (b.orca_id || 0),
        vencimento: b.vencimento ? String(b.vencimento).slice(0, 10) : '',
        data_pagamento: pg.toISOString().slice(0, 10),
        valor: Number((Number(b.valor) || 0).toFixed(2)),
        forma_pagamento_id: b.forma_pagamento_id,
      })
    })
    recebidosLinhas.sort((a, b2) =>
      a.data_pagamento < b2.data_pagamento ? -1 : a.data_pagamento > b2.data_pagamento ? 1 : 0,
    )
    const totalRecebidos = Number(recebidosLinhas.reduce((s, r) => s + r.valor, 0).toFixed(2))

    // Parcelas por orçamento
    const parcelasPorOrca: Record<number, any[]> = {}
    boletos.forEach((b: any) => {
      if (!b.orca_id) return
      ;(parcelasPorOrca[b.orca_id] = parcelasPorOrca[b.orca_id] || []).push(b)
    })
    const pago = (b: any) => b.pagamento != null && String(b.pagamento).trim() !== ''
    const parcelasLinhas: any[] = []
    orcas.forEach((o: any) => {
      if (!inWin(new Date(o.created_at).getTime())) return
      const arr = parcelasPorOrca[o.id]
      if (!arr || !arr.length) return
      const total = arr.length
      const pagas = arr.filter(pago).length
      const valorTotal = arr.reduce((s, b) => s + (Number(b.valor) || 0), 0)
      const valorPago = arr.filter(pago).reduce((s, b) => s + (Number(b.valor) || 0), 0)
      parcelasLinhas.push({
        orca_id: o.id,
        cod_orca: o.cod_orca || '#' + o.id,
        cliente: clienteFantasia[o.cliente_id] || clienteNome[o.cliente_id] || '',
        venda: Number((Number(o.vnd_tot) || 0).toFixed(2)),
        total_parcelas: total,
        pagas,
        valor_total: Number(valorTotal.toFixed(2)),
        valor_pago: Number(valorPago.toFixed(2)),
        a_receber: Number(Math.max(0, valorTotal - valorPago).toFixed(2)),
      })
    })
    const parcelasTot: any = {
      valor_total: 0,
      valor_pago: 0,
      a_receber: 0,
      total_parcelas: 0,
      pagas: 0,
    }
    parcelasLinhas.forEach((r: any) => {
      parcelasTot.valor_total += r.valor_total
      parcelasTot.valor_pago += r.valor_pago
      parcelasTot.a_receber += r.a_receber
      parcelasTot.total_parcelas += r.total_parcelas
      parcelasTot.pagas += r.pagas
    })
    parcelasTot.valor_total = Number(parcelasTot.valor_total.toFixed(2))
    parcelasTot.valor_pago = Number(parcelasTot.valor_pago.toFixed(2))
    parcelasTot.a_receber = Number(parcelasTot.a_receber.toFixed(2))

    // Funil
    const transMap: Record<string, number> = {}
    const aprovOrcas = new Set<number>()
    logsStatus.forEach((l: any) => {
      const ts = new Date(l.created_at).getTime()
      if (!inWin(ts)) return
      if (!l.status) return
      const de = l.status_anterior || '(início)'
      const chave = de + '|' + l.status
      transMap[chave] = (transMap[chave] || 0) + 1
      if (l.status === 'APROVADO') aprovOrcas.add(l.orca_id)
    })
    const transicoes = Object.keys(transMap)
      .map((k) => {
        const p = k.split('|')
        return { de: p[0], para: p[1], qtde: transMap[k] }
      })
      .sort((a, b2) => b2.qtde - a.qtde)

    const diasAprov: number[] = []
    const aprovadosPorOrca: Record<number, number> = {}
    logsStatus.forEach((l: any) => {
      if (l.status !== 'APROVADO') return
      const ts = new Date(l.created_at).getTime()
      if (isNaN(ts)) return
      if (!aprovadosPorOrca[l.orca_id] || ts < aprovadosPorOrca[l.orca_id])
        aprovadosPorOrca[l.orca_id] = ts
    })
    Object.keys(aprovadosPorOrca).forEach((id: any) => {
      const o = orcaById[id]
      if (!o) return
      const cri = new Date(o.created_at).getTime()
      if (isNaN(cri)) return
      const dias = (aprovadosPorOrca[id] - cri) / 86400000
      if (dias >= 0) diasAprov.push(dias)
    })
    const mediaDiasAprov = diasAprov.length
      ? Number((diasAprov.reduce((s, d) => s + d, 0) / diasAprov.length).toFixed(1))
      : 0

    const orcamentosJanela = orcas.filter(
      (o: any) => !ehPedido(o) && inWin(new Date(o.created_at).getTime()),
    )
    const conversao = orcamentosJanela.length
      ? Number(((aprovOrcas.size / orcamentosJanela.length) * 100).toFixed(1))
      : 0

    return json({
      financeiro: { pedidos: financeiroLinhas, totais: fin },
      recebidos: { linhas: recebidosLinhas, totais: { total: totalRecebidos, qtde: recebidosLinhas.length } },
      parcelas: { linhas: parcelasLinhas, totais: parcelasTot },
      funil: {
        transicoes,
        aprovacoes: aprovOrcas.size,
        media_dias_aprovacao: mediaDiasAprov,
        orcamentos_janela: orcamentosJanela.length,
        conversao,
      },
    })
  } catch (err) {
    return json({ error: (err as Error).message || 'Erro ao gerar relatório' }, 500)
  }
})
