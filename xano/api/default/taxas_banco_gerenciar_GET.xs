// Lista as taxas da empresa (todos os canais, inclui inativas), as taxas GLOBAIS
// (padrão/fallback, somente leitura) e os provedores ativos, para a tela "Minhas taxas".
// Admin da empresa; admin_geral escolhe a conta (user_id).
query taxas_banco_gerenciar verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int user_id? {
      table = "User"
    }
  }

  stack {
    db.get User {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "role", "vendedor_pai_id"]
    } as $me
  
    // Admin: role explícita OU legado sem role e sem pai (dono da conta)
    precondition ($me.role == "admin" || $me.role == "admin_geral" || (($me.role == null || $me.role == "") && ($me.vendedor_pai_id == null || $me.vendedor_pai_id == 0))) {
      error_type = "accessdenied"
      error = "Apenas administradores gerenciam as taxas."
    }
  
    var $target_id {
      value = $auth.id
    }
  
    conditional {
      if (($me.role == "admin_geral") && ($input.user_id != null)) {
        var.update $target_id {
          value = $input.user_id
        }
      }
    }
  
    function.run f_empresa_id {
      input = {user_id: $target_id}
    } as $empresa_id
  
    db.query Taxa_Banco {
      join = {
        Provedor: {
          table: "Provedor"
          where: $db.Provedor.id == $db.Taxa_Banco.provedor_id
        }
      }
    
      where = $db.Taxa_Banco.user_id == $empresa_id
      sort = {Taxa_Banco.parcelas: "asc"}
      eval = {provedor: $db.Provedor.nome}
      return = {type: "list"}
      output = ["id", "provedor_id", "parcelas", "cc_taxa", "provedor", "canal", "origem", "ativo", "user_id", "atualizado_em"]
    } as $taxas
  
    // Taxas globais (padrão/fallback) — somente leitura na tela
    db.query Taxa_Banco {
      join = {
        Provedor: {
          table: "Provedor"
          where: $db.Provedor.id == $db.Taxa_Banco.provedor_id
        }
      }
    
      where = $db.Taxa_Banco.ativo == true && ($db.Taxa_Banco.user_id == null || $db.Taxa_Banco.user_id == 0)
      sort = {Taxa_Banco.parcelas: "asc"}
      eval = {provedor: $db.Provedor.nome}
      return = {type: "list"}
      output = ["id", "provedor_id", "parcelas", "cc_taxa", "provedor", "canal", "origem", "ativo", "user_id"]
    } as $taxas_globais
  
    db.query Provedor {
      where = $db.Provedor.ativo == true
      sort = {Provedor.nome: "asc"}
      return = {type: "list"}
      output = ["id", "nome", "canal_default", "metodo", "url_taxas"]
    } as $provedores
  }

  response = {
    taxas         : $taxas
    taxas_globais : $taxas_globais
    provedores    : $provedores
    empresa_id    : $empresa_id
    papel         : $me.role
  }

  tags = ["novo-sis", "taxas"]
  guid = "taxas-banco-gerenciar-0001"
}
