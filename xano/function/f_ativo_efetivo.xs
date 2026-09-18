// Retorna `false` se o usuário OU qualquer ancestral (vendedor_pai_id) estiver
// inativo (`ativo=false`). Desativar um "pai" bloqueia toda a árvore; reativar
// restaura (não mexe nos flags individuais). admin_geral também é avaliado.
function f_ativo_efetivo {
  input {
    int user_id? {
      table = "User"
    }
  }

  stack {
    db.query User {
      return = {type: "list"}
      output = ["id", "vendedor_pai_id", "ativo"]
    } as $usuarios
  
    var $uid {
      value = $input.user_id
    }
  
    api.lambda {
      code = """
        const id = Number($var.uid) || 0;
        const users = $var.usuarios || [];
        const byId = {};
        users.forEach((u) => { byId[Number(u.id)] = u; });
        let cur = byId[id];
        if (!cur) return { ok: false };
        let guard = 0;
        while (cur && guard < 50) {
          if (cur.ativo === false) return { ok: false };
          const pai = Number(cur.vendedor_pai_id) || 0;
          cur = pai > 0 ? byId[pai] : null;
          guard += 1;
        }
        return { ok: true };
        """
      timeout = 5
    } as $res
  }

  response = $res.ok
  tags = ["usuario", "ativo", "f3"]
  guid = "f-ativo-efetivo-0001"
}