// Comissões (F3 Fase A): lista por período. admin → filhos; admin_geral → todos;
// vendedor → só as dele. Params opcionais mes_inicio/periodo (default = todos).
query comissoes verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    text mes_inicio?
    text periodo?
  }

  stack {
    db.get User {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "role"]
    } as $me
  
    // Serviço de comissões (plano). admin_geral (sistema) sempre passa.
    function.run f_tem_comissoes {
      input = {user_id: $auth.id}
    } as $temComissoes
  
    precondition (($me.role == "admin_geral") || ($temComissoes)) {
      error_type = "accessdenied"
      error = "Sem acesso a esta funcionalidade."
    }
  
    db.query Comissao {
      join = {
        Orca : {table: "Orca", where: $db.Comissao.orca_id == $db.Orca.id}
        UserV: {
          table: "User"
          type : "left"
          where: $db.Comissao.user_id == $db.UserV.id
        }
      }
    
      sort = {created_at: "desc"}
      eval = {
        cod_orca      : $db.Orca.cod_orca
        vendedor_nome : $db.UserV.name_first
        vendedor_pai  : $db.UserV.vendedor_pai_id
        orca_user_id  : $db.Orca.user_id
        orca_eh_pedido: $db.Orca.eh_pedido
      }
    
      return = {type: "list"}
      output = [
        "id"
        "user_id"
        "orca_id"
        "percentual"
        "lucro_real_base"
        "base_valor"
        "tipo"
        "valor"
        "status"
        "data_pagamento"
        "created_at"
        "cod_orca"
        "vendedor_nome"
        "vendedor_pai"
        "orca_user_id"
        "orca_eh_pedido"
      ]
    } as $comissoes
  
    var $mesInicio {
      value = $input.mes_inicio
    }
  
    var $periodo {
      value = $input.periodo
    }
  
    // Todos os usuários (id + pai) para calcular a árvore/ancestralidade no lambda.
    db.query User {
      return = {type: "list"}
      output = ["id", "vendedor_pai_id"]
    } as $usuarios
  
    api.lambda {
      code = """
        const me = $var.me || {};
        const meRole = me.role || 'admin';
        const meId = Number(me.id) || 0;
        
        const hoje = new Date();
        hoje.setHours(0, 0, 0, 0);
        
        const rawMes = String($var.mesInicio || '').trim();
        const mes = rawMes || (hoje.getFullYear() + '-' + String(hoje.getMonth() + 1).padStart(2, '0'));
        const periodo = String($var.periodo || 'todos').trim();
        const N = { mensal: 1, trimestral: 3, semestral: 6, anual: 12 }[periodo] || 0;
        
        const parts = mes.split('-').map(Number);
        const baseAno = parts[0] || hoje.getFullYear();
        const baseMes = parts[1] || hoje.getMonth() + 1;
        
        let iniMs = -Infinity;
        let fimMs = Infinity;
        if (N > 0) {
          iniMs = new Date(baseAno, baseMes - 1, 1).getTime();
          fimMs = new Date(baseAno, baseMes - 1 + N, 1).getTime();
        }
        
        const todas = $var.comissoes || [];
        const usuarios = $var.usuarios || [];
        const childrenOf = {};
        usuarios.forEach((u) => {
          const p = Number(u.vendedor_pai_id) || 0;
          if (p > 0) (childrenOf[p] = childrenOf[p] || []).push(Number(u.id));
        });
        const descendentes = (id) => {
          const set = new Set();
          const fila = [id];
          while (fila.length) {
            const cur = fila.pop();
            for (const c of childrenOf[cur] || []) {
              if (!set.has(c)) {
                set.add(c);
                fila.push(c);
              }
            }
          }
          return set;
        };
        const meus =
          meRole === 'admin' || meRole === 'vendedor_master' ? descendentes(meId) : null;
        
        const linhas = todas
          .filter((c) => {
            const dono = Number(c.user_id) || 0;
            if (meRole === 'vendedor') {
              if (dono !== meId) return false;
            } else if (meRole !== 'admin_geral') {
              if (dono !== meId && !(meus && meus.has(dono))) return false;
            }
            const ts = new Date(c.created_at).getTime();
            return !isNaN(ts) && ts >= iniMs && ts < fimMs;
          })
          .map((c) => ({
            id: c.id,
            user_id: c.user_id,
            vendedor: c.vendedor_nome || ('Vendedor ' + c.user_id),
            cod_orca: c.cod_orca || ('#' + c.orca_id),
            orca_id: c.orca_id,
            percentual: Number(c.percentual) || 0,
            base: Number(c.base_valor ?? c.lucro_real_base) || 0,
            tipo: c.tipo === 'override' ? 'override' : 'vendedor',
            valor: Number(c.valor) || 0,
            status: c.status === 'paga' ? 'paga' : 'calculada',
            data_pagamento: c.data_pagamento || null,
            data: c.created_at ? new Date(c.created_at).toISOString().slice(0, 10) : '',
          }));
        
        const totais = { calculada: { qtd: 0, total: 0 }, paga: { qtd: 0, total: 0 } };
        linhas.forEach((l) => {
          const t = totais[l.status];
          t.qtd += 1;
          t.total += l.valor;
        });
        totais.calculada.total = Number(totais.calculada.total.toFixed(2));
        totais.paga.total = Number(totais.paga.total.toFixed(2));
        
        return { linhas, totais };
        """
      timeout = 10
    } as $resumo
  }

  response = $resumo
  tags = ["comissoes", "f3"]
  guid = "comissoes-f3-0001"
}