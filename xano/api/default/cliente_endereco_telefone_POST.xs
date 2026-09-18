// Inserir um cliente novo seu endereço e telefone
query Cliente_Endereco_Telefone verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    text tipo_pessoa? filters=trim
    text razao_social? filters=trim
    text nome_fantasia? filters=trim
    text contato? filters=trim
    text cpf? filters=trim
    text cnpj? filters=trim
    text inscricao_estadual? filters=trim
    bool contribui_icms?
    bool isento?
    text observacao? filters=trim
    email "e-mail"?
    text endereco? filters=trim
    text numero? filters=trim
    text complemento? filters=trim
    text cep? filters=trim
    text bairro? filters=trim
    text cidade? filters=trim
    text estado? filters=trim
    text[] telefone?
    int ramo_id? {
      table = "Ramo"
    }
  
    int mercado_id? {
      table = "Mercado"
    }
  
    int regime_id? {
      table = "Regime"
    }
  
    int beneficio_fiscal_id? {
      table = "Beneficio_Fiscal"
    }
  
    int[] tipotelefone?
    object[] objphone? {
      schema {
        text telefone? filters=trim
        int tipo?
      }
    }
  
    text nome_cpf? filters=trim
  }

  stack {
    var $TipoEndereco {
      value = "Comercial"
    }
  
    conditional {
      if ("CNPJ"|is_null) {
        var.update $TipoEndereco {
          value = "Residencial"
        }
      }
    }
  
    precondition (($input.razao_social != null && $input.razao_social != "") || ($input.nome_cpf != null && $input.nome_cpf != "")) {
      error_type = "badrequest"
      error = "Informe a Razão Social (ou o Nome, para CPF)."
    }
  
    precondition (($input.contato != null && $input.contato != "")) {
      error_type = "badrequest"
      error = "Informe o Contato."
    }
  
    precondition (($input.objphone|count) > 0) {
      error_type = "badrequest"
      error = "Informe ao menos um telefone."
    }
  
    db.transaction {
      stack {
        db.add Cliente {
          enforce_hidden_fields = false
          data = {
            created_at         : "now"
            tipo_pessoa        : $input.tipo_pessoa
            razao_social       : $input.razao_social
            nome_fantasia      : $input.nome_fantasia
            contato            : $input.contato
            cpf                : $input.cpf
            nome_cpf           : $input.nome_cpf
            cnpj               : $input.cnpj
            inscricao_estadual : $input.inscricao_estadual
            "e-mail"           : $input["e-mail"]
            contribui_icms     : $input.contribui_icms
            isento             : $input.isento
            observacao         : $input.observacao
            user_id            : $auth.id
            beneficio_fiscal_id: $input.beneficio_fiscal_id
            mercado_id         : $input.mercado_id
            ramo_id            : $input.ramo_id
            regime_id          : $input.regime_id
          }
        } as $Cliente_2
      
        db.add Endereco_Cliente {
          enforce_hidden_fields = false
          data = {
            created_at : "now"
            cliente_id : $Cliente_2.id
            Tipo       : $TipoEndereco
            endereco   : $input.endereco
            numero     : $input.numero
            complemento: $input.complemento
            cep        : $input.cep
            bairro     : $input.bairro
            cidade     : $input.cidade
            estado     : $input.estado
          }
        } as $Endereco_Cliente_2
      
        foreach ($input.objphone) {
          each as $item {
            db.add Telefone_Cliente {
              enforce_hidden_fields = false
              data = {
                created_at      : "now"
                telefone        : $item.telefone
                cliente_id      : $Cliente_2.id
                tipo_telefone_id: $item.tipo
              }
            } as $Telefone_Cliente_2
          }
        }
      }
    }
  }

  response = {
    Endereco_Cliente_2: $Endereco_Cliente_2
    Telefone_Cliente_2: $Telefone_Cliente_2
    Cliente_2         : $Cliente_2
  }

  guid = "O3YNCDwfv6u6WnpwHVrlTF2ToG8"
}