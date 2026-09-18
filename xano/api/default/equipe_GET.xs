// Equipe (F3 fase inicial): vendedores do usuário.
// admin → filhos (vendedor_pai_id = auth.id); admin_geral → todos os usuários (exceto ele).
query equipe verb=GET {
  api_group = "Default"
  auth = "User"

  input {
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
  
    var $lista {
      value = []
    }
  
    conditional {
      if ($me.role == "admin_geral") {
        db.query User {
          where = $db.User.id != $auth.id
          sort = {created_at: "desc"}
          return = {type: "list"}
          output = [
            "id"
            "name"
            "name_first"
            "name_last"
            "email"
            "role"
            "vendedor_pai_id"
            "percentual_comissao"
            "ativo"
            "desconto_livre_perc"
            "desconto_max_perc"
            "plano"
            "created_at"
          ]
        } as $todos
      
        var.update $lista {
          value = $todos
        }
      }
    
      else {
        db.query User {
          where = $db.User.vendedor_pai_id == $auth.id
          sort = {created_at: "desc"}
          return = {type: "list"}
          output = [
            "id"
            "name"
            "name_first"
            "name_last"
            "email"
            "role"
            "vendedor_pai_id"
            "percentual_comissao"
            "ativo"
            "desconto_livre_perc"
            "desconto_max_perc"
            "plano"
            "created_at"
          ]
        } as $filhos
      
        var.update $lista {
          value = $filhos
        }
      }
    }
  
    // Ativo EFETIVO por membro (pai inativo bloqueia os filhos)
    db.query User {
      return = {type: "list"}
      output = ["id", "vendedor_pai_id", "ativo"]
    } as $mapaUsuarios
  
    api.lambda {
      code = """
        const lista = $var.lista || [];
        const users = $var.mapaUsuarios || [];
        const byId = {};
        users.forEach((u) => { byId[Number(u.id)] = u; });
        const efetivo = (id) => {
          let cur = byId[Number(id)];
          let guard = 0;
          while (cur && guard < 50) {
            if (cur.ativo === false) return false;
            const pai = Number(cur.vendedor_pai_id) || 0;
            cur = pai > 0 ? byId[pai] : null;
            guard += 1;
          }
          return true;
        };
        return { lista: lista.map((m) => ({ ...m, ativo_efetivo: efetivo(m.id) })) };
        """
      timeout = 5
    } as $res
  
    var.update $lista {
      value = $res.lista
    }
  }

  response = $lista
  tags = ["equipe", "f3"]
  guid = "equipe-get-f3-0001"
}