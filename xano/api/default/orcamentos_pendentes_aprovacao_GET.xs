// Orçamentos de filhos com desconto acima do limite aguardando aprovação do pai.
// Visão: vendedor_master vê os pontas diretos; admin vê Master + pontas (netos);
// admin_geral vê todos. Retorna linhas leves p/ lista e aprovação.
query orcamentos_pendentes_aprovacao verb=GET {
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
  
    db.query Orca {
      where = $db.Orca.desconto_aprovado == false && $db.Orca.desconto > 0
      sort = {created_at: "desc"}
      return = {type: "list"}
      output = ["id", "cod_orca", "user_id", "desconto", "vnd_tot", "created_at"]
    } as $orcamentos
  
    db.query User {
      return = {type: "list"}
      output = ["id", "name_first", "role", "vendedor_pai_id"]
    } as $usuarios
  
    api.lambda {
      code = """
        const me = $var.me || {};
        const meRole = me.role || 'admin';
        const meId = Number(me.id) || 0;
        
        const users = {};
        ($var.usuarios || []).forEach((u) => {
          users[Number(u.id)] = u;
        });
        
        const podeVer = (ownerId) => {
          const id = Number(ownerId) || 0;
          if (meRole === 'admin_geral') return true;
          const owner = users[id];
          if (!owner) return false;
          const paiId = Number(owner.vendedor_pai_id) || 0;
          if (paiId === meId) return true;
          const pai = users[paiId];
          if (pai && pai.role === 'vendedor_master' && Number(pai.vendedor_pai_id) === meId) return true;
          return false;
        };
        
        const linhas = ($var.orcamentos || [])
          .filter((o) => o.desconto_status !== 'recusado' && podeVer(o.user_id))
          .map((o) => {
            const owner = users[Number(o.user_id)] || {};
            return {
              id: o.id,
              user_id: o.user_id,
              cod_orca: o.cod_orca || ('#' + o.id),
              vendedor: owner.name_first || ('Vendedor ' + o.user_id),
              venda: Number(o.vnd_tot) || 0,
              desconto: Number(o.desconto) || 0,
              data: o.created_at ? new Date(o.created_at).toISOString().slice(0, 10) : ''
            };
          });
        
        return { linhas };
        """
      timeout = 10
    } as $resumo
  }

  response = $resumo
  tags = ["orcamento", "f3"]
  guid = "orcamentos-pendentes-aprovacao-f3-0001"
}