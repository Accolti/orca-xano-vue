// Relatório consolidado por período (auth User). Substitui o f_relatorio_recebidos
// legado (que join-ava a tabela Pedido). Params opcionais: mes_inicio (YYYY-MM,
// default = mês corrente) e periodo (todos|mensal|trimestral|semestral|anual).
// Janela igual ao dashboard: periodo != todos → [1º do mês, +N meses); todos → sem limite.
// Retorna:
//  financeiro: pedidos convertidos (eh_pedido) por created_at — custo_kapazi,
//              desconto_kapazi (perc do Desconto_Kapazi_Log mais recente, senão
//              ControlePedido.desconto_kapazi_perc), frete_efetivo
//              (ControlePedido.freteB2BReal > 0 senão Orca.frtB2B),
//              lucro_real = luc_tot + desconto_kapazi + (frtB2B − frete_efetivo),
//              margem_real = lucro_real / vnd_tot × 100 — + totais.
//  recebidos: parcelas pagas na janela (mês do pagamento) — + totais.
//  funil: transições de Orca_Status_Log na janela + tempo médio até APROVADO + conversão.
query relatorio verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    text mes_inicio?
    text periodo?
  }

  stack {
    db.query Orca {
      join = {
        Cliente: {
          table: "Cliente"
          type : "left"
          where: $db.Orca.cliente_id ==? $db.Cliente.id
        }
      }
    
      where = $db.Orca.user_id == $auth.id
      eval = {
        cliente_nome    : $db.Cliente.razao_social
        cliente_fantasia: $db.Cliente.nome_fantasia
      }
    
      return = {type: "list"}
      output = [
        "id"
        "cod_orca"
        "cliente_id"
        "eh_pedido"
        "status"
        "created_at"
        "vnd_tot"
        "luc_tot"
        "frtB2B"
        "valor_difal_tot"
        "vlr_credito_icms_tot"
        "vlr_st_tot"
        "cliente_nome"
        "cliente_fantasia"
      ]
    } as $orcamentos
  
    db.query item {
      join = {
        Orca: {
          table: "Orca"
          where: $db.item.orca_id == $db.Orca.id && $db.Orca.user_id == $auth.id
        }
      }
    
      return = {type: "list"}
      output = ["orca_id", "qtd", "vlr_cst_nota_unit"]
    } as $itens
  
    db.query ControlePedido {
      where = $db.ControlePedido.user_id == $auth.id
      return = {type: "list"}
      output = ["orca_id", "desconto_kapazi_perc", "freteB2BReal"]
    } as $controles
  
    db.query Desconto_Kapazi_Log {
      join = {
        Orca: {
          table: "Orca"
          where: $db.Desconto_Kapazi_Log.orca_id == $db.Orca.id && $db.Orca.user_id == $auth.id
        }
      }
    
      sort = {created_at: "asc"}
      return = {type: "list"}
      output = ["orca_id", "desconto_anterior", "desconto_novo", "created_at"]
    } as $logs_desc
  
    db.query Boleto {
      where = $db.Boleto.user_id == $auth.id
      return = {type: "list"}
      output = [
        "orca_id"
        "vencimento"
        "pagamento"
        "valor"
        "forma_pagamento_id"
      ]
    } as $boletos
  
    db.query Orca_Status_Log {
      join = {
        Orca: {
          table: "Orca"
          where: $db.Orca_Status_Log.orca_id == $db.Orca.id && $db.Orca.user_id == $auth.id
        }
      }
    
      return = {type: "list"}
      output = ["orca_id", "status", "status_anterior", "created_at"]
    } as $logs_status
  
    var $mesInicio {
      value = $input.mes_inicio
    }
  
    var $periodo {
      value = $input.periodo
    }
  
    api.lambda {
      code = """
        const hoje = new Date();
        hoje.setHours(0, 0, 0, 0);
        
        const rawMes = String($var.mesInicio || '').trim();
        const mes = rawMes || (hoje.getFullYear() + '-' + String(hoje.getMonth() + 1).padStart(2, '0'));
        const periodo = String($var.periodo || 'todos').trim();
        const N = { mensal: 1, trimestral: 3, semestral: 6, anual: 12 }[periodo] || 0;
        
        const parts = mes.split('-').map(Number);
        const baseAno = parts[0] || hoje.getFullYear();
        const baseMes = parts[1] || hoje.getMonth() + 1;
        const base = new Date(baseAno, baseMes - 1, 1);
        
        let iniMs = -Infinity;
        let fimMs = Infinity;
        if (N > 0) {
          iniMs = base.getTime();
          fimMs = new Date(baseAno, baseMes - 1 + N, 1).getTime();
        }
        
        const inWin = (ts) => !isNaN(ts) && ts >= iniMs && ts < fimMs;
        const ehPedido = (o) => o.eh_pedido === true || o.eh_pedido === 'true' || o.eh_pedido === 1 || o.eh_pedido === '1';
        
        const orcas = $var.orcamentos || [];
        const itens = $var.itens || [];
        const controles = $var.controles || [];
        const logsDesc = $var.logs_desc || [];
        const boletos = $var.boletos || [];
        const logsStatus = $var.logs_status || [];
        
        // Índices
        const somaItens = {};
        itens.forEach((i) => {
          const v = (Number(i.vlr_cst_nota_unit) || 0) * (Number(i.qtd) || 1);
          somaItens[i.orca_id] = (somaItens[i.orca_id] || 0) + v;
        });
        const ctrl = {};
        controles.forEach((c) => { ctrl[c.orca_id] = c; });
        const descPorOrca = {};
        logsDesc.forEach((l) => { descPorOrca[l.orca_id] = l; });
        const orcaById = {};
        orcas.forEach((o) => { orcaById[o.id] = o; });
        
        // ---------- Financeiro (pedidos convertidos, por created_at) ----------
        const pedidos = orcas.filter((o) => ehPedido(o) && inWin(new Date(o.created_at).getTime()));
        const financeiroLinhas = pedidos.map((o) => {
          const custoKapazi = somaItens[o.id] || 0;
          const perc = Number((descPorOrca[o.id] && descPorOrca[o.id].desconto_novo != null ? descPorOrca[o.id].desconto_novo : (ctrl[o.id] && ctrl[o.id].desconto_kapazi_perc)) || 0);
          const descontoKapazi = custoKapazi * (perc / 100);
          const frtB2B = Number(o.frtB2B) || 0;
          const freteRealRaw = (ctrl[o.id] && ctrl[o.id].freteB2BReal != null) ? Number(ctrl[o.id].freteB2BReal) : 0;
          const freteEfetivo = freteRealRaw > 0 ? freteRealRaw : frtB2B;
          const lucT = Number(o.luc_tot) || 0;
          const vnd = Number(o.vnd_tot) || 0;
          const stTot = Number(o.vlr_st_tot) || 0;
          const difal = Number(o.valor_difal_tot) || 0;
          const credito = Number(o.vlr_credito_icms_tot) || 0;
          // DIFAL só compõe o custo em MEI/Simples (sem crédito); Lucro Real/Presumido abate crédito.
          const difalEfetivo = credito > 0 ? 0 : difal;
          const impostos = stTot + difalEfetivo - credito;
          const lucroReal = lucT + descontoKapazi + (frtB2B - freteEfetivo);
          const margemReal = vnd > 0 ? (lucroReal / vnd) * 100 : 0;
          const created = o.created_at ? new Date(o.created_at) : null;
          return {
            orca_id: o.id,
            cod_orca: o.cod_orca || ('#' + o.id),
            cliente: o.cliente_fantasia || o.cliente_nome || '',
            data: created && !isNaN(created.getTime()) ? created.toISOString().slice(0, 10) : '',
            custo_kapazi: Number(custoKapazi.toFixed(2)),
            perc_desconto: perc,
            desconto_kapazi: Number(descontoKapazi.toFixed(2)),
            frete_efetivo: Number(freteEfetivo.toFixed(2)),
            impostos: Number(impostos.toFixed(2)),
            venda: Number(vnd.toFixed(2)),
            lucro_real: Number(lucroReal.toFixed(2)),
            margem_real: Number(margemReal.toFixed(2))
          };
        });
        const fin = {
          custo_kapazi: 0,
          desconto_kapazi: 0,
          frete_efetivo: 0,
          impostos: 0,
          venda: 0,
          lucro_real: 0
        };
        financeiroLinhas.forEach((r) => {
          fin.custo_kapazi += r.custo_kapazi;
          fin.desconto_kapazi += r.desconto_kapazi;
          fin.frete_efetivo += r.frete_efetivo;
          fin.impostos += r.impostos;
          fin.venda += r.venda;
          fin.lucro_real += r.lucro_real;
        });
        Object.keys(fin).forEach((k) => { fin[k] = Number(fin[k].toFixed(2)); });
        fin.margem_real = fin.venda > 0 ? Number(((fin.lucro_real / fin.venda) * 100).toFixed(2)) : 0;
        
        // ---------- Recebidos (pagos, pelo mês do pagamento) ----------
        const recebidosLinhas = [];
        boletos.forEach((b) => {
          const pg = b.pagamento ? new Date(b.pagamento) : null;
          if (!pg || isNaN(pg.getTime())) return;
          if (!inWin(pg.getTime())) return;
          const orca = orcaById[b.orca_id];
          recebidosLinhas.push({
            id: b.id,
            orca_id: b.orca_id,
            cod_orca: orca && orca.cod_orca ? orca.cod_orca : ('#' + (b.orca_id || 0)),
            vencimento: b.vencimento ? String(b.vencimento).slice(0, 10) : '',
            data_pagamento: pg.toISOString().slice(0, 10),
            valor: Number((Number(b.valor) || 0).toFixed(2)),
            forma_pagamento_id: b.forma_pagamento_id
          });
        });
        recebidosLinhas.sort((a, b2) => (a.data_pagamento < b2.data_pagamento ? -1 : a.data_pagamento > b2.data_pagamento ? 1 : 0));
        const totalRecebidos = Number(recebidosLinhas.reduce((s, r) => s + r.valor, 0).toFixed(2));
        
        // ---------- Parcelas por orçamento (reconciliação venda x recebido) ----------
        const parcelasPorOrca = {};
        boletos.forEach((b) => {
          if (!b.orca_id) return;
          (parcelasPorOrca[b.orca_id] = parcelasPorOrca[b.orca_id] || []).push(b);
        });
        const pago = (b) => b.pagamento != null && String(b.pagamento).trim() !== '';
        const parcelasLinhas = [];
        orcas.forEach((o) => {
          if (!inWin(new Date(o.created_at).getTime())) return;
          const arr = parcelasPorOrca[o.id];
          if (!arr || !arr.length) return;
          const total = arr.length;
          const pagas = arr.filter(pago).length;
          const valorTotal = arr.reduce((s, b) => s + (Number(b.valor) || 0), 0);
          const valorPago = arr.filter(pago).reduce((s, b) => s + (Number(b.valor) || 0), 0);
          parcelasLinhas.push({
            orca_id: o.id,
            cod_orca: o.cod_orca || ('#' + o.id),
            cliente: o.cliente_fantasia || o.cliente_nome || '',
            venda: Number((Number(o.vnd_tot) || 0).toFixed(2)),
            total_parcelas: total,
            pagas,
            valor_total: Number(valorTotal.toFixed(2)),
            valor_pago: Number(valorPago.toFixed(2)),
            a_receber: Number(Math.max(0, valorTotal - valorPago).toFixed(2))
          });
        });
        const parcelasTot = {
          valor_total: 0,
          valor_pago: 0,
          a_receber: 0,
          total_parcelas: 0,
          pagas: 0
        };
        parcelasLinhas.forEach((r) => {
          parcelasTot.valor_total += r.valor_total;
          parcelasTot.valor_pago += r.valor_pago;
          parcelasTot.a_receber += r.a_receber;
          parcelasTot.total_parcelas += r.total_parcelas;
          parcelasTot.pagas += r.pagas;
        });
        parcelasTot.valor_total = Number(parcelasTot.valor_total.toFixed(2));
        parcelasTot.valor_pago = Number(parcelasTot.valor_pago.toFixed(2));
        parcelasTot.a_receber = Number(parcelasTot.a_receber.toFixed(2));
        
        // ---------- Funil (Orca_Status_Log na janela) ----------
        const transMap = {};
        const aprovOrcas = new Set();
        logsStatus.forEach((l) => {
          const ts = new Date(l.created_at).getTime();
          if (!inWin(ts)) return;
          if (!l.status) return;
          const de = l.status_anterior || '(início)';
          const chave = de + '|' + l.status;
          transMap[chave] = (transMap[chave] || 0) + 1;
          if (l.status === 'APROVADO') aprovOrcas.add(l.orca_id);
        });
        const transicoes = Object.keys(transMap).map((k) => {
          const p = k.split('|');
          return { de: p[0], para: p[1], qtde: transMap[k] };
        }).sort((a, b2) => b2.qtde - a.qtde);
        
        const diasAprov = [];
        const aprovadosPorOrca = {};
        logsStatus.forEach((l) => {
          if (l.status !== 'APROVADO') return;
          const ts = new Date(l.created_at).getTime();
          if (isNaN(ts)) return;
          if (!aprovadosPorOrca[l.orca_id] || ts < aprovadosPorOrca[l.orca_id]) aprovadosPorOrca[l.orca_id] = ts;
        });
        Object.keys(aprovadosPorOrca).forEach((id) => {
          const o = orcaById[id];
          if (!o) return;
          const cri = new Date(o.created_at).getTime();
          if (isNaN(cri)) return;
          const dias = (aprovadosPorOrca[id] - cri) / 86400000;
          if (dias >= 0) diasAprov.push(dias);
        });
        const mediaDiasAprov = diasAprov.length
          ? Number((diasAprov.reduce((s, d) => s + d, 0) / diasAprov.length).toFixed(1))
          : 0;
        
        const orcamentosJanela = orcas.filter((o) => !ehPedido(o) && inWin(new Date(o.created_at).getTime()));
        const conversao = orcamentosJanela.length
          ? Number(((aprovOrcas.size / orcamentosJanela.length) * 100).toFixed(1))
          : 0;
        
        return {
          financeiro: {
            pedidos: financeiroLinhas,
            totais: fin
          },
          recebidos: {
            linhas: recebidosLinhas,
            totais: { total: totalRecebidos, qtde: recebidosLinhas.length }
          },
          parcelas: {
            linhas: parcelasLinhas,
            totais: parcelasTot
          },
          funil: {
            transicoes,
            aprovacoes: aprovOrcas.size,
            media_dias_aprovacao: mediaDiasAprov,
            orcamentos_janela: orcamentosJanela.length,
            conversao
          }
        };
        """
      timeout = 10
    } as $relatorio
  }

  response = $relatorio
  tags = ["relatorios", "novo-sis"]
  guid = "relatorio-orcakap-0001"
}