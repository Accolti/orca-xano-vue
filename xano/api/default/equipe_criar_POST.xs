// Cria um vendedor (role vendedor, pai = quem está criando). Só admin/admin_geral/vendedor_master.
// vendedor_master só cria role "vendedor"; a criação de "vendedor_master" é restrita a admin/admin_geral.
query equipe_criar verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    text name_first? filters=trim
    text name_last? filters=trim
    email email?
    text password?
    decimal percentual_comissao?
  
    // "vendedor" (padrão) | "vendedor_master" (criação por admin/admin_geral)
    text role? filters=trim
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
  
    db.get User {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "role"]
    } as $me
  
    precondition ($me.role == "admin" || $me.role == "admin_geral" || $me.role == "vendedor_master") {
      error_type = "accessdenied"
      error = "Apenas administradores ou vendedores master podem criar vendedores."
    }
  
    // Serviço de comissões (plano). admin_geral (sistema) sempre passa.
    function.run f_tem_comissoes {
      input = {user_id: $auth.id}
    } as $temComissoes
  
    precondition (($me.role == "admin_geral") || ($temComissoes)) {
      error_type = "accessdenied"
      error = "Sem acesso a esta funcionalidade."
    }
  
    precondition (($input.name_first != null) && ($input.email != null) && ($input.password != null)) {
      error_type = "badrequest"
      error = "Informe nome, e-mail e senha inicial."
    }
  
    // Master só pode ser criado por admin/admin_geral
    precondition (($input.role != "vendedor_master") || ($me.role == "admin") || ($me.role == "admin_geral")) {
      error_type = "accessdenied"
      error = "Apenas administradores podem criar um Vendedor Master."
    }
  
    var $novo_role {
      value = "vendedor"
    }
  
    conditional {
      if ($input.role == "vendedor_master") {
        var.update $novo_role {
          value = "vendedor_master"
        }
      }
    }
  
    db.get User {
      field_name = "email"
      field_value = $input.email
    } as $existente
  
    precondition ($existente == null) {
      error_type = "badrequest"
      error = "Já existe um usuário com esse e-mail."
    }
  
    db.add User {
      enforce_hidden_fields = false
      data = {
        created_at         : "now"
        name               : $input.name_first|concat:$input.name_last:" "
        name_first         : $input.name_first
        name_last          : $input.name_last
        email              : $input.email
        password           : $input.password
        role               : $novo_role
        vendedor_pai_id    : $auth.id
        percentual_comissao: $input.percentual_comissao
        ativo              : true
      }
    } as $novo
  }

  response = {
    id                 : $novo.id
    name_first         : $novo.name_first
    name_last          : $novo.name_last
    email              : $novo.email
    role               : $novo.role
    percentual_comissao: $novo.percentual_comissao
  }

  tags = ["equipe", "f3"]
  guid = "equipe-criar-f3-0001"
}