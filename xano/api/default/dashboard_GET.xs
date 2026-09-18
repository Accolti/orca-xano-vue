// novo-sis: resumo do dashboard do usuário com filtro de período.
// Params opcionais: mes_inicio (YYYY-MM, default = mês corrente) e
// periodo (todos|mensal|trimestral|semestral|anual, default = todos).
// - Orçamentos/Pedidos/Status: criados a partir do 1º dia do mês até o fim da janela.
// - Boletos Vencidos: não pagos com vencimento antes de hoje (sempre, independente do período).
// - Boletos a Vencer: não pagos, venc >= hoje e venc < fim da janela.
// - Boletos Pagos: pagos com vencimento < fim da janela.
// - serie: meses (mes, vendas, recebido, areceber) para os gráficos.
//   periodo != todos → N meses a partir de mes_inicio; todos → todo o histórico
//   (do 1º registro até o último relevante — mês atual ou último vencimento).
// Contagem em JS (mesma fonte/regra do Controle Financeiro), sem a função legada fDadosDashBoard.
query dashboard verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    text mes_inicio?
    text periodo?
  }

  stack {
    db.query Orca {
      where = $db.Orca.user_id == $auth.id
      return = {type: "list"}
      output = ["id", "status", "eh_pedido", "created_at", "vnd_tot"]
    } as $orcamentos
  
    db.query Boleto {
      where = $db.Boleto.user_id == $auth.id
      return = {type: "list"}
      output = ["id", "vencimento", "pagamento", "valor"]
    } as $parcelas
  
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
        const hojeMs = hoje.getTime();
        
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
        
        const ehPedido = (o) => o.eh_pedido === true || o.eh_pedido === 'true' || o.eh_pedido === 1 || o.eh_pedido === '1';
        
        const orcas = $var.orcamentos || [];
        let orcamentos = 0;
        let pedidos = 0;
        const funil = { RASCUNHO: 0, ENVIADO: 0, AGUARDANDO_RETORNO: 0, APROVADO: 0, RECUSADO: 0, CANCELADO: 0 };
        
        orcas.forEach((o) => {
          const ts = new Date(o.created_at).getTime();
          if (isNaN(ts) || ts < iniMs || ts >= fimMs) return;
          if (ehPedido(o)) {
            pedidos++;
          } else {
            orcamentos++;
            const s = o.status || 'RASCUNHO';
            funil[s] = (funil[s] || 0) + 1;
          }
        });
        
        const boletos = $var.parcelas || [];
        let boletosVencidos = 0;
        let boletosAVencer = 0;
        let boletosPagos = 0;
        
        boletos.forEach((b) => {
          const vencStr = b.vencimento ? String(b.vencimento).slice(0, 10) : null;
          const venc = vencStr ? new Date(vencStr + 'T00:00:00') : null;
          const vencMs = venc && !isNaN(venc.getTime()) ? venc.getTime() : null;
          const pago = Boolean(b.pagamento);
        
          if (pago) {
            if (vencMs !== null && vencMs < fimMs) boletosPagos++;
          } else {
            if (vencMs !== null && vencMs < hojeMs) {
              boletosVencidos++;
            } else if (vencMs !== null && vencMs >= hojeMs && vencMs < fimMs) {
              boletosAVencer++;
            }
          }
        });
        
        // ---------- Série mensal (gráficos) ----------
        const chaveMes = (d) => {
          const dt = new Date(d);
          if (isNaN(dt.getTime())) return null;
          return dt.getFullYear() + '-' + String(dt.getMonth() + 1).padStart(2, '0');
        };
        const cmpMes = (a, b) => (a.y !== b.y ? a.y - b.y : a.m - b.m);
        
        const mesesMap = {};
        orcas.forEach((o) => {
          if (o.created_at) mesesMap[chaveMes(o.created_at)] = true;
        });
        boletos.forEach((b) => {
          if (b.vencimento) mesesMap[chaveMes(b.vencimento)] = true;
          if (b.pagamento) mesesMap[chaveMes(b.pagamento)] = true;
        });
        
        const hojeMes = { y: hoje.getFullYear(), m: hoje.getMonth() };
        let ini, fim;
        if (N > 0) {
          ini = { y: baseAno, m: baseMes - 1 };
          fim = { y: baseAno, m: baseMes - 1 + N - 1 };
        } else {
          const lista = Object.keys(mesesMap).map((k) => {
            const p = k.split('-').map(Number);
            return { y: p[0], m: p[1] - 1 };
          });
          if (!lista.length) {
            ini = hojeMes;
            fim = hojeMes;
          } else {
            ini = lista.reduce((a, b) => (cmpMes(a, b) <= 0 ? a : b));
            fim = lista.reduce((a, b) => (cmpMes(a, b) >= 0 ? a : b));
            if (cmpMes(hojeMes, fim) > 0) fim = hojeMes;
          }
        }
        
        const serie = [];
        let y = ini.y;
        let m = ini.m;
        while (cmpMes({ y, m }, fim) <= 0) {
          const st = new Date(y, m, 1).getTime();
          const en = new Date(y, m + 1, 1).getTime();
          let vendas = 0;
          let recebido = 0;
          let areceber = 0;
        
          orcas.forEach((o) => {
            if (!ehPedido(o)) return;
            const ts = new Date(o.created_at).getTime();
            if (isNaN(ts) || ts < st || ts >= en) return;
            vendas += Number(o.vnd_tot) || 0;
          });
        
          boletos.forEach((b) => {
            const pago = Boolean(b.pagamento);
            const val = Number(b.valor) || 0;
            if (pago) {
              const pg = b.pagamento ? new Date(b.pagamento) : null;
              const pgt = pg && !isNaN(pg.getTime()) ? pg.getTime() : null;
              if (pgt !== null && pgt >= st && pgt < en) recebido += val;
            } else {
              const vencStr = b.vencimento ? String(b.vencimento).slice(0, 10) : null;
              const venc = vencStr ? new Date(vencStr + 'T00:00:00') : null;
              const vt = venc && !isNaN(venc.getTime()) ? venc.getTime() : null;
              if (vt !== null && vt >= st && vt < en) areceber += val;
            }
          });
        
          serie.push({
            mes: y + '-' + String(m + 1).padStart(2, '0'),
            vendas: Number(vendas.toFixed(2)),
            recebido: Number(recebido.toFixed(2)),
            areceber: Number(areceber.toFixed(2)),
          });
          m += 1;
          if (m > 11) {
            m = 0;
            y += 1;
          }
        }
        
        return {
          orcamentos: orcamentos,
          pedidos: pedidos,
          boletosVencidos: boletosVencidos,
          boletosAVencer: boletosAVencer,
          boletosPagos: boletosPagos,
          funil: funil,
          serie: serie,
        };
        """
      timeout = 10
    } as $resumo
  }

  response = $resumo
  tags = ["dashboard", "novo-sis"]
  guid = "dashboard-orcakap-0001"
}