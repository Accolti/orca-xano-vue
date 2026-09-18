// EDIÇÃO um cliente - endereço - telefone
query Cliente_Endereco_Telefone verb=PATCH {
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
  
    // Passar um objeto com tipo (inteiro), telefone (texto ) e telefone_id (inteiro)
    object[] objphone? {
      schema {
        text telefone? filters=trim
        text tipo? filters=trim
        int telefone_id?
      }
    }
  
    int cliente_id? {
      table = "Cliente"
    }
  
    int endereco_cliente_id? {
      table = "Endereco_Cliente"
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
  
    // Documento: o tipo é definido por tipo_pessoa (persistido explicitamente,
    // pois CNPJ pode não ter número). Quando um tipo está presente, o outro campo
    // é limpo — evita estado duplo e garante a detecção correta no load.
    var $novo_cpf {
      value = $input.cpf
    }
  
    var $novo_cnpj {
      value = $input.cnpj
    }
  
    var $novo_nome_cpf {
      value = $input.nome_cpf
    }
  
    conditional {
      if (($input.tipo_pessoa == "CNPJ") || (($input.cnpj != null) && ($input.cnpj != ""))) {
        var.update $novo_cpf {
          value = ""
        }
      
        var.update $novo_nome_cpf {
          value = ""
        }
      }
    
      else {
        conditional {
          if (($input.tipo_pessoa == "CPF") || (($input.cpf != null) && ($input.cpf != ""))) {
            var.update $novo_cnpj {
              value = ""
            }
          }
        }
      }
    }
  
    db.transaction {
      stack {
        db.edit Cliente {
          field_name = "id"
          field_value = $input.cliente_id
          enforce_hidden_fields = false
          data = {
            tipo_pessoa        : $input.tipo_pessoa
            razao_social       : $input.razao_social
            nome_fantasia      : $input.nome_fantasia
            contato            : $input.contato
            cpf                : $novo_cpf
            cnpj               : $novo_cnpj
            nome_cpf           : $novo_nome_cpf
            inscricao_estadual : $input.inscricao_estadual
            "e-mail"           : $input["e-mail"]
            contribui_icms     : $input.contribui_icms
            isento             : $input.isento
            observacao         : $input.observacao
            beneficio_fiscal_id: $input.beneficio_fiscal_id
            mercado_id         : $input.mercado_id
            ramo_id            : $input.ramo_id
            regime_id          : $input.regime_id
          }
        } as $Cliente
      
        conditional {
          if (($input.endereco_cliente_id != null) && ($input.endereco_cliente_id != "")) {
            db.edit Endereco_Cliente {
              field_name = "id"
              field_value = $input.endereco_cliente_id
              enforce_hidden_fields = false
              data = {
                cliente_id : $input.cliente_id
                endereco   : $input.endereco
                numero     : $input.numero
                complemento: $input.complemento
                cep        : $input.cep
                bairro     : $input.bairro
                cidade     : $input.cidade
                estado     : $input.estado
              }
            } as $Endereco_Cliente
          }
        
          else {
            conditional {
              if (`($input.endereco|first_notempty != "") || ($input.cep|first_notempty != "")`) {
                db.add Endereco_Cliente {
                  enforce_hidden_fields = false
                  data = {
                    created_at : "now"
                    cliente_id : $input.cliente_id
                    Tipo       : $TipoEndereco
                    endereco   : $input.endereco
                    numero     : $input.numero
                    complemento: $input.complemento
                    cep        : $input.cep
                    bairro     : $input.bairro
                    cidade     : $input.cidade
                    estado     : $input.estado
                  }
                } as $Endereco_Cliente
              }
            }
          }
        }
      
        foreach ($input.objphone) {
          each as $item {
            // IF para Inserir se não tiver o telefone
            conditional {
              if (($item.telefone_id == null) || ($item.telefone_id == 0)) {
                db.add Telefone_Cliente {
                  enforce_hidden_fields = false
                  data = {
                    created_at      : "now"
                    cliente_id      : $input.cliente_id
                    tipo_telefone_id: $item.tipo
                    telefone        : $item.telefone
                  }
                } as $Telefone_Cliente
              }
            
              else {
                // IF para Deletar o o telefone 
                conditional {
                  if ($item.telefone == null && $item.tipo == null && $item.telefone_id > 0) {
                    db.del Telefone_Cliente {
                      field_name = "id"
                      field_value = $item.telefone_id
                    }
                  }
                
                  else {
                    db.edit Telefone_Cliente {
                      field_name = "id"
                      field_value = $item.telefone_id
                      enforce_hidden_fields = false
                      data = {telefone: $item.telefone, tipo_telefone_id: $item.tipo}
                    } as $Telefone_Cliente
                  }
                }
              }
            }
          }
        }
      
        db.query Telefone_Cliente {
          where = $db.Telefone_Cliente.cliente_id == $input.cliente_id
          return = {type: "list"}
        } as $Telefone_Cliente
      }
    }
  }

  response = {
    Endereco_Cliente: $Endereco_Cliente
    Telefone_Cliente: $Telefone_Cliente
    Cliente         : $Cliente
  }

  guid = "FWUjQ7pGUYSmMm1Ls2jSxbqCYsw"
}