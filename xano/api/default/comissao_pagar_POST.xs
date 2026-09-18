// Marca uma comissão como paga (data_pagamento = hoje). Pai do vendedor ou admin_geral.
query comissao_pagar verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int comissao_id? {
      table = "Comissao"
    }
  }

  stack {
    // Reforço: bloqueia quem foi desativado (o próprio ou um "pai") após o login
    function.run f_ativo_efetivo {
      input = {user_id: $auth.id}
    } as $ativoEfetivo
  
    precondition ($ativoEfetivo) {
      error_type = "accessdenied"
      error = "Conta inativa. Fale com o administrador."
    }
  
    db.get Comissao {
      field_name = "id"
      field_value = $input.comissao_id
    } as $comissao
  
    precondition ($comissao != null) {
      error_type = "notfound"
      error = "Comissão não encontrada."
    }
  
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
  
    db.query User {
      return = {type: "list"}
      output = ["id", "vendedor_pai_id"]
    } as $usuarios
  
    // Paga a empresa (admin/admin_geral ancestral) ou o admin_geral do sistema.
    // O vendedor_master NÃO paga (só a empresa dona da árvore).
    api.lambda {
      code = """
        const meId = Number($var.me.id) || 0;
        const meRole = $var.me.role || 'admin';
        const donoId = Number($var.comissao.user_id) || 0;
        const users = $var.usuarios || [];
        const parentOf = {};
        users.forEach((u) => {
          parentOf[Number(u.id)] = Number(u.vendedor_pai_id) || 0;
        });
        let pode = meRole === 'admin_geral';
        if (!pode && (meRole === 'admin' || meRole === 'admin_geral')) {
          let cur = parentOf[donoId] || 0;
          let guard = 0;
          while (cur > 0 && guard < 50) {
            if (cur === meId) {
              pode = true;
              break;
            }
            cur = parentOf[cur] || 0;
            guard += 1;
          }
        }
        return { pode };
        """
      timeout = 10
    } as $podePagar
  
    precondition ($podePagar.pode) {
      error_type = "accessdenied"
      error = "Você não pode pagar esta comissão."
    }
  
    db.edit Comissao {
      field_name = "id"
      field_value = $input.comissao_id
      enforce_hidden_fields = false
      data = {status: "paga", data_pagamento: "today"}
    } as $editada
  }

  response = $editada
  tags = ["comissoes", "f3"]
  guid = "comissao-pagar-f3-0001"
}